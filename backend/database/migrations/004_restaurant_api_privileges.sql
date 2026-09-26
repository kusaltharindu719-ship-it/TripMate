-- =========================================================
-- TripMate
-- Migration 004: Restaurant API Privileges
-- =========================================================


-- =========================================================
-- 1. PUBLIC SCHEMA ACCESS
-- =========================================================

grant usage on schema public
to anon, authenticated;



-- =========================================================
-- 2. PROVIDER VERIFICATION
-- Providers can view/submit their own verification requests.
-- RLS controls which rows they can access.
-- =========================================================

grant select, insert
on table public.provider_verifications
to authenticated;



-- =========================================================
-- 3. MAIN RESTAURANT TABLE
-- Public can read approved restaurants.
-- Authenticated owners can create/update/delete their own.
-- =========================================================

grant select
on table public.restaurants
to anon, authenticated;

grant insert, update, delete
on table public.restaurants
to authenticated;



-- =========================================================
-- 4. RESTAURANT OWNER-MANAGED TABLES
-- Public can read allowed rows.
-- Authenticated owners can manage only their own rows via RLS.
-- =========================================================

grant select
on table
  public.restaurant_opening_hours,
  public.restaurant_images,
  public.restaurant_features,
  public.restaurant_service_modes,
  public.restaurant_cuisines,
  public.restaurant_dietary_options,
  public.food_categories,
  public.food_items,
  public.food_item_dietary_options,
  public.buffet_packages,
  public.buffet_items,
  public.restaurant_offers,
  public.restaurant_availability,
  public.restaurant_policies
to anon, authenticated;


grant insert, update, delete
on table
  public.restaurant_opening_hours,
  public.restaurant_images,
  public.restaurant_features,
  public.restaurant_service_modes,
  public.restaurant_cuisines,
  public.restaurant_dietary_options,
  public.food_categories,
  public.food_items,
  public.food_item_dietary_options,
  public.buffet_packages,
  public.buffet_items,
  public.restaurant_offers,
  public.restaurant_availability,
  public.restaurant_policies
to authenticated;



-- =========================================================
-- 5. REFERENCE / CATALOG TABLES
-- Everyone can read them.
-- Normal users cannot modify them.
-- =========================================================

grant select
on table
  public.restaurant_feature_catalog,
  public.service_modes,
  public.cuisines,
  public.dietary_options
to anon, authenticated;



-- =========================================================
-- 6. IDENTITY SEQUENCES
-- Needed when authenticated owners INSERT rows into
-- tables using generated bigint identity IDs.
-- =========================================================

grant usage, select
on sequence
  public.restaurants_id_seq,
  public.provider_verifications_id_seq,
  public.restaurant_opening_hours_id_seq,
  public.restaurant_images_id_seq,
  public.food_categories_id_seq,
  public.food_items_id_seq,
  public.buffet_packages_id_seq,
  public.buffet_items_id_seq,
  public.restaurant_offers_id_seq,
  public.restaurant_availability_id_seq,
  public.restaurant_policies_id_seq
to authenticated;
