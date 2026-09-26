-- =========================================================
-- TripMate
-- Migration 015: Driver Module Security / RLS
-- =========================================================


-- =========================================================
-- 1. SECURITY HELPER FUNCTIONS
-- =========================================================

create or replace function public.is_vehicle_owner(
  p_vehicle_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.vehicles v
    where v.id = p_vehicle_id
      and v.driver_id = auth.uid()
  );
$$;


create or replace function public.is_vehicle_public(
  p_vehicle_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.vehicles v
    join public.vehicle_verifications vv
      on vv.vehicle_id = v.id
    where v.id = p_vehicle_id
      and v.is_active = true
      and vv.status = 'approved'
      and public.is_provider_approved(
        v.driver_id,
        'driver'
      )
  );
$$;


create or replace function public.is_transport_request_owner(
  p_request_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.transport_requests tr
    where tr.id = p_request_id
      and tr.traveler_id = auth.uid()
  );
$$;


-- Approved drivers can see:
-- 1. currently open requests
-- 2. requests they already submitted a bid for
create or replace function public.driver_can_view_transport_request(
  p_request_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    public.is_provider_approved(
      auth.uid(),
      'driver'
    )
    and exists (
      select 1
      from public.transport_requests tr
      where tr.id = p_request_id
        and (
          tr.status = 'open'

          or exists (
            select 1
            from public.driver_bids db
            where db.transport_request_id = tr.id
              and db.driver_id = auth.uid()
          )
        )
    );
$$;



-- =========================================================
-- 2. ENABLE RLS
-- =========================================================

alter table public.driver_profiles
enable row level security;

alter table public.driver_licenses
enable row level security;

alter table public.driver_documents
enable row level security;

alter table public.vehicle_types
enable row level security;

alter table public.vehicles
enable row level security;

alter table public.vehicle_verifications
enable row level security;

alter table public.vehicle_images
enable row level security;

alter table public.vehicle_feature_catalog
enable row level security;

alter table public.vehicle_features
enable row level security;

alter table public.vehicle_documents
enable row level security;

alter table public.driver_availability
enable row level security;

alter table public.transport_requests
enable row level security;

alter table public.transport_request_stops
enable row level security;

alter table public.driver_bids
enable row level security;



-- =========================================================
-- 3. DRIVER PROFILES
-- =========================================================

drop policy if exists
"Approved drivers are publicly visible"
on public.driver_profiles;

create policy
"Approved drivers are publicly visible"
on public.driver_profiles
for select
using (
  user_id = auth.uid()
  or public.is_provider_approved(
    user_id,
    'driver'
  )
);


drop policy if exists
"Drivers create own profile"
on public.driver_profiles;

create policy
"Drivers create own profile"
on public.driver_profiles
for insert
to authenticated
with check (
  user_id = auth.uid()

  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'driver'
  )
);


drop policy if exists
"Drivers update own profile"
on public.driver_profiles;

create policy
"Drivers update own profile"
on public.driver_profiles
for update
to authenticated
using (
  user_id = auth.uid()
)
with check (
  user_id = auth.uid()
);



-- =========================================================
-- 4. DRIVER LICENCE
-- PRIVATE
-- =========================================================

drop policy if exists
"Drivers view own licence"
on public.driver_licenses;

