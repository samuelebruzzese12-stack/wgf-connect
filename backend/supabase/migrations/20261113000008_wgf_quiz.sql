-- =====================================================================
-- WGF CONNECT – Migrazione 0008: quiz "Quanto conosci i WGF?"
-- Punteggio migliore salvato sul profilo e mostrato come badge.
-- =====================================================================
alter table public.profiles
  add column if not exists wgf_quiz_score smallint not null default 0
  check (wgf_quiz_score between 0 and 100);

-- Il client non può impostare il punteggio direttamente: passa da submit_wgf_quiz()
create or replace function app_private.protect_profile_columns()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.id <> old.id or new.age_band <> old.age_band
       or new.role <> old.role or new.status <> old.status
       or new.created_at <> old.created_at
       or new.wgf_quiz_score <> old.wgf_quiz_score then
      raise exception 'forbidden: campo protetto' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

create or replace function public.submit_wgf_quiz(p_correct int, p_total int)
returns int language plpgsql security definer set search_path = '' as $$
declare v_score int;
begin
  if auth.uid() is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_total < 5 or p_total > 50 or p_correct < 0 or p_correct > p_total then
    raise exception 'invalid_argument' using errcode = 'P0400';
  end if;
  perform app_private.enforce_rate_limit('wgf_quiz', 20, interval '1 hour');
  v_score := round(100.0 * p_correct / p_total);
  update public.profiles set wgf_quiz_score = greatest(wgf_quiz_score, v_score) where id = auth.uid();
  return (select wgf_quiz_score from public.profiles where id = auth.uid());
end $$;
revoke execute on function public.submit_wgf_quiz(int, int) from public, anon;
grant execute on function public.submit_wgf_quiz(int, int) to authenticated;

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
    'role', case when p.role in ('admin','creator') then 'founder' else null end
  );
$$;
