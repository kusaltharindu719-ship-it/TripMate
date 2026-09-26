-- =========================================================
-- TripMate
-- Migration 027: Reviews + Notifications Security
-- =========================================================


-- =========================================================
-- 1. REVIEW CONTENT BASIC VALIDATION
-- =========================================================

alter table public.reviews
drop constraint if exists reviews_title_length_check;

alter table public.reviews
add constraint reviews_title_length_check
check (
  title is null
  or char_length(title) <= 120
);


alter table public.reviews
drop constraint if exists reviews_comment_length_check;

alter table public.reviews
add constraint reviews_comment_length_check
check (
  comment is null
  or char_length(comment) <= 2000
);


alter table public.reviews
drop constraint if exists reviews_reply_length_check;

alter table public.reviews
add constraint reviews_reply_length_check
check (
  provider_reply is null
  or char_length(provider_reply) <= 2000
);



-- =========================================================
-- 2. REVIEW ELIGIBILITY
--
-- Review allowed only when:
--   - booking belongs to current traveler
--   - booking item belongs to that booking
--   - item was not cancelled/failed
--   - service has already finished
-- =========================================================

create or replace function public.is_booking_item_reviewable(
  p_booking_item_id bigint,
  p_user_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_item record;
  v_service_finished boolean := false;
  v_transport_end_date date;
begin

  select
    bi.id,
    bi.item_type,
    bi.status as item_status,
    bi.service_date,
    bi.service_end_time,
    bi.check_out_date,
    bi.snapshot_data,

    b.traveler_id,
    b.status as booking_status

  into v_item

  from public.booking_items bi

  join public.bookings b
    on b.id = bi.booking_id

  where bi.id = p_booking_item_id;


  if not found then
    return false;
  end if;


  if v_item.traveler_id <> p_user_id then
    return false;
  end if;


  if v_item.item_status not in (
    'confirmed',
    'completed'
  ) then
    return false;
  end if;


  if v_item.booking_status in (
    'cancelled',
    'failed',
    'expired'
  ) then
    return false;
  end if;


  -- Already explicitly completed
  if v_item.item_status = 'completed' then
    return true;
  end if;


  -- -------------------------------------------------------
  -- Room:
  -- review only after checkout date
  -- -------------------------------------------------------

  if v_item.item_type = 'room' then

    v_service_finished :=
      v_item.check_out_date is not null
      and v_item.check_out_date <= current_date;


  -- -------------------------------------------------------
  -- Transport:
  -- trip_end_date is preserved in snapshot_data
  -- -------------------------------------------------------

  elsif v_item.item_type = 'transport' then

    begin

      v_transport_end_date :=
        nullif(
          v_item.snapshot_data ->> 'trip_end_date',
          ''
        )::date;

    exception
      when others then
        v_transport_end_date := null;
    end;


    v_service_finished :=
      v_transport_end_date is not null
      and v_transport_end_date < current_date;


  -- -------------------------------------------------------
  -- Other services
  -- -------------------------------------------------------

  else

    if v_item.service_date is null then
      v_service_finished := false;

    elsif v_item.service_date < current_date then
      v_service_finished := true;

    elsif v_item.service_date = current_date
          and v_item.service_end_time is not null
          and v_item.service_end_time <= localtime then

      v_service_finished := true;

    else
      v_service_finished := false;

    end if;

  end if;


  return v_service_finished;

end;
$$;



-- =========================================================
-- 3. SECURE REVIEW SUBMISSION
--
-- User does NOT choose review target.
-- Booking item determines the target.
-- =========================================================

create or replace function public.submit_review(
  p_booking_item_id bigint,
  p_rating integer,
  p_title text default null,
  p_comment text default null
)
returns public.reviews
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.booking_items%rowtype;
  v_result public.reviews%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5';
  end if;


  if not public.is_booking_item_reviewable(
    p_booking_item_id,
    auth.uid()
  ) then

    raise exception
      'This booking item is not eligible for review';

  end if;


  if exists (
    select 1
    from public.reviews r
    where r.booking_item_id = p_booking_item_id
  ) then

    raise exception
      'A review already exists for this booking item';

  end if;


  select *
  into v_item
  from public.booking_items
  where id = p_booking_item_id;


  insert into public.reviews (
    booking_item_id,
    booking_id,
    reviewer_id,

    -- Temporary valid value.
    -- populate_review_target() overwrites this from the
    -- authoritative booking item before INSERT completes.
    target_type,

    rating,
    title,
    comment,

    status
  )
  values (
    v_item.id,
    v_item.booking_id,
    auth.uid(),

    'restaurant',

    p_rating,

    nullif(trim(p_title), ''),
    nullif(trim(p_comment), ''),

    'pending'
  )
  returning *
  into v_result;


  return v_result;

end;
$$;



-- =========================================================
-- 4. REVIEWER CAN EDIT OWN REVIEW
--
-- Editing content sends review back to moderation.
-- Target / booking relationship cannot be changed.
-- =========================================================

create or replace function public.edit_review(
  p_review_id bigint,
  p_rating integer,
  p_title text default null,
  p_comment text default null
)
returns public.reviews
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.reviews%rowtype;
  v_result public.reviews%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5';
  end if;


  select *
  into v_review
  from public.reviews
  where id = p_review_id
  for update;


  if not found then
    raise exception 'Review does not exist';
  end if;


  if v_review.reviewer_id <> auth.uid() then
    raise exception 'You do not own this review';
  end if;


  update public.reviews
  set
    rating = p_rating,

    title =
      nullif(trim(p_title), ''),

    comment =
      nullif(trim(p_comment), ''),

    status = 'pending',

    moderation_notes = null

  where id = p_review_id

  returning *
  into v_result;


  return v_result;

end;
$$;



-- =========================================================
-- 5. PROVIDER REPLY
--
-- Only provider linked to booking item can reply.
-- Platform-managed attraction/activity reviews can be
-- handled by admin.
-- =========================================================

create or replace function public.reply_to_review(
  p_review_id bigint,
  p_reply text
)
returns public.reviews
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_review public.reviews%rowtype;
  v_result public.reviews%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  if nullif(trim(p_reply), '') is null then
    raise exception 'Reply cannot be empty';
  end if;


  select *
  into v_review
  from public.reviews
  where id = p_review_id
  for update;


  if not found then
    raise exception 'Review does not exist';
  end if;


  if v_review.status <> 'published' then
    raise exception
      'Only published reviews can receive provider replies';
  end if;


  if not public.is_admin_user()
     and v_review.target_provider_user_id
         is distinct from auth.uid() then

    raise exception
      'You are not authorized to reply to this review';

  end if;


  update public.reviews
  set
    provider_reply =
      trim(p_reply),

    provider_replied_at =
      now()

  where id = p_review_id

  returning *
  into v_result;


  return v_result;

end;
$$;



-- =========================================================
-- 6. ADMIN REVIEW MODERATION
-- =========================================================

create or replace function public.moderate_review(
  p_review_id bigint,
  p_status text,
  p_notes text default null
)
returns public.reviews
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result public.reviews%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  if not public.is_admin_user() then
    raise exception
      'Only an administrator can moderate reviews';
  end if;


  if p_status not in (
    'published',
    'hidden',
    'rejected'
  ) then

    raise exception
      'Invalid review moderation status';

  end if;


  update public.reviews
  set
    status = p_status,

    moderation_notes =
      nullif(trim(p_notes), '')

  where id = p_review_id

  returning *
  into v_result;


  if not found then
    raise exception 'Review does not exist';
  end if;


  return v_result;

end;
$$;



-- =========================================================
-- 7. ENABLE RLS
-- =========================================================

alter table public.reviews
enable row level security;

alter table public.notifications
enable row level security;

alter table public.notification_preferences
enable row level security;



-- =========================================================
-- 8. REVIEW VISIBILITY
--
-- Published reviews -> public
-- Reviewer -> own review even pending/hidden/rejected
-- Target provider -> reviews about own service
-- Admin -> all
-- =========================================================

drop policy if exists
"Published reviews are public"
on public.reviews;

create policy
"Published reviews are public"
on public.reviews
for select
using (
  status = 'published'
);


drop policy if exists
"Reviewers view own reviews"
on public.reviews;

create policy
"Reviewers view own reviews"
on public.reviews
for select
to authenticated
using (
  reviewer_id = auth.uid()
);


drop policy if exists
"Providers view reviews about them"
on public.reviews;

create policy
"Providers view reviews about them"
on public.reviews
for select
to authenticated
using (
  target_provider_user_id = auth.uid()
);


drop policy if exists
"Admins view all reviews"
on public.reviews;

create policy
"Admins view all reviews"
on public.reviews
for select
to authenticated
using (
  public.is_admin_user()
);



-- =========================================================
-- 9. NOTIFICATION VISIBILITY
-- =========================================================

drop policy if exists
"Users view own notifications"
on public.notifications;

create policy
"Users view own notifications"
on public.notifications
for select
to authenticated
using (
  user_id = auth.uid()
);



-- =========================================================
-- 10. NOTIFICATION PREFERENCES
-- =========================================================

drop policy if exists
"Users view own notification preferences"
on public.notification_preferences;

create policy
"Users view own notification preferences"
on public.notification_preferences
for select
to authenticated
using (
  user_id = auth.uid()
);


drop policy if exists
"Users update own notification preferences"
on public.notification_preferences;

create policy
"Users update own notification preferences"
on public.notification_preferences
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);



