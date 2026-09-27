-- =========================================================
-- TripMate
-- Migration 034: Review Rating Aggregation
-- =========================================================
--
-- Ratings are calculated only from PUBLISHED reviews.
-- No manually editable average-rating column is stored.
-- =========================================================


-- =========================================================
-- 1. ACCOMMODATION RATINGS
-- =========================================================

create or replace view public.accommodation_rating_summary
with (security_invoker = true)
as

select
  r.accommodation_id,

  count(*)::bigint
    as review_count,

  round(
    avg(r.rating)::numeric,
    2
  ) as average_rating

from public.reviews r

where r.status = 'published'
  and r.target_type = 'accommodation'
  and r.accommodation_id is not null

group by
  r.accommodation_id;



-- =========================================================
-- 2. RESTAURANT RATINGS
-- =========================================================

create or replace view public.restaurant_rating_summary
with (security_invoker = true)
as

select
  r.restaurant_id,

  count(*)::bigint
    as review_count,

  round(
    avg(r.rating)::numeric,
    2
  ) as average_rating

from public.reviews r

where r.status = 'published'
  and r.target_type = 'restaurant'
  and r.restaurant_id is not null

group by
  r.restaurant_id;



-- =========================================================
-- 3. ATTRACTION RATINGS
-- =========================================================

create or replace view public.attraction_rating_summary
with (security_invoker = true)
as

select
  r.attraction_id,

  count(*)::bigint
    as review_count,

  round(
    avg(r.rating)::numeric,
    2
  ) as average_rating

from public.reviews r

where r.status = 'published'
  and r.target_type = 'attraction'
  and r.attraction_id is not null

group by
  r.attraction_id;



-- =========================================================
-- 4. ACTIVITY RATINGS
-- =========================================================

create or replace view public.activity_rating_summary
with (security_invoker = true)
as

select
  r.activity_id,

  count(*)::bigint
    as review_count,

  round(
    avg(r.rating)::numeric,
    2
  ) as average_rating

from public.reviews r

where r.status = 'published'
  and r.target_type = 'activity'
  and r.activity_id is not null

group by
  r.activity_id;



-- =========================================================
-- 5. DRIVER RATINGS
-- =========================================================

create or replace view public.driver_rating_summary
with (security_invoker = true)
as

select
  r.driver_id,

  count(*)::bigint
    as review_count,

  round(
    avg(r.rating)::numeric,
    2
  ) as average_rating

from public.reviews r

where r.status = 'published'
  and r.target_type = 'driver'
  and r.driver_id is not null

group by
  r.driver_id;



-- =========================================================
-- 6. API PRIVILEGES
-- =========================================================

grant select
on public.accommodation_rating_summary
to anon, authenticated;

grant select
on public.restaurant_rating_summary
to anon, authenticated;

grant select
on public.attraction_rating_summary
to anon, authenticated;

grant select
on public.activity_rating_summary
to anon, authenticated;

grant select
on public.driver_rating_summary
to anon, authenticated;
