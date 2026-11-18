alter table public.profiles
  add column facebook_url text,
  add column instagram_url text,
  add column tiktok_url text,
  add constraint profiles_facebook_url_valid check (
    facebook_url is null
    or (
      facebook_url = btrim(facebook_url)
      and char_length(facebook_url) <= 2048
      and facebook_url ~* '^https://(www[.]|m[.])?facebook[.]com/[^[:space:]/][^[:space:]]*$'
    )
  ),
  add constraint profiles_instagram_url_valid check (
    instagram_url is null
    or (
      instagram_url = btrim(instagram_url)
      and char_length(instagram_url) <= 2048
      and instagram_url ~* '^https://(www[.])?instagram[.]com/[^[:space:]/][^[:space:]]*$'
    )
  ),
  add constraint profiles_tiktok_url_valid check (
    tiktok_url is null
    or (
      tiktok_url = btrim(tiktok_url)
      and char_length(tiktok_url) <= 2048
      and tiktok_url ~* '^https://(www[.]|m[.])?tiktok[.]com/[^[:space:]/][^[:space:]]*$'
    )
  );

create function public.get_match_social_links(match_uuid uuid)
returns table(facebook_url text, instagram_url text, tiktok_url text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select other_profile.facebook_url, other_profile.instagram_url, other_profile.tiktok_url
  from public.matches matched
  join public.profiles other_profile
    on other_profile.id = case
      when matched.user_low = auth.uid() then matched.user_high
      else matched.user_low
    end
  where matched.id = match_uuid
    and auth.uid() in (matched.user_low, matched.user_high)
    and public.is_account_active()
    and other_profile.account_active
    and not public.is_blocked(matched.user_low, matched.user_high);
$$;

alter function public.get_match_social_links(uuid) owner to postgres;
alter function public.get_match_social_links(uuid) set search_path = public, pg_temp;
revoke all on function public.get_match_social_links(uuid) from public, anon;
grant execute on function public.get_match_social_links(uuid) to authenticated;
