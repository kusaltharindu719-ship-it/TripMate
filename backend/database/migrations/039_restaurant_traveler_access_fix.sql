-- Restaurant traveler access fix
-- Ensures authenticated travelers can read active, approved restaurants.

grant select on table public.restaurants to authenticated;

alter table public.restaurants enable row level security;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'restaurants'
          and policyname = 'Authenticated users can view active approved restaurants'
    ) then
        create policy "Authenticated users can view active approved restaurants"
        on public.restaurants
        for select
        to authenticated
        using (
            is_active = true
            and public.is_provider_approved(owner_id, 'restaurant')
        );
    end if;
end
$$;

-- Food item traveler access fix

grant select on table public.food_items to authenticated;

alter table public.food_items enable row level security;

do $$
begin
    if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'food_items'
          and policyname = 'Authenticated users can view available food items'
    ) then
        create policy "Authenticated users can view available food items"
        on public.food_items
        for select
        to authenticated
        using (
            is_available = true
            and exists (
                select 1
                from public.restaurants r
                where r.id = food_items.restaurant_id
                  and r.is_active = true
                  and public.is_provider_approved(r.owner_id, 'restaurant')
            )
        );
    end if;
end
$$;
