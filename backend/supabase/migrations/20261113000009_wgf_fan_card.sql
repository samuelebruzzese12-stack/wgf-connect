-- =====================================================================
-- WGF CONNECT – Migrazione 0009: Tessera Fan WGF
-- Numero di iscrizione, "fan dal", serie preferita.
-- =====================================================================
alter table public.profiles
  add column if not exists wgf_fan_since smallint check (wgf_fan_since between 2012 and 2100),
  add column if not exists wgf_favorite_series text check (char_length(wgf_favorite_series) <= 60);

-- Numero tessera: ordine di iscrizione (1 = primo iscritto)
create or replace function public.my_member_number()
returns int language sql stable security definer set search_path = '' as $$
  select count(*)::int from public.profiles p
  where p.created_at <= (select created_at from public.profiles where id = auth.uid());
$$;
revoke execute on function public.my_member_number() from public, anon;
grant execute on function public.my_member_number() to authenticated;

create or replace function app_private.profile_card(p public.profiles)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id, 'username', p.username, 'display_name', p.display_name,
    'bio', p.bio, 'avatar_path', p.avatar_path, 'country', p.country, 'city', p.city,
    'interests', p.interests, 'favorite_games', p.favorite_games,
    'favorite_wgf_characters', p.favorite_wgf_characters,
    'friendship_preferences', p.friendship_preferences,
    'age', case when p.show_age then
             (select app_private.age_from_birth(pp.birth_date) from public.profiles_private pp where pp.user_id = p.id)
           end,
    'verified_adult', app_private.is_verified_adult(p.id),
    'wgf_quiz_score', p.wgf_quiz_score,
    'wgf_fan_since', p.wgf_fan_since,
    'wgf_favorite_series', p.wgf_favorite_series,
    'role', case when p.role in ('admin','creator') then 'founder' else null end
  );
$$;
