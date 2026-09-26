-- =========================================================
-- TripMate
-- Migration 012: Traveler API Privileges
-- =========================================================


-- =========================================================
-- 1. PUBLIC SCHEMA ACCESS
-- =========================================================

grant usage on schema public
to anon, authenticated;



-- =========================================================
-- 2. PUBLIC TRAVEL DISCOVERY DATA
-- Travelers and public users may browse these.
-- RLS decides which rows are visible.
-- =========================================================

grant select
on table
  public.destinations,
  public.attraction_categories,
  public.attractions,
  public.attraction_images,
  public.attraction_opening_hours,
  public.activities,
  public.activity_availability
to anon, authenticated;



-- =========================================================
-- 3. TRAVELER TRIPS
-- Authenticated travelers can manage their own trips.
-- RLS prevents access to other travelers' trips.
-- =========================================================

grant select, insert, update, delete
on table public.trips
to authenticated;



-- =========================================================
-- 4. TRIP PREFERENCES
-- =========================================================

grant select, insert, update, delete
on table public.trip_preferences
to authenticated;



-- =========================================================
-- 5. TRIP DESTINATIONS
-- =========================================================

grant select, insert, update, delete
on table public.trip_destinations
to authenticated;



-- =========================================================
-- 6. TRIP CART
-- =========================================================

grant select, insert, update, delete
on table public.trip_cart_items
to authenticated;



-- =========================================================
-- 7. IDENTITY SEQUENCES
-- Needed when authenticated travelers create records.
-- =========================================================

grant usage, select
on sequence
  public.trips_id_seq,
  public.trip_preferences_id_seq,
  public.trip_destinations_id_seq,
  public.trip_cart_items_id_seq
to authenticated;
