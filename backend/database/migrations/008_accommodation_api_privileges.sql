-- =========================================================
-- TripMate
-- Migration 008: Accommodation API Privileges
-- =========================================================


-- 1. Allow API roles to use public schema
grant usage on schema public
to anon, authenticated;


-- 2. Main accommodation table
-- Public can read allowed properties.
-- Authenticated owners can manage their own via RLS.

grant select
on table public.accommodations
to anon, authenticated;

grant insert, update, delete
on table public.accommodations
to authenticated;


-- 3. Accommodation owner-managed child tables

grant select
on table
  public.accommodation_images,
  public.accommodation_amenities,
  public.room_types,
  public.room_images,
  public.room_amenities,
  public.room_beds,
  public.accommodation_meal_plans,
  public.room_availability,
  public.accommodation_offers,
  public.accommodation_policies,
  public.accommodation_availability
to anon, authenticated;


grant insert, update, delete
on table
  public.accommodation_images,
  public.accommodation_amenities,
  public.room_types,
  public.room_images,
  public.room_amenities,
  public.room_beds,
  public.accommodation_meal_plans,
  public.room_availability,
  public.accommodation_offers,
  public.accommodation_policies,
  public.accommodation_availability
to authenticated;


-- 4. Reference/catalog tables
-- Public/authenticated users can read.
-- Normal users cannot modify.

grant select
on table
  public.accommodation_types,
  public.accommodation_amenity_catalog,
  public.room_amenity_catalog,
  public.bed_types,
  public.meal_plans
to anon, authenticated;


-- 5. Identity sequences needed when owners insert records

grant usage, select
on sequence
  public.accommodations_id_seq,
  public.accommodation_images_id_seq,
  public.room_types_id_seq,
  public.room_images_id_seq,
  public.room_beds_id_seq,
  public.accommodation_meal_plans_id_seq,
  public.room_availability_id_seq,
  public.accommodation_offers_id_seq,
  public.accommodation_policies_id_seq,
  public.accommodation_availability_id_seq
to authenticated;
