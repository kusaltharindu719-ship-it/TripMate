-- =========================================================
-- TripMate
-- Migration 016: Secure Driver Bid Workflows
-- =========================================================


-- =========================================================
-- 1. IMPROVE DRIVER REQUEST VISIBILITY
-- Expired open requests should not appear to new drivers.
-- Drivers who already bid may still view their history.
-- =========================================================

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
          (
            tr.status = 'open'
            and tr.bidding_deadline is not null
            and tr.bidding_deadline > now()
          )

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
-- 2. PROTECT TRANSPORT REQUEST WORKFLOW FIELDS
--
-- Prevent client from manually doing:
-- status = driver_selected
-- selected_bid_id = some bid
-- =========================================================

create or replace function public.protect_transport_request_workflow()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  workflow_action text;
begin

  workflow_action :=
    current_setting(
      'tripmate.transport_workflow',
      true
    );


  -- Identity cannot be changed
  if new.trip_id is distinct from old.trip_id then
    raise exception 'Transport request trip cannot be changed';
  end if;

  if new.traveler_id is distinct from old.traveler_id then
    raise exception 'Transport request owner cannot be changed';
  end if;


  -- Status changes only through secure workflow functions
  if new.status is distinct from old.status then

    if workflow_action is null
       or workflow_action not in (
         'open_request',
         'accept_bid',
         'cancel_request'
       ) then

      raise exception
        'Transport request status must be changed through a secure workflow';

    end if;

  end if;


  -- selected_bid_id can only be assigned by accept workflow
  if new.selected_bid_id is distinct from old.selected_bid_id then

    if workflow_action is distinct from 'accept_bid' then
      raise exception
        'Selected bid can only be changed through the bid acceptance workflow';
    end if;

  end if;


  -- After publication, route/request details are frozen.
  if old.status <> 'draft' then

    if
      new.pickup_location_snapshot
        is distinct from old.pickup_location_snapshot

      or new.pickup_latitude
        is distinct from old.pickup_latitude

      or new.pickup_longitude
        is distinct from old.pickup_longitude

      or new.trip_start_date
        is distinct from old.trip_start_date

      or new.trip_end_date
        is distinct from old.trip_end_date

      or new.passenger_count
        is distinct from old.passenger_count

      or new.luggage_count
        is distinct from old.luggage_count

      or new.special_requirements
        is distinct from old.special_requirements

      or new.route_distance_km
        is distinct from old.route_distance_km

      or new.estimated_duration_minutes
        is distinct from old.estimated_duration_minutes

      or new.currency
        is distinct from old.currency

      or new.bidding_deadline
        is distinct from old.bidding_deadline

    then

      raise exception
        'Published transport request details cannot be modified';

    end if;

  end if;


  return new;
end;
$$;


drop trigger if exists
protect_transport_request_workflow_trigger
on public.transport_requests;

create trigger
protect_transport_request_workflow_trigger
before update
on public.transport_requests
for each row
execute procedure public.protect_transport_request_workflow();



-- =========================================================
-- 3. PROTECT BID STATUS
--
-- Driver may edit price/message/vehicle while pending,
-- but cannot manually mark own bid accepted.
-- =========================================================

create or replace function public.protect_driver_bid_workflow()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  workflow_action text;
begin

  workflow_action :=
    current_setting(
      'tripmate.transport_workflow',
      true
    );


  if new.transport_request_id
       is distinct from old.transport_request_id then
    raise exception
      'Bid transport request cannot be changed';
  end if;


  if new.driver_id
       is distinct from old.driver_id then
    raise exception
      'Bid driver cannot be changed';
  end if;


  -- Completed/non-pending bids cannot be edited
  if old.status <> 'pending' then
    raise exception
      'A completed bid cannot be modified';
  end if;


  if new.status is distinct from old.status then

    if workflow_action is null
       or workflow_action not in (
         'withdraw_bid',
         'accept_bid',
         'cancel_request'
       ) then

      raise exception
        'Bid status must be changed through a secure workflow';

    end if;

  end if;


  return new;
end;
$$;


drop trigger if exists
protect_driver_bid_workflow_trigger
on public.driver_bids;

create trigger
protect_driver_bid_workflow_trigger
before update
on public.driver_bids
for each row
execute procedure public.protect_driver_bid_workflow();



-- =========================================================
-- 4. PROTECT DRIVER-RELATED TRIP STATUS
-- =========================================================

