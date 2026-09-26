-- =========================================================
-- TripMate
-- Migration 017: Driver Verification Hardening
-- =========================================================


-- =========================================================
-- 1. DRIVER LICENCE CHANGE INVALIDATES DRIVER APPROVAL
-- Suspended drivers remain suspended.
-- =========================================================

create or replace function public.reset_driver_approval_on_license_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid;
begin

  if tg_op = 'DELETE' then
    v_driver_id := old.driver_id;
  else
    v_driver_id := new.driver_id;
  end if;


  update public.provider_verifications
  set status = 'pending'
  where user_id = v_driver_id
    and provider_type = 'driver'
    and status in (
      'approved',
      'rejected'
    );


  return coalesce(new, old);
end;
$$;


drop trigger if exists
reset_driver_approval_on_license_change_trigger
on public.driver_licenses;

create trigger
reset_driver_approval_on_license_change_trigger
after insert or update or delete
on public.driver_licenses
for each row
execute procedure
public.reset_driver_approval_on_license_change();



-- =========================================================
-- 2. IMPORTANT DRIVER DOCUMENT CHANGES
--    ALSO REQUIRE RE-VERIFICATION
-- =========================================================

create or replace function public.reset_driver_approval_on_document_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid;
  v_is_sensitive_change boolean := false;
begin

  if tg_op = 'INSERT' then

    v_driver_id := new.driver_id;

    v_is_sensitive_change :=
      new.document_type in (
        'driving_license',
        'nic',
        'passport'
      );


  elsif tg_op = 'DELETE' then

    v_driver_id := old.driver_id;

    v_is_sensitive_change :=
      old.document_type in (
        'driving_license',
        'nic',
        'passport'
      );


  else

    v_driver_id := new.driver_id;

    v_is_sensitive_change :=
      (
        old.document_type
          is distinct from new.document_type

        or old.storage_path
          is distinct from new.storage_path

        or old.expiry_date
          is distinct from new.expiry_date
      )
      and (
        old.document_type in (
          'driving_license',
          'nic',
          'passport'
        )

        or new.document_type in (
          'driving_license',
          'nic',
          'passport'
        )
      );

  end if;


  if v_is_sensitive_change then

    update public.provider_verifications
    set status = 'pending'
    where user_id = v_driver_id
      and provider_type = 'driver'
      and status in (
        'approved',
        'rejected'
      );

  end if;


  return coalesce(new, old);
end;
$$;


drop trigger if exists
reset_driver_approval_on_document_change_trigger
on public.driver_documents;

create trigger
reset_driver_approval_on_document_change_trigger
after insert or update or delete
on public.driver_documents
for each row
execute procedure
public.reset_driver_approval_on_document_change();



-- =========================================================
-- 3. VEHICLE OWNER CANNOT BE CHANGED
-- =========================================================

create or replace function public.prevent_vehicle_owner_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin

  if new.driver_id is distinct from old.driver_id then
    raise exception 'Vehicle owner cannot be changed';
  end if;

  return new;
end;
$$;


drop trigger if exists
prevent_vehicle_owner_change_trigger
on public.vehicles;

create trigger
prevent_vehicle_owner_change_trigger
before update
on public.vehicles
for each row
execute procedure
public.prevent_vehicle_owner_change();



-- =========================================================
-- 4. CRITICAL VEHICLE DETAIL CHANGE
--    INVALIDATES VEHICLE APPROVAL
--
-- Example:
-- approved 4-seat car cannot simply become a
-- "10-seat vehicle" without another verification.
-- =========================================================

create or replace function public.reset_vehicle_approval_on_detail_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  if
    new.vehicle_type_id
      is distinct from old.vehicle_type_id

    or new.registration_number
      is distinct from old.registration_number

    or new.make
      is distinct from old.make

    or new.model
      is distinct from old.model

    or new.manufacture_year
      is distinct from old.manufacture_year

    or new.passenger_capacity
      is distinct from old.passenger_capacity

    or new.luggage_capacity
      is distinct from old.luggage_capacity

  then

    update public.vehicle_verifications
    set
      status = 'pending',
      submitted_at = now(),
      reviewed_by = null,
      reviewed_at = null,
      review_notes = null
    where vehicle_id = new.id
      and status in (
        'approved',
        'rejected'
      );

  end if;


  return new;
end;
$$;


drop trigger if exists
reset_vehicle_approval_on_detail_change_trigger
on public.vehicles;

create trigger
reset_vehicle_approval_on_detail_change_trigger
after update
on public.vehicles
for each row
execute procedure
public.reset_vehicle_approval_on_detail_change();



-- =========================================================
-- 5. VEHICLE DOCUMENT CHANGE
--    INVALIDATES VEHICLE APPROVAL
-- =========================================================

create or replace function public.reset_vehicle_approval_on_document_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_vehicle_id bigint;
  v_changed boolean := false;
begin

  if tg_op = 'INSERT' then

    v_vehicle_id := new.vehicle_id;
    v_changed := true;


  elsif tg_op = 'DELETE' then

    v_vehicle_id := old.vehicle_id;
    v_changed := true;


  else

    v_vehicle_id := new.vehicle_id;

    v_changed :=
      old.vehicle_id
        is distinct from new.vehicle_id

      or old.document_type
        is distinct from new.document_type

      or old.storage_path
        is distinct from new.storage_path

      or old.expiry_date
        is distinct from new.expiry_date;

  end if;


  if v_changed then

    update public.vehicle_verifications
    set
      status = 'pending',
      submitted_at = now(),
      reviewed_by = null,
      reviewed_at = null,
      review_notes = null
    where vehicle_id = v_vehicle_id
      and status in (
        'approved',
        'rejected'
      );

  end if;


  return coalesce(new, old);
end;
$$;


drop trigger if exists
reset_vehicle_approval_on_document_change_trigger
on public.vehicle_documents;

create trigger
reset_vehicle_approval_on_document_change_trigger
after insert or update or delete
on public.vehicle_documents
for each row
execute procedure
public.reset_vehicle_approval_on_document_change();
