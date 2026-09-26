-- =========================================================
-- TripMate
-- Migration 023: Booking Security and Cancellation Requests
-- =========================================================


-- =========================================================
-- 1. HISTORICAL IDENTITY SNAPSHOTS
-- =========================================================

alter table public.bookings
add column if not exists traveler_name_snapshot text;

alter table public.bookings
add column if not exists traveler_phone_snapshot text;


alter table public.booking_items
add column if not exists provider_user_id_snapshot uuid
references public.profiles(id)
on delete set null;


create index if not exists
booking_items_provider_snapshot_idx
on public.booking_items(provider_user_id_snapshot)
where provider_user_id_snapshot is not null;



-- =========================================================
-- 2. NEVER TRUST TRAVELER SNAPSHOT VALUES FROM CLIENT
-- =========================================================

create or replace function public.populate_booking_traveler_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_phone text;
begin

  select
    p.full_name,
    p.phone
  into
    v_name,
    v_phone
  from public.profiles p
  where p.id = new.traveler_id;


  if not found then
    raise exception 'Traveler profile does not exist';
  end if;


  new.traveler_name_snapshot := v_name;
  new.traveler_phone_snapshot := v_phone;

  return new;
end;
$$;


drop trigger if exists
populate_booking_traveler_snapshot_trigger
on public.bookings;

create trigger
populate_booking_traveler_snapshot_trigger
before insert
on public.bookings
for each row
execute procedure public.populate_booking_traveler_snapshot();



-- =========================================================
-- 3. CAPTURE PROVIDER ID WHEN BOOKING ITEM IS CREATED
--
-- This is historical ownership.
-- Later service deletion/ownership changes do not break
-- provider booking history.
-- =========================================================

create or replace function public.populate_booking_item_provider_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider_id uuid;
begin

  v_provider_id := null;


  if new.item_type = 'room' then

    select a.owner_id
    into v_provider_id
    from public.room_types rt
    join public.accommodations a
      on a.id = rt.accommodation_id
    where rt.id = new.room_type_id;


  elsif new.item_type = 'food' then

    select r.owner_id
    into v_provider_id
    from public.food_items fi
    join public.restaurants r
      on r.id = fi.restaurant_id
    where fi.id = new.food_item_id;


  elsif new.item_type = 'buffet' then

    select r.owner_id
    into v_provider_id
    from public.buffet_packages bp
    join public.restaurants r
      on r.id = bp.restaurant_id
    where bp.id = new.buffet_package_id;


  elsif new.item_type = 'restaurant_reservation' then

    select r.owner_id
    into v_provider_id
    from public.restaurants r
    where r.id = new.restaurant_id;


  elsif new.item_type = 'transport' then

    select db.driver_id
    into v_provider_id
    from public.driver_bids db
    where db.id = new.driver_bid_id;

  end if;


  -- Attraction/activity currently use platform-managed data.
  -- If dedicated attraction providers are added later,
  -- this trigger can be extended without changing history.

  new.provider_user_id_snapshot := v_provider_id;

  return new;
end;
$$;


drop trigger if exists
populate_booking_item_provider_snapshot_trigger
on public.booking_items;

create trigger
populate_booking_item_provider_snapshot_trigger
before insert
on public.booking_items
for each row
execute procedure
public.populate_booking_item_provider_snapshot();



-- =========================================================
-- 4. BACKFILL EXISTING BOOKING ITEMS IF ANY EXIST
-- =========================================================

update public.booking_items bi
set provider_user_id_snapshot =
  case

    when bi.item_type = 'room' then (
      select a.owner_id
      from public.room_types rt
      join public.accommodations a
        on a.id = rt.accommodation_id
      where rt.id = bi.room_type_id
    )

    when bi.item_type = 'food' then (
      select r.owner_id
      from public.food_items fi
      join public.restaurants r
        on r.id = fi.restaurant_id
      where fi.id = bi.food_item_id
    )

    when bi.item_type = 'buffet' then (
      select r.owner_id
      from public.buffet_packages bp
      join public.restaurants r
        on r.id = bp.restaurant_id
      where bp.id = bi.buffet_package_id
    )

    when bi.item_type = 'restaurant_reservation' then (
      select r.owner_id
      from public.restaurants r
      where r.id = bi.restaurant_id
    )

    when bi.item_type = 'transport' then (
      select db.driver_id
      from public.driver_bids db
      where db.id = bi.driver_bid_id
    )

    else null

  end
where bi.provider_user_id_snapshot is null;



-- =========================================================
-- 5. SECURITY HELPERS
-- =========================================================

create or replace function public.is_booking_owner(
  p_booking_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.bookings b
    where b.id = p_booking_id
      and b.traveler_id = auth.uid()
  );