create policy
"Drivers view own licence"
on public.driver_licenses
for select
to authenticated
using (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers create own licence"
on public.driver_licenses;

create policy
"Drivers create own licence"
on public.driver_licenses
for insert
to authenticated
with check (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers update own licence"
on public.driver_licenses;

create policy
"Drivers update own licence"
on public.driver_licenses
for update
to authenticated
using (
  driver_id = auth.uid()
)
with check (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers delete own licence"
on public.driver_licenses;

create policy
"Drivers delete own licence"
on public.driver_licenses
for delete
to authenticated
using (
  driver_id = auth.uid()
);



-- =========================================================
-- 5. DRIVER DOCUMENTS
-- PRIVATE
-- =========================================================

drop policy if exists
"Drivers view own documents"
on public.driver_documents;

create policy
"Drivers view own documents"
on public.driver_documents
for select
to authenticated
using (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers add own documents"
on public.driver_documents;

create policy
"Drivers add own documents"
on public.driver_documents
for insert
to authenticated
with check (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers update own documents"
on public.driver_documents;

create policy
"Drivers update own documents"
on public.driver_documents
for update
to authenticated
using (
  driver_id = auth.uid()
)
with check (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers delete own documents"
on public.driver_documents;

create policy
"Drivers delete own documents"
on public.driver_documents
for delete
to authenticated
using (
  driver_id = auth.uid()
);



-- =========================================================
-- 6. VEHICLE TYPE CATALOG
-- =========================================================

drop policy if exists
"Vehicle types are public"
on public.vehicle_types;

create policy
"Vehicle types are public"
on public.vehicle_types
for select
using (true);



-- =========================================================
-- 7. VEHICLES
-- =========================================================

drop policy if exists
"Public can view approved vehicles"
on public.vehicles;

create policy
"Public can view approved vehicles"
on public.vehicles
for select
using (
  driver_id = auth.uid()
  or public.is_vehicle_public(id)
);


drop policy if exists
"Drivers add own vehicles"
on public.vehicles;

create policy
"Drivers add own vehicles"
on public.vehicles
for insert
to authenticated
with check (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers update own vehicles"
on public.vehicles;

create policy
"Drivers update own vehicles"
on public.vehicles
for update
to authenticated
using (
  driver_id = auth.uid()
)
with check (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers delete own vehicles"
on public.vehicles;

create policy
"Drivers delete own vehicles"
on public.vehicles
for delete
to authenticated
using (
  driver_id = auth.uid()
);



-- =========================================================
-- 8. VEHICLE VERIFICATION
-- Driver can VIEW status only.
-- Driver cannot approve own vehicle.
-- =========================================================

drop policy if exists
"Drivers view own vehicle verification"
on public.vehicle_verifications;

create policy
"Drivers view own vehicle verification"
on public.vehicle_verifications
for select
to authenticated
using (
  public.is_vehicle_owner(vehicle_id)
);



-- =========================================================
-- 9. VEHICLE IMAGES
-- =========================================================

drop policy if exists
"Vehicle images are visible"
on public.vehicle_images;

create policy
"Vehicle images are visible"
on public.vehicle_images
for select
using (
  public.is_vehicle_owner(vehicle_id)
  or public.is_vehicle_public(vehicle_id)
);


drop policy if exists
"Drivers manage own vehicle images"
on public.vehicle_images;

create policy
"Drivers manage own vehicle images"
on public.vehicle_images
for all
to authenticated
using (
  public.is_vehicle_owner(vehicle_id)
)
with check (
  public.is_vehicle_owner(vehicle_id)
);



-- =========================================================
-- 10. VEHICLE FEATURE CATALOG
-- =========================================================

drop policy if exists
"Vehicle feature catalog is public"
on public.vehicle_feature_catalog;

create policy
"Vehicle feature catalog is public"
on public.vehicle_feature_catalog
for select
using (true);



-- =========================================================
-- 11. VEHICLE FEATURES
-- =========================================================

drop policy if exists
"Vehicle features are visible"
on public.vehicle_features;

create policy
"Vehicle features are visible"
on public.vehicle_features
for select
using (
  public.is_vehicle_owner(vehicle_id)
  or public.is_vehicle_public(vehicle_id)
);


drop policy if exists
"Drivers manage own vehicle features"
on public.vehicle_features;

create policy
"Drivers manage own vehicle features"
on public.vehicle_features
for all
to authenticated
using (
  public.is_vehicle_owner(vehicle_id)
)
with check (
  public.is_vehicle_owner(vehicle_id)
);



-- =========================================================
-- 12. VEHICLE DOCUMENTS
-- PRIVATE
-- =========================================================

drop policy if exists
"Drivers view own vehicle documents"
on public.vehicle_documents;

create policy
"Drivers view own vehicle documents"
on public.vehicle_documents
for select
to authenticated
using (
  public.is_vehicle_owner(vehicle_id)
);


drop policy if exists
"Drivers add own vehicle documents"
on public.vehicle_documents;

create policy
"Drivers add own vehicle documents"
on public.vehicle_documents
for insert
to authenticated
with check (
  public.is_vehicle_owner(vehicle_id)
);


drop policy if exists
"Drivers update own vehicle documents"
on public.vehicle_documents;

create policy
"Drivers update own vehicle documents"
on public.vehicle_documents
for update
to authenticated
using (
  public.is_vehicle_owner(vehicle_id)
)
with check (
  public.is_vehicle_owner(vehicle_id)
);


drop policy if exists
"Drivers delete own vehicle documents"
on public.vehicle_documents;

create policy
"Drivers delete own vehicle documents"
on public.vehicle_documents
for delete
to authenticated
using (
  public.is_vehicle_owner(vehicle_id)
);



-- =========================================================
-- 13. DRIVER AVAILABILITY
-- Do not publicly expose complete driver schedules.
-- =========================================================

drop policy if exists
"Drivers view own availability"
on public.driver_availability;

create policy
"Drivers view own availability"
on public.driver_availability
for select
to authenticated
using (
  driver_id = auth.uid()
);


drop policy if exists
"Drivers manage own availability"
on public.driver_availability;

create policy
"Drivers manage own availability"
on public.driver_availability
for all
to authenticated
using (
  driver_id = auth.uid()
)
with check (
  driver_id = auth.uid()
);



-- =========================================================
-- 14. TRANSPORT REQUESTS
-- =========================================================

drop policy if exists
"Travelers and eligible drivers view transport requests"
on public.transport_requests;

create policy
"Travelers and eligible drivers view transport requests"
on public.transport_requests
for select
to authenticated
using (
  traveler_id = auth.uid()
  or public.driver_can_view_transport_request(id)
);


drop policy if exists
"Travelers create own transport requests"
on public.transport_requests;

create policy
"Travelers create own transport requests"
on public.transport_requests
for insert
to authenticated
with check (
  traveler_id = auth.uid()
  and public.is_trip_owner(trip_id)
);


drop policy if exists
"Travelers update own transport requests"
on public.transport_requests;

create policy
"Travelers update own transport requests"
on public.transport_requests
for update
to authenticated
using (
  traveler_id = auth.uid()
)
with check (
  traveler_id = auth.uid()
  and public.is_trip_owner(trip_id)
);


-- Direct DELETE only while still draft.
-- Once published/opened we preserve history and use cancellation.
drop policy if exists
"Travelers delete draft transport requests"
on public.transport_requests;

create policy
"Travelers delete draft transport requests"
on public.transport_requests
for delete
to authenticated
using (
  traveler_id = auth.uid()
  and status = 'draft'
);



-- =========================================================
-- 15. TRANSPORT REQUEST STOPS
-- Snapshot stops are created by database trigger.
-- Clients only READ them.
-- =========================================================

drop policy if exists
"Travelers and drivers view request stops"
on public.transport_request_stops;

create policy
"Travelers and drivers view request stops"
on public.transport_request_stops
for select
to authenticated
using (
  public.is_transport_request_owner(
    transport_request_id
  )
  or public.driver_can_view_transport_request(
    transport_request_id
  )
);



-- =========================================================
-- 16. DRIVER BIDS
-- =========================================================

drop policy if exists
"Drivers and request owners view bids"
on public.driver_bids;

create policy
"Drivers and request owners view bids"
on public.driver_bids
for select
to authenticated
using (
  driver_id = auth.uid()

  or public.is_transport_request_owner(
    transport_request_id
  )
);


drop policy if exists
"Approved drivers create own bids"
on public.driver_bids;

create policy
"Approved drivers create own bids"
on public.driver_bids
for insert
to authenticated
with check (
  driver_id = auth.uid()

  and status = 'pending'

  and public.is_provider_approved(
    auth.uid(),
    'driver'
  )

  and public.is_vehicle_owner(
    vehicle_id
  )

  and public.driver_can_view_transport_request(
    transport_request_id
  )
);


-- Drivers may edit their own pending bid details.
-- Sensitive status transitions will be handled by secure
-- workflow functions in the next migration.
drop policy if exists
"Drivers update own pending bids"
on public.driver_bids;

create policy
"Drivers update own pending bids"
on public.driver_bids
for update
to authenticated
using (
  driver_id = auth.uid()
  and status = 'pending'
)
with check (
  driver_id = auth.uid()
  and status in (
    'pending',
    'withdrawn'
  )
  and public.is_vehicle_owner(
    vehicle_id
  )
);
