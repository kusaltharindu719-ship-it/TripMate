-- =========================================================
-- TripMate
-- Migration 040: Legacy Schema Alignment
-- =========================================================
-- Aligns the older Supabase schema with the current
-- TripMate traveler + restaurant cart implementation.
-- =========================================================


-- =========================================================
-- 1. ALIGN TRIPS TABLE
-- =========================================================

alter table public.trips
    add column if not exists trip_name text,
    add column if not exists start_location text,
    add column if not exists start_lat numeric(9,6),
    add column if not exists start_lng numeric(9,6),
    add column if not exists start_date date,
    add column if not exists end_date date,
    add column if not exists number_of_travelers integer,
    add column if not exists adult_count integer default 1,
    add column if not exists child_count integer default 0,
    add column if not exists budget numeric(12,2),
    add column if not exists currency text default 'LKR',
    add column if not exists status text default 'planning',
    add column if not exists special_requirements text,
    add column if not exists updated_at timestamptz default now();


-- =========================================================
-- 2. BACKFILL LEGACY TRIP DATA WHEN AVAILABLE
-- =========================================================

do $$
begin
    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'trips'
          and column_name = 'title'
    ) then
        execute '
            update public.trips
            set trip_name = title
            where trip_name is null
              and title is not null
        ';
    end if;

    if exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'trips'
          and column_name = 'destination'
    ) then
        execute '
            update public.trips
            set start_location = destination
            where start_location is null
              and destination is not null
        ';
    end if;
end
$$;


update public.trips
set
    adult_count = coalesce(adult_count, 1),
    child_count = coalesce(child_count, 0),
    currency = coalesce(currency, 'LKR'),
    status = coalesce(status, 'planning');

update public.trips
set number_of_travelers =
    adult_count + child_count
where number_of_travelers is null;


-- =========================================================
-- 3. TRIP DEFAULTS
-- =========================================================

alter table public.trips
    alter column adult_count set default 1,
    alter column child_count set default 0,
    alter column currency set default 'LKR',
    alter column status set default 'planning';


-- Apply NOT NULL only when existing data is safe.
do $$
begin
    if not exists (
        select 1
        from public.trips
        where traveler_id is null
           or trip_name is null
           or start_location is null
           or start_date is null
           or end_date is null
           or adult_count is null
           or child_count is null
           or number_of_travelers is null
    ) then
        alter table public.trips
            alter column traveler_id set not null,
            alter column trip_name set not null,
            alter column start_location set not null,
            alter column start_date set not null,
            alter column end_date set not null,
            alter column adult_count set not null,
            alter column child_count set not null,
            alter column number_of_travelers set not null;
    end if;
end
$$;


-- =========================================================
-- 4. KEEP TRAVELER COUNT SYNCHRONIZED
-- =========================================================

create or replace function public.sync_trip_traveler_count()
returns trigger
language plpgsql
as $$
begin
    new.number_of_travelers :=
        coalesce(new.adult_count, 0)
        + coalesce(new.child_count, 0);

    return new;
end;
$$;


drop trigger if exists sync_trip_traveler_count_trigger
on public.trips;

create trigger sync_trip_traveler_count_trigger
before insert or update
on public.trips
for each row
execute procedure public.sync_trip_traveler_count();


-- =========================================================
-- 5. UPDATED_AT SUPPORT
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;


drop trigger if exists set_trips_updated_at
on public.trips;

create trigger set_trips_updated_at
before update
on public.trips
for each row
execute procedure public.set_updated_at();


-- =========================================================
-- 6. BASIC TRIP VALIDATION
-- =========================================================

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'trips_date_range_check'
    ) then
        alter table public.trips
            add constraint trips_date_range_check
            check (
                end_date is null
                or start_date is null
                or end_date >= start_date
            );
    end if;
end
$$;


do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'trips_total_travelers_check'
    ) then
        alter table public.trips
            add constraint trips_total_travelers_check
            check (
                number_of_travelers is null
                or number_of_travelers > 0
            );
    end if;
end
$$;


do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'trips_budget_check'
    ) then
        alter table public.trips
            add constraint trips_budget_check
            check (
                budget is null
                or budget >= 0
            );
    end if;
end
$$;


-- =========================================================
-- 7. FIX TRAVELER FOREIGN KEY
-- Old schema referenced public.users(id).
-- Current TripMate uses public.profiles(id).
-- =========================================================

alter table public.trips
drop constraint if exists trips_traveler_id_fkey;


alter table public.trips
add constraint trips_traveler_id_fkey
foreign key (traveler_id)
references public.profiles(id)
not valid;


do $$
begin
    if not exists (
        select 1
        from public.trips t
        left join public.profiles p
            on p.id = t.traveler_id
        where t.traveler_id is not null
          and p.id is null
    ) then
        alter table public.trips
        validate constraint trips_traveler_id_fkey;
    end if;
end
$$;


-- =========================================================
-- 8. ALIGN FOOD ITEMS FOR CART SNAPSHOTS
-- set_trip_cart_snapshot() requires fi.currency.
-- =========================================================

alter table public.food_items
add column if not exists currency text default 'LKR';


update public.food_items
set currency = 'LKR'
where currency is null;


alter table public.food_items
    alter column currency set default 'LKR',
    alter column currency set not null;


-- =========================================================
-- 9. TRAVELER API PRIVILEGES
-- =========================================================

grant usage on schema public
to authenticated;


grant select, insert, update, delete
on table public.trips
to authenticated;


grant select, insert, update, delete
on table public.trip_cart_items
to authenticated;


grant usage, select
on sequence public.trips_id_seq
to authenticated;


grant usage, select
on sequence public.trip_cart_items_id_seq
to authenticated;


-- =========================================================
-- 10. TRIP ROW LEVEL SECURITY
-- =========================================================

alter table public.trips
enable row level security;


drop policy if exists
"Travelers can view own trips"
on public.trips;

create policy
"Travelers can view own trips"
on public.trips
for select
to authenticated
using (
    traveler_id = auth.uid()
);


drop policy if exists
"Travelers can create own trips"
on public.trips;

create policy
"Travelers can create own trips"
on public.trips
for insert
to authenticated
with check (
    traveler_id = auth.uid()

    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'traveler'
    )
);


drop policy if exists
"Travelers can update own trips"
on public.trips;

create policy
"Travelers can update own trips"
on public.trips
for update
to authenticated
using (
    traveler_id = auth.uid()
)
with check (
    traveler_id = auth.uid()

    and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role = 'traveler'
    )
);


drop policy if exists
"Travelers can delete own planning trips"
on public.trips;

create policy
"Travelers can delete own planning trips"
on public.trips
for delete
to authenticated
using (
    traveler_id = auth.uid()
    and status = 'planning'
);


-- =========================================================
-- END MIGRATION 040
-- =========================================================