create or replace function public.protect_driver_trip_status()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  workflow_action text;
begin

  if new.status is not distinct from old.status then
    return new;
  end if;


  workflow_action :=
    current_setting(
      'tripmate.transport_workflow',
      true
    );


  if
    new.status in (
      'requesting_driver',
      'driver_selected'
    )

    or old.status in (
      'requesting_driver',
      'driver_selected'
    )
  then

    if workflow_action is null
       or workflow_action not in (
         'open_request',
         'accept_bid',
         'cancel_request'
       ) then

      raise exception
        'Driver-related trip status must use the transport workflow';

    end if;

  end if;


  return new;
end;
$$;


drop trigger if exists
protect_driver_trip_status_trigger
on public.trips;

create trigger
protect_driver_trip_status_trigger
before update
on public.trips
for each row
execute procedure public.protect_driver_trip_status();



-- =========================================================
-- 5. OPEN TRANSPORT REQUEST
--
-- Snapshot is refreshed when request becomes public.
-- This avoids stale route data if traveler edited the trip
-- while request was still draft.
-- =========================================================

create or replace function public.open_transport_request(
  p_request_id bigint,
  p_route_distance_km numeric,
  p_estimated_duration_minutes integer,
  p_bidding_deadline timestamptz,
  p_luggage_count integer default 0
)
returns public.transport_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_record public.transport_requests%rowtype;
  trip_record public.trips%rowtype;
  result_record public.transport_requests%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  if p_route_distance_km is null
     or p_route_distance_km <= 0 then
    raise exception 'Valid route distance is required';
  end if;


  if p_estimated_duration_minutes is null
     or p_estimated_duration_minutes <= 0 then
    raise exception 'Valid route duration is required';
  end if;


  if p_luggage_count < 0 then
    raise exception 'Luggage count cannot be negative';
  end if;


  if p_bidding_deadline is null
     or p_bidding_deadline <= now() then
    raise exception 'Bidding deadline must be in the future';
  end if;


  select *
  into request_record
  from public.transport_requests
  where id = p_request_id
  for update;


  if not found then
    raise exception 'Transport request does not exist';
  end if;


  if request_record.traveler_id <> auth.uid() then
    raise exception 'You do not own this transport request';
  end if;


  if request_record.status <> 'draft' then
    raise exception 'Only draft transport requests can be opened';
  end if;


  select *
  into trip_record
  from public.trips
  where id = request_record.trip_id
  for update;


  if not found then
    raise exception 'Trip does not exist';
  end if;


  if trip_record.traveler_id <> auth.uid() then
    raise exception 'You do not own this trip';
  end if;


  if trip_record.status <> 'planning' then
    raise exception
      'Trip must be in planning status before requesting a driver';
  end if;


  if trip_record.start_date < current_date then
    raise exception 'Cannot request transport for a past trip';
  end if;


  if p_bidding_deadline::date > trip_record.start_date then
    raise exception
      'Bidding deadline cannot be after the trip start date';
  end if;


  if not exists (
    select 1
    from public.trip_destinations td
    where td.trip_id = trip_record.id
  ) then
    raise exception
      'Trip must contain at least one destination';
  end if;


  -- Allow protected workflow changes
  perform pg_catalog.set_config(
    'tripmate.transport_workflow',
    'open_request',
    true
  );


  -- Rebuild route snapshot using latest trip plan
  delete from public.transport_request_stops
  where transport_request_id = request_record.id;


  -- Refresh request snapshot
  update public.transport_requests
  set
    traveler_id =
      trip_record.traveler_id,

    pickup_location_snapshot =
      trip_record.start_location,

    pickup_latitude =
      trip_record.start_lat,

    pickup_longitude =
      trip_record.start_lng,

    trip_start_date =
      trip_record.start_date,

    trip_end_date =
      trip_record.end_date,

    passenger_count =
      trip_record.number_of_travelers,

    luggage_count =
      p_luggage_count,

    special_requirements =
      trip_record.special_requirements,

    currency =
      coalesce(
        trip_record.currency,
        'LKR'
      ),

    route_distance_km =
      p_route_distance_km,

    estimated_duration_minutes =
      p_estimated_duration_minutes,

    bidding_deadline =
      p_bidding_deadline,

    status =
      'open'

  where id = request_record.id

  returning *
  into result_record;


  -- Pickup stop
  insert into public.transport_request_stops (
    transport_request_id,
    stop_order,
    stop_type,
    location_name,
    latitude,
    longitude,
    planned_departure_date
  )
  values (
    request_record.id,
    0,
    'pickup',
    trip_record.start_location,
    trip_record.start_lat,
    trip_record.start_lng,
    trip_record.start_date
  );


  -- Destination stops
  insert into public.transport_request_stops (
    transport_request_id,
    stop_order,
    stop_type,
    location_name,
    latitude,
    longitude,
    planned_arrival_date,
    planned_departure_date
  )
  select
    request_record.id,
    td.visit_order,
    'destination',
    d.name,
    d.latitude,
    d.longitude,
    td.planned_arrival_date,
    td.planned_departure_date
  from public.trip_destinations td
  join public.destinations d
    on d.id = td.destination_id
  where td.trip_id = trip_record.id
  order by td.visit_order;


  update public.trips
  set status = 'requesting_driver'
  where id = trip_record.id;


  return result_record;
