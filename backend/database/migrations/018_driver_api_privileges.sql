-- =========================================================
-- TripMate
-- Migration 018: Driver Document Security
-- =========================================================


-- =========================================================
-- 1. ADMIN HELPER
-- =========================================================

create or replace function public.is_admin_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  );
$$;



-- =========================================================
-- 2. DRIVER CANNOT SELF-APPROVE DOCUMENTS
-- =========================================================

create or replace function public.protect_driver_document_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  if not public.is_admin_user() then

    if tg_op = 'INSERT' then

      if new.verification_status <> 'pending'
         or new.review_notes is not null then

        raise exception
          'Driver cannot approve or review own documents';

      end if;


    elsif tg_op = 'UPDATE' then

      if new.verification_status
           is distinct from old.verification_status

         or new.review_notes
           is distinct from old.review_notes then

        raise exception
          'Driver cannot change document verification fields';

      end if;

    end if;

  end if;


  return new;
end;
$$;


drop trigger if exists
protect_driver_document_review_trigger
on public.driver_documents;

create trigger
protect_driver_document_review_trigger
before insert or update
on public.driver_documents
for each row
execute procedure
public.protect_driver_document_review();



-- =========================================================
-- 3. DRIVER CANNOT SELF-APPROVE VEHICLE DOCUMENTS
-- =========================================================

create or replace function public.protect_vehicle_document_review()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin

  if not public.is_admin_user() then

    if tg_op = 'INSERT' then

      if new.verification_status <> 'pending'
         or new.review_notes is not null then

        raise exception
          'Driver cannot approve or review own vehicle documents';

      end if;


    elsif tg_op = 'UPDATE' then

      if new.verification_status
           is distinct from old.verification_status

         or new.review_notes
           is distinct from old.review_notes then

        raise exception
          'Driver cannot change vehicle document verification fields';

      end if;

    end if;

  end if;


  return new;
end;
$$;


drop trigger if exists
protect_vehicle_document_review_trigger
on public.vehicle_documents;

create trigger
protect_vehicle_document_review_trigger
before insert or update
on public.vehicle_documents
for each row
execute procedure
public.protect_vehicle_document_review();



-- =========================================================
-- 4. VEHICLE DOCUMENT CANNOT BE MOVED TO ANOTHER VEHICLE
-- =========================================================

create or replace function public.prevent_vehicle_document_move()
returns trigger
language plpgsql
set search_path = ''
as $$
begin

  if new.vehicle_id is distinct from old.vehicle_id then
    raise exception
      'Vehicle document cannot be moved to another vehicle';
  end if;

  return new;
end;
$$;


drop trigger if exists
prevent_vehicle_document_move_trigger
on public.vehicle_documents;

create trigger
prevent_vehicle_document_move_trigger
before update
on public.vehicle_documents
for each row
execute procedure
public.prevent_vehicle_document_move();



-- =========================================================
-- 5. VEHICLE DOCUMENT COMPLIANCE
--
-- Registration:
--   must be approved.
--
-- Insurance + Revenue Licence:
--   must be approved and remain valid until trip end.
-- =========================================================

create or replace function public.vehicle_is_compliant_for_trip(
  p_vehicle_id bigint,
  p_trip_end_date date
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select

    -- Registration
    exists (
      select 1
      from public.vehicle_documents vd
      where vd.vehicle_id = p_vehicle_id
        and vd.document_type = 'registration'
        and vd.verification_status = 'approved'
        and (
          vd.expiry_date is null
          or vd.expiry_date >= p_trip_end_date
        )
    )

    and

    -- Insurance
    exists (
      select 1
      from public.vehicle_documents vd
      where vd.vehicle_id = p_vehicle_id
        and vd.document_type = 'insurance'
        and vd.verification_status = 'approved'
        and vd.expiry_date is not null
        and vd.expiry_date >= p_trip_end_date
    )

    and

    -- Revenue Licence
    exists (
      select 1
      from public.vehicle_documents vd
      where vd.vehicle_id = p_vehicle_id
        and vd.document_type = 'revenue_license'
        and vd.verification_status = 'approved'
        and vd.expiry_date is not null
        and vd.expiry_date >= p_trip_end_date
    );
$$;



-- =========================================================
-- 6. CHECK DOCUMENTS WHEN BID IS CREATED OR ACCEPTED
-- =========================================================

create or replace function public.validate_bid_vehicle_documents()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_trip_end_date date;
begin

  -- Only active bidding states need this validation
  if new.status not in (
    'pending',
    'accepted'
  ) then
    return new;
  end if;


  select tr.trip_end_date
  into v_trip_end_date
  from public.transport_requests tr
  where tr.id = new.transport_request_id;


  if not found then
    raise exception
      'Transport request does not exist';
  end if;


  if not public.vehicle_is_compliant_for_trip(
    new.vehicle_id,
    v_trip_end_date
  ) then

    raise exception
      'Vehicle registration, insurance and revenue licence must be approved and valid for the complete trip';

  end if;


  return new;
end;
$$;


drop trigger if exists
validate_bid_vehicle_documents_trigger
on public.driver_bids;

create trigger
validate_bid_vehicle_documents_trigger
before insert or update
on public.driver_bids
for each row
execute procedure
public.validate_bid_vehicle_documents();



-- =========================================================
-- 7. ONLY ONE PRIMARY VEHICLE IMAGE
-- =========================================================

create unique index if not exists
one_primary_image_per_vehicle_idx
on public.vehicle_images(vehicle_id)
where is_primary = true;
