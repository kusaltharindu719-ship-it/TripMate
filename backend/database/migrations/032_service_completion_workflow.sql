-- =========================================================
-- TripMate
-- Migration 032: Secure Service Completion Workflow
-- =========================================================


-- =========================================================
-- 1. BOOKING ITEM COMPLETION METADATA
-- =========================================================

alter table public.booking_items
add column if not exists completed_at timestamptz;

alter table public.booking_items
add column if not exists completed_by uuid
references public.profiles(id)
on delete set null;

alter table public.booking_items
add column if not exists completion_note text;



-- =========================================================
-- 2. COMPLETE ONE BOOKING ITEM
--
-- Allowed:
--   - provider assigned to the booking item
--   - admin
--
-- NOT allowed:
--   - traveler
--   - unrelated provider
--
-- When every non-cancelled item is completed:
--   booking -> completed
--   trip    -> completed
-- =========================================================

create or replace function public.complete_booking_item(
  p_booking_item_id bigint,
  p_note text default null
)
returns public.booking_items
language plpgsql
security definer
set search_path = ''
as $$
declare

  v_item public.booking_items%rowtype;
  v_booking public.bookings%rowtype;

  v_item_json jsonb;

  v_due_date date;

  v_is_admin boolean := false;
  v_is_provider boolean := false;

  v_remaining_count integer;
  v_completed_count integer;

  v_result public.booking_items%rowtype;

begin

  -- -------------------------------------------------------
  -- Authentication
  -- -------------------------------------------------------

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  v_is_admin := public.is_admin_user();


  -- -------------------------------------------------------
  -- Lock booking item
  -- -------------------------------------------------------

  select *
  into v_item
  from public.booking_items
  where id = p_booking_item_id
  for update;


  if not found then
    raise exception 'Booking item does not exist';
  end if;


  -- -------------------------------------------------------
  -- Lock parent booking
  -- -------------------------------------------------------

  select *
  into v_booking
  from public.bookings
  where id = v_item.booking_id
  for update;


  if not found then
    raise exception 'Booking does not exist';
  end if;



  -- =======================================================
  -- 3. STATUS VALIDATION
  -- =======================================================

  if v_item.status = 'completed' then
    raise exception 'Booking item is already completed';
  end if;


  if v_item.status = 'cancelled' then
    raise exception 'Cancelled booking item cannot be completed';
  end if;


  if v_item.status <> 'confirmed' then
    raise exception
      'Only a confirmed booking item can be completed';
  end if;


  if v_booking.status in (
    'cancelled',
    'failed',
    'expired'
  ) then
    raise exception
      'This booking cannot be completed';
  end if;



  -- =======================================================
  -- 4. AUTHORIZATION
  --
  -- provider_user_id_snapshot was stored at secure checkout.
  -- This prevents another provider from claiming the service.
  -- =======================================================

  v_is_provider :=
    v_item.provider_user_id_snapshot is not null
    and
    v_item.provider_user_id_snapshot = auth.uid();


  if not v_is_admin
     and not v_is_provider then

    raise exception
      'You are not authorized to complete this booking item';

  end if;



  -- =======================================================
  -- 5. BASIC SERVICE-DATE PROTECTION
  --
  -- Prevents providers from marking a future service as
  -- completed.
  --
  -- Uses JSON representation so the workflow remains safe
  -- across different booking-item service types.
  -- =======================================================

  v_item_json := to_jsonb(v_item);


  if v_item.item_type = 'room' then

    if nullif(
      v_item_json ->> 'check_out_date',
      ''
    ) is not null then

      v_due_date :=
        (v_item_json ->> 'check_out_date')::date;

    end if;


  elsif v_item.item_type = 'transport' then

    if nullif(
      v_item.snapshot_data ->> 'trip_end_date',
      ''
    ) is not null then

      v_due_date :=
        (
          v_item.snapshot_data
          ->> 'trip_end_date'
        )::date;

    elsif nullif(
      v_item_json ->> 'service_date',
      ''
    ) is not null then

      v_due_date :=
        (v_item_json ->> 'service_date')::date;

    end if;


  else

    if nullif(
      v_item_json ->> 'service_date',
      ''
    ) is not null then

      v_due_date :=
        (v_item_json ->> 'service_date')::date;

    end if;

  end if;


  if v_due_date is not null
     and v_due_date > current_date then

    raise exception
      'Future service cannot be marked as completed';

  end if;



  -- =======================================================
  -- 6. NOTE VALIDATION
  -- =======================================================

  if p_note is not null
     and length(trim(p_note)) > 1000 then

    raise exception
      'Completion note cannot exceed 1000 characters';

  end if;



  -- =======================================================
  -- 7. COMPLETE ITEM
  -- =======================================================

  update public.booking_items
  set
    status = 'completed',
    completed_at = now(),
    completed_by = auth.uid(),
    completion_note =
      nullif(trim(p_note), '')
  where id = p_booking_item_id
  returning *
  into v_result;



  -- =======================================================
  -- 8. CHECK WHETHER BOOKING IS NOW COMPLETE
  --
  -- Cancelled items are ignored.
  -- At least one completed service must exist.
  -- =======================================================

  select count(*)
  into v_remaining_count
  from public.booking_items bi
  where bi.booking_id = v_item.booking_id
    and bi.status <> 'cancelled'
    and bi.status <> 'completed';


  select count(*)
  into v_completed_count
  from public.booking_items bi
  where bi.booking_id = v_item.booking_id
    and bi.status = 'completed';



  -- =======================================================
  -- 9. AUTO-COMPLETE BOOKING + TRIP
  -- =======================================================

  if v_remaining_count = 0
     and v_completed_count > 0 then


    update public.bookings
    set
      status = 'completed',
      completed_at =
        coalesce(
          completed_at,
          now()
        )
    where id = v_item.booking_id
      and status not in (
        'cancelled',
        'failed',
        'expired',
        'completed'
      );


    update public.trips
    set
      status = 'completed',
      updated_at = now()
    where id = v_booking.trip_id
      and status not in (
        'cancelled',
        'completed'
      );

  end if;


  return v_result;

end;
$$;



-- =========================================================
-- 10. CLIENT TABLE PRIVILEGE DEFENCE
--
-- Booking lifecycle must still be changed only by secure
-- workflows, never direct browser UPDATE.
-- =========================================================

revoke insert, update, delete
on table public.bookings
from authenticated;

revoke insert, update, delete
on table public.booking_items
from authenticated;


grant select
on table public.bookings
to authenticated;

grant select
on table public.booking_items
to authenticated;



-- =========================================================
-- 11. FUNCTION ACCESS
-- =========================================================

revoke all
on function public.complete_booking_item(
  bigint,
  text
)
from public, anon;


grant execute
on function public.complete_booking_item(
  bigint,
  text
)
to authenticated;
