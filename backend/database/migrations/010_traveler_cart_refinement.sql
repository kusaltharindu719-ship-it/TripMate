-- =========================================================
-- TripMate
-- Migration 010: Trip Cart Refinement
-- =========================================================


-- =========================================================
-- 1. ADD BOOKING-SPECIFIC CART DATA
-- =========================================================

alter table public.trip_cart_items
  add column if not exists check_in_date date,
  add column if not exists check_out_date date,

  add column if not exists accommodation_meal_plan_id bigint
    references public.accommodation_meal_plans(id)
    on delete set null,

  add column if not exists notes text;



-- =========================================================
-- 2. REMOVE OLD DUPLICATE RULES
-- They did not support different dates/times.
-- =========================================================

drop index if exists public.idx_trip_cart_unique_room;
drop index if exists public.idx_trip_cart_unique_food;
drop index if exists public.idx_trip_cart_unique_buffet;
drop index if exists public.idx_trip_cart_unique_restaurant_reservation;
drop index if exists public.idx_trip_cart_unique_attraction;
drop index if exists public.idx_trip_cart_unique_activity;



-- =========================================================
-- 3. IMPROVED CART VALIDATION
-- =========================================================

create or replace function public.validate_trip_cart_item()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  trip_start date;
  trip_end date;

  room_accommodation_id bigint;
  meal_plan_accommodation_id bigint;
begin

  -- Find trip dates
  select
    start_date,
    end_date
  into
    trip_start,
    trip_end
  from public.trips
  where id = new.trip_id;


  if trip_start is null then
    raise exception 'Invalid trip';
  end if;


  -- =====================================================
  -- ROOM
  -- =====================================================

  if new.item_type = 'room' then

    if new.room_type_id is null
       or new.food_item_id is not null
       or new.buffet_package_id is not null
       or new.restaurant_id is not null
       or new.attraction_id is not null
       or new.activity_id is not null
    then
      raise exception 'Invalid source for room cart item';
    end if;


    if new.check_in_date is null
       or new.check_out_date is null
    then
      raise exception
        'Room cart item requires check-in and check-out dates';
    end if;


    if new.check_out_date <= new.check_in_date then
      raise exception
        'Check-out date must be after check-in date';
    end if;


    if new.check_in_date < trip_start
       or new.check_out_date > trip_end
    then
      raise exception
        'Room dates must be within trip dates';
    end if;


    -- Validate selected meal plan belongs to same accommodation
    if new.accommodation_meal_plan_id is not null then

      select accommodation_id
      into room_accommodation_id
      from public.room_types
      where id = new.room_type_id;


      select accommodation_id
      into meal_plan_accommodation_id
      from public.accommodation_meal_plans
      where id = new.accommodation_meal_plan_id;


      if room_accommodation_id is distinct from
         meal_plan_accommodation_id
      then
        raise exception
          'Meal plan must belong to the same accommodation';
      end if;

    end if;


  -- =====================================================
  -- FOOD
  -- =====================================================

  elsif new.item_type = 'food' then

    if new.food_item_id is null
       or new.room_type_id is not null
       or new.buffet_package_id is not null
       or new.restaurant_id is not null
       or new.attraction_id is not null
       or new.activity_id is not null
    then
      raise exception 'Invalid source for food cart item';
    end if;


  -- =====================================================
  -- BUFFET
  -- =====================================================

  elsif new.item_type = 'buffet' then

    if new.buffet_package_id is null
       or new.room_type_id is not null
       or new.food_item_id is not null
       or new.restaurant_id is not null
       or new.attraction_id is not null
       or new.activity_id is not null
    then
      raise exception 'Invalid source for buffet cart item';
    end if;


  -- =====================================================
  -- RESTAURANT RESERVATION
  -- =====================================================

  elsif new.item_type = 'restaurant_reservation' then

    if new.restaurant_id is null
       or new.room_type_id is not null
       or new.food_item_id is not null
       or new.buffet_package_id is not null
       or new.attraction_id is not null
       or new.activity_id is not null
    then
      raise exception
        'Invalid source for restaurant reservation';
    end if;


    if new.service_date is null
       or new.service_start_time is null
    then
      raise exception
        'Restaurant reservation requires date and time';
    end if;


  -- =====================================================
  -- ATTRACTION
  -- =====================================================

  elsif new.item_type = 'attraction' then

    if new.attraction_id is null
       or new.room_type_id is not null
       or new.food_item_id is not null
       or new.buffet_package_id is not null
       or new.restaurant_id is not null
       or new.activity_id is not null
    then
      raise exception 'Invalid source for attraction cart item';
    end if;


  -- =====================================================
  -- ACTIVITY
  -- =====================================================

  elsif new.item_type = 'activity' then

    if new.activity_id is null
       or new.room_type_id is not null
       or new.food_item_id is not null
       or new.buffet_package_id is not null
       or new.restaurant_id is not null
       or new.attraction_id is not null
    then
      raise exception 'Invalid source for activity cart item';
    end if;

  end if;


  -- =====================================================
  -- SERVICE DATE VALIDATION
  -- =====================================================

  if new.service_date is not null
     and (
       new.service_date < trip_start
       or new.service_date > trip_end
     )
  then
    raise exception
      'Service date must be within trip dates';
  end if;


  return new;

end;
$$;



-- =========================================================
-- 4. DATE-AWARE DUPLICATE PREVENTION
-- =========================================================


-- Same room can be selected again for different stay dates
create unique index if not exists
idx_trip_cart_unique_room
on public.trip_cart_items (
  trip_id,
  room_type_id,
  check_in_date,
  check_out_date
)
where item_type = 'room';


-- Same food can appear on different dates/times
create unique index if not exists
idx_trip_cart_unique_food
on public.trip_cart_items (
  trip_id,
  food_item_id,
  coalesce(service_date, date '0001-01-01'),
  coalesce(service_start_time, time '00:00')
)
where item_type = 'food';


-- Same buffet can be selected for different days/times
create unique index if not exists
idx_trip_cart_unique_buffet
on public.trip_cart_items (
  trip_id,
  buffet_package_id,
  coalesce(service_date, date '0001-01-01'),
  coalesce(service_start_time, time '00:00')
)
where item_type = 'buffet';


-- Restaurant can be reserved multiple times
-- if date/time is different
create unique index if not exists
idx_trip_cart_unique_restaurant_reservation
on public.trip_cart_items (
  trip_id,
  restaurant_id,
  service_date,
  service_start_time
)
where item_type = 'restaurant_reservation';


-- Same attraction may be visited on different dates
create unique index if not exists
idx_trip_cart_unique_attraction
on public.trip_cart_items (
  trip_id,
  attraction_id,
  coalesce(service_date, date '0001-01-01')
)
where item_type = 'attraction';


-- Same activity can be booked at different sessions
create unique index if not exists
idx_trip_cart_unique_activity
on public.trip_cart_items (
  trip_id,
  activity_id,
  coalesce(service_date, date '0001-01-01'),
  coalesce(service_start_time, time '00:00')
)
where item_type = 'activity';
