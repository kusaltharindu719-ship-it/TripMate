-- TripMate
-- Migration 038: Trusted Backend Service Privileges

grant select
on table public.room_inventory_reservations
to service_role;

grant select
on table public.activity_inventory_reservations
to service_role;
