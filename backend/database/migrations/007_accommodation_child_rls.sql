-- =========================================================
-- TripMate
-- Migration 007: Accommodation Child Table RLS
-- =========================================================


-- =========================================================
-- 1. HELPER: ROOM TYPE OWNERSHIP
-- =========================================================

create or replace function public.is_room_type_owner(
  target_room_type_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.room_types rt
    where rt.id = target_room_type_id
      and public.is_accommodation_owner(rt.accommodation_id)
  );
$$;

revoke all
on function public.is_room_type_owner(bigint)
from public;

grant execute
on function public.is_room_type_owner(bigint)
to authenticated;



-- =========================================================
-- 2. HELPER: PUBLIC ROOM TYPE
-- =========================================================

create or replace function public.is_room_type_public(
  target_room_type_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.room_types rt
    where rt.id = target_room_type_id
      and rt.is_active = true
      and public.is_accommodation_public(rt.accommodation_id)
  );
$$;

revoke all
on function public.is_room_type_public(bigint)
from public;

grant execute
on function public.is_room_type_public(bigint)
to anon, authenticated;



-- =========================================================
-- 3. VALIDATE OFFER ROOM BELONGS TO SAME PROPERTY
-- =========================================================

create or replace function public.validate_accommodation_offer_room()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  if new.room_type_id is not null
     and not exists (
       select 1
       from public.room_types rt
       where rt.id = new.room_type_id
         and rt.accommodation_id = new.accommodation_id
     )
  then
    raise exception
      'Room type must belong to the same accommodation';
  end if;

  return new;

end;
$$;


drop trigger if exists validate_accommodation_offer_room_trigger
on public.accommodation_offers;

create trigger validate_accommodation_offer_room_trigger
before insert or update
on public.accommodation_offers
for each row
execute procedure public.validate_accommodation_offer_room();



-- =========================================================
-- 4. ENABLE RLS
-- =========================================================

alter table public.accommodation_types enable row level security;

alter table public.accommodation_images enable row level security;

alter table public.accommodation_amenity_catalog enable row level security;
alter table public.accommodation_amenities enable row level security;

alter table public.room_types enable row level security;
alter table public.room_images enable row level security;

alter table public.room_amenity_catalog enable row level security;
alter table public.room_amenities enable row level security;

alter table public.bed_types enable row level security;
alter table public.room_beds enable row level security;

alter table public.meal_plans enable row level security;
alter table public.accommodation_meal_plans enable row level security;

alter table public.room_availability enable row level security;

alter table public.accommodation_offers enable row level security;
alter table public.accommodation_policies enable row level security;
alter table public.accommodation_availability enable row level security;



-- =========================================================
-- 5. REFERENCE CATALOG TABLES
-- =========================================================

create policy "Public can read accommodation types"
on public.accommodation_types
for select
to anon, authenticated
using (is_active = true);


create policy "Public can read accommodation amenities"
on public.accommodation_amenity_catalog
for select
to anon, authenticated
using (is_active = true);


create policy "Public can read room amenities"
on public.room_amenity_catalog
for select
to anon, authenticated
using (is_active = true);


create policy "Public can read bed types"
on public.bed_types
for select
to anon, authenticated
using (is_active = true);


create policy "Public can read meal plans"
on public.meal_plans
for select
to anon, authenticated
using (is_active = true);



-- =========================================================
-- 6. ACCOMMODATION IMAGES
-- =========================================================

create policy "Public can view accommodation images"
on public.accommodation_images
for select
to anon, authenticated
using (
  public.is_accommodation_public(accommodation_id)
);


create policy "Owners manage own accommodation images"
on public.accommodation_images
for all
to authenticated
using (
  public.is_accommodation_owner(accommodation_id)
)
with check (
  public.is_accommodation_owner(accommodation_id)
);



-- =========================================================
-- 7. PROPERTY AMENITIES
-- =========================================================

create policy "Public can view accommodation amenity links"
on public.accommodation_amenities
for select
to anon, authenticated
using (
  public.is_accommodation_public(accommodation_id)
);


create policy "Owners manage own accommodation amenities"
on public.accommodation_amenities
for all
to authenticated
using (
  public.is_accommodation_owner(accommodation_id)
)
with check (
  public.is_accommodation_owner(accommodation_id)
);



