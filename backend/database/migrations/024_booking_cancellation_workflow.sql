-- =========================================================
-- TripMate
-- Migration 024: Secure Booking Cancellation Workflow
-- =========================================================


-- =========================================================
-- 1. CANCELLATION REVIEW AUDIT FIELDS
-- =========================================================

alter table public.booking_cancellations
add column if not exists reviewed_by uuid
references public.profiles(id)
on delete set null;

alter table public.booking_cancellations
add column if not exists review_notes text;

alter table public.booking_cancellations
add column if not exists processed_by uuid
references public.profiles(id)
on delete set null;



-- =========================================================
-- 2. IMPROVE BOOKING STATUS HISTORY
-- Secure workflows can attach a reason to status changes.
-- =========================================================

create or replace function public.log_booking_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text;
begin

  v_reason :=
    nullif(
      current_setting(
        'tripmate.booking_status_reason',
        true
      ),
      ''
    );


  if tg_op = 'INSERT' then

    insert into public.booking_status_history (
      booking_id,
      old_status,
      new_status,
      changed_by,
      reason
    )
    values (
      new.id,
      null,
      new.status,
      auth.uid(),
      v_reason
    );


  elsif new.status is distinct from old.status then

    insert into public.booking_status_history (
      booking_id,
      old_status,
      new_status,
      changed_by,
      reason
    )
    values (
      new.id,
      old.status,
      new.status,
      auth.uid(),
      v_reason
    );

  end if;


  return new;
end;
$$;



-- =========================================================
-- 3. ALLOW TRANSPORT REQUEST CANCELLATION FROM BOOKING
-- =========================================================

create or replace function public.protect_transport_request_workflow()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  workflow_action text;
begin

  workflow_action :=
    current_setting(
      'tripmate.transport_workflow',
      true
    );


  if new.trip_id is distinct from old.trip_id then
    raise exception
      'Transport request trip cannot be changed';
  end if;


  if new.traveler_id is distinct from old.traveler_id then
    raise exception
      'Transport request owner cannot be changed';
  end if;


  if new.status is distinct from old.status then

    if workflow_action is null
       or workflow_action not in (
         'open_request',
         'accept_bid',
         'cancel_request',
         'booking_cancellation'
       ) then

      raise exception
        'Transport request status must be changed through a secure workflow';

    end if;

  end if;


  if new.selected_bid_id
       is distinct from old.selected_bid_id then

    if workflow_action is distinct from 'accept_bid' then

      raise exception
        'Selected bid can only be changed through the bid acceptance workflow';

    end if;

  end if;


  if old.status <> 'draft' then

    if
      new.pickup_location_snapshot
        is distinct from old.pickup_location_snapshot

      or new.pickup_latitude
        is distinct from old.pickup_latitude

      or new.pickup_longitude
        is distinct from old.pickup_longitude

      or new.trip_start_date
        is distinct from old.trip_start_date

      or new.trip_end_date
        is distinct from old.trip_end_date

      or new.passenger_count
        is distinct from old.passenger_count

      or new.luggage_count
        is distinct from old.luggage_count

      or new.special_requirements
        is distinct from old.special_requirements

      or new.route_distance_km
        is distinct from old.route_distance_km

      or new.estimated_duration_minutes
        is distinct from old.estimated_duration_minutes

      or new.currency
        is distinct from old.currency

      or new.bidding_deadline
        is distinct from old.bidding_deadline

    then

      raise exception
        'Published transport request details cannot be modified';

    end if;

  end if;


  return new;
end;
$$;



-- =========================================================
-- 4. REVIEW CANCELLATION
--
-- Item cancellation:
--   relevant provider OR admin can approve/reject.
--
-- Full multi-provider cancellation:
--   admin only.
--
-- Approval also releases reserved inventory atomically.
-- =========================================================

create or replace function public.review_booking_cancellation(
  p_cancellation_id bigint,
  p_decision text,
  p_refund_amount numeric default 0,
  p_review_notes text default null
)
returns public.booking_cancellations
language plpgsql
security definer
set search_path = ''
as $$
declare

  v_cancellation public.booking_cancellations%rowtype;
  v_booking public.bookings%rowtype;
  v_item public.booking_items%rowtype;

  v_refund numeric(14,2);
  v_max_refund numeric(14,2);

  v_remaining_items integer;

  v_result public.booking_cancellations%rowtype;