$$;


create or replace function public.provider_has_booking_item(
  p_booking_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.booking_items bi
    where bi.booking_id = p_booking_id
      and bi.provider_user_id_snapshot = auth.uid()
  );
$$;


create or replace function public.can_view_booking_item(
  p_booking_item_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.booking_items bi
    join public.bookings b
      on b.id = bi.booking_id
    where bi.id = p_booking_item_id
      and (
        b.traveler_id = auth.uid()
        or bi.provider_user_id_snapshot = auth.uid()
        or public.is_admin_user()
      )
  );
$$;



-- =========================================================
-- 6. ENABLE RLS
-- =========================================================

alter table public.bookings
enable row level security;

alter table public.booking_items
enable row level security;

alter table public.room_inventory_reservations
enable row level security;

alter table public.activity_inventory_reservations
enable row level security;

alter table public.booking_status_history
enable row level security;

alter table public.booking_cancellations
enable row level security;



-- =========================================================
-- 7. BOOKINGS
--
-- Full booking header contains totals for the complete basket.
-- Therefore providers do NOT directly receive the full header.
-- Traveler + admin only.
-- =========================================================

drop policy if exists
"Traveler and admin view bookings"
on public.bookings;

create policy
"Traveler and admin view bookings"
on public.bookings
for select
to authenticated
using (
  traveler_id = auth.uid()
  or public.is_admin_user()
);



-- =========================================================
-- 8. BOOKING ITEMS
--
-- Traveler sees all own items.
-- Provider sees ONLY the item that belongs to them.
-- =========================================================

drop policy if exists
"Authorized users view booking items"
on public.booking_items;

create policy
"Authorized users view booking items"
on public.booking_items
for select
to authenticated
using (
  public.is_booking_owner(booking_id)
  or provider_user_id_snapshot = auth.uid()
  or public.is_admin_user()
);



-- =========================================================
-- 9. ROOM INVENTORY LEDGER
-- =========================================================

drop policy if exists
"Authorized users view room reservations"
on public.room_inventory_reservations;

create policy
"Authorized users view room reservations"
on public.room_inventory_reservations
for select
to authenticated
using (
  public.can_view_booking_item(
    booking_item_id
  )
);



-- =========================================================
-- 10. ACTIVITY INVENTORY LEDGER
-- =========================================================

drop policy if exists
"Authorized users view activity reservations"
on public.activity_inventory_reservations;

create policy
"Authorized users view activity reservations"
on public.activity_inventory_reservations
for select
to authenticated
using (
  public.can_view_booking_item(
    booking_item_id
  )
);



-- =========================================================
-- 11. BOOKING STATUS HISTORY
-- Full booking-level history is traveler/admin only.
-- =========================================================

drop policy if exists
"Traveler and admin view booking history"
on public.booking_status_history;

create policy
"Traveler and admin view booking history"
on public.booking_status_history
for select
to authenticated
using (
  public.is_booking_owner(booking_id)
  or public.is_admin_user()
);



-- =========================================================
-- 12. CANCELLATION VISIBILITY
--
-- Traveler sees own cancellation requests.
-- Relevant provider can see item/full cancellation requests.
-- =========================================================

drop policy if exists
"Authorized users view cancellations"
on public.booking_cancellations;

create policy
"Authorized users view cancellations"
on public.booking_cancellations
for select
to authenticated
using (
  public.is_booking_owner(booking_id)

  or public.is_admin_user()

  or (
    booking_item_id is not null
    and public.can_view_booking_item(
      booking_item_id
    )
  )

  or (
    booking_item_id is null
    and public.provider_has_booking_item(
      booking_id
    )
  )
);



-- =========================================================
-- 13. PREVENT DUPLICATE ACTIVE CANCELLATION REQUESTS
-- =========================================================

create unique index if not exists
one_active_full_cancellation_per_booking_idx
on public.booking_cancellations(booking_id)
where
  booking_item_id is null
  and status in (
    'requested',
    'approved'
  );


create unique index if not exists
one_active_item_cancellation_idx
on public.booking_cancellations(booking_item_id)
where
  booking_item_id is not null
  and status in (
    'requested',
    'approved'
  );



-- =========================================================
-- 14. SECURE CANCELLATION REQUEST FUNCTION
--
-- p_booking_item_id = NULL
--   -> full booking cancellation request
--
-- p_booking_item_id = ID
--   -> one booking item cancellation request
-- =========================================================

create or replace function public.request_booking_cancellation(
  p_booking_id bigint,
  p_booking_item_id bigint default null,
  p_reason text default null
)
returns public.booking_cancellations
language plpgsql
security definer
set search_path = ''
as $$
declare

  v_booking public.bookings%rowtype;

  v_item public.booking_items%rowtype;

  v_result public.booking_cancellations%rowtype;

  v_service_date date;