end;
$$;



-- =========================================================
-- 6. DRIVER WITHDRAWS OWN BID
-- =========================================================

create or replace function public.withdraw_driver_bid(
  p_bid_id bigint
)
returns public.driver_bids
language plpgsql
security definer
set search_path = ''
as $$
declare
  bid_record public.driver_bids%rowtype;
  result_record public.driver_bids%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  select *
  into bid_record
  from public.driver_bids
  where id = p_bid_id
  for update;


  if not found then
    raise exception 'Bid does not exist';
  end if;


  if bid_record.driver_id <> auth.uid() then
    raise exception 'You do not own this bid';
  end if;


  if bid_record.status <> 'pending' then
    raise exception 'Only pending bids can be withdrawn';
  end if;


  perform pg_catalog.set_config(
    'tripmate.transport_workflow',
    'withdraw_bid',
    true
  );


  update public.driver_bids
  set status = 'withdrawn'
  where id = p_bid_id
  returning *
  into result_record;


  return result_record;
end;
$$;



-- =========================================================
-- 7. TRAVELER CANCELS REQUEST
--
-- Allowed before driver selection.
-- Existing pending bids are rejected.
-- =========================================================

create or replace function public.cancel_transport_request(
  p_request_id bigint
)
returns public.transport_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_record public.transport_requests%rowtype;
  result_record public.transport_requests%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  select *
  into request_record
  from public.transport_requests
  where id = p_request_id
  for update;


  if not found then
    raise exception 'Transport request does not exist';
  end if;


  if request_record.traveler_id <> auth.uid() then
    raise exception 'You do not own this transport request';
  end if;


  if request_record.status not in (
    'draft',
    'open'
  ) then
    raise exception
      'This transport request can no longer be cancelled using this workflow';
  end if;


  perform pg_catalog.set_config(
    'tripmate.transport_workflow',
    'cancel_request',
    true
  );


  update public.driver_bids
  set status = 'rejected'
  where transport_request_id = request_record.id
    and status = 'pending';


  update public.transport_requests
  set status = 'cancelled'
  where id = request_record.id
  returning *
  into result_record;


  update public.trips
  set status = 'planning'
  where id = request_record.trip_id
    and status = 'requesting_driver';


  return result_record;
end;
$$;



-- =========================================================
-- 8. TRAVELER ACCEPTS DRIVER BID
--
-- Atomic workflow:
-- 1. Lock request
-- 2. Lock bid
-- 3. Recheck driver/vehicle validity
-- 4. Prevent overlapping accepted trips
-- 5. Accept selected bid
-- 6. Reject other pending bids
-- 7. Update request
-- 8. Update trip
-- =========================================================

create or replace function public.accept_driver_bid(
  p_request_id bigint,
  p_bid_id bigint
)
returns public.transport_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_record public.transport_requests%rowtype;
  bid_record public.driver_bids%rowtype;

  license_expiry date;

  vehicle_driver_id uuid;
  vehicle_passenger_capacity integer;
  vehicle_luggage_capacity integer;
  vehicle_active boolean;
  vehicle_verification_status text;

  driver_accepting boolean;

  result_record public.transport_requests%rowtype;
