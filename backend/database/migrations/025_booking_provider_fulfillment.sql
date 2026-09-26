-- =========================================================
-- TripMate
-- Migration 025: Provider Fulfillment Snapshots
-- =========================================================


-- =========================================================
-- 1. PROVIDER-SAFE BOOKING INFORMATION
--
-- Providers cannot read the complete booking header because
-- it may contain totals/services belonging to other providers.
--
-- Each booking item therefore keeps only the traveler
-- information required to fulfil that specific service.
-- =========================================================

alter table public.booking_items
add column if not exists booking_reference_snapshot text;

alter table public.booking_items
add column if not exists traveler_name_snapshot text;

alter table public.booking_items
add column if not exists traveler_phone_snapshot text;



-- =========================================================
-- 2. POPULATE SNAPSHOTS FROM AUTHORITATIVE BOOKING
--
-- Never trust these values from the frontend.
-- =========================================================

create or replace function
public.populate_booking_item_fulfillment_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking_reference text;
  v_traveler_name text;
  v_traveler_phone text;
begin

  select
    b.booking_reference,
    b.traveler_name_snapshot,
    b.traveler_phone_snapshot

  into
    v_booking_reference,
    v_traveler_name,
    v_traveler_phone

  from public.bookings b

  where b.id = new.booking_id;


  if not found then
    raise exception 'Booking does not exist';
  end if;


  new.booking_reference_snapshot :=
    v_booking_reference;

  new.traveler_name_snapshot :=
    v_traveler_name;

  new.traveler_phone_snapshot :=
    v_traveler_phone;


  return new;

end;
$$;



drop trigger if exists
populate_booking_item_fulfillment_snapshot_trigger
on public.booking_items;


create trigger
populate_booking_item_fulfillment_snapshot_trigger
before insert
on public.booking_items
for each row
execute procedure
public.populate_booking_item_fulfillment_snapshot();



-- =========================================================
-- 3. BACKFILL EXISTING BOOKING ITEMS
-- =========================================================

update public.booking_items bi
set
  booking_reference_snapshot =
    b.booking_reference,

  traveler_name_snapshot =
    b.traveler_name_snapshot,

  traveler_phone_snapshot =
    b.traveler_phone_snapshot

from public.bookings b

where b.id = bi.booking_id

  and (
    bi.booking_reference_snapshot is null
    or bi.traveler_name_snapshot is null
    or bi.traveler_phone_snapshot is null
  );



-- =========================================================
-- 4. LOOKUP INDEX
-- Providers can quickly search by booking reference.
-- =========================================================

create index if not exists
booking_items_reference_snapshot_idx
on public.booking_items(
  booking_reference_snapshot
);
