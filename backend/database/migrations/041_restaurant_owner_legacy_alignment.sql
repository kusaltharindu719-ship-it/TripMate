-- =========================================================
-- TripMate
-- Migration 041: Restaurant Owner Legacy Alignment
-- =========================================================

-- =========================================================
-- 1. FIX RESTAURANT OWNER FOREIGN KEY
-- Legacy schema referenced public.users(id).
-- Current TripMate uses public.profiles(id).
-- =========================================================

alter table public.restaurants
drop constraint if exists restaurants_owner_id_fkey;

alter table public.restaurants
add constraint restaurants_owner_id_fkey
foreign key (owner_id)
references public.profiles(id)
on delete cascade
not valid;


-- =========================================================
-- 2. REQUIRED TABLE PRIVILEGES
-- =========================================================

grant select, insert, update, delete
on table
    public.restaurants,
    public.food_items,
    public.buffet_packages,
    public.restaurant_opening_hours
to authenticated;


-- =========================================================
-- 3. REQUIRED SEQUENCE PRIVILEGES
-- =========================================================

grant usage, select
on sequence
    public.restaurants_id_seq,
    public.food_items_id_seq,
    public.buffet_packages_id_seq,
    public.restaurant_opening_hours_id_seq
to authenticated;


-- =========================================================
-- 4. RESTAURANT OWNER CREATE POLICY
-- =========================================================

alter table public.restaurants
enable row level security;

drop policy if exists
"Restaurant owners can create own restaurants"
on public.restaurants;

create policy
"Restaurant owners can create own restaurants"
on public.restaurants
for insert
to authenticated
with check (
    owner_id = auth.uid()

    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'restaurant_owner'
    )
);


-- =========================================================
-- 5. FOOD ITEM OWNER POLICY
-- =========================================================

alter table public.food_items
enable row level security;

drop policy if exists
"Owners manage own food items"
on public.food_items;

create policy
"Owners manage own food items"
on public.food_items
for all
to authenticated
using (
    public.is_restaurant_owner(restaurant_id)
)
with check (
    public.is_restaurant_owner(restaurant_id)
);


-- =========================================================
-- 6. BUFFET PACKAGE OWNER POLICY
-- =========================================================

alter table public.buffet_packages
enable row level security;

drop policy if exists
"Owners manage own buffet packages"
on public.buffet_packages;

create policy
"Owners manage own buffet packages"
on public.buffet_packages
for all
to authenticated
using (
    public.is_restaurant_owner(restaurant_id)
)
with check (
    public.is_restaurant_owner(restaurant_id)
);


-- =========================================================
-- 7. OPENING HOURS OWNER POLICY
-- =========================================================

alter table public.restaurant_opening_hours
enable row level security;

drop policy if exists
"Owners manage own restaurant opening hours"
on public.restaurant_opening_hours;

create policy
"Owners manage own restaurant opening hours"
on public.restaurant_opening_hours
for all
to authenticated
using (
    public.is_restaurant_owner(restaurant_id)
)
with check (
    public.is_restaurant_owner(restaurant_id)
);


-- =========================================================
-- END MIGRATION 041
-- =========================================================