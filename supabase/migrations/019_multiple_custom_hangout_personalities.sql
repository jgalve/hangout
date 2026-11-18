create function public.valid_custom_hangout_personalities(value text)
returns boolean
language sql
immutable
strict
set search_path = pg_catalog, public, pg_temp
as $$
  select value = btrim(value)
    and char_length(value) <= 94
    and value ~ '^[^[:space:],]{1,30}([[:space:]]*,[[:space:]]*[^[:space:],]{1,30}){0,2}$'
    and not (
      regexp_split_to_array(lower(value), '[[:space:]]*,[[:space:]]*')
      && array[
        'coffee',
        'explore',
        'foodie',
        'music',
        'culture',
        'markets',
        'parks',
        'fitness',
        'games',
        'nightlife',
        'nature',
        'community'
      ]::text[]
    )
    and cardinality(regexp_split_to_array(lower(value), '[[:space:]]*,[[:space:]]*')) =
      cardinality(array(
        select distinct personality
        from unnest(regexp_split_to_array(lower(value), '[[:space:]]*,[[:space:]]*')) as entries(personality)
      ));
$$;

revoke all on function public.valid_custom_hangout_personalities(text) from public, anon;
grant execute on function public.valid_custom_hangout_personalities(text) to authenticated, service_role;

alter table public.profiles
  drop constraint profiles_custom_hangout_personality_valid,
  add constraint profiles_custom_hangout_personality_valid check (
    custom_hangout_personality is null
    or public.valid_custom_hangout_personalities(custom_hangout_personality)
  );