begin

  -- -------------------------------------------------------
  -- Authentication
  -- -------------------------------------------------------

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  -- -------------------------------------------------------
  -- Lock booking
  --
  -- Serializes competing cancellation requests.
  -- -------------------------------------------------------

  select *
  into v_booking
  from public.bookings
  where id = p_booking_id
  for update;


  if not found then
    raise exception 'Booking does not exist';
  end if;


  if v_booking.traveler_id <> auth.uid() then
    raise exception 'You do not own this booking';
  end if;


  if v_booking.status not in (
    'confirmed',
    'partially_cancelled'
  ) then

    raise exception
      'This booking is not eligible for cancellation';

  end if;



  -- =======================================================
  -- FULL BOOKING CANCELLATION REQUEST
  -- =======================================================

  if p_booking_item_id is null then

    -- Do not allow a full cancellation after a booked
    -- service has already passed/started on a previous date.
    if exists (
      select 1
      from public.booking_items bi
      where bi.booking_id = p_booking_id
        and bi.status = 'confirmed'
        and coalesce(
              bi.check_in_date,
              bi.service_date
            ) < current_date
    ) then

      raise exception
        'Full booking cancellation cannot be requested after a service has started';

    end if;


    -- Prevent full cancellation while any other active
    -- cancellation request already exists.
    if exists (
      select 1
      from public.booking_cancellations bc
      where bc.booking_id = p_booking_id
        and bc.status in (
          'requested',
          'approved'
        )
    ) then

      raise exception
        'An active cancellation request already exists for this booking';

    end if;


    insert into public.booking_cancellations (
      booking_id,
      booking_item_id,
      requested_by,
      cancellation_type,
      reason,
      status
    )
    values (
      p_booking_id,
      null,
      auth.uid(),
      'full_booking',
      nullif(trim(p_reason), ''),
      'requested'
    )
    returning *
    into v_result;



  -- =======================================================
  -- SINGLE BOOKING ITEM CANCELLATION REQUEST
  -- =======================================================

  else

    select *
    into v_item
    from public.booking_items
    where id = p_booking_item_id
      and booking_id = p_booking_id
    for update;


    if not found then
      raise exception
        'Booking item does not belong to this booking';
    end if;


    if v_item.status <> 'confirmed' then
      raise exception
        'Only a confirmed booking item can be cancelled';
    end if;


    v_service_date :=
      coalesce(
        v_item.check_in_date,
        v_item.service_date
      );


    if v_service_date is not null
       and v_service_date < current_date then

      raise exception
        'This service has already started or passed';

    end if;


    -- Full cancellation already waiting?
    if exists (
      select 1
      from public.booking_cancellations bc
      where bc.booking_id = p_booking_id
        and bc.booking_item_id is null
        and bc.status in (
          'requested',
          'approved'
        )
    ) then

      raise exception
        'A full-booking cancellation request already exists';

    end if;


    -- Same item already waiting?
    if exists (
      select 1
      from public.booking_cancellations bc
      where bc.booking_item_id = p_booking_item_id
        and bc.status in (
          'requested',
          'approved'
        )
    ) then

      raise exception
        'An active cancellation request already exists for this booking item';

    end if;


    insert into public.booking_cancellations (
      booking_id,
      booking_item_id,
      requested_by,
      cancellation_type,
      reason,
      status
    )
    values (
      p_booking_id,
      p_booking_item_id,
      auth.uid(),
      'booking_item',
      nullif(trim(p_reason), ''),
      'requested'
    )
    returning *
    into v_result;

  end if;


  return v_result;

end;
$$;



-- =========================================================
-- 15. API PRIVILEGE LOCKDOWN
--
-- Client can READ permitted rows only.
-- Client cannot manually create/change confirmed bookings.
-- =========================================================

revoke all
on table
  public.bookings,
  public.booking_items,
  public.room_inventory_reservations,
  public.activity_inventory_reservations,
  public.booking_status_history,
  public.booking_cancellations
from anon, authenticated;


grant select
on table
  public.bookings,
  public.booking_items,
  public.room_inventory_reservations,
  public.activity_inventory_reservations,
  public.booking_status_history,
  public.booking_cancellations
to authenticated;



-- =========================================================
-- 16. FUNCTION PRIVILEGES
-- =========================================================

revoke all
on function public.request_booking_cancellation(
  bigint,
  bigint,
  text
)
from public, anon;


grant execute
on function public.request_booking_cancellation(
  bigint,
  bigint,
  text
)
to authenticated;