-- =========================================================
-- 11. MARK ONE NOTIFICATION READ / UNREAD
-- =========================================================

create or replace function public.set_notification_read_state(
  p_notification_id bigint,
  p_is_read boolean
)
returns public.notifications
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result public.notifications%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  update public.notifications
  set is_read = p_is_read

  where id = p_notification_id
    and user_id = auth.uid()

  returning *
  into v_result;


  if not found then
    raise exception
      'Notification does not exist or does not belong to you';
  end if;


  return v_result;

end;
$$;



-- =========================================================
-- 12. MARK ALL OWN NOTIFICATIONS READ
-- =========================================================

create or replace function public.mark_all_notifications_read()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  update public.notifications
  set is_read = true

  where user_id = auth.uid()
    and is_read = false;


  get diagnostics
    v_count = row_count;


  return v_count;

end;
$$;



-- =========================================================
-- 13. API PRIVILEGES
--
-- Reviews:
-- SELECT only directly.
-- INSERT/UPDATE happen through secure functions.
--
-- Notifications:
-- SELECT only directly.
-- Users cannot create fake notifications.
-- =========================================================

revoke all
on table
  public.reviews,
  public.notifications,
  public.notification_preferences
from anon, authenticated;


grant select
on table public.reviews
to anon, authenticated;