begin

  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;


  -- Lock transport request first
  select *
  into request_record
  from public.transport_requests
  where id = p_request_id
  for update;


  if not found then
    raise exception 'Transport request does not exist';
  end if;


  if request_record.traveler_id <> auth.uid() then
    raise exception 'You do not own this transport request';
  end if;


  if request_record.status <> 'open' then
    raise exception 'Transport request is not open';
  end if;


  if request_record.bidding_deadline is null
     or request_record.bidding_deadline <= now() then
    raise exception 'Bidding deadline has passed';
  end if;


  -- Lock selected bid
  select *
  into bid_record
  from public.driver_bids
  where id = p_bid_id
    and transport_request_id = p_request_id
  for update;


  if not found then
    raise exception
      'Bid does not belong to this transport request';
  end if;


  if bid_record.status <> 'pending' then
    raise exception 'Only a pending bid can be accepted';
  end if;


  if bid_record.expires_at is not null
     and bid_record.expires_at <= now() then
    raise exception 'Bid has expired';
  end if;


  -- Serialize acceptance for the same driver.
  -- Prevents two travelers accepting the same driver
  -- at the same moment.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      bid_record.driver_id::text,
      0
    )
  );


  -- Driver must still be approved
  if not public.is_provider_approved(
    bid_record.driver_id,
    'driver'
  ) then
    raise exception 'Driver is no longer approved';
  end if;


  select
    dp.is_accepting_requests,
    dl.expiry_date
  into
    driver_accepting,
    license_expiry
  from public.driver_profiles dp
  left join public.driver_licenses dl
    on dl.driver_id = dp.user_id
  where dp.user_id = bid_record.driver_id;


  if not found then
    raise exception 'Driver profile does not exist';
  end if;


  if driver_accepting is not true then
    raise exception
      'Driver is no longer accepting requests';
  end if;


  if license_expiry is null
     or license_expiry < request_record.trip_end_date then
    raise exception
      'Driver licence is not valid for the complete trip';
  end if;


  -- Vehicle validity is checked again at acceptance time
  select
    v.driver_id,
    v.passenger_capacity,
    v.luggage_capacity,
    v.is_active,
    vv.status
  into
    vehicle_driver_id,
    vehicle_passenger_capacity,
    vehicle_luggage_capacity,
    vehicle_active,
    vehicle_verification_status
  from public.vehicles v
  left join public.vehicle_verifications vv
    on vv.vehicle_id = v.id
  where v.id = bid_record.vehicle_id;


  if not found then
    raise exception 'Vehicle does not exist';
  end if;


  if vehicle_driver_id <> bid_record.driver_id then
    raise exception
      'Selected vehicle does not belong to the driver';
  end if;


  if vehicle_active is not true then
    raise exception 'Vehicle is inactive';
  end if;


  if vehicle_verification_status
       is distinct from 'approved' then
    raise exception 'Vehicle is no longer approved';
  end if;


  if vehicle_passenger_capacity
       < request_record.passenger_count then
    raise exception
      'Vehicle no longer has sufficient passenger capacity';
  end if;


  if vehicle_luggage_capacity
       < request_record.luggage_count then
    raise exception
      'Vehicle does not have sufficient luggage capacity';
  end if;


  -- Driver availability re-check
  if exists (
    select 1
    from public.driver_availability da
    where da.driver_id = bid_record.driver_id
      and da.availability_date
          between request_record.trip_start_date
          and request_record.trip_end_date
      and da.status in (
        'unavailable',
        'booked'
      )
  ) then
    raise exception
      'Driver is unavailable during these trip dates';
  end if;


  -- Prevent driver double-booking across accepted trips
  if exists (
    select 1
    from public.driver_bids existing_bid
    join public.transport_requests existing_request
      on existing_request.id =
         existing_bid.transport_request_id
    where existing_bid.driver_id =
          bid_record.driver_id

      and existing_bid.status = 'accepted'

      and existing_bid.id <> bid_record.id

      and existing_request.status =
          'driver_selected'

      and existing_request.trip_start_date
          <= request_record.trip_end_date

      and request_record.trip_start_date
          <= existing_request.trip_end_date
  ) then

    raise exception
      'Driver already has another selected trip during these dates';

  end if;


  perform pg_catalog.set_config(
    'tripmate.transport_workflow',
    'accept_bid',
    true
  );


  -- Accept selected bid
  update public.driver_bids
  set status = 'accepted'
  where id = bid_record.id;


  -- Reject remaining pending bids
  update public.driver_bids
  set status = 'rejected'
  where transport_request_id = request_record.id
    and id <> bid_record.id
    and status = 'pending';


  -- Finalize request
  update public.transport_requests
  set
    selected_bid_id = bid_record.id,
    status = 'driver_selected'
  where id = request_record.id
  returning *
  into result_record;


  -- Synchronize trip
  update public.trips
  set status = 'driver_selected'
  where id = request_record.trip_id;


  return result_record;
end;
$$;



-- =========================================================
-- 9. SECURITY DEFINER FUNCTION EXECUTION PRIVILEGES
-- =========================================================

revoke all
on function public.open_transport_request(
  bigint,
  numeric,
  integer,
  timestamptz,
  integer
)
from public, anon;


grant execute
on function public.open_transport_request(
  bigint,
  numeric,
  integer,
  timestamptz,
  integer
)
to authenticated;


revoke all
on function public.withdraw_driver_bid(bigint)
from public, anon;


grant execute
on function public.withdraw_driver_bid(bigint)
to authenticated;


revoke all
on function public.cancel_transport_request(bigint)
from public, anon;


grant execute
on function public.cancel_transport_request(bigint)
to authenticated;


revoke all
on function public.accept_driver_bid(
  bigint,
  bigint
)
from public, anon;


grant execute
on function public.accept_driver_bid(
  bigint,
  bigint
)
to authenticated;
