-- =========================================================
-- TripMate
-- Migration 022: Secure Atomic Checkout
-- =========================================================


-- =========================================================
-- 1. BOOKING ITEM PRICE ADJUSTMENTS
--
-- Needed for:
--   - nightly room price overrides
--   - accommodation meal-plan charges
-- =========================================================

alter table public.booking_items
add column if not exists price_adjustment_total numeric(14,2)
not null default 0;


-- Rebuild line_total so adjustments are included
alter table public.booking_items
drop column if exists line_total;

alter table public.booking_items
add column line_total numeric(14,2)
generated always as (
  (unit_price_snapshot * billing_units)
  + price_adjustment_total
  - discount_total
  + tax_total
) stored;


alter table public.booking_items
drop constraint if exists
booking_items_nonnegative_final_total_check;

alter table public.booking_items
add constraint
booking_items_nonnegative_final_total_check
check (
  (
    unit_price_snapshot * billing_units
  )
  + price_adjustment_total
  - discount_total
  + tax_total
  >= 0
);



-- =========================================================
-- 2. ONLY ONE ACTIVE BOOKING PER TRIP
--
-- Cancelled / failed / expired bookings allow a new checkout.
-- =========================================================

create unique index if not exists
one_active_booking_per_trip_idx
on public.bookings(trip_id)
where status in (
  'pending',
  'confirmed',
  'partially_cancelled',
  'completed'
);



-- =========================================================
-- 3. ALLOW BOOKING WORKFLOW TO MOVE
-- driver_selected -> confirmed
-- =========================================================

create or replace function public.protect_driver_trip_status()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  workflow_action text;
begin

  if new.status is not distinct from old.status then
    return new;
  end if;


  workflow_action :=
    current_setting(
      'tripmate.transport_workflow',
      true
    );


  if
    new.status in (
      'requesting_driver',
      'driver_selected'
    )

    or old.status in (
      'requesting_driver',
      'driver_selected'
    )
  then

    if workflow_action is null
       or workflow_action not in (
         'open_request',
         'accept_bid',
         'cancel_request',
         'confirm_booking'
       ) then

      raise exception
        'Driver-related trip status must use a secure workflow';

    end if;

  end if;


  return new;
end;
$$;



-- =========================================================
-- 4. SECURE CHECKOUT
--
-- Entire function is atomic:
--
-- Either:
--   everything succeeds
--
-- Or:
--   everything rolls back
-- =========================================================

create or replace function public.checkout_trip(
  p_trip_id bigint
)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare

  v_trip public.trips%rowtype;
  v_booking public.bookings%rowtype;
  v_cart public.trip_cart_items%rowtype;

  v_booking_currency text;

  v_subtotal numeric(14,2) := 0;

  v_booking_item_id bigint;


  -- -------------------------------------------------------
  -- Room variables
  -- -------------------------------------------------------

  v_room record;

  v_room_availability record;

  v_room_base_price numeric(14,2);

  v_room_actual_total numeric(14,2);

  v_room_adjustment numeric(14,2);

  v_room_daily_price numeric(14,2);

  v_room_capacity integer;

  v_room_reserved integer;

  v_room_nights integer;

  v_stay_date date;

  v_room_adults integer;
  v_room_children integer;

  v_assigned_adults integer := 0;
  v_assigned_children integer := 0;
  v_room_item_count integer := 0;

  v_nightly_rates jsonb;


  -- -------------------------------------------------------
  -- Meal-plan variables
  -- -------------------------------------------------------

  v_meal_plan record;

  v_meal_plan_total numeric(14,2);


  -- -------------------------------------------------------
  -- Other service variables
  -- -------------------------------------------------------

  v_food record;
  v_buffet record;
  v_restaurant record;
  v_attraction record;
  v_activity record;

  v_current_price numeric(14,2);


  -- -------------------------------------------------------
  -- Activity availability variables
  -- -------------------------------------------------------

  v_activity_slot record;

  v_activity_slot_count integer;

  v_activity_reserved integer;


  -- -------------------------------------------------------
  -- Transport variables
  -- -------------------------------------------------------

  v_transport record;

  v_transport_count integer := 0;

  v_cart_count integer := 0;

