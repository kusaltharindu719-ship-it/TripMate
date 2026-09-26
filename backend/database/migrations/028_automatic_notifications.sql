-- =========================================================
-- TripMate
-- Migration 028: Automatic Notification Events
-- =========================================================


-- =========================================================
-- 1. CHECK USER NOTIFICATION PREFERENCES
-- =========================================================

create or replace function public.notification_is_enabled(
  p_user_id uuid,
  p_notification_type text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_pref public.notification_preferences%rowtype;
begin

  select *
  into v_pref
  from public.notification_preferences
  where user_id = p_user_id;


  -- If preferences somehow do not exist,
  -- default to in-app notifications enabled.
  if not found then
    return true;
  end if;


  if v_pref.in_app_enabled is not true then
    return false;
  end if;


  -- Booking / cancellation events
  if p_notification_type in (
    'booking_confirmed',
    'booking_cancelled',
    'cancellation_requested',
    'cancellation_approved',
    'cancellation_rejected'
  ) then

    return v_pref.booking_updates;


  -- Driver bidding
  elsif p_notification_type in (
    'driver_bid_received',
    'driver_bid_accepted',
    'driver_bid_rejected'
  ) then

    return v_pref.driver_bid_updates;


  -- Provider / vehicle verification
  elsif p_notification_type in (
    'provider_verification_approved',
    'provider_verification_rejected',
    'provider_verification_suspended',
    'vehicle_verification_approved',
    'vehicle_verification_rejected',
    'vehicle_verification_suspended'
  ) then

    return v_pref.verification_updates;


  -- Reviews
  elsif p_notification_type in (
    'review_received',
    'review_reply'
  ) then

    return v_pref.review_updates;


  elsif p_notification_type = 'trip_reminder' then

    return v_pref.trip_reminders;


  elsif p_notification_type = 'service_reminder' then

    return v_pref.service_reminders;

  end if;


  return true;

end;
$$;



-- =========================================================
-- 2. INTERNAL NOTIFICATION CREATOR
--
-- event_key prevents duplicate notifications.
-- =========================================================

create or replace function public.enqueue_notification(
  p_user_id uuid,
  p_notification_type text,
  p_title text,
  p_message text,

  p_event_key text default null,

  p_related_entity_type text default null,
  p_related_entity_id text default null,

  p_deep_link text default null,

  p_data jsonb default '{}'::jsonb,

  p_priority text default 'normal',

  p_scheduled_for timestamptz default null,
  p_expires_at timestamptz default null
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_notification_id bigint;
begin

  if p_user_id is null then
    return null;
  end if;


  if not public.notification_is_enabled(
    p_user_id,
    p_notification_type
  ) then

    return null;

  end if;


  insert into public.notifications (
    user_id,
    notification_type,
    title,
    message,

    event_key,

    related_entity_type,
    related_entity_id,

    deep_link,
    data,

    priority,

    scheduled_for,
    expires_at
  )
  values (
    p_user_id,
    p_notification_type,
    p_title,
    p_message,

    p_event_key,

    p_related_entity_type,
    p_related_entity_id,

    p_deep_link,

    coalesce(
      p_data,
      '{}'::jsonb
    ),

    p_priority,

    p_scheduled_for,
    p_expires_at
  )

  on conflict (event_key)
  do nothing

  returning id
  into v_notification_id;


  return v_notification_id;

end;
$$;



-- =========================================================
-- 3. BOOKING NOTIFICATIONS
--
-- Traveler:
--   booking confirmed / booking cancelled
--
-- Providers:
--   new confirmed service assigned to them
-- =========================================================

create or replace function public.notify_booking_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider_id uuid;
begin

  if new.status is not distinct from old.status then
    return new;
  end if;


  -- -------------------------------------------------------
  -- BOOKING CONFIRMED
  -- -------------------------------------------------------

  if new.status = 'confirmed' then

    perform public.enqueue_notification(
      new.traveler_id,

      'booking_confirmed',

      'Booking confirmed',

      'Your TripMate booking has been confirmed.',

      'booking-confirmed:traveler:'
        || new.id::text,

      'booking',
      new.id::text,

      '/bookings/' || new.id::text,

      jsonb_build_object(
        'booking_id',
        new.id,

        'booking_reference',
        new.booking_reference,

        'total_amount',
        new.total_amount,

        'currency',
        new.currency
      ),

      'high'
    );


    -- Notify each involved provider only once
    for v_provider_id in

      select distinct
        bi.provider_user_id_snapshot

      from public.booking_items bi

      where bi.booking_id = new.id
        and bi.provider_user_id_snapshot
            is not null

    loop

      perform public.enqueue_notification(
        v_provider_id,

        'booking_confirmed',

        'New confirmed booking',

        'A TripMate service assigned to you has been confirmed.',

        'booking-confirmed:provider:'
          || new.id::text
          || ':'
          || v_provider_id::text,

        'booking',
        new.id::text,

        '/provider/bookings',

        jsonb_build_object(
          'booking_id',
          new.id,
          'booking_reference',
          new.booking_reference
        ),

        'high'
      );

    end loop;


  -- -------------------------------------------------------
  -- BOOKING CANCELLED
  -- -------------------------------------------------------

  elsif new.status = 'cancelled' then

    perform public.enqueue_notification(
      new.traveler_id,

      'booking_cancelled',

      'Booking cancelled',

      'Your TripMate booking has been cancelled.',

      'booking-cancelled:'
        || new.id::text,

      'booking',
      new.id::text,

      '/bookings/' || new.id::text,

      jsonb_build_object(
        'booking_id',
        new.id,
        'booking_reference',
        new.booking_reference
      ),

      'high'
    );

  end if;


  return new;

end;
$$;


drop trigger if exists
notify_booking_event_trigger
on public.bookings;


create trigger
notify_booking_event_trigger
after update of status
on public.bookings
for each row
execute procedure public.notify_booking_event();



-- =========================================================
-- 4. CANCELLATION REQUEST NOTIFICATION
--
-- Item request:
--   relevant provider gets notification.
--
-- Full booking / platform-managed item:
--   admins receive notification.
-- =========================================================

create or replace function public.notify_cancellation_request()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_provider_id uuid;
  v_admin_id uuid;
begin

  if new.booking_item_id is not null then

    select
      bi.provider_user_id_snapshot

    into v_provider_id

    from public.booking_items bi

    where bi.id = new.booking_item_id;

  end if;


  -- Relevant provider
  if v_provider_id is not null then

    perform public.enqueue_notification(
      v_provider_id,

      'cancellation_requested',

      'Cancellation requested',

      'A traveler requested cancellation of one of your booked services.',

      'cancellation-requested:provider:'
        || new.id::text,

      'booking_cancellation',
      new.id::text,

      '/provider/cancellations',

      jsonb_build_object(
        'cancellation_id',
        new.id,
        'booking_id',
        new.booking_id,
        'booking_item_id',
        new.booking_item_id
      ),

      'high'
    );


  -- Full booking or platform-managed service
  else

    for v_admin_id in

      select p.id
      from public.profiles p
      where p.role = 'admin'

    loop

      perform public.enqueue_notification(
        v_admin_id,

        'cancellation_requested',

        'Cancellation review required',

        'A TripMate booking cancellation request requires review.',

        'cancellation-requested:admin:'
          || new.id::text
          || ':'
          || v_admin_id::text,

        'booking_cancellation',
        new.id::text,

        '/admin/cancellations',

        jsonb_build_object(
          'cancellation_id',
          new.id,
          'booking_id',
          new.booking_id,
          'booking_item_id',
          new.booking_item_id
        ),

        'high'
      );

    end loop;

  end if;


  return new;

end;
$$;


drop trigger if exists
notify_cancellation_request_trigger
on public.booking_cancellations;


create trigger
notify_cancellation_request_trigger
after insert
on public.booking_cancellations
for each row
execute procedure public.notify_cancellation_request();



-- =========================================================
-- 5. CANCELLATION DECISION NOTIFICATION
-- =========================================================

create or replace function public.notify_cancellation_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  if new.status is not distinct from old.status then
    return new;
  end if;


  if new.status = 'approved' then

    perform public.enqueue_notification(
      new.requested_by,

      'cancellation_approved',

      'Cancellation approved',

      'Your TripMate cancellation request has been approved.',

      'cancellation-approved:'
        || new.id::text,

      'booking_cancellation',
      new.id::text,

      '/bookings/' || new.booking_id::text,

      jsonb_build_object(
        'cancellation_id',
        new.id,
        'booking_id',
        new.booking_id,
        'refund_amount',
        new.refund_amount
      ),

      'high'
    );


  elsif new.status = 'rejected' then

    perform public.enqueue_notification(
      new.requested_by,

      'cancellation_rejected',

      'Cancellation request rejected',

      'Your TripMate cancellation request was not approved.',

      'cancellation-rejected:'
        || new.id::text,

      'booking_cancellation',
      new.id::text,

      '/bookings/' || new.booking_id::text,

      jsonb_build_object(
        'cancellation_id',
        new.id,
        'booking_id',
        new.booking_id
      ),

      'high'
    );

  end if;


  return new;

end;
$$;


drop trigger if exists
notify_cancellation_decision_trigger
on public.booking_cancellations;


create trigger
notify_cancellation_decision_trigger
after update of status
on public.booking_cancellations
for each row
execute procedure public.notify_cancellation_decision();



-- =========================================================
-- 6. DRIVER BID RECEIVED
-- Traveler receives notification
-- =========================================================

create or replace function public.notify_driver_bid_received()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_traveler_id uuid;
begin

  if new.status <> 'pending' then
    return new;
  end if;


  select tr.traveler_id
  into v_traveler_id
  from public.transport_requests tr
  where tr.id = new.transport_request_id;


  if v_traveler_id is null then
    return new;
  end if;


  perform public.enqueue_notification(
    v_traveler_id,

    'driver_bid_received',

    'New driver bid received',

    'A driver submitted a new bid for your trip.',

    'driver-bid-received:'
      || new.id::text,

    'driver_bid',
    new.id::text,

    '/transport/requests/'
      || new.transport_request_id::text,

    jsonb_build_object(
      'bid_id',
      new.id,

      'transport_request_id',
      new.transport_request_id,

      'bid_amount',
      new.bid_amount,

      'currency',
      new.currency
    ),

    'normal'
  );


  return new;

end;
$$;


drop trigger if exists
notify_driver_bid_received_trigger
on public.driver_bids;


create trigger
notify_driver_bid_received_trigger
after insert
on public.driver_bids
for each row
execute procedure public.notify_driver_bid_received();



-- =========================================================
-- 7. DRIVER BID ACCEPTED / REJECTED
-- Driver receives notification
-- =========================================================

create or replace function public.notify_driver_bid_status()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  if new.status is not distinct from old.status then
    return new;
  end if;


  if new.status = 'accepted' then

    perform public.enqueue_notification(
      new.driver_id,

      'driver_bid_accepted',

      'Bid accepted',

      'A traveler accepted your TripMate transport bid.',

      'driver-bid-accepted:'
        || new.id::text,

      'driver_bid',
      new.id::text,

      '/driver/bids/' || new.id::text,

      jsonb_build_object(
        'bid_id',
        new.id,

        'transport_request_id',
        new.transport_request_id,

        'bid_amount',
        new.bid_amount,

        'currency',
        new.currency
      ),

      'high'
    );


  elsif new.status = 'rejected' then

    perform public.enqueue_notification(
      new.driver_id,

      'driver_bid_rejected',

      'Bid not selected',

      'Your TripMate transport bid was not selected.',

      'driver-bid-rejected:'
        || new.id::text,

      'driver_bid',
      new.id::text,

      '/driver/bids/' || new.id::text,

      jsonb_build_object(
        'bid_id',
        new.id,
        'transport_request_id',
        new.transport_request_id
      ),

      'normal'
    );

  end if;


  return new;

end;
$$;


drop trigger if exists
notify_driver_bid_status_trigger
on public.driver_bids;


create trigger
notify_driver_bid_status_trigger
after update of status
on public.driver_bids
for each row
execute procedure public.notify_driver_bid_status();



-- =========================================================
-- 8. PROVIDER VERIFICATION RESULT
-- =========================================================

create or replace function public.notify_provider_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_type text;
  v_title text;
  v_message text;
begin

  if new.status is not distinct from old.status then
    return new;
  end if;


  if new.status = 'approved' then

    v_type :=
      'provider_verification_approved';

    v_title :=
      'Provider verification approved';

    v_message :=
      'Your TripMate provider verification has been approved.';


  elsif new.status = 'rejected' then

    v_type :=
      'provider_verification_rejected';

    v_title :=
      'Provider verification rejected';

    v_message :=
      'Your TripMate provider verification was not approved.';


  elsif new.status = 'suspended' then

    v_type :=
      'provider_verification_suspended';

    v_title :=
      'Provider verification suspended';

    v_message :=
      'Your TripMate provider access has been suspended.';

  else

    return new;

  end if;


  perform public.enqueue_notification(
    new.user_id,

    v_type,

    v_title,

    v_message,

    'provider-verification:'
      || new.user_id::text
      || ':'
      || new.provider_type
      || ':'
      || new.status,

    'provider_verification',

    new.user_id::text,

    '/provider/verification',

    jsonb_build_object(
      'provider_type',
      new.provider_type,
      'status',
      new.status
    ),

    'high'
  );


  return new;

end;
$$;


drop trigger if exists
notify_provider_verification_trigger
on public.provider_verifications;


create trigger
notify_provider_verification_trigger
after update of status
on public.provider_verifications
for each row
execute procedure public.notify_provider_verification();



-- =========================================================
-- 9. VEHICLE VERIFICATION RESULT
-- =========================================================

create or replace function public.notify_vehicle_verification()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid;
  v_registration text;

  v_type text;
  v_title text;
  v_message text;
begin

  if new.status is not distinct from old.status then
    return new;
  end if;


  select
    v.driver_id,
    v.registration_number

  into
    v_driver_id,
    v_registration

  from public.vehicles v

  where v.id = new.vehicle_id;


  if v_driver_id is null then
    return new;
  end if;


  if new.status = 'approved' then

    v_type :=
      'vehicle_verification_approved';

    v_title :=
      'Vehicle approved';

    v_message :=
      'Your TripMate vehicle has been approved.';


  elsif new.status = 'rejected' then

    v_type :=
      'vehicle_verification_rejected';

    v_title :=
      'Vehicle verification rejected';

    v_message :=
      'Your TripMate vehicle verification was not approved.';


  elsif new.status = 'suspended' then

    v_type :=
      'vehicle_verification_suspended';

    v_title :=
      'Vehicle suspended';

    v_message :=
      'Your TripMate vehicle has been suspended.';

  else

    return new;

  end if;


  perform public.enqueue_notification(
    v_driver_id,

    v_type,

    v_title,

    v_message,

    'vehicle-verification:'
      || new.vehicle_id::text
      || ':'
      || new.status,

    'vehicle',
    new.vehicle_id::text,

    '/driver/vehicles/'
      || new.vehicle_id::text,

    jsonb_build_object(
      'vehicle_id',
      new.vehicle_id,

      'registration_number',
      v_registration,

      'status',
      new.status
    ),

    'high'
  );


  return new;

end;
$$;


drop trigger if exists
notify_vehicle_verification_trigger
on public.vehicle_verifications;


create trigger
notify_vehicle_verification_trigger
after update of status
on public.vehicle_verifications
for each row
execute procedure public.notify_vehicle_verification();



-- =========================================================
-- 10. REVIEW PUBLISHED + PROVIDER REPLY
-- =========================================================

create or replace function public.notify_review_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  -- -------------------------------------------------------
  -- Published review -> provider
  -- -------------------------------------------------------

  if new.status = 'published'
     and new.status is distinct from old.status
     and new.target_provider_user_id is not null then

    perform public.enqueue_notification(
      new.target_provider_user_id,

      'review_received',

      'New review received',

      'A traveler published a review for one of your TripMate services.',

      'review-received:'
        || new.id::text,

      'review',
      new.id::text,

      '/provider/reviews',

      jsonb_build_object(
        'review_id',
        new.id,
        'rating',
        new.rating,
        'target_type',
        new.target_type
      ),

      'normal'
    );

  end if;


  -- -------------------------------------------------------
  -- Provider reply -> traveler
  -- -------------------------------------------------------

  if new.provider_reply is not null
     and new.provider_reply
         is distinct from old.provider_reply then

    perform public.enqueue_notification(
      new.reviewer_id,

      'review_reply',

      'Provider replied to your review',

      'A provider replied to your TripMate review.',

      'review-reply:'
        || new.id::text,

      'review',
      new.id::text,

      '/reviews/' || new.id::text,

      jsonb_build_object(
        'review_id',
        new.id,
        'target_type',
        new.target_type
      ),

      'normal'
    );

  end if;


  return new;

end;
$$;


drop trigger if exists
notify_review_event_trigger
on public.reviews;


create trigger
notify_review_event_trigger
after update of status, provider_reply
on public.reviews
for each row
execute procedure public.notify_review_event();



-- =========================================================
-- 11. INTERNAL FUNCTIONS MUST NOT BE CALLABLE BY USERS
--
-- Otherwise user could manufacture fake notifications.
-- =========================================================

revoke all
on function public.notification_is_enabled(
  uuid,
  text
)
from public, anon, authenticated;


revoke all
on function public.enqueue_notification(
  uuid,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb,
  text,
  timestamptz,
  timestamptz
)
from public, anon, authenticated;


revoke all
on function public.notify_booking_event()
from public, anon, authenticated;


revoke all
on function public.notify_cancellation_request()
from public, anon, authenticated;


revoke all
on function public.notify_cancellation_decision()
from public, anon, authenticated;


revoke all
on function public.notify_driver_bid_received()
from public, anon, authenticated;


revoke all
on function public.notify_driver_bid_status()
from public, anon, authenticated;


revoke all
on function public.notify_provider_verification()
from public, anon, authenticated;


revoke all
on function public.notify_vehicle_verification()
from public, anon, authenticated;


revoke all
on function public.notify_review_event()
from public, anon, authenticated;
