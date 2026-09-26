-- =========================================================
-- TripMate
-- Migration 011: Traveler Core RLS Security
-- =========================================================


-- =========================================================
-- 1. HELPER: CHECK TRIP OWNERSHIP
-- =========================================================

create or replace function public.is_trip_owner(
  target_trip_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.trips t
    join public.profiles p
      on p.id = t.traveler_id
    where t.id = target_trip_id
      and t.traveler_id = auth.uid()
      and p.role = 'traveler'
  );
$$;

revoke all
on function public.is_trip_owner(bigint)
from public;

grant execute
on function public.is_trip_owner(bigint)
to authenticated;



-- =========================================================
-- 2. HELPER: PUBLIC DESTINATION
-- =========================================================

create or replace function public.is_destination_public(
  target_destination_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.destinations d
    where d.id = target_destination_id
      and d.is_active = true
  );
$$;

revoke all
on function public.is_destination_public(bigint)
from public;

grant execute
on function public.is_destination_public(bigint)
to anon, authenticated;



-- =========================================================
-- 3. HELPER: PUBLIC ATTRACTION
-- =========================================================

create or replace function public.is_attraction_public(
  target_attraction_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.attractions a
    join public.destinations d
      on d.id = a.destination_id
    where a.id = target_attraction_id
      and a.is_active = true
      and d.is_active = true
  );
$$;

revoke all
on function public.is_attraction_public(bigint)
from public;

grant execute
on function public.is_attraction_public(bigint)
to anon, authenticated;



-- =========================================================
-- 4. HELPER: PUBLIC ACTIVITY
-- =========================================================

create or replace function public.is_activity_public(
  target_activity_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.activities ac
    join public.destinations d
      on d.id = ac.destination_id
    where ac.id = target_activity_id
      and ac.is_active = true
      and d.is_active = true
      and (
        ac.attraction_id is null
        or public.is_attraction_public(ac.attraction_id)
      )
  );
$$;

revoke all
on function public.is_activity_public(bigint)
from public;

grant execute
on function public.is_activity_public(bigint)
to anon, authenticated;



-- =========================================================
-- 5. HELPER: CHECK CART SERVICE VISIBILITY
-- =========================================================

create or replace function public.is_cart_source_public(
  source_type text,
  source_room_type_id bigint,
  source_food_item_id bigint,
  source_buffet_package_id bigint,
  source_restaurant_id bigint,
  source_attraction_id bigint,
  source_activity_id bigint
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin

  if source_type = 'room' then
    return public.is_room_type_public(
      source_room_type_id
    );

  elsif source_type = 'food' then
    return public.is_food_item_public(
      source_food_item_id
    );

  elsif source_type = 'buffet' then
    return public.is_buffet_public(
      source_buffet_package_id
    );

  elsif source_type = 'restaurant_reservation' then
    return public.is_restaurant_public(
      source_restaurant_id
    );

  elsif source_type = 'attraction' then
    return public.is_attraction_public(
      source_attraction_id
    );

  elsif source_type = 'activity' then
    return public.is_activity_public(
      source_activity_id
    );

  end if;

  return false;

end;
$$;

revoke all
on function public.is_cart_source_public(
  text,
  bigint,
  bigint,
  bigint,
  bigint,
  bigint,
  bigint
)
from public;

grant execute
on function public.is_cart_source_public(
  text,
  bigint,
  bigint,
  bigint,
  bigint,
  bigint,
  bigint
)
to authenticated;



-- =========================================================
-- 6. ENABLE RLS
-- =========================================================

alter table public.trips enable row level security;
alter table public.trip_preferences enable row level security;
alter table public.trip_destinations enable row level security;
alter table public.trip_cart_items enable row level security;

alter table public.destinations enable row level security;

alter table public.attraction_categories enable row level security;
alter table public.attractions enable row level security;
alter table public.attraction_images enable row level security;
alter table public.attraction_opening_hours enable row level security;

alter table public.activities enable row level security;
alter table public.activity_availability enable row level security;



-- =========================================================
-- 7. DESTINATIONS - PUBLIC READ
-- =========================================================

drop policy if exists
"Public can view active destinations"
on public.destinations;

create policy
"Public can view active destinations"
on public.destinations
for select
to anon, authenticated
using (
  is_active = true
);



-- =========================================================
-- 8. ATTRACTION CATEGORIES - PUBLIC READ
-- =========================================================

drop policy if exists
"Public can view attraction categories"
on public.attraction_categories;

create policy
"Public can view attraction categories"
on public.attraction_categories
for select
to anon, authenticated
using (
  is_active = true
);



-- =========================================================
-- 9. ATTRACTIONS - PUBLIC READ
-- =========================================================

drop policy if exists
"Public can view active attractions"
on public.attractions;

create policy
"Public can view active attractions"
on public.attractions
for select
to anon, authenticated
using (
  public.is_attraction_public(id)
);



-- =========================================================
-- 10. ATTRACTION IMAGES
-- =========================================================

drop policy if exists
"Public can view attraction images"
on public.attraction_images;

create policy
"Public can view attraction images"
on public.attraction_images
for select
to anon, authenticated
using (
  public.is_attraction_public(attraction_id)
);



-- =========================================================
-- 11. ATTRACTION OPENING HOURS
-- =========================================================

drop policy if exists
"Public can view attraction opening hours"
on public.attraction_opening_hours;

create policy
"Public can view attraction opening hours"
on public.attraction_opening_hours
for select
to anon, authenticated
using (
  public.is_attraction_public(attraction_id)
);



-- =========================================================
-- 12. ACTIVITIES - PUBLIC READ
-- =========================================================

drop policy if exists
"Public can view active activities"
on public.activities;

create policy
"Public can view active activities"
on public.activities
for select
to anon, authenticated
using (
  public.is_activity_public(id)
);



-- =========================================================
-- 13. ACTIVITY AVAILABILITY
-- =========================================================

drop policy if exists
"Public can view activity availability"
on public.activity_availability;

create policy
"Public can view activity availability"
on public.activity_availability
for select
to anon, authenticated
using (
  public.is_activity_public(activity_id)
);



-- =========================================================
-- 14. TRIPS - OWNER READ
-- =========================================================

drop policy if exists
"Travelers can view own trips"
on public.trips;

create policy
"Travelers can view own trips"
on public.trips
for select
to authenticated
using (
  traveler_id = auth.uid()
);



-- =========================================================
-- 15. TRIPS - CREATE
-- =========================================================

drop policy if exists
"Travelers can create own trips"
on public.trips;

create policy
"Travelers can create own trips"
on public.trips
for insert
to authenticated
with check (
  traveler_id = auth.uid()

  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'traveler'
  )
);