begin

  -- -------------------------------------------------------
  -- Authentication
  -- -------------------------------------------------------

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  if p_decision not in (
    'approved',
    'rejected'
  ) then

    raise exception
      'Decision must be approved or rejected';

  end if;


  v_refund :=
    coalesce(p_refund_amount, 0);


  if v_refund < 0 then
    raise exception
      'Refund amount cannot be negative';
  end if;



  -- -------------------------------------------------------
  -- Lock cancellation request
  -- -------------------------------------------------------

  select *
  into v_cancellation
  from public.booking_cancellations
  where id = p_cancellation_id
  for update;


  if not found then
    raise exception
      'Cancellation request does not exist';
  end if;


  if v_cancellation.status <> 'requested' then
    raise exception
      'Cancellation request has already been reviewed';
  end if;



  -- -------------------------------------------------------
  -- Lock booking
  -- -------------------------------------------------------

  select *
  into v_booking
  from public.bookings
  where id = v_cancellation.booking_id
  for update;


  if not found then
    raise exception 'Booking does not exist';
  end if;



  -- =======================================================
  -- ITEM CANCELLATION AUTHORIZATION
  -- =======================================================

  if v_cancellation.booking_item_id is not null then

    select *
    into v_item
    from public.booking_items
    where id = v_cancellation.booking_item_id
      and booking_id = v_booking.id
    for update;


    if not found then
      raise exception
        'Booking item does not belong to booking';
    end if;


    -- Relevant provider or admin only
    if not public.is_admin_user()
       and v_item.provider_user_id_snapshot
           is distinct from auth.uid() then

      raise exception
        'You are not authorized to review this cancellation';

    end if;


    if v_item.status <> 'confirmed' then
      raise exception
        'Booking item is no longer confirmed';
    end if;


    v_max_refund :=
      v_item.line_total;



  -- =======================================================
  -- FULL BOOKING AUTHORIZATION
  -- =======================================================

  else

    -- Full booking may contain hotel + restaurant + driver,
    -- therefore only platform admin coordinates approval.
    if not public.is_admin_user() then

      raise exception
        'Only an administrator can review a full booking cancellation';

    end if;


    select
      coalesce(sum(bi.line_total), 0)
    into v_max_refund
    from public.booking_items bi
    where bi.booking_id = v_booking.id
      and bi.status = 'confirmed';

  end if;



  -- =======================================================
  -- REFUND PROTECTION
  -- =======================================================

  if v_refund > v_max_refund then

    raise exception
      'Refund amount exceeds cancellable booking value';

  end if;


  -- No money can be refunded from an unpaid booking.
  if v_booking.payment_status not in (
       'paid',
       'partially_refunded'
     )
     and v_refund > 0 then

    raise exception
      'A positive refund cannot be issued for an unpaid booking';

  end if;



  -- =======================================================
  -- REJECT
  -- =======================================================

  if p_decision = 'rejected' then

    update public.booking_cancellations
    set
      status = 'rejected',
      refund_amount = 0,
      reviewed_by = auth.uid(),
      reviewed_at = now(),
      review_notes =
        nullif(trim(p_review_notes), '')
    where id = p_cancellation_id
    returning *
    into v_result;


    return v_result;

  end if;



  -- =======================================================
  -- APPROVE
  -- =======================================================

  update public.booking_cancellations
  set
    status = 'approved',
    refund_amount = v_refund,
    reviewed_by = auth.uid(),
    reviewed_at = now(),
    review_notes =
      nullif(trim(p_review_notes), '')
  where id = p_cancellation_id;



  -- =======================================================
  -- RELEASE ROOM INVENTORY
  -- =======================================================

  update public.room_inventory_reservations rir
  set
    status = 'released',
    released_at = now()
  where rir.status = 'reserved'
    and rir.booking_item_id in (

      select bi.id
      from public.booking_items bi
      where bi.booking_id = v_booking.id
        and bi.status = 'confirmed'

        and (
          v_cancellation.booking_item_id is null
          or bi.id =
             v_cancellation.booking_item_id
        )
    );



  -- =======================================================
  -- RELEASE ACTIVITY INVENTORY
  -- =======================================================

  update public.activity_inventory_reservations air
  set
    status = 'released',
    released_at = now()
  where air.status = 'reserved'
    and air.booking_item_id in (

      select bi.id
      from public.booking_items bi
      where bi.booking_id = v_booking.id
        and bi.status = 'confirmed'

        and (
          v_cancellation.booking_item_id is null
          or bi.id =
             v_cancellation.booking_item_id
        )
    );



  -- =======================================================
  -- CANCEL SELECTED TRANSPORT REQUEST IF TRANSPORT ITEM
  -- IS INCLUDED IN THIS CANCELLATION
  --
  -- Accepted bid remains as historical evidence.
  -- Request status becomes cancelled, which also frees the
  -- driver from overlap checks.
  -- =======================================================

  perform pg_catalog.set_config(
    'tripmate.transport_workflow',
    'booking_cancellation',
    true
  );


  update public.transport_requests tr
  set status = 'cancelled'
  where tr.id in (

    select db.transport_request_id
    from public.booking_items bi

    join public.driver_bids db
      on db.id = bi.driver_bid_id

    where bi.booking_id = v_booking.id
      and bi.item_type = 'transport'
      and bi.status = 'confirmed'

      and (
        v_cancellation.booking_item_id is null
        or bi.id =
           v_cancellation.booking_item_id
      )
  )
  and tr.status = 'driver_selected';



  -- =======================================================
  -- CANCEL BOOKING ITEM(S)
  -- =======================================================

  update public.booking_items bi
  set status = 'cancelled'
  where bi.booking_id = v_booking.id
    and bi.status = 'confirmed'

    and (
      v_cancellation.booking_item_id is null
      or bi.id =
         v_cancellation.booking_item_id
    );



  -- =======================================================
  -- DETERMINE FINAL BOOKING STATUS
  -- =======================================================

  select count(*)
  into v_remaining_items
  from public.booking_items bi
  where bi.booking_id = v_booking.id
    and bi.status = 'confirmed';



  if v_remaining_items = 0 then

    perform pg_catalog.set_config(
      'tripmate.booking_status_reason',
      'All booking items cancelled',
      true
    );


    update public.bookings
    set
      status = 'cancelled',
      cancelled_at = now()
    where id = v_booking.id;


    -- Nothing remains in the trip booking
    update public.trips
    set status = 'cancelled'
    where id = v_booking.trip_id;


  else

    perform pg_catalog.set_config(
      'tripmate.booking_status_reason',
      'One or more booking items cancelled',
      true
    );


    update public.bookings
    set status = 'partially_cancelled'
    where id = v_booking.id;

  end if;



  select *
  into v_result
  from public.booking_cancellations
  where id = p_cancellation_id;


  return v_result;

