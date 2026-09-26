-- =========================================================
-- TripMate Migration 020
-- Add Trip Starting Coordinates
-- =========================================================

alter table public.trips
add column if not exists start_lat numeric(9,6);

alter table public.trips
add column if not exists start_lng numeric(9,6);


-- Valid latitude range
alter table public.trips
drop constraint if exists trips_start_lat_check;

alter table public.trips
add constraint trips_start_lat_check
check (
  start_lat is null
  or start_lat between -90 and 90
);


-- Valid longitude range
alter table public.trips
drop constraint if exists trips_start_lng_check;

alter table public.trips
add constraint trips_start_lng_check
check (
  start_lng is null
  or start_lng between -180 and 180
);
