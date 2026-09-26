-- =========================================================
-- TripMate
-- Migration 003: Restaurant Child Table Security
-- =========================================================


-- =========================================================
-- 1. HELPER FUNCTIONS
-- =========================================================

create or replace function public.is_food_item_owner(
  target_food_item_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.food_items fi
    where fi.id = target_food_item_id
      and public.is_restaurant_owner(fi.restaurant_id)
  );
$$;

revoke all
on function public.is_food_item_owner(bigint)
from public;

grant execute
on function public.is_food_item_owner(bigint)
to authenticated;


create or replace function public.is_food_item_public(
  target_food_item_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.food_items fi
    where fi.id = target_food_item_id
      and fi.is_available = true
      and public.is_restaurant_public(fi.restaurant_id)
  );
$$;

revoke all
on function public.is_food_item_public(bigint)
from public;

grant execute
on function public.is_food_item_public(bigint)
to anon, authenticated;


create or replace function public.is_buffet_owner(
  target_buffet_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.buffet_packages bp
    where bp.id = target_buffet_id
      and public.is_restaurant_owner(bp.restaurant_id)
  );
$$;

revoke all
on function public.is_buffet_owner(bigint)
from public;

grant execute
on function public.is_buffet_owner(bigint)
to authenticated;


create or replace function public.is_buffet_public(
  target_buffet_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.buffet_packages bp
    where bp.id = target_buffet_id
      and bp.is_available = true
      and public.is_restaurant_public(bp.restaurant_id)
  );
$$;

revoke all
on function public.is_buffet_public(bigint)
from public;

grant execute
on function public.is_buffet_public(bigint)
to anon, authenticated;



-- =========================================================
-- 2. PREVENT FOOD ITEM FROM USING ANOTHER RESTAURANT'S
--    FOOD CATEGORY
-- =========================================================

create or replace function public.validate_food_item_category()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  if new.category_id is not null
     and not exists (
       select 1
       from public.food_categories fc
       where fc.id = new.category_id
         and fc.restaurant_id = new.restaurant_id
     )
  then
    raise exception
      'Food category must belong to the same restaurant';
  end if;

  return new;

end;
$$;


drop trigger if exists validate_food_item_category_trigger
on public.food_items;

create trigger validate_food_item_category_trigger
before insert or update
on public.food_items
for each row
execute procedure public.validate_food_item_category();



-- =========================================================
-- 3. ENABLE RLS
-- =========================================================

alter table public.restaurant_opening_hours enable row level security;
alter table public.restaurant_images enable row level security;

alter table public.restaurant_feature_catalog enable row level security;
alter table public.restaurant_features enable row level security;

alter table public.service_modes enable row level security;
alter table public.restaurant_service_modes enable row level security;

alter table public.cuisines enable row level security;
alter table public.restaurant_cuisines enable row level security;

alter table public.dietary_options enable row level security;
alter table public.restaurant_dietary_options enable row level security;

alter table public.food_categories enable row level security;
alter table public.food_items enable row level security;
alter table public.food_item_dietary_options enable row level security;

alter table public.buffet_packages enable row level security;
alter table public.buffet_items enable row level security;

alter table public.restaurant_offers enable row level security;
alter table public.restaurant_availability enable row level security;
alter table public.restaurant_policies enable row level security;



-- =========================================================
-- 4. REFERENCE CATALOGS
-- Everyone can READ.
-- Normal users cannot INSERT / UPDATE / DELETE.
-- =========================================================

create policy "Public can read restaurant feature catalog"
on public.restaurant_feature_catalog
for select
to anon, authenticated
using (is_active = true);


create policy "Public can read service modes"
on public.service_modes
for select
to anon, authenticated
using (true);


create policy "Public can read cuisines"
on public.cuisines
for select
to anon, authenticated
using (true);


create policy "Public can read dietary options"
on public.dietary_options
for select
to anon, authenticated
using (true);



-- =========================================================
-- 5. OPENING HOURS
-- =========================================================

