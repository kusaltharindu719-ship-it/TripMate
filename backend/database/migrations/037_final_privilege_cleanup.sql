-- =========================================================
-- TripMate
-- Migration 037: Final Privilege Cleanup
-- =========================================================


-- =========================================================
-- 1. CLEAN ALL CURRENT PUBLIC TABLES
-- =========================================================

do $$
declare
  r record;
begin

  for r in

    select
      n.nspname as schema_name,
      c.relname as table_name

    from pg_class c

    join pg_namespace n
      on n.oid = c.relnamespace

    where n.nspname = 'public'

      and c.relkind in (
        'r', -- ordinary table
        'p'  -- partitioned table
      )

  loop

    -- Anonymous browser users must never write directly.
    execute format(
      'revoke insert, update, delete, truncate, trigger, references
       on table %I.%I
       from anon',
      r.schema_name,
      r.table_name
    );


    -- Logged-in users may have intentional CRUD permissions,
    -- but never these dangerous schema/table capabilities.
    execute format(
      'revoke truncate, trigger, references
       on table %I.%I
       from authenticated',
      r.schema_name,
      r.table_name
    );

  end loop;

end
$$;



-- =========================================================
-- 2. FIX DEFAULT PRIVILEGES FOR FUTURE TABLES
--
-- Prevents new migrations from reintroducing the same issue.
-- =========================================================

alter default privileges
in schema public

revoke
  truncate,
  trigger,
  references
on tables
from anon;


alter default privileges
in schema public

revoke
  truncate,
  trigger,
  references
on tables
from authenticated;


alter default privileges
in schema public

revoke
  insert,
  update,
  delete
on tables
from anon;



-- =========================================================
-- 3. FUTURE SEQUENCE HARDENING
--
-- Anonymous users do not need direct sequence access.
-- =========================================================

alter default privileges
in schema public

revoke all
on sequences
from anon;

-- =========================================================
-- FINAL PATCH: HARDEN RATING SUMMARY VIEWS
-- =========================================================

revoke all
on table
  public.accommodation_rating_summary,
  public.restaurant_rating_summary,
  public.attraction_rating_summary,
  public.activity_rating_summary,
  public.driver_rating_summary
from anon, authenticated;


grant select
on table
  public.accommodation_rating_summary,
  public.restaurant_rating_summary,
  public.attraction_rating_summary,
  public.activity_rating_summary,
  public.driver_rating_summary
to anon, authenticated;
