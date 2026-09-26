-- =========================================================
-- TripMate
-- Migration 013: Trip Cart Snapshot Integrity
-- =========================================================

create or replace function public.set_trip_cart_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_name text;
  source_price numeric(12,2);
  source_currency text;
begin

  -- Room
  if new.item_type = 'room' then

    select
      rt.name,
      rt.base_price_per_night,
      rt.currency
    into
      source_name,
      source_price,
      source_currency
    from public.room_types rt
    where rt.id = new.room_type_id;


  -- Food
  elsif new.item_type = 'food' then

    select
      fi.name,
      fi.price,
      fi.currency
    into
      source_name,
      source_price,
      source_currency
    from public.food_items fi
    where fi.id = new.food_item_id;


  -- Buffet
  elsif new.item_type = 'buffet' then

    select
      bp.name,
      bp.price_per_person,
      bp.currency
    into
      source_name,
      source_price,
      source_currency
    from public.buffet_packages bp
    where bp.id = new.buffet_package_id;


  -- Restaurant Reservation
  elsif new.item_type = 'restaurant_reservation' then

    select
      r.name
    into source_name
    from public.restaurants r
    where r.id = new.restaurant_id;

    source_price := 0;
    source_currency := 'LKR';


  -- Attraction
  elsif new.item_type = 'attraction' then

    select
      a.name,
      a.entrance_fee,
      a.currency
    into
      source_name,
      source_price,
      source_currency
    from public.attractions a
    where a.id = new.attraction_id;


  -- Activity
  elsif new.item_type = 'activity' then

    select
      ac.name,
      ac.price_per_person,
      ac.currency
    into
      source_name,
      source_price,
      source_currency
    from public.activities ac
    where ac.id = new.activity_id;

  end if;


  if source_name is null then
    raise exception 'Invalid cart service source';
  end if;


  -- Never trust snapshot values sent by the browser.
  -- Copy them from the real service record instead.
  new.item_name_snapshot := source_name;
  new.unit_price_snapshot := coalesce(source_price, 0);
  new.currency := coalesce(source_currency, 'LKR');

  return new;

end;
$$;


drop trigger if exists set_trip_cart_snapshot_trigger
on public.trip_cart_items;

create trigger set_trip_cart_snapshot_trigger
before insert or update
on public.trip_cart_items
for each row
execute procedure public.set_trip_cart_snapshot();