create policy "Public can view restaurant opening hours"
on public.restaurant_opening_hours
for select
to anon, authenticated
using (
  public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own restaurant opening hours"
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
-- 6. RESTAURANT IMAGES
-- =========================================================

create policy "Public can view restaurant images"
on public.restaurant_images
for select
to anon, authenticated
using (
  public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own restaurant images"
on public.restaurant_images
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);



-- =========================================================
-- 7. RESTAURANT FEATURES
-- Parking, Wi-Fi, BYOB etc.
-- =========================================================

create policy "Public can view restaurant features"
on public.restaurant_features
for select
to anon, authenticated
using (
  public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own restaurant features"
on public.restaurant_features
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);



-- =========================================================
-- 8. SERVICE MODES
-- Dine-in / Takeaway / Delivery / Pickup
-- =========================================================

create policy "Public can view restaurant service modes"
on public.restaurant_service_modes
for select
to anon, authenticated
using (
  public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own restaurant service modes"
on public.restaurant_service_modes
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);



-- =========================================================
-- 9. CUISINES
-- =========================================================

create policy "Public can view restaurant cuisines"
on public.restaurant_cuisines
for select
to anon, authenticated
using (
  public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own restaurant cuisines"
on public.restaurant_cuisines
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);



-- =========================================================
-- 10. RESTAURANT DIETARY OPTIONS
-- =========================================================

create policy "Public can view restaurant dietary options"
on public.restaurant_dietary_options
for select
to anon, authenticated
using (
  public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage restaurant dietary options"
on public.restaurant_dietary_options
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);



-- =========================================================
-- 11. FOOD CATEGORIES
-- =========================================================

create policy "Public can view food categories"
on public.food_categories
for select
to anon, authenticated
using (
  is_active = true
  and public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own food categories"
on public.food_categories
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);



-- =========================================================
-- 12. FOOD ITEMS
-- =========================================================

create policy "Public can view available food items"
on public.food_items
for select
to anon, authenticated
using (
  is_available = true
  and public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own food items"
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
-- 13. FOOD ITEM DIETARY TAGS
-- =========================================================

create policy "Public can view food dietary tags"
on public.food_item_dietary_options
for select
to anon, authenticated
using (
  public.is_food_item_public(food_item_id)
);


create policy "Owners manage own food dietary tags"
on public.food_item_dietary_options
for all
to authenticated
using (
  public.is_food_item_owner(food_item_id)
)
with check (
  public.is_food_item_owner(food_item_id)
);



-- =========================================================
-- 14. BUFFET PACKAGES
-- =========================================================

create policy "Public can view available buffet packages"
on public.buffet_packages
for select
to anon, authenticated
using (
  is_available = true
  and public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own buffet packages"
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
-- 15. BUFFET ITEMS
-- =========================================================

create policy "Public can view buffet items"
on public.buffet_items
for select
to anon, authenticated
using (
  public.is_buffet_public(buffet_id)
);


create policy "Owners manage own buffet items"
on public.buffet_items
for all
to authenticated
using (
  public.is_buffet_owner(buffet_id)
)
with check (
  public.is_buffet_owner(buffet_id)
);



-- =========================================================
-- 16. RESTAURANT OFFERS
-- Only currently valid offers are public.
-- =========================================================

create policy "Public can view valid restaurant offers"
on public.restaurant_offers
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

  and public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own restaurant offers"
on public.restaurant_offers
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);



-- =========================================================
-- 17. SPECIAL AVAILABILITY / CLOSURES
-- =========================================================

create policy "Public can view restaurant availability"
on public.restaurant_availability
for select
to anon, authenticated
using (
  public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own restaurant availability"
on public.restaurant_availability
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);



-- =========================================================
-- 18. RESTAURANT POLICIES
-- BYOB / corkage / dress code / smoking etc.
-- =========================================================

create policy "Public can view restaurant policies"
on public.restaurant_policies
for select
to anon, authenticated
using (
  public.is_restaurant_public(restaurant_id)
);


create policy "Owners manage own restaurant policies"
on public.restaurant_policies
for all
to authenticated
using (
  public.is_restaurant_owner(restaurant_id)
)
with check (
  public.is_restaurant_owner(restaurant_id)
);
