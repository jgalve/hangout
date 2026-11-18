-- The position range and per-profile uniqueness constraint already cap pins at five.
-- Avoid querying profile_places from its own RLS policy, which causes recursion.
drop policy if exists "profile places owner insert" on public.profile_places;

create policy "profile places owner insert"
on public.profile_places
for insert
to authenticated
with check ((select auth.uid()) = profile_id);
