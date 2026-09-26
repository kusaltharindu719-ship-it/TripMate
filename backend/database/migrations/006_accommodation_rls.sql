-- =========================================================
-- TripMate
-- Migration 006: Accommodation Security / RLS
-- =========================================================


-- =========================================================
-- 1. HELPER: CHECK ACCOMMODATION OWNERSHIP
-- =========================================================

create or replace function public.is_accommodation_owner(
  target_accommodation_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.accommodations a
    join public.profiles p
      on p.id = a.owner_id
    where a.id = target_accommodation_id
      and a.owner_id = auth.uid()
      and p.role = 'accommodation_owner'
  );
$$;

revoke all
on function public.is_accommodation_owner(bigint)
from public;

grant execute
on function public.is_accommodation_owner(bigint)
to authenticated;



-- =========================================================
-- 2. HELPER: CHECK PUBLIC ACCOMMODATION VISIBILITY
-- =========================================================

create or replace function public.is_accommodation_public(
  target_accommodation_id bigint
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.accommodations a
    where a.id = target_accommodation_id
      and a.is_active = true
      and public.is_provider_approved(
        a.owner_id,
        'accommodation'
      )
  );
$$;

revoke all
on function public.is_accommodation_public(bigint)
from public;

grant execute
on function public.is_accommodation_public(bigint)
to anon, authenticated;



-- =========================================================
-- 3. ENABLE RLS
-- =========================================================

alter table public.accommodations
enable row level security;



-- =========================================================
-- 4. PUBLIC CAN VIEW APPROVED ACTIVE ACCOMMODATIONS
-- =========================================================

create policy
"Public can view approved active accommodations"
on public.accommodations

for select
to anon, authenticated

using (
  is_active = true
  and public.is_provider_approved(
    owner_id,
    'accommodation'
  )
);



-- =========================================================
-- 5. OWNER CAN VIEW OWN PROPERTY
-- even if pending or inactive
-- =========================================================

create policy
"Accommodation owners can view own properties"
on public.accommodations

for select
to authenticated

using (
  owner_id = auth.uid()
);



-- =========================================================
-- 6. OWNER CAN CREATE OWN PROPERTY
-- =========================================================

create policy
"Accommodation owners can create properties"
on public.accommodations

for insert
to authenticated

with check (
  owner_id = auth.uid()

  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'accommodation_owner'
  )
);



-- =========================================================
-- 7. OWNER CAN UPDATE OWN PROPERTY
-- =========================================================

create policy
"Accommodation owners can update own properties"
on public.accommodations

for update
to authenticated

using (
  owner_id = auth.uid()
)

with check (
  owner_id = auth.uid()

  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'accommodation_owner'
  )
);



-- =========================================================
-- 8. OWNER CAN DELETE OWN PROPERTY
-- =========================================================

create policy
"Accommodation owners can delete own properties"
on public.accommodations

for delete
to authenticated

using (
  owner_id = auth.uid()

  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'accommodation_owner'
  )
);