-- =========================================================
-- 16. TRIPS - UPDATE
-- =========================================================

drop policy if exists
"Travelers can update own trips"
on public.trips;

create policy
"Travelers can update own trips"
on public.trips
for update
to authenticated
using (
  traveler_id = auth.uid()
)
with check (
  traveler_id = auth.uid()

  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'traveler'
  )
);



-- =========================================================
-- 17. TRIPS - DELETE
-- Only planning trips may be physically deleted.
-- Later trips should be cancelled instead.
-- =========================================================

drop policy if exists
"Travelers can delete own planning trips"
on public.trips;

create policy
"Travelers can delete own planning trips"
on public.trips
for delete
to authenticated
using (
  traveler_id = auth.uid()
  and status = 'planning'
);



-- =========================================================
-- 18. TRIP PREFERENCES
-- =========================================================

drop policy if exists
"Travelers manage own trip preferences"
on public.trip_preferences;

create policy
"Travelers manage own trip preferences"
on public.trip_preferences
for all
to authenticated
using (
  public.is_trip_owner(trip_id)
)
with check (
  public.is_trip_owner(trip_id)
);



-- =========================================================
-- 19. TRIP DESTINATIONS - VIEW
-- =========================================================

drop policy if exists
"Travelers view own trip destinations"
on public.trip_destinations;

create policy
"Travelers view own trip destinations"
on public.trip_destinations
for select
to authenticated
using (
  public.is_trip_owner(trip_id)
);



-- =========================================================
-- 20. TRIP DESTINATIONS - INSERT
-- Only active destinations can be newly selected.
-- =========================================================

drop policy if exists
"Travelers add destinations to own trips"
on public.trip_destinations;

create policy
"Travelers add destinations to own trips"
on public.trip_destinations
for insert
to authenticated
with check (
  public.is_trip_owner(trip_id)
  and public.is_destination_public(destination_id)
);



-- =========================================================
-- 21. TRIP DESTINATIONS - UPDATE
-- =========================================================

drop policy if exists
"Travelers update own trip destinations"
on public.trip_destinations;

create policy
"Travelers update own trip destinations"
on public.trip_destinations
for update
to authenticated
using (
  public.is_trip_owner(trip_id)
)
with check (
  public.is_trip_owner(trip_id)
  and public.is_destination_public(destination_id)
);



-- =========================================================
-- 22. TRIP DESTINATIONS - DELETE
-- =========================================================

drop policy if exists
"Travelers delete own trip destinations"
on public.trip_destinations;

create policy
"Travelers delete own trip destinations"
on public.trip_destinations
for delete
to authenticated
using (
  public.is_trip_owner(trip_id)
);



-- =========================================================
-- 23. TRIP CART - VIEW
-- Existing snapshot remains visible even if provider
-- later disables the service.
-- =========================================================

drop policy if exists
"Travelers view own trip cart"
on public.trip_cart_items;

create policy
"Travelers view own trip cart"
on public.trip_cart_items
for select
to authenticated
using (
  public.is_trip_owner(trip_id)
);



-- =========================================================
-- 24. TRIP CART - INSERT
-- New items must belong to the traveler and currently
-- represent a public/available service.
-- =========================================================

drop policy if exists
"Travelers add valid services to own cart"
on public.trip_cart_items;

create policy
"Travelers add valid services to own cart"
on public.trip_cart_items
for insert
to authenticated
with check (
  public.is_trip_owner(trip_id)

  and public.is_cart_source_public(
    item_type,
    room_type_id,
    food_item_id,
    buffet_package_id,
    restaurant_id,
    attraction_id,
    activity_id
  )
);



-- =========================================================
-- 25. TRIP CART - UPDATE
-- =========================================================

drop policy if exists
"Travelers update own valid cart items"
on public.trip_cart_items;

create policy
"Travelers update own valid cart items"
on public.trip_cart_items
for update
to authenticated
using (
  public.is_trip_owner(trip_id)
)
with check (
  public.is_trip_owner(trip_id)

  and public.is_cart_source_public(
    item_type,
    room_type_id,
    food_item_id,
    buffet_package_id,
    restaurant_id,
    attraction_id,
    activity_id
  )
);



-- =========================================================
-- 26. TRIP CART - DELETE
-- Even if a service becomes unavailable, traveler must
-- still be able to remove it from the cart.
-- =========================================================

drop policy if exists
"Travelers delete own cart items"
on public.trip_cart_items;

create policy
"Travelers delete own cart items"
on public.trip_cart_items
for delete
to authenticated
using (
  public.is_trip_owner(trip_id)
);