end;
$$;



-- =========================================================
-- 5. MARK APPROVED CANCELLATION AS PROCESSED
--
-- This should be called only after the real refund/payment
-- action has been completed externally.
--
-- For now admin controls this workflow.
-- =========================================================

create or replace function public.process_booking_cancellation(
  p_cancellation_id bigint
)
returns public.booking_cancellations
language plpgsql
security definer
set search_path = ''
as $$
declare

  v_cancellation public.booking_cancellations%rowtype;
  v_booking public.bookings%rowtype;

  v_processed_refund_total numeric(14,2);

  v_result public.booking_cancellations%rowtype;

begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  if not public.is_admin_user() then
    raise exception
      'Only an administrator can mark cancellation processing complete';
  end if;



  select *
  into v_cancellation
  from public.booking_cancellations
  where id = p_cancellation_id
  for update;


  if not found then
    raise exception
      'Cancellation request does not exist';
  end if;


  if v_cancellation.status <> 'approved' then

    raise exception
      'Only an approved cancellation can be processed';

  end if;



  select *
  into v_booking
  from public.bookings
  where id = v_cancellation.booking_id
  for update;



  update public.booking_cancellations
  set
    status = 'processed',
    processed_at = now(),
    processed_by = auth.uid()
  where id = p_cancellation_id
  returning *
  into v_result;



  -- -------------------------------------------------------
  -- Update payment status only if money had previously
  -- been paid.
  -- -------------------------------------------------------

  if v_booking.payment_status in (
       'paid',
       'partially_refunded'
     ) then

    select
      coalesce(sum(bc.refund_amount), 0)
    into v_processed_refund_total
    from public.booking_cancellations bc
    where bc.booking_id = v_booking.id
      and bc.status = 'processed';


    if v_processed_refund_total
       >= v_booking.total_amount then

      update public.bookings
      set payment_status = 'refunded'
      where id = v_booking.id;

    elsif v_processed_refund_total > 0 then

      update public.bookings
      set payment_status = 'partially_refunded'
      where id = v_booking.id;

    end if;

  end if;


  return v_result;

end;
$$;



-- =========================================================
-- 6. FUNCTION PRIVILEGES
-- =========================================================

revoke all
on function public.review_booking_cancellation(
  bigint,
  text,
  numeric,
  text
)
from public, anon;


grant execute
on function public.review_booking_cancellation(
  bigint,
  text,
  numeric,
  text
)
to authenticated;



revoke all
on function public.process_booking_cancellation(bigint)
from public, anon;


grant execute
on function public.process_booking_cancellation(bigint)
to authenticated;