grant select
on table public.notifications
to authenticated;


grant select, update
on table public.notification_preferences
to authenticated;



-- =========================================================
-- 14. SECURE FUNCTION PRIVILEGES
-- =========================================================

revoke all
on function public.submit_review(
  bigint,
  integer,
  text,
  text
)
from public, anon;


grant execute
on function public.submit_review(
  bigint,
  integer,
  text,
  text
)
to authenticated;



revoke all
on function public.edit_review(
  bigint,
  integer,
  text,
  text
)
from public, anon;


grant execute
on function public.edit_review(
  bigint,
  integer,
  text,
  text
)
to authenticated;



revoke all
on function public.reply_to_review(
  bigint,
  text
)
from public, anon;


grant execute
on function public.reply_to_review(
  bigint,
  text
)
to authenticated;



revoke all
on function public.moderate_review(
  bigint,
  text,
  text
)
from public, anon;


grant execute
on function public.moderate_review(
  bigint,
  text,
  text
)
to authenticated;



revoke all
on function public.set_notification_read_state(
  bigint,
  boolean
)
from public, anon;


grant execute
on function public.set_notification_read_state(
  bigint,
  boolean
)
to authenticated;



revoke all
on function public.mark_all_notifications_read()
from public, anon;


grant execute
on function public.mark_all_notifications_read()
to authenticated;
