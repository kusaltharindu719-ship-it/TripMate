-- =========================================================
-- TripMate
-- Migration 030: Final API Privilege Hardening
-- =========================================================


-- =========================================================
-- 1. REMOVE DANGEROUS TABLE-LEVEL PRIVILEGES
--
-- Frontend API roles never need:
--   TRUNCATE
--   TRIGGER
--   REFERENCES
-- =========================================================

do $$
declare
  r record;
begin

  for r in
    select
      schemaname,
      tablename
    from pg_tables
    where schemaname = 'public'
  loop

    execute format(
      'revoke truncate, trigger, references on table %I.%I from anon, authenticated',
      r.schemaname,
      r.tablename
    );

  end loop;

end
$$;



-- =========================================================
-- 2. HARDEN PROFILES
--
-- Anonymous users must never directly read/write profiles.
-- Signup profile creation is handled by the auth trigger.
-- =========================================================

revoke all
on table public.profiles
from anon;


revoke all
on table public.profiles
from authenticated;


-- Authenticated users need:
-- SELECT -> own profile / admin visibility controlled by RLS
-- UPDATE -> own safe profile fields controlled by RLS + triggers
grant select, update
on table public.profiles
to authenticated;



-- =========================================================
-- 3. PROVIDER VERIFICATION
--
-- Anonymous users require no access.
-- Authenticated providers only submit/read their own request.
-- =========================================================

revoke all
on table public.provider_verifications
from anon;


revoke all
on table public.provider_verifications
from authenticated;


grant select, insert
on table public.provider_verifications
to authenticated;



-- =========================================================
-- 4. PRIVATE DRIVER TABLES
-- Explicitly remove anonymous access.
-- =========================================================

revoke all
on table
  public.driver_licenses,
  public.driver_documents,
  public.driver_availability,
  public.driver_bids,
  public.vehicle_documents,
  public.vehicle_verifications,
  public.transport_requests,
  public.transport_request_stops
from anon;



-- =========================================================
-- 5. PRIVATE TRAVELER TABLES
-- =========================================================

revoke all
on table
  public.trips,
  public.trip_preferences,
  public.trip_destinations,
  public.trip_cart_items
from anon;



-- =========================================================
-- 6. PRIVATE BOOKING / NOTIFICATION TABLES
-- =========================================================

revoke all
on table
  public.bookings,
  public.booking_items,
  public.booking_status_history,
  public.booking_cancellations,
  public.room_inventory_reservations,
  public.activity_inventory_reservations,
  public.notifications,
  public.notification_preferences,
  public.verification_audit_log
from anon;



-- =========================================================
-- 7. RESTORE REQUIRED AUTHENTICATED PRIVILEGES
-- =========================================================

grant select, insert, update, delete
on table
  public.trips,
  public.trip_preferences,
  public.trip_destinations,
  public.trip_cart_items
to authenticated;


grant select, insert, update, delete
on table
  public.driver_licenses,
  public.driver_documents,
  public.driver_availability,
  public.vehicle_documents
to authenticated;


grant select, insert, update
on table public.driver_bids
to authenticated;


grant select, insert, update, delete
on table public.transport_requests
to authenticated;


grant select
on table public.transport_request_stops
to authenticated;


grant select
on table public.vehicle_verifications
to authenticated;


-- Secure booking tables remain read-only to clients.
grant select
on table
  public.bookings,
  public.booking_items,
  public.booking_status_history,
  public.booking_cancellations,
  public.room_inventory_reservations,
  public.activity_inventory_reservations
to authenticated;


grant select
on table public.notifications
to authenticated;


grant select, update
on table public.notification_preferences
to authenticated;


grant select
on table public.verification_audit_log
to authenticated;
