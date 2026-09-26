-- =========================================================
-- TripMate
-- Migration 031: Internal Function Execution Hardening
-- =========================================================
--
-- Removes direct API execution rights from trigger-only
-- and internal maintenance functions.
--
-- IMPORTANT:
-- RLS helper functions are NOT revoked here because policies
-- may legitimately need to execute them.
-- =========================================================


-- =========================================================
-- 1. AUTH / PROFILE INTERNAL TRIGGERS
-- =========================================================

revoke all
on function public.handle_new_user()
from public, anon, authenticated;

revoke all
on function public.prevent_profile_role_change()
from public, anon, authenticated;



-- =========================================================
-- 2. GENERIC INTERNAL TRIGGERS
-- =========================================================

revoke all
on function public.set_updated_at()
from public, anon, authenticated;

revoke all
on function public.sync_trip_traveler_count()
from public, anon, authenticated;

revoke all
on function public.sync_notification_read_state()
from public, anon, authenticated;



-- =========================================================
-- 3. NOTIFICATION INTERNAL TRIGGERS
-- =========================================================

revoke all
on function public.create_default_notification_preferences()
from public, anon, authenticated;



-- =========================================================
-- 4. TRIP / CART INTERNAL TRIGGERS
-- =========================================================

revoke all
on function public.set_trip_cart_snapshot()
from public, anon, authenticated;

revoke all
on function public.validate_trip_cart_item()
from public, anon, authenticated;

revoke all
on function public.validate_trip_destination_dates()
from public, anon, authenticated;



-- =========================================================
-- 5. TRANSPORT / DRIVER INTERNAL TRIGGERS
-- =========================================================

revoke all
on function public.create_transport_request_stops()
from public, anon, authenticated;

revoke all
on function public.populate_transport_request_snapshot()
from public, anon, authenticated;

revoke all
on function public.create_vehicle_verification()
from public, anon, authenticated;

revoke all
on function public.validate_driver_profile_role()
from public, anon, authenticated;

revoke all
on function public.validate_driver_bid()
from public, anon, authenticated;

revoke all
on function public.validate_bid_vehicle_documents()
from public, anon, authenticated;

revoke all
on function public.protect_driver_bid_workflow()
from public, anon, authenticated;

revoke all
on function public.protect_driver_trip_status()
from public, anon, authenticated;

revoke all
on function public.protect_transport_request_workflow()
from public, anon, authenticated;

revoke all
on function public.prevent_vehicle_owner_change()
from public, anon, authenticated;

revoke all
on function public.prevent_vehicle_document_move()
from public, anon, authenticated;

revoke all
on function public.protect_driver_document_review()
from public, anon, authenticated;

revoke all
on function public.protect_vehicle_document_review()
from public, anon, authenticated;



-- =========================================================
-- 6. VERIFICATION RESET TRIGGERS
-- =========================================================

revoke all
on function public.reset_driver_approval_on_document_change()
from public, anon, authenticated;

revoke all
on function public.reset_driver_approval_on_license_change()
from public, anon, authenticated;

revoke all
on function public.reset_vehicle_approval_on_detail_change()
from public, anon, authenticated;

revoke all
on function public.reset_vehicle_approval_on_document_change()
from public, anon, authenticated;



-- =========================================================
-- 7. RESTAURANT / ACCOMMODATION VALIDATION TRIGGERS
-- =========================================================

revoke all
on function public.validate_accommodation_offer_room()
from public, anon, authenticated;

revoke all
on function public.validate_food_item_category()
from public, anon, authenticated;

revoke all
on function public.validate_room_inventory()
from public, anon, authenticated;



-- =========================================================
-- 8. BOOKING INTERNAL TRIGGERS
-- =========================================================

revoke all
on function public.validate_booking_item_source()
from public, anon, authenticated;

revoke all
on function public.validate_booking_cancellation_item()
from public, anon, authenticated;

revoke all
on function public.populate_booking_traveler_snapshot()
from public, anon, authenticated;

revoke all
on function public.populate_booking_item_provider_snapshot()
from public, anon, authenticated;

revoke all
on function public.populate_booking_item_fulfillment_snapshot()
from public, anon, authenticated;

revoke all
on function public.log_booking_status_change()
from public, anon, authenticated;



-- =========================================================
-- 9. REVIEW INTERNAL TRIGGER
-- =========================================================

revoke all
on function public.populate_review_target()
from public, anon, authenticated;



-- =========================================================
-- 10. SUPABASE / INTERNAL RLS AUTO TRIGGER
-- =========================================================

revoke all
on function public.rls_auto_enable()
from public, anon, authenticated;



-- =========================================================
-- 11. DEFENSIVELY PRESERVE USER-FACING RPC ACCESS
--
-- These are intentionally called by authenticated clients.
-- =========================================================

grant execute
on function public.checkout_trip(bigint)
to authenticated;


grant execute
on function public.open_transport_request(
  bigint,
  numeric,
  integer,
  timestamptz,
  integer
)
to authenticated;


grant execute
on function public.accept_driver_bid(bigint, bigint)
to authenticated;


grant execute
on function public.withdraw_driver_bid(bigint)
to authenticated;


grant execute
on function public.cancel_transport_request(bigint)
to authenticated;


grant execute
on function public.request_booking_cancellation(
  bigint,
  bigint,
  text
)
to authenticated;


grant execute
on function public.review_booking_cancellation(
  bigint,
  text,
  numeric,
  text
)
to authenticated;


grant execute
on function public.process_booking_cancellation(bigint)
to authenticated;


grant execute
on function public.submit_review(
  bigint,
  integer,
  text,
  text
)
to authenticated;


grant execute
on function public.edit_review(
  bigint,
  integer,
  text,
  text
)
to authenticated;


grant execute
on function public.reply_to_review(
  bigint,
  text
)
to authenticated;


grant execute
on function public.moderate_review(
  bigint,
  text,
  text
)
to authenticated;


grant execute
on function public.set_notification_read_state(
  bigint,
  boolean
)
to authenticated;


grant execute
on function public.mark_all_notifications_read()
to authenticated;


grant execute
on function public.review_provider_verification(
  uuid,
  text,
  text,
  text
)
to authenticated;


grant execute
on function public.review_driver_document(
  bigint,
  text,
  text
)
to authenticated;


grant execute
on function public.review_vehicle_document(
  bigint,
  text,
  text
)
to authenticated;


grant execute
on function public.review_vehicle_verification(
  bigint,
  text,
  text
)
to authenticated;
