-- =========================================================
-- TripMate
-- Migration 033: Supabase Storage Security
-- =========================================================


-- =========================================================
-- 1. PUBLIC MEDIA BUCKET
--
-- Used for:
--   restaurant images
--   accommodation / room images
--   approved vehicle images
--   attraction / activity images if needed
--
-- No SVG files are allowed.
-- =========================================================

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'tripmate-public-media',
  'tripmate-public-media',
  true,
  10485760, -- 10 MB
  array[
    'image/jpeg',
    'image/png',
    'image/webp'
  ]
)
on conflict (id)
do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;



-- =========================================================
-- 2. PRIVATE DOCUMENT BUCKET
--
-- Used for:
--   driver identity documents
--   driving licence files
--   vehicle registration
--   insurance
--   revenue licence
--   future provider verification documents
-- =========================================================

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'tripmate-private-documents',
  'tripmate-private-documents',
  false,
  10485760, -- 10 MB
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ]
)
on conflict (id)
do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;



-- =========================================================
-- 3. PUBLIC MEDIA - READ
--
-- Public discovery images may be viewed by everyone.
-- =========================================================

drop policy if exists
"TripMate public media read"
on storage.objects;

create policy
"TripMate public media read"
on storage.objects
for select
to public
using (
  bucket_id = 'tripmate-public-media'
);



-- =========================================================
-- 4. PUBLIC MEDIA - INSERT
--
-- Required path format:
--
--   {user_uuid}/restaurants/file.webp
--   {user_uuid}/accommodations/file.webp
--   {user_uuid}/vehicles/file.webp
--   {admin_uuid}/attractions/file.webp
--   {admin_uuid}/activities/file.webp
--
-- Provider can upload only inside own UUID folder.
-- =========================================================

drop policy if exists
"TripMate public media insert"
on storage.objects;

create policy
"TripMate public media insert"
on storage.objects
for insert
to authenticated
with check (

  bucket_id = 'tripmate-public-media'

  and

  (
    public.is_admin_user()

    or

    (
      (storage.foldername(name))[1] = auth.uid()::text

      and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and (
            (
              p.role = 'restaurant_owner'
              and (storage.foldername(name))[2] = 'restaurants'
            )

            or

            (
              p.role = 'accommodation_owner'
              and (storage.foldername(name))[2] = 'accommodations'
            )

            or

            (
              p.role = 'driver'
              and (storage.foldername(name))[2] = 'vehicles'
            )
          )
      )
    )
  )
);



-- =========================================================
-- 5. PUBLIC MEDIA - UPDATE
-- =========================================================

drop policy if exists
"TripMate public media update"
on storage.objects;

create policy
"TripMate public media update"
on storage.objects
for update
to authenticated
using (

  bucket_id = 'tripmate-public-media'

  and (
    public.is_admin_user()
    or (storage.foldername(name))[1] = auth.uid()::text
  )

)
with check (

  bucket_id = 'tripmate-public-media'

  and (
    public.is_admin_user()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);



-- =========================================================
-- 6. PUBLIC MEDIA - DELETE
-- =========================================================

drop policy if exists
"TripMate public media delete"
on storage.objects;

create policy
"TripMate public media delete"
on storage.objects
for delete
to authenticated
using (

  bucket_id = 'tripmate-public-media'

  and (
    public.is_admin_user()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);



-- =========================================================
-- 7. PRIVATE DOCUMENTS - SELECT
--
-- Owner:
--   can access own folder only
--
-- Admin:
--   can access all verification documents
-- =========================================================

drop policy if exists
"TripMate private documents read"
on storage.objects;

create policy
"TripMate private documents read"
on storage.objects
for select
to authenticated
using (

  bucket_id = 'tripmate-private-documents'

  and (
    public.is_admin_user()

    or

    (storage.foldername(name))[1] = auth.uid()::text
  )
);



-- =========================================================
-- 8. PRIVATE DOCUMENTS - INSERT
--
-- Example paths:
--
-- {driver_uuid}/driver/nic/file.pdf
--
-- {driver_uuid}/driver/license/file.jpg
--
-- {driver_uuid}/vehicles/{vehicle_id}/insurance/file.pdf
--
-- {provider_uuid}/verification/file.pdf
-- =========================================================

drop policy if exists
"TripMate private documents insert"
on storage.objects;

create policy
"TripMate private documents insert"
on storage.objects
for insert
to authenticated
with check (

  bucket_id = 'tripmate-private-documents'

  and

  (
    public.is_admin_user()

    or

    (
      (storage.foldername(name))[1] = auth.uid()::text

      and exists (
        select 1
        from public.profiles p
        where p.id = auth.uid()
          and p.role in (
            'restaurant_owner',
            'accommodation_owner',
            'driver'
          )
      )
    )
  )
);



-- =========================================================
-- 9. PRIVATE DOCUMENTS - UPDATE
-- =========================================================

drop policy if exists
"TripMate private documents update"
on storage.objects;

create policy
"TripMate private documents update"
on storage.objects
for update
to authenticated
using (

  bucket_id = 'tripmate-private-documents'

  and (
    public.is_admin_user()
    or (storage.foldername(name))[1] = auth.uid()::text
  )

)
with check (

  bucket_id = 'tripmate-private-documents'

  and (
    public.is_admin_user()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);



-- =========================================================
-- 10. PRIVATE DOCUMENTS - DELETE
-- =========================================================

drop policy if exists
"TripMate private documents delete"
on storage.objects;

create policy
"TripMate private documents delete"
on storage.objects
for delete
to authenticated
using (

  bucket_id = 'tripmate-private-documents'

  and (
    public.is_admin_user()
    or (storage.foldername(name))[1] = auth.uid()::text
  )
);
