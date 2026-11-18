create function public.discover_hangout_rankings()
returns table(category text, ranking_position integer, place_id uuid, place_name text, user_count bigint)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  with active_pins as (
    select pp.place_id, pp.profile_id, pp.created_at, place.name as place_name
    from public.profile_places pp
    join public.profiles profile
      on profile.id = pp.profile_id
      and profile.account_active
    join public.places place on place.id = pp.place_id
    where public.is_account_active()
  ),
  popular_counts as (
    select
      place_id,
      place_name,
      count(distinct profile_id) as user_count
    from active_pins
    group by place_id, place_name
  ),
  popular as (
    select
      'popular'::text as category,
      row_number() over (order by user_count desc, place_name, place_id)::integer as ranking_position,
      place_id,
      place_name,
      user_count
    from popular_counts
    order by user_count desc, place_name, place_id
    limit 5
  ),
  trending_counts as (
    select
      place_id,
      place_name,
      count(distinct profile_id) as user_count
    from active_pins
    where created_at >= now() - interval '7 days'
      and created_at <= now()
    group by place_id, place_name
  ),
  trending as (
    select
      'trending'::text as category,
      row_number() over (order by user_count desc, place_name, place_id)::integer as ranking_position,
      place_id,
      place_name,
      user_count
    from trending_counts
    order by user_count desc, place_name, place_id
    limit 5
  )
  select * from popular
  union all
  select * from trending;
$$;

alter function public.discover_hangout_rankings() owner to postgres;
alter function public.discover_hangout_rankings() set search_path = public, pg_temp;
revoke all on function public.discover_hangout_rankings() from public, anon;
grant execute on function public.discover_hangout_rankings() to authenticated;