begin

  -- =======================================================
  -- A. AUTHENTICATION
  -- =======================================================

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;



  -- =======================================================
  -- B. LOCK TRIP
  --
  -- This also serializes simultaneous checkout attempts
  -- for the same trip.
  -- =======================================================

  select *
  into v_trip
  from public.trips
  where id = p_trip_id
  for update;


  if not found then
    raise exception 'Trip does not exist';
  end if;


  if v_trip.traveler_id <> auth.uid() then
    raise exception 'You do not own this trip';
  end if;


  if v_trip.status not in (
    'planning',
    'driver_selected'
  ) then

    raise exception
      'Trip is not in a valid state for checkout';

  end if;



  -- =======================================================
  -- C. BLOCK UNRESOLVED TRANSPORT REQUESTS
  -- =======================================================

  if exists (
    select 1
    from public.transport_requests tr
    where tr.trip_id = p_trip_id
      and tr.status in (
        'draft',
        'open'
      )
  ) then

    raise exception
      'Complete or cancel the active transport request before checkout';

  end if;



  -- =======================================================
  -- D. LOCK CART
  -- =======================================================

  perform 1
  from public.trip_cart_items
  where trip_id = p_trip_id
  for update;


  select count(*)
  into v_cart_count
  from public.trip_cart_items
  where trip_id = p_trip_id;



  -- =======================================================
  -- E. CHECK FOR SELECTED TRANSPORT
  -- =======================================================

  select count(*)
  into v_transport_count
  from public.transport_requests tr
  join public.driver_bids db
    on db.id = tr.selected_bid_id
  where tr.trip_id = p_trip_id
    and tr.status = 'driver_selected'
    and db.status = 'accepted';


  if v_cart_count = 0
     and v_transport_count = 0 then

    raise exception
      'Trip cart is empty and no transport has been selected';

  end if;


  if v_trip.status = 'driver_selected'
     and v_transport_count = 0 then

    raise exception
      'Trip indicates a selected driver but no valid accepted bid exists';

  end if;



  -- =======================================================
  -- F. BOOKING CURRENCY
  -- =======================================================

  v_booking_currency :=
    coalesce(v_trip.currency, 'LKR');



  -- =======================================================
  -- G. CREATE TEMPORARY PENDING BOOKING
  -- =======================================================

  insert into public.bookings (
    traveler_id,
    trip_id,
    status,
    payment_status,
    currency,
    subtotal,
    discount_total,
    service_fee_total,
    tax_total
  )
  values (
    auth.uid(),
    p_trip_id,
    'pending',
    'unpaid',
    v_booking_currency,
    0,
    0,
    0,
    0
  )
  returning *
  into v_booking;



  -- =======================================================
  -- H. PROCESS CART ITEMS
  -- =======================================================

  for v_cart in

    select *
    from public.trip_cart_items
    where trip_id = p_trip_id
    order by id
    for update

  loop


    -- =====================================================
    -- ROOM
    -- =====================================================

    if v_cart.item_type = 'room' then

      v_room_item_count :=
        v_room_item_count + 1;


      if v_cart.check_in_date is null
         or v_cart.check_out_date is null then

        raise exception
          'Room booking requires check-in and check-out dates';

      end if;


      if v_cart.check_out_date
         <= v_cart.check_in_date then

        raise exception
          'Room check-out must be after check-in';

      end if;


      if v_cart.check_in_date < v_trip.start_date
         or v_cart.check_out_date > v_trip.end_date + 1 then

        raise exception
          'Room stay must be within the trip date range';

      end if;


      -- Lock room type.
      -- All checkout attempts for the same room type
      -- serialize here, preventing race-condition overbooking.
      select
        rt.id,
        rt.accommodation_id,
        rt.name,
        rt.max_adults,
        rt.max_children,
        rt.max_guests,
        rt.base_price_per_night,
        rt.currency,
        rt.total_rooms,
        rt.is_active,
        a.name as accommodation_name
      into v_room
      from public.room_types rt
      join public.accommodations a
        on a.id = rt.accommodation_id
      where rt.id = v_cart.room_type_id
      for update of rt;


      if not found then
        raise exception 'Room type does not exist';
      end if;


      if v_room.is_active is not true
         or not public.is_room_type_public(v_room.id) then

        raise exception
          'Selected room is no longer available';

      end if;


      if v_room.currency <> v_booking_currency then

        raise exception
          'Mixed booking currencies are not currently supported';

      end if;


      -- ---------------------------------------------------
      -- Guest allocation
      --
      -- Frontend must store per-room-line guest allocation:
      --
      -- {
      --   "adult_count": 2,
      --   "child_count": 1
      -- }
      -- ---------------------------------------------------

      if not (
        v_cart.selection_details ? 'adult_count'
      )
      or not (
        v_cart.selection_details ? 'child_count'
      ) then

        raise exception
          'Room selection must include adult_count and child_count';

      end if;


      begin

        v_room_adults :=
          (v_cart.selection_details ->> 'adult_count')::integer;

        v_room_children :=
          (v_cart.selection_details ->> 'child_count')::integer;

      exception
        when invalid_text_representation then
          raise exception
            'Room guest counts must be valid integers';
      end;


      if v_room_adults < 0
         or v_room_children < 0 then

        raise exception
          'Room guest counts cannot be negative';

      end if;


      if
        v_room.max_adults is not null
        and v_room_adults >
            (v_room.max_adults * v_cart.quantity)
      then

        raise exception
          'Room selection exceeds adult capacity';

      end if;


      if
        v_room.max_children is not null
        and v_room_children >
            (v_room.max_children * v_cart.quantity)
      then

        raise exception
          'Room selection exceeds child capacity';

      end if;


      if
        v_room.max_guests is not null
        and (
          v_room_adults + v_room_children
        ) >
        (
          v_room.max_guests * v_cart.quantity
        )
      then

        raise exception
          'Room selection exceeds total guest capacity';

      end if;


      v_assigned_adults :=
        v_assigned_adults + v_room_adults;

      v_assigned_children :=
        v_assigned_children + v_room_children;


      v_room_nights :=
        v_cart.check_out_date
        - v_cart.check_in_date;


      v_room_base_price :=
        v_room.base_price_per_night;


      v_room_actual_total := 0;

      v_meal_plan_total := 0;


      -- ---------------------------------------------------
      -- Check every night
      -- ---------------------------------------------------

      for v_stay_date in

        select
          generate_series(
            v_cart.check_in_date,
            v_cart.check_out_date - 1,
            interval '1 day'
          )::date

      loop

        select
          ra.available_rooms,
          ra.price_override,
          ra.minimum_stay_nights,
          ra.is_closed
        into v_room_availability
        from public.room_availability ra
        where ra.room_type_id = v_room.id
          and ra.date = v_stay_date
        for update;


        if found then

          if v_room_availability.is_closed is true then

            raise exception
              'Room is closed on %',
              v_stay_date;

          end if;


          if
            v_room_availability.minimum_stay_nights
              is not null

            and v_room_nights
                < v_room_availability.minimum_stay_nights
          then

            raise exception
              'Minimum stay requirement is not satisfied';

          end if;


          v_room_capacity :=
            v_room_availability.available_rooms;


          v_room_daily_price :=
            coalesce(
              v_room_availability.price_override,
              v_room_base_price
            );

        else

          v_room_capacity :=
            v_room.total_rooms;

          v_room_daily_price :=
            v_room_base_price;

        end if;


        select
          coalesce(
            sum(rir.rooms_reserved),
            0
          )
        into v_room_reserved
        from public.room_inventory_reservations rir
        where rir.room_type_id = v_room.id
          and rir.stay_date = v_stay_date
          and rir.status = 'reserved';


        if
          v_room_reserved + v_cart.quantity
          > v_room_capacity
        then

          raise exception
            'Not enough rooms available on %',
            v_stay_date;

        end if;


        v_room_actual_total :=
          v_room_actual_total
          + (
            v_room_daily_price
            * v_cart.quantity
          );

      end loop;



      -- ---------------------------------------------------
      -- Optional accommodation meal plan
      -- ---------------------------------------------------

      if v_cart.accommodation_meal_plan_id
         is not null then

        select
          amp.id,
          amp.accommodation_id,
          amp.price_per_adult,
          amp.price_per_child,
          amp.currency,
          amp.is_available
        into v_meal_plan
        from public.accommodation_meal_plans amp
        where amp.id =
              v_cart.accommodation_meal_plan_id;


        if not found then
          raise exception
            'Accommodation meal plan does not exist';
        end if;


        if v_meal_plan.accommodation_id
           <> v_room.accommodation_id then

          raise exception
            'Meal plan does not belong to selected accommodation';

        end if;


        if v_meal_plan.is_available is not true then

          raise exception
            'Selected meal plan is unavailable';

        end if;


        if v_meal_plan.currency
           <> v_booking_currency then

          raise exception
            'Mixed booking currencies are not currently supported';

        end if;


        v_meal_plan_total :=
          (
            coalesce(
              v_meal_plan.price_per_adult,
              0
            )
            * v_room_adults

            +

            coalesce(
              v_meal_plan.price_per_child,
              0
            )
            * v_room_children
          )
          * v_room_nights;

      end if;



      -- ---------------------------------------------------
      -- Build exact nightly-rate snapshot
      -- ---------------------------------------------------

      select
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'date',
              gs.stay_date,
              'price_per_room',
              coalesce(
                ra.price_override,
                v_room_base_price
              )
            )
            order by gs.stay_date
          ),
          '[]'::jsonb
        )
      into v_nightly_rates

      from (
        select
          generate_series(
            v_cart.check_in_date,
            v_cart.check_out_date - 1,
            interval '1 day'
          )::date as stay_date
      ) gs

      left join public.room_availability ra
        on ra.room_type_id = v_room.id
       and ra.date = gs.stay_date;



      -- Base subtotal uses normal room price.
      -- Adjustment stores:
      --   nightly overrides + meal-plan charge.
      v_room_adjustment :=
        (
          v_room_actual_total
          - (
            v_room_base_price
            * v_cart.quantity
            * v_room_nights
          )
        )
        + v_meal_plan_total;


      insert into public.booking_items (
        booking_id,
        item_type,
        room_type_id,
        accommodation_meal_plan_id,

        item_name_snapshot,
        provider_name_snapshot,

        currency,

        quantity,
        billing_units,

        unit_price_snapshot,
        price_adjustment_total,

        check_in_date,
        check_out_date,

        adult_count,
        child_count,

        notes,

        snapshot_data,

        status
      )
      values (
        v_booking.id,
        'room',
        v_room.id,
        v_cart.accommodation_meal_plan_id,

        v_room.name,
        v_room.accommodation_name,

        v_booking_currency,

        v_cart.quantity,
        v_cart.quantity * v_room_nights,

        v_room_base_price,
        v_room_adjustment,

        v_cart.check_in_date,
        v_cart.check_out_date,

        v_room_adults,
        v_room_children,

        v_cart.notes,

        jsonb_build_object(
          'night_count',
          v_room_nights,

          'nightly_rates',
          v_nightly_rates,

          'meal_plan_total',
          v_meal_plan_total,

          'original_cart_selection',
          v_cart.selection_details
        ),

        'confirmed'
      )
      returning id
      into v_booking_item_id;



      -- ---------------------------------------------------
      -- Store one inventory reservation per night
      -- ---------------------------------------------------

      insert into public.room_inventory_reservations (
        booking_item_id,
        room_type_id,
        stay_date,
        rooms_reserved,
        price_per_room_snapshot,
        status
      )

      select
        v_booking_item_id,
        v_room.id,
        gs.stay_date,
        v_cart.quantity,

        coalesce(
          ra.price_override,
          v_room_base_price
        ),

        'reserved'

      from (
        select
          generate_series(
            v_cart.check_in_date,
            v_cart.check_out_date - 1,
            interval '1 day'
          )::date as stay_date
      ) gs

      left join public.room_availability ra
        on ra.room_type_id = v_room.id
       and ra.date = gs.stay_date;


      v_subtotal :=
        v_subtotal
        + v_room_actual_total
        + v_meal_plan_total;



    -- =====================================================
    -- FOOD
    -- =====================================================

    elsif v_cart.item_type = 'food' then

      if v_cart.service_date is null then
        raise exception
          'Food order requires a service date';
      end if;


      if not public.is_food_item_public(
        v_cart.food_item_id
      ) then

        raise exception
          'Selected food item is unavailable';

      end if;


      select
        fi.id,
        fi.name,
        fi.price,
        fi.currency,
        fi.is_available,
        r.name as restaurant_name
      into v_food
      from public.food_items fi
      join public.restaurants r
        on r.id = fi.restaurant_id
      where fi.id = v_cart.food_item_id;


      if v_food.currency <> v_booking_currency then
        raise exception
          'Mixed booking currencies are not currently supported';
      end if;


      v_current_price :=
        v_food.price;


      insert into public.booking_items (
        booking_id,
        item_type,
        food_item_id,

        item_name_snapshot,
        provider_name_snapshot,

        currency,

        quantity,
        billing_units,
        unit_price_snapshot,

        service_date,
        service_start_time,
        service_end_time,

        notes,
        snapshot_data,
        status
      )
      values (
        v_booking.id,
        'food',
        v_food.id,

        v_food.name,
        v_food.restaurant_name,

        v_booking_currency,

        v_cart.quantity,
        v_cart.quantity,
        v_current_price,

        v_cart.service_date,
        v_cart.service_start_time,
        v_cart.service_end_time,

        v_cart.notes,
        v_cart.selection_details,
        'confirmed'
      );


      v_subtotal :=
        v_subtotal
        + (
          v_current_price
          * v_cart.quantity
        );



    -- =====================================================
    -- BUFFET
    -- =====================================================

    elsif v_cart.item_type = 'buffet' then

      if v_cart.service_date is null then
        raise exception
          'Buffet booking requires a service date';
      end if;


      if not public.is_buffet_public(
        v_cart.buffet_package_id
      ) then

        raise exception
          'Selected buffet package is unavailable';

      end if;


      select
        bp.id,
        bp.name,
        bp.price_per_person,
        bp.currency,
        bp.minimum_guests,
        bp.maximum_guests,
        bp.start_time,
        bp.end_time,
        r.name as restaurant_name
      into v_buffet
      from public.buffet_packages bp
      join public.restaurants r
        on r.id = bp.restaurant_id
      where bp.id =
            v_cart.buffet_package_id;


      if
        v_buffet.minimum_guests is not null
        and v_cart.quantity
            < v_buffet.minimum_guests
      then

        raise exception
          'Buffet minimum guest requirement is not satisfied';

      end if;


      if
        v_buffet.maximum_guests is not null
        and v_cart.quantity
            > v_buffet.maximum_guests
      then

        raise exception
          'Buffet maximum guest limit exceeded';

      end if;


      if v_buffet.currency
         <> v_booking_currency then

        raise exception
          'Mixed booking currencies are not currently supported';

      end if;


      v_current_price :=
        v_buffet.price_per_person;


      insert into public.booking_items (
        booking_id,
        item_type,
        buffet_package_id,

        item_name_snapshot,
        provider_name_snapshot,

        currency,

        quantity,
        billing_units,
        unit_price_snapshot,

        service_date,
        service_start_time,
        service_end_time,

        notes,
        snapshot_data,
        status
      )
      values (
        v_booking.id,
        'buffet',
        v_buffet.id,

        v_buffet.name,
        v_buffet.restaurant_name,

        v_booking_currency,

        v_cart.quantity,
        v_cart.quantity,
        v_current_price,

        v_cart.service_date,
        coalesce(
          v_cart.service_start_time,
          v_buffet.start_time
        ),
        coalesce(
          v_cart.service_end_time,
          v_buffet.end_time
        ),

        v_cart.notes,
        v_cart.selection_details,
        'confirmed'
      );


      v_subtotal :=
        v_subtotal
        + (
          v_current_price
          * v_cart.quantity
        );



    -- =====================================================
    -- RESTAURANT RESERVATION
    -- =====================================================

    elsif v_cart.item_type =
          'restaurant_reservation' then

      if v_cart.service_date is null
         or v_cart.service_start_time is null then

        raise exception
          'Restaurant reservation requires date and time';

      end if;


      if not public.is_restaurant_public(
        v_cart.restaurant_id
      ) then

        raise exception
          'Selected restaurant is unavailable';

      end if;


      select
        r.id,
        r.name,
        r.accepts_reservations
      into v_restaurant
      from public.restaurants r
      where r.id = v_cart.restaurant_id;


      if v_restaurant.accepts_reservations
         is not true then

        raise exception
          'Restaurant does not currently accept reservations';

      end if;


      insert into public.booking_items (
        booking_id,
        item_type,
        restaurant_id,

        item_name_snapshot,
        provider_name_snapshot,

        currency,

        quantity,
        billing_units,
        unit_price_snapshot,

        service_date,
        service_start_time,
        service_end_time,

        notes,
        snapshot_data,
        status
      )
      values (
        v_booking.id,
        'restaurant_reservation',
        v_restaurant.id,

        'Restaurant Reservation',
        v_restaurant.name,

        v_booking_currency,

        v_cart.quantity,
        1,
        0,

        v_cart.service_date,
        v_cart.service_start_time,
        v_cart.service_end_time,

        v_cart.notes,
        v_cart.selection_details,
        'confirmed'
      );



    -- =====================================================
    -- ATTRACTION
    -- =====================================================

    elsif v_cart.item_type = 'attraction' then

      if v_cart.service_date is null then
        raise exception
          'Attraction booking requires a service date';
      end if;


      if not public.is_attraction_public(
        v_cart.attraction_id
      ) then

        raise exception
          'Selected attraction is unavailable';

      end if;


      select
        a.id,
        a.name,
        a.entrance_fee,
        a.currency,
        a.booking_required
      into v_attraction
      from public.attractions a
      where a.id =
            v_cart.attraction_id;


      if v_attraction.currency
         <> v_booking_currency then

        raise exception
          'Mixed booking currencies are not currently supported';

      end if;


      v_current_price :=
        coalesce(
          v_attraction.entrance_fee,
          0
        );


      insert into public.booking_items (
        booking_id,
        item_type,
        attraction_id,

        item_name_snapshot,

        currency,

        quantity,
        billing_units,
        unit_price_snapshot,

        service_date,
        service_start_time,
        service_end_time,

        notes,
        snapshot_data,
        status
      )
      values (
        v_booking.id,
        'attraction',
        v_attraction.id,

        v_attraction.name,

        v_booking_currency,

        v_cart.quantity,
        v_cart.quantity,
        v_current_price,

        v_cart.service_date,
        v_cart.service_start_time,
        v_cart.service_end_time,

        v_cart.notes,

        jsonb_build_object(
          'booking_required',
          v_attraction.booking_required,

          'original_cart_selection',
          v_cart.selection_details
        ),

        'confirmed'
      );


      v_subtotal :=
        v_subtotal
        + (
          v_current_price
          * v_cart.quantity
        );



    -- =====================================================
    -- ACTIVITY
    -- =====================================================

    elsif v_cart.item_type = 'activity' then

      if v_cart.service_date is null then
        raise exception
          'Activity booking requires a service date';
      end if;


      if not public.is_activity_public(
        v_cart.activity_id
      ) then

        raise exception
          'Selected activity is unavailable';

      end if;


      select
        a.id,
        a.name,
        a.price_per_person,
        a.currency,
        a.minimum_participants,
        a.maximum_participants,
        a.booking_required
      into v_activity
      from public.activities a
      where a.id = v_cart.activity_id;


      if
        v_activity.minimum_participants is not null
        and v_cart.quantity
            < v_activity.minimum_participants
      then

        raise exception
          'Activity minimum participant requirement is not satisfied';

      end if;


      if
        v_activity.maximum_participants is not null
        and v_cart.quantity
            > v_activity.maximum_participants
      then

        raise exception
          'Activity participant limit exceeded';

      end if;


      if v_activity.currency
         <> v_booking_currency then

        raise exception
          'Mixed booking currencies are not currently supported';

      end if;


      -- Count slots for selected day
      select count(*)
      into v_activity_slot_count
      from public.activity_availability aa
      where aa.activity_id = v_activity.id
        and aa.date = v_cart.service_date;


      -- Multiple slots require explicit time selection
      if v_cart.service_start_time is null
         and v_activity_slot_count > 1 then

        raise exception
          'Activity has multiple time slots; select a start time';

      end if;


      -- ---------------------------------------------------
      -- Resolve exact activity slot and lock it
      -- ---------------------------------------------------

      if v_cart.service_start_time
         is not null then

        select
          aa.id,
          aa.start_time,
          aa.end_time,
          aa.available_slots,
          aa.price_override,
          aa.is_available
        into v_activity_slot
        from public.activity_availability aa
        where aa.activity_id = v_activity.id
          and aa.date = v_cart.service_date
          and aa.start_time =
              v_cart.service_start_time
        for update;


      elsif v_activity_slot_count = 1 then

        select
          aa.id,
          aa.start_time,
          aa.end_time,
          aa.available_slots,
          aa.price_override,
          aa.is_available
        into v_activity_slot
        from public.activity_availability aa
        where aa.activity_id = v_activity.id
          and aa.date = v_cart.service_date
        for update;

      else

        v_activity_slot := null;

      end if;



      if v_activity_slot_count > 0
         and v_activity_slot.id is null then

        raise exception
          'Selected activity time slot does not exist';

      end if;


      if v_activity.booking_required is true
         and v_activity_slot.id is null then

        raise exception
          'Activity requires an available booking slot';

      end if;



      -- ---------------------------------------------------
      -- Slot-based inventory check
      -- ---------------------------------------------------

      if v_activity_slot.id is not null then

        if v_activity_slot.is_available
           is not true then

          raise exception
            'Activity time slot is unavailable';

        end if;


        select
          coalesce(
            sum(
              air.participants_reserved
            ),
            0
          )
        into v_activity_reserved
        from public.activity_inventory_reservations air
        where air.activity_availability_id =
              v_activity_slot.id
          and air.status = 'reserved';


        if
          v_activity_reserved
          + v_cart.quantity
          > v_activity_slot.available_slots
        then

          raise exception
            'Not enough activity slots are available';

        end if;


        v_current_price :=
          coalesce(
            v_activity_slot.price_override,
            v_activity.price_per_person
          );

      else

        v_current_price :=
          v_activity.price_per_person;

      end if;



      insert into public.booking_items (
        booking_id,
        item_type,
        activity_id,

        item_name_snapshot,

        currency,

        quantity,
        billing_units,
        unit_price_snapshot,

        service_date,
        service_start_time,
        service_end_time,

        notes,
        snapshot_data,
        status
      )
      values (
        v_booking.id,
        'activity',
        v_activity.id,

        v_activity.name,

        v_booking_currency,

        v_cart.quantity,
        v_cart.quantity,
        v_current_price,

        v_cart.service_date,

        case
          when v_activity_slot.id is not null
            then v_activity_slot.start_time
          else v_cart.service_start_time
        end,

        case
          when v_activity_slot.id is not null
            then v_activity_slot.end_time
          else v_cart.service_end_time
        end,

        v_cart.notes,

        jsonb_build_object(
          'activity_availability_id',
          v_activity_slot.id,

          'original_cart_selection',
          v_cart.selection_details
        ),

        'confirmed'
      )
      returning id
      into v_booking_item_id;



      if v_activity_slot.id is not null then

        insert into public.activity_inventory_reservations (
          booking_item_id,
          activity_availability_id,
          participants_reserved,
          price_per_person_snapshot,
          status
        )
        values (
          v_booking_item_id,
          v_activity_slot.id,
          v_cart.quantity,
          v_current_price,
          'reserved'
        );

      end if;


      v_subtotal :=
        v_subtotal
        + (
          v_current_price
          * v_cart.quantity
        );


    else

      raise exception
        'Unsupported cart item type: %',
        v_cart.item_type;

    end if;


  end loop;



  -- =======================================================
  -- I. ROOM GUEST ALLOCATION MUST MATCH TRIP
  -- =======================================================

  if v_room_item_count > 0 then

    if v_assigned_adults
       <> v_trip.adult_count then

      raise exception
        'Room adult allocation does not match trip adult count';

    end if;


    if v_assigned_children
       <> v_trip.child_count then

      raise exception
        'Room child allocation does not match trip child count';

    end if;

  end if;



  -- =======================================================
  -- J. ADD SELECTED TRANSPORT AUTOMATICALLY
  -- =======================================================

  if v_transport_count > 0 then

    select
      tr.id as request_id,
      tr.route_distance_km,
      tr.estimated_duration_minutes,
      tr.trip_start_date,
      tr.trip_end_date,

      db.id as bid_id,
      db.driver_id,
      db.vehicle_id,
      db.bid_amount,
      db.currency,

      dp.public_name as driver_name,

      v.make,
      v.model,
      v.registration_number

    into v_transport

    from public.transport_requests tr

    join public.driver_bids db
      on db.id = tr.selected_bid_id

    join public.driver_profiles dp
      on dp.user_id = db.driver_id

    join public.vehicles v
      on v.id = db.vehicle_id

    where tr.trip_id = p_trip_id
      and tr.status = 'driver_selected'
      and db.status = 'accepted'

    order by tr.id desc
    limit 1;


    if v_transport.currency
       <> v_booking_currency then

      raise exception
        'Transport currency does not match booking currency';

    end if;


    -- Recheck driver approval at checkout
    if not public.is_provider_approved(
      v_transport.driver_id,
      'driver'
    ) then

      raise exception
        'Selected driver is no longer approved';

    end if;


    -- Recheck vehicle legal documents
    if not public.vehicle_is_compliant_for_trip(
      v_transport.vehicle_id,
      v_trip.end_date
    ) then

      raise exception
        'Selected vehicle documents are no longer valid';

    end if;


    insert into public.booking_items (
      booking_id,
      item_type,
      driver_bid_id,

      item_name_snapshot,
      provider_name_snapshot,

      currency,

      quantity,
      billing_units,
      unit_price_snapshot,

      service_date,

      snapshot_data,
      status
    )
    values (
      v_booking.id,
      'transport',
      v_transport.bid_id,

      concat(
        'Transport - ',
        v_transport.make,
        ' ',
        v_transport.model
      ),

      v_transport.driver_name,

      v_booking_currency,

      1,
      1,
      v_transport.bid_amount,

      v_transport.trip_start_date,

      jsonb_build_object(
        'transport_request_id',
        v_transport.request_id,

        'vehicle_id',
        v_transport.vehicle_id,

        'vehicle_registration',
        v_transport.registration_number,

        'route_distance_km',
        v_transport.route_distance_km,

        'estimated_duration_minutes',
        v_transport.estimated_duration_minutes,

        'trip_start_date',
        v_transport.trip_start_date,

        'trip_end_date',
        v_transport.trip_end_date
      ),

      'confirmed'
    );


    v_subtotal :=
      v_subtotal
      + v_transport.bid_amount;

  end if;



  -- =======================================================
  -- K. FINALIZE BOOKING
  -- =======================================================

  update public.bookings
  set
    subtotal = v_subtotal,

    status = 'confirmed',

    confirmed_at = now()

  where id = v_booking.id

  returning *
  into v_booking;



  -- =======================================================
  -- L. CONFIRM TRIP
  -- =======================================================

  perform pg_catalog.set_config(
    'tripmate.transport_workflow',
    'confirm_booking',
    true
  );


  update public.trips
  set status = 'confirmed'
  where id = p_trip_id;



  -- =======================================================
  -- M. CLEAR CART ONLY AFTER EVERYTHING SUCCEEDED
  -- =======================================================

  delete from public.trip_cart_items
  where trip_id = p_trip_id;



  -- =======================================================
  -- N. RETURN FINAL BOOKING
  -- =======================================================

  return v_booking;

end;
$$;



-- =========================================================
-- 5. FUNCTION PERMISSIONS
-- =========================================================

revoke all
on function public.checkout_trip(bigint)
from public, anon;


grant execute
on function public.checkout_trip(bigint)
to authenticated;
