-- =====================================================================
-- WGF CONNECT – Migrazione 0011: inviti "Ambasciatore WGF" e classifica fan
-- - ogni profilo ha un codice invito personale
-- - un nuovo iscritto può usare UN codice (solo stessa fascia d'età)
-- - classifiche quiz / inviti visibili solo dentro la propria fascia
-- =====================================================================
alter table public.profiles
  add column if not exists invite_code text unique,
  add column if not exists invited_by uuid references public.profiles(id) on delete set null,
  add column if not exists invite_count int not null default 0 check (invite_count >= 0);

create or replace function app_private.new_invite_code()
returns text language plpgsql volatile set search_path = '' as $$
declare v text;
begin
  loop
    -- niente caratteri ambigui (0/O, 1/I)
    v := 'WGF-' || array_to_string(array(
           select substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1)
           from generate_series(1, 6)), '');
    exit when not exists (select 1 from public.profiles where invite_code = v);
  end loop;
  return v;
end $$;

update public.profiles set invite_code = app_private.new_invite_code() where invite_code is null;

create or replace function app_private.set_invite_code()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.invite_code is null then new.invite_code := app_private.new_invite_code(); end if;
  return new;
end $$;
drop trigger if exists profiles_invite_code on public.profiles;
create trigger profiles_invite_code before insert on public.profiles
  for each row execute function app_private.set_invite_code();

-- campi inviti protetti come gli altri
create or replace function app_private.protect_profile_columns()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.id <> old.id or new.age_band <> old.age_band
       or new.role <> old.role or new.status <> old.status
       or new.created_at <> old.created_at
       or new.wgf_quiz_score <> old.wgf_quiz_score
       or new.invite_code is distinct from old.invite_code
       or new.invited_by is distinct from old.invited_by
       or new.invite_count <> old.invite_count then
      raise exception 'forbidden: campo protetto' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

create or replace function app_private.ambassador_level(p_count int)
returns text language sql immutable set search_path = '' as $$
  select case when p_count >= 50 then 'Leggenda WGF'
              when p_count >= 20 then 'Ambasciatore d''oro'
              when p_count >= 5  then 'Ambasciatore'
              when p_count >= 1  then 'Reclutatore'
              else '' end;
$$;

create or replace function public.my_invite_info()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'code', p.invite_code,
    'count', p.invite_count,
    'level', app_private.ambassador_level(p.invite_count),
    'invited_by', (select i.username from public.profiles i where i.id = p.invited_by),
    'can_redeem', p.invited_by is null and p.created_at > now() - interval '30 days'
  )
  from public.profiles p where p.id = auth.uid();
$$;
revoke execute on function public.my_invite_info() from public, anon;
grant execute on function public.my_invite_info() to authenticated;

create or replace function public.redeem_invite(p_code text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_me public.profiles;
  v_inviter public.profiles;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  perform app_private.enforce_rate_limit('redeem_invite', 10, interval '1 hour');
  select * into v_me from public.profiles where id = v_uid;
  if v_me.invited_by is not null then
    raise exception 'invite_already_used' using errcode = 'P0409';
  end if;
  if v_me.created_at < now() - interval '30 days' then
    raise exception 'invite_too_late' using errcode = 'P0409';
  end if;
  select * into v_inviter from public.profiles where invite_code = upper(trim(p_code));
  -- stesso messaggio per codice inesistente, proprio, o di un'altra fascia d'età:
  -- non si rivela nulla su chi c'è dietro il codice
  if v_inviter.id is null or v_inviter.id = v_uid
     or v_inviter.invited_by = v_uid
     or not app_private.can_interact(v_uid, v_inviter.id) then
    raise exception 'invite_not_valid' using errcode = 'P0404';
  end if;
  update public.profiles set invited_by = v_inviter.id where id = v_uid;
  update public.profiles set invite_count = invite_count + 1 where id = v_inviter.id;
  perform app_private.notify(v_inviter.id, 'community',
    jsonb_build_object('type', 'invite', 'username', v_me.username,
                       'count', v_inviter.invite_count + 1));
  return v_inviter.username;
end $$;
revoke execute on function public.redeem_invite(text) from public, anon;
grant execute on function public.redeem_invite(text) to authenticated;

-- Classifica: solo utenti attivi della MIA fascia d'età, esclusi i bloccati
create or replace function public.fan_leaderboard(p_kind text default 'quiz', p_limit int default 50)
returns table (rank int, user_id uuid, username text, display_name text, avatar_path text,
               score int, badge text, is_me boolean)
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_kind not in ('quiz', 'invites') then
    raise exception 'invalid_argument' using errcode = 'P0400';
  end if;
  return query
  with pool as (
    select p.*, case when p_kind = 'quiz' then p.wgf_quiz_score::int else p.invite_count end as s
    from public.profiles p
    where (p.id = v_uid or app_private.can_interact(v_uid, p.id))
      and p.role not in ('admin', 'creator')
  ), ranked as (
    select (rank() over (order by s desc, created_at))::int as r, * from pool where s > 0 or id = v_uid
  )
  select r.r, r.id, r.username, r.display_name, r.avatar_path, r.s,
         case when p_kind = 'invites' then app_private.ambassador_level(r.s) else null end,
         r.id = v_uid
  from ranked r
  where r.r <= least(greatest(p_limit, 1), 100) or r.id = v_uid
  order by r.r;
end $$;
revoke execute on function public.fan_leaderboard(text, int) from public, anon;
grant execute on function public.fan_leaderboard(text, int) to authenticated;

-- Il badge ambasciatore compare sul profilo pubblico
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
    'ambassador', app_private.ambassador_level(p.invite_count),
    'role', case when p.role in ('admin','creator') then 'founder' else null end
  );
$$;