-- =========================================================
-- 8. ROOM TYPES
-- =========================================================

create policy "Public can view active room types"
on public.room_types
for select
to anon, authenticated
using (
  is_active = true
  and public.is_accommodation_public(accommodation_id)
);


create policy "Owners manage own room types"
on public.room_types
for all
to authenticated
using (
  public.is_accommodation_owner(accommodation_id)
)
with check (
  public.is_accommodation_owner(accommodation_id)
);



-- =========================================================
-- 9. ROOM IMAGES
-- =========================================================

create policy "Public can view room images"
on public.room_images
for select
to anon, authenticated
using (
  public.is_room_type_public(room_type_id)
);


create policy "Owners manage own room images"
on public.room_images
for all
to authenticated
using (
  public.is_room_type_owner(room_type_id)
)
with check (
  public.is_room_type_owner(room_type_id)
);



-- =========================================================
-- 10. ROOM AMENITIES
-- =========================================================

create policy "Public can view room amenity links"
on public.room_amenities
for select
to anon, authenticated
using (
  public.is_room_type_public(room_type_id)
);


create policy "Owners manage own room amenities"
on public.room_amenities
for all
to authenticated
using (
  public.is_room_type_owner(room_type_id)
)
with check (
  public.is_room_type_owner(room_type_id)
);



-- =========================================================
-- 11. ROOM BEDS
-- =========================================================

create policy "Public can view room beds"
on public.room_beds
for select
to anon, authenticated
using (
  public.is_room_type_public(room_type_id)
);


create policy "Owners manage own room beds"
on public.room_beds
for all
to authenticated
using (
  public.is_room_type_owner(room_type_id)
)
with check (
  public.is_room_type_owner(room_type_id)
);



-- =========================================================
-- 12. ACCOMMODATION MEAL PLANS
-- =========================================================

create policy "Public can view accommodation meal plans"
on public.accommodation_meal_plans
for select
to anon, authenticated
using (
  is_available = true
  and public.is_accommodation_public(accommodation_id)
);


create policy "Owners manage own accommodation meal plans"
on public.accommodation_meal_plans
for all
to authenticated
using (
  public.is_accommodation_owner(accommodation_id)
)
with check (
  public.is_accommodation_owner(accommodation_id)
);



-- =========================================================
-- 13. ROOM AVAILABILITY
-- =========================================================

create policy "Public can view room availability"
on public.room_availability
for select
to anon, authenticated
using (
  public.is_room_type_public(room_type_id)
);


create policy "Owners manage own room availability"
on public.room_availability
for all
to authenticated
using (
  public.is_room_type_owner(room_type_id)
)
with check (
  public.is_room_type_owner(room_type_id)
);



-- =========================================================
-- 14. ACCOMMODATION OFFERS
-- Only currently valid offers are public.
-- =========================================================

create policy "Public can view valid accommodation offers"
on public.accommodation_offers
for select
to anon, authenticated
using (
  is_active = true

  and (
    start_date is null
    or start_date <= current_date
  )

  and (
    end_date is null
    or end_date >= current_date
  )

  and public.is_accommodation_public(accommodation_id)
);


create policy "Owners manage own accommodation offers"
on public.accommodation_offers
for all
to authenticated
using (
  public.is_accommodation_owner(accommodation_id)
)
with check (
  public.is_accommodation_owner(accommodation_id)
);



-- =========================================================
-- 15. ACCOMMODATION POLICIES
-- =========================================================

create policy "Public can view accommodation policies"
on public.accommodation_policies
for select
to anon, authenticated
using (
  public.is_accommodation_public(accommodation_id)
);


create policy "Owners manage own accommodation policies"
on public.accommodation_policies
for all
to authenticated
using (
  public.is_accommodation_owner(accommodation_id)
)
with check (
  public.is_accommodation_owner(accommodation_id)
);



-- =========================================================
-- 16. PROPERTY TEMPORARY AVAILABILITY
-- =========================================================

create policy "Public can view accommodation availability"
on public.accommodation_availability
for select
to anon, authenticated
using (
  public.is_accommodation_public(accommodation_id)
);


create policy "Owners manage own accommodation availability"
on public.accommodation_availability
for all
to authenticated
using (
  public.is_accommodation_owner(accommodation_id)
)
with check (
  public.is_accommodation_owner(accommodation_id)
);
