-- =========================================================
-- TripMate
-- Migration 019: Driver Module API Privileges
-- =========================================================


-- =========================================================
-- 1. SCHEMA ACCESS
-- =========================================================

grant usage on schema public
to anon, authenticated;



-- =========================================================
-- 2. PUBLIC DRIVER / VEHICLE DISCOVERY
-- RLS still decides which approved records are visible.
-- =========================================================

grant select
on table
  public.driver_profiles,
  public.vehicle_types,
  public.vehicles,
  public.vehicle_images,
  public.vehicle_feature_catalog,
  public.vehicle_features
to anon, authenticated;



-- =========================================================
-- 3. DRIVER PROFILE MANAGEMENT
-- =========================================================

grant insert, update
on table public.driver_profiles
to authenticated;



-- =========================================================
-- 4. PRIVATE DRIVER LICENCE + DOCUMENTS
-- =========================================================

grant select, insert, update, delete
on table
  public.driver_licenses,
  public.driver_documents
to authenticated;



-- =========================================================
-- 5. VEHICLE MANAGEMENT
-- =========================================================

grant insert, update, delete
on table public.vehicles
to authenticated;


-- Driver can only READ verification result.
-- Approval itself will be handled by admin workflow.
grant select
on table public.vehicle_verifications
to authenticated;


grant insert, update, delete
on table public.vehicle_images
to authenticated;


-- Vehicle features are links:
-- add feature / remove feature.
grant insert, delete
on table public.vehicle_features
to authenticated;


grant select, insert, update, delete
on table public.vehicle_documents
to authenticated;



-- =========================================================
-- 6. DRIVER AVAILABILITY
-- =========================================================

grant select, insert, update, delete
on table public.driver_availability
to authenticated;



-- =========================================================
-- 7. TRANSPORT REQUESTS
-- Only authenticated users participate.
-- RLS separates travelers from drivers.
-- =========================================================

grant select, insert, update, delete
on table public.transport_requests
to authenticated;


-- Stops are database-generated snapshots.
-- Client can read them but cannot directly create/change them.
grant select
on table public.transport_request_stops
to authenticated;



-- =========================================================
-- 8. DRIVER BIDS
-- No DELETE permission:
-- bid history should be preserved.
-- Withdrawal uses status workflow instead.
-- =========================================================

grant select, insert, update
on table public.driver_bids
to authenticated;



-- =========================================================
-- 9. IDENTITY SEQUENCES
-- Only sequences required for client-side INSERT operations.
-- =========================================================

grant usage, select
on sequence
  public.driver_licenses_id_seq,
  public.driver_documents_id_seq,
  public.vehicles_id_seq,
  public.vehicle_images_id_seq,
  public.vehicle_documents_id_seq,
  public.driver_availability_id_seq,
  public.transport_requests_id_seq,
  public.driver_bids_id_seq
to authenticated;
