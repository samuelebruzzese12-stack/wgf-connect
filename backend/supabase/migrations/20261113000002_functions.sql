-- =====================================================================
-- WGF CONNECT – Migrazione 0002: funzioni, trigger, RPC
-- Le funzioni di supporto stanno nello schema app_private, che NON è
-- esposto da PostgREST. Le RPC pubbliche sono in public e sono
-- eseguibili solo dal ruolo "authenticated".
-- =====================================================================

create schema if not exists app_private;
grant usage on schema app_private to authenticated, service_role;

-- ---------------------------------------------------------------------
-- Helper di base
-- ---------------------------------------------------------------------
create or replace function app_private.cfg_bool(p_key text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select (value)::text::boolean from public.app_config where key = p_key), false);
$$;

create or replace function app_private.cfg_int(p_key text)
returns int language sql stable security definer set search_path = '' as $$
  select (select (value)::text::int from public.app_config where key = p_key);
$$;

create or replace function app_private.current_band()
returns text language sql stable security definer set search_path = '' as $$
  select age_band from public.profiles where id = auth.uid() and status = 'active';
$$;

create or replace function app_private.current_role_name()
returns text language sql stable security definer set search_path = '' as $$
  select role from public.profiles where id = auth.uid() and status = 'active';
$$;

create or replace function app_private.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.current_role_name() in ('admin','moderator'), false);
$$;

create or replace function app_private.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.current_role_name() = 'admin', false);
$$;

create or replace function app_private.is_creator_or_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(app_private.current_role_name() in ('creator','admin'), false);
$$;

create or replace function app_private.is_blocked_between(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.blocked_users
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  );
$$;

-- D5: punto unico di controllo per qualsiasi interazione tra due utenti
create or replace function app_private.can_interact(a uuid, b uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select a is not null and b is not null and a <> b
     and exists (
       select 1 from public.profiles pa join public.profiles pb on pb.id = b
       where pa.id = a
         and pa.status = 'active' and pb.status = 'active'
         and pa.age_band = pb.age_band
     )
     and not app_private.is_blocked_between(a, b);
$$;

create or replace function app_private.is_verified_adult(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = p_user and p.age_band = 'adult' and p.status = 'active'
      and exists (select 1 from public.age_verifications v
                  where v.user_id = p.id and v.status = 'verified')
  );
$$;

create or replace function app_private.is_conversation_member(p_conv uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.conversation_participants
                 where conversation_id = p_conv and user_id = p_user);
$$;

create or replace function app_private.age_from_birth(p_birth date)
returns int language sql immutable set search_path = '' as $$
  select extract(year from age(current_date, p_birth))::int;
$$;

-- Rate limiting: max p_max azioni nella finestra p_window
create or replace function app_private.enforce_rate_limit(p_action text, p_max int, p_window interval)
returns void language plpgsql security definer set search_path = '' as $$
declare v_count int;
begin
  if auth.uid() is null then return; end if;  -- service role / job interni
  delete from public.rate_limit_events
   where user_id = auth.uid() and action = p_action and created_at < now() - interval '1 day';
  select count(*) into v_count from public.rate_limit_events
   where user_id = auth.uid() and action = p_action and created_at > now() - p_window;
  if v_count >= p_max then
    raise exception 'rate_limited: troppe azioni (%), riprova più tardi', p_action
      using errcode = 'P0429';
  end if;
  insert into public.rate_limit_events (user_id, action) values (auth.uid(), p_action);
end $$;

-- Filtro antispam di base (gratuito, lato database)
create or replace function app_private.enforce_spam_filter(p_text text)
returns void language plpgsql immutable set search_path = '' as $$
declare v_links int;
begin
  if p_text is null then return; end if;
  v_links := (select count(*) from regexp_matches(p_text, '(https?://|www\.)', 'gi'));
  if v_links > 3 then
    raise exception 'spam_detected: troppi link' using errcode = 'P0422';
  end if;
  if p_text ~ '(.)\1{29,}' then
    raise exception 'spam_detected: testo ripetitivo' using errcode = 'P0422';
  end if;
end $$;

create or replace function app_private.notify(p_user uuid, p_kind text, p_payload jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare v_ok boolean := true;
begin
  select case p_kind
           when 'match'   then notify_matches
           when 'message' then notify_messages
           when 'like'    then notify_likes
           when 'comment' then notify_comments
           when 'reply'   then notify_comments
           when 'event'   then notify_events
           when 'community' then notify_community
           when 'creator' then notify_creator
           else true end
    into v_ok
    from public.user_preferences where user_id = p_user;
  if coalesce(v_ok, true) then
    insert into public.notifications (user_id, kind, payload) values (p_user, p_kind, p_payload);
  end if;
end $$;

-- Scheda profilo pubblica: MAI data di nascita, mai posizione precisa
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
    'verified_adult', app_private.is_verified_adult(p.id)
  );
$$;

-- ---------------------------------------------------------------------
-- Trigger generici
-- ---------------------------------------------------------------------
create or replace function app_private.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at := now(); return new; end $$;

create trigger profiles_updated_at before update on public.profiles
  for each row execute function app_private.set_updated_at();
create trigger posts_updated_at before update on public.posts
  for each row execute function app_private.set_updated_at();
create trigger creator_updates_updated_at before update on public.creator_updates
  for each row execute function app_private.set_updated_at();
create trigger user_preferences_updated_at before update on public.user_preferences
  for each row execute function app_private.set_updated_at();

-- D3: il client non può modificare fascia d'età, ruolo, stato, id
create or replace function app_private.protect_profile_columns()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.id <> old.id or new.age_band <> old.age_band
       or new.role <> old.role or new.status <> old.status
       or new.created_at <> old.created_at then
      raise exception 'forbidden: campo protetto' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger profiles_protect before update on public.profiles
  for each row execute function app_private.protect_profile_columns();

-- Contenuti: la fascia del contenuto è SEMPRE quella dell'autore
create or replace function app_private.before_insert_content()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_band text; v_text text;
begin
  if auth.uid() is not null then
    select age_band into v_band from public.profiles where id = new.author_id and status = 'active';
    if v_band is null then raise exception 'forbidden: utente non attivo' using errcode = '42501'; end if;
    new.audience_band := v_band;
    new.is_hidden := false;
  end if;
  v_text := new.body;
  perform app_private.enforce_spam_filter(v_text);
  perform app_private.enforce_rate_limit(tg_table_name, 10, interval '1 minute');
  return new;
end $$;
create trigger posts_before_insert before insert on public.posts
  for each row execute function app_private.before_insert_content();
create trigger support_posts_before_insert before insert on public.support_posts
  for each row execute function app_private.before_insert_content();

-- Commenti e risposte di supporto: niente audience_band propria, ma spam/rate limit + notifiche
create or replace function app_private.before_insert_reply()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null then new.is_hidden := false; end if;
  perform app_private.enforce_spam_filter(new.body);
  perform app_private.enforce_rate_limit(tg_table_name, 20, interval '1 minute');
  return new;
end $$;
create trigger comments_before_insert before insert on public.comments
  for each row execute function app_private.before_insert_reply();
create trigger support_replies_before_insert before insert on public.support_replies
  for each row execute function app_private.before_insert_reply();

create or replace function app_private.after_insert_comment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_post_author uuid; v_parent_author uuid;
begin
  select author_id into v_post_author from public.posts where id = new.post_id;
  if v_post_author is not null and v_post_author <> new.author_id then
    perform app_private.notify(v_post_author, 'comment',
      jsonb_build_object('post_id', new.post_id, 'comment_id', new.id));
  end if;
  if new.parent_id is not null then
    select author_id into v_parent_author from public.comments where id = new.parent_id;
    if v_parent_author is not null and v_parent_author <> new.author_id
       and v_parent_author is distinct from v_post_author then
      perform app_private.notify(v_parent_author, 'reply',
        jsonb_build_object('post_id', new.post_id, 'comment_id', new.id));
    end if;
  end if;
  return null;
end $$;
create trigger comments_after_insert after insert on public.comments
  for each row execute function app_private.after_insert_comment();

-- Eventi: fascia = organizzatore; gli utenti normali creano solo eventi "pending_review"
create or replace function app_private.before_insert_event()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_band text;
begin
  if auth.uid() is not null then
    select age_band into v_band from public.profiles where id = new.organizer_id and status = 'active';
    if v_band is null then raise exception 'forbidden' using errcode = '42501'; end if;
    new.audience_band := v_band;
    if not app_private.is_staff() then new.status := 'pending_review'; end if;
  end if;
  perform app_private.enforce_spam_filter(new.description);
  perform app_private.enforce_rate_limit('events', 5, interval '1 day');
  return new;
end $$;
create trigger events_before_insert before insert on public.events
  for each row execute function app_private.before_insert_event();

create or replace function app_private.before_insert_event_participant()
returns trigger language plpgsql security definer set search_path = '' as $$
declare e public.events; v_count int;
begin
  select * into e from public.events where id = new.event_id for update;
  if e.id is null or e.status <> 'published' or e.starts_at < now() then
    raise exception 'event_not_open' using errcode = 'P0400';
  end if;
  if e.audience_band <> (select age_band from public.profiles where id = new.user_id) then
    raise exception 'forbidden: fascia d''età non compatibile' using errcode = '42501';
  end if;
  if e.max_participants is not null then
    select count(*) into v_count from public.event_participants where event_id = e.id;
    if v_count >= e.max_participants then
      raise exception 'event_full' using errcode = 'P0409';
    end if;
  end if;
  return new;
end $$;
create trigger event_participants_before_insert before insert on public.event_participants
  for each row execute function app_private.before_insert_event_participant();

-- Gruppi: fascia = creatore; iscrizione solo alla propria fascia
create or replace function app_private.before_insert_group()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null then
    new.audience_band := app_private.current_band();
    new.is_hidden := false;
    if new.audience_band is null then raise exception 'forbidden' using errcode = '42501'; end if;
  end if;
  perform app_private.enforce_rate_limit('groups', 3, interval '1 day');
  return new;
end $$;
create trigger groups_before_insert before insert on public.groups
  for each row execute function app_private.before_insert_group();

create or replace function app_private.after_insert_group()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.created_by is not null then
    insert into public.group_members (group_id, user_id, role) values (new.id, new.created_by, 'owner');
  end if;
  return null;
end $$;
create trigger groups_after_insert after insert on public.groups
  for each row execute function app_private.after_insert_group();

-- Messaggi: rate limit, antispam, immagini sempre "pending", notifiche
create or replace function app_private.before_insert_message()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null then
    new.created_at := now();
    new.delivered_at := null; new.read_at := null; new.deleted_at := null;
    if new.image_path is not null then new.image_status := 'pending'; end if;
  end if;
  perform app_private.enforce_spam_filter(new.body);
  perform app_private.enforce_rate_limit('messages', 30, interval '1 minute');
  return new;
end $$;
create trigger messages_before_insert before insert on public.messages
  for each row execute function app_private.before_insert_message();

create or replace function app_private.after_insert_message()
returns trigger language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select user_id from public.conversation_participants
           where conversation_id = new.conversation_id and user_id <> new.sender_id loop
    perform app_private.notify(r.user_id, 'message',
      jsonb_build_object('conversation_id', new.conversation_id, 'message_id', new.id));
  end loop;
  return null;
end $$;
create trigger messages_after_insert after insert on public.messages
  for each row execute function app_private.after_insert_message();

-- Segnalazioni: rate limit; il reporter è sempre l'utente corrente
create or replace function app_private.before_insert_report()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null then
    new.reporter_id := auth.uid();
    new.status := 'open'; new.resolved_at := null; new.resolved_by := null; new.evidence := null;
  end if;
  -- Conserva una prova del messaggio segnalato (solo se chi segnala partecipa alla chat)
  if new.target_type in ('message','image') then
    select jsonb_build_object('sender_id', m.sender_id, 'body', m.body, 'image_path', m.image_path,
                              'created_at', m.created_at, 'conversation_id', m.conversation_id)
      into new.evidence
      from public.messages m
     where m.id = new.target_id
       and app_private.is_conversation_member(m.conversation_id, new.reporter_id);
  end if;
  perform app_private.enforce_rate_limit('reports', 20, interval '1 hour');
  return new;
end $$;
create trigger reports_before_insert before insert on public.reports
  for each row execute function app_private.before_insert_report();

-- Idee per il fondatore: un utente normale non può renderle pubbliche
create or replace function app_private.before_insert_creator_idea()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and not app_private.is_creator_or_admin() then
    new.is_public := false;
  end if;
  perform app_private.enforce_spam_filter(new.body);
  perform app_private.enforce_rate_limit('creator_ideas', 5, interval '1 hour');
  return new;
end $$;
create trigger creator_ideas_before_insert before insert on public.creator_ideas
  for each row execute function app_private.before_insert_creator_idea();

-- Aggiornamenti di Sentinel: notifica ai follower alla pubblicazione
create or replace function app_private.after_publish_creator_update()
returns trigger language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  if new.published and (tg_op = 'INSERT' or not old.published) then
    for r in select user_id from public.creator_followers loop
      perform app_private.notify(r.user_id, 'creator',
        jsonb_build_object('update_id', new.id, 'title', new.title));
    end loop;
  end if;
  return null;
end $$;
create trigger creator_updates_after_write after insert or update on public.creator_updates
  for each row execute function app_private.after_publish_creator_update();

-- =====================================================================
-- RPC PUBBLICHE (chiamate dall'app)
-- =====================================================================

-- Onboarding con controllo dell'età lato server
create or replace function public.complete_onboarding(
  p_username text,
  p_birth_date date,
  p_country text,
  p_city text,
  p_interests text[] default '{}',
  p_friendship_preferences text[] default '{}',
  p_accept_terms boolean default false,
  p_accept_privacy boolean default false,
  p_policy_version text default '1.0'
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_age int;
  v_band text;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'already_onboarded' using errcode = 'P0409';
  end if;
  if not (p_accept_terms and p_accept_privacy) then
    raise exception 'consent_required: accetta termini e informativa privacy' using errcode = 'P0400';
  end if;
  if p_birth_date is null or p_birth_date > current_date then
    raise exception 'invalid_birth_date' using errcode = 'P0400';
  end if;

  v_age := app_private.age_from_birth(p_birth_date);

  -- UNDER 13: nessuna registrazione, nessun dato salvato
  if v_age < app_private.cfg_int('min_registration_age') then
    raise exception 'age_not_allowed' using errcode = 'P0403';
  end if;

  if v_age >= app_private.cfg_int('adult_age') then
    v_band := 'adult';
  else
    if not app_private.cfg_bool('minors_registration_enabled') then
      -- v1 solo maggiorenni: messaggio neutro, nessun dato salvato
      raise exception 'age_not_allowed' using errcode = 'P0403';
    end if;
    v_band := 'teen';
  end if;

  insert into public.profiles (id, username, country, city, interests, friendship_preferences, age_band)
  values (v_uid, lower(p_username), upper(p_country), p_city,
          coalesce(p_interests, '{}'), coalesce(p_friendship_preferences, '{}'), v_band);

  insert into public.profiles_private (user_id, birth_date) values (v_uid, p_birth_date);

  insert into public.user_preferences (user_id, min_age, max_age)
  values (v_uid, case when v_band = 'adult' then 18 else 13 end,
                 case when v_band = 'adult' then 99 else 17 end);

  insert into public.user_consents (user_id, consent_type, version, granted) values
    (v_uid, 'terms', p_policy_version, true),
    (v_uid, 'privacy_policy', p_policy_version, true);

  return jsonb_build_object('user_id', v_uid, 'age_band', v_band);
end $$;

-- Discover / FanFinder: profili compatibili, paginati
create or replace function public.discover_profiles(
  p_mode text default 'friendship',
  p_city text default null,
  p_interest text default null,
  p_min_age int default null,
  p_max_age int default null,
  p_limit int default 20,
  p_offset int default 0
) returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_band text;
begin
  v_band := app_private.current_band();
  if v_band is null then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_mode not in ('friendship','dating') then raise exception 'invalid_mode' using errcode = 'P0400'; end if;
  if p_mode = 'dating' and not (app_private.cfg_bool('dating_enabled') and app_private.is_verified_adult(v_uid)) then
    raise exception 'dating_not_available' using errcode = 'P0403';
  end if;

  return query
  select app_private.profile_card(p)
  from public.profiles p
  left join public.profiles_private pp on pp.user_id = p.id
  where p.id <> v_uid
    and p.status = 'active' and p.discoverable
    and p.age_band = v_band                                -- separazione per fascia
    and not app_private.is_blocked_between(v_uid, p.id)
    and not exists (select 1 from public.likes l
                    where l.liker_id = v_uid and l.likee_id = p.id and l.mode = p_mode)
    and (p_mode <> 'dating' or app_private.is_verified_adult(p.id))
    and (p_city is null or lower(p.city) = lower(p_city))
    and (p_interest is null or p_interest = any(p.interests))
    and (p_min_age is null or app_private.age_from_birth(pp.birth_date) >= p_min_age)
    and (p_max_age is null or app_private.age_from_birth(pp.birth_date) <= p_max_age)
  order by
    cardinality(array(select unnest(p.interests) intersect
                      select unnest(me.interests)
                      from public.profiles me where me.id = v_uid)) desc,
    p.created_at desc
  limit least(greatest(p_limit, 1), 50) offset greatest(p_offset, 0);
end $$;

-- Scheda singolo profilo
create or replace function public.get_profile(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare p public.profiles;
begin
  if p_user = auth.uid() then
    select * into p from public.profiles where id = p_user;
    return app_private.profile_card(p);
  end if;
  if not app_private.can_interact(auth.uid(), p_user) then
    return null;
  end if;
  select * into p from public.profiles where id = p_user;
  return app_private.profile_card(p);
end $$;

-- Like / Pass / Super Like + match reciproco
create or replace function public.like_user(p_target uuid, p_mode text default 'friendship', p_action text default 'like')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_match uuid; v_conv uuid;
  v_a uuid; v_b uuid;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_mode not in ('friendship','dating') or p_action not in ('like','pass','super_like') then
    raise exception 'invalid_argument' using errcode = 'P0400';
  end if;
  if not app_private.can_interact(v_uid, p_target) then
    raise exception 'forbidden: interazione non consentita' using errcode = '42501';
  end if;
  if p_mode = 'dating' and not (app_private.cfg_bool('dating_enabled')
        and app_private.is_verified_adult(v_uid) and app_private.is_verified_adult(p_target)) then
    raise exception 'dating_not_available' using errcode = 'P0403';
  end if;
  perform app_private.enforce_rate_limit('likes', 100, interval '1 hour');

  insert into public.likes (liker_id, likee_id, mode, action)
  values (v_uid, p_target, p_mode, p_action)
  on conflict (liker_id, likee_id, mode) do update set action = excluded.action, created_at = now();

  if p_action = 'pass' then
    return jsonb_build_object('matched', false);
  end if;

  if p_action = 'super_like' then
    perform app_private.notify(p_target, 'like', jsonb_build_object('mode', p_mode, 'super', true));
  end if;

  if exists (select 1 from public.likes
             where liker_id = p_target and likee_id = v_uid and mode = p_mode
               and action in ('like','super_like')) then
    v_a := least(v_uid, p_target); v_b := greatest(v_uid, p_target);
    insert into public.matches (user_a, user_b, mode) values (v_a, v_b, p_mode)
    on conflict (user_a, user_b, mode) do update set unmatched_at = null, unmatched_by = null
    returning id into v_match;

    insert into public.conversations (kind, match_id) values ('match', v_match)
    on conflict (match_id) do update set is_active = true
    returning id into v_conv;

    insert into public.conversation_participants (conversation_id, user_id)
    values (v_conv, v_a), (v_conv, v_b) on conflict do nothing;

    perform app_private.notify(v_uid, 'match', jsonb_build_object('match_id', v_match, 'conversation_id', v_conv));
    perform app_private.notify(p_target, 'match', jsonb_build_object('match_id', v_match, 'conversation_id', v_conv));
    return jsonb_build_object('matched', true, 'match_id', v_match, 'conversation_id', v_conv);
  end if;

  return jsonb_build_object('matched', false);
end $$;

create or replace function public.unmatch(p_match uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.matches;
begin
  select * into m from public.matches where id = p_match;
  if m.id is null or auth.uid() not in (m.user_a, m.user_b) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.matches set unmatched_at = now(), unmatched_by = auth.uid() where id = p_match;
  update public.conversations set is_active = false where match_id = p_match;
  delete from public.likes
   where mode = m.mode and ((liker_id = m.user_a and likee_id = m.user_b) or (liker_id = m.user_b and likee_id = m.user_a));
end $$;

-- Blocco: chiude conversazioni, match e amicizie tra i due
create or replace function public.block_user(p_target uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null or p_target is null or v_uid = p_target then
    raise exception 'invalid_argument' using errcode = 'P0400';
  end if;
  insert into public.blocked_users (blocker_id, blocked_id) values (v_uid, p_target) on conflict do nothing;
  update public.matches set unmatched_at = coalesce(unmatched_at, now()), unmatched_by = coalesce(unmatched_by, v_uid)
   where user_a = least(v_uid, p_target) and user_b = greatest(v_uid, p_target);
  update public.conversations c set is_active = false
   where exists (select 1 from public.conversation_participants a where a.conversation_id = c.id and a.user_id = v_uid)
     and exists (select 1 from public.conversation_participants b where b.conversation_id = c.id and b.user_id = p_target);
  delete from public.friendships
   where (requester_id = v_uid and addressee_id = p_target) or (requester_id = p_target and addressee_id = v_uid);
  delete from public.likes
   where (liker_id = v_uid and likee_id = p_target) or (liker_id = p_target and likee_id = v_uid);
end $$;

create or replace function public.unblock_user(p_target uuid)
returns void language sql security definer set search_path = '' as $$
  delete from public.blocked_users where blocker_id = auth.uid() and blocked_id = p_target;
$$;

-- Amicizie
create or replace function public.send_friend_request(p_target uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not app_private.can_interact(auth.uid(), p_target) then
    raise exception 'forbidden: interazione non consentita' using errcode = '42501';
  end if;
  perform app_private.enforce_rate_limit('friend_requests', 30, interval '1 hour');
  insert into public.friendships (requester_id, addressee_id) values (auth.uid(), p_target) returning id into v_id;
  perform app_private.notify(p_target, 'friend_request', jsonb_build_object('friendship_id', v_id));
  return v_id;
end $$;

create or replace function public.respond_friend_request(p_friendship uuid, p_accept boolean)
returns uuid language plpgsql security definer set search_path = '' as $$
declare f public.friendships; v_conv uuid;
begin
  select * into f from public.friendships where id = p_friendship for update;
  if f.id is null or f.addressee_id <> auth.uid() or f.status <> 'pending' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not app_private.can_interact(f.requester_id, f.addressee_id) then
    raise exception 'forbidden: interazione non consentita' using errcode = '42501';
  end if;
  update public.friendships set status = case when p_accept then 'accepted' else 'declined' end,
         responded_at = now() where id = f.id;
  if p_accept then
    insert into public.conversations (kind, friendship_id) values ('friendship', f.id) returning id into v_conv;
    insert into public.conversation_participants (conversation_id, user_id)
    values (v_conv, f.requester_id), (v_conv, f.addressee_id);
  end if;
  return v_conv;
end $$;

-- Chat: lettura e cancellazione con regole trasparenti
create or replace function public.mark_conversation_read(p_conversation uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_conversation_member(p_conversation, auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.messages set delivered_at = coalesce(delivered_at, now()), read_at = coalesce(read_at, now())
   where conversation_id = p_conversation and sender_id <> auth.uid() and read_at is null;
  update public.conversation_participants set last_read_at = now()
   where conversation_id = p_conversation and user_id = auth.uid();
end $$;

create or replace function public.mark_messages_delivered(p_conversation uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_conversation_member(p_conversation, auth.uid()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.messages set delivered_at = now()
   where conversation_id = p_conversation and sender_id <> auth.uid() and delivered_at is null;
end $$;

-- Regola: il mittente può eliminare per tutti un proprio messaggio entro 24 ore.
-- Il testo viene cancellato; restano solo metadati (id, orario) per l'integrità della chat.
-- Se il messaggio era stato segnalato, i moderatori conservano la copia in reports.evidence.
create or replace function public.delete_message(p_message uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare m public.messages;
begin
  select * into m from public.messages where id = p_message;
  if m.id is null or m.sender_id <> auth.uid() then raise exception 'forbidden' using errcode = '42501'; end if;
  if m.created_at < now() - interval '24 hours' then
    raise exception 'delete_window_expired' using errcode = 'P0403';
  end if;
  update public.messages set deleted_at = now(), body = null, image_path = null, image_status = null where id = m.id;
end $$;

-- GDPR: esportazione dati personali
create or replace function public.export_my_data()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  return jsonb_build_object(
    'exported_at', now(),
    'profile', (select to_jsonb(p) from public.profiles p where p.id = v_uid),
    'private', (select to_jsonb(pp) from public.profiles_private pp where pp.user_id = v_uid),
    'preferences', (select to_jsonb(up) from public.user_preferences up where up.user_id = v_uid),
    'consents', (select coalesce(jsonb_agg(c), '[]') from public.user_consents c where c.user_id = v_uid),
    'age_verifications', (select coalesce(jsonb_agg(jsonb_build_object('method', v.method, 'status', v.status,
                           'verified_at', v.verified_at)), '[]') from public.age_verifications v where v.user_id = v_uid),
    'posts', (select coalesce(jsonb_agg(x), '[]') from public.posts x where x.author_id = v_uid),
    'comments', (select coalesce(jsonb_agg(x), '[]') from public.comments x where x.author_id = v_uid),
    'support_posts', (select coalesce(jsonb_agg(x), '[]') from public.support_posts x where x.author_id = v_uid),
    'messages_sent', (select coalesce(jsonb_agg(x), '[]') from public.messages x where x.sender_id = v_uid),
    'likes_given', (select coalesce(jsonb_agg(x), '[]') from public.likes x where x.liker_id = v_uid),
    'friendships', (select coalesce(jsonb_agg(x), '[]') from public.friendships x where v_uid in (x.requester_id, x.addressee_id)),
    'blocked', (select coalesce(jsonb_agg(x.blocked_id), '[]') from public.blocked_users x where x.blocker_id = v_uid),
    'events_joined', (select coalesce(jsonb_agg(x.event_id), '[]') from public.event_participants x where x.user_id = v_uid),
    'reports_filed', (select coalesce(jsonb_agg(jsonb_build_object('target_type', r.target_type, 'reason', r.reason,
                       'created_at', r.created_at, 'status', r.status)), '[]') from public.reports r where r.reporter_id = v_uid)
  );
end $$;

-- GDPR: cancellazione account (cascade su tutti i dati personali)
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '42501'; end if;
  delete from public.rate_limit_events where user_id = v_uid;
  delete from auth.users where id = v_uid;   -- cascade su profiles e su tutto il resto
end $$;

-- Consensi separati (marketing, notifiche push, analytics) – revocabili
create or replace function public.set_consent(p_type text, p_granted boolean, p_version text default '1.0')
returns void language plpgsql security definer set search_path = '' as $$
begin
  if p_type in ('terms','privacy_policy') and not p_granted then
    raise exception 'use_delete_my_account: revocare termini/privacy richiede la cancellazione account' using errcode = 'P0400';
  end if;
  insert into public.user_consents (user_id, consent_type, version, granted) values (auth.uid(), p_type, p_version, p_granted);
end $$;

-- =====================================================================
-- RPC AMMINISTRATIVE – ogni azione viene registrata in moderation_actions
-- =====================================================================
create or replace function app_private.log_action(p_action text, p_type text, p_target uuid, p_reason text, p_report uuid default null)
returns void language sql security definer set search_path = '' as $$
  insert into public.moderation_actions (actor_id, action, target_type, target_id, reason, report_id)
  values (auth.uid(), p_action, p_type, p_target, p_reason, p_report);
$$;

create or replace function public.admin_set_user_status(p_user uuid, p_status text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_user = auth.uid() then raise exception 'cannot_moderate_self' using errcode = 'P0400'; end if;
  if (select role from public.profiles where id = p_user) in ('admin','creator') and not app_private.is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.profiles set status = p_status where id = p_user;
  perform app_private.log_action('set_status:' || p_status, 'profile', p_user, p_reason);
end $$;

create or replace function public.admin_set_role(p_user uuid, p_role text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_user = auth.uid() then raise exception 'cannot_change_own_role' using errcode = 'P0400'; end if;
  update public.profiles set role = p_role where id = p_user;
  perform app_private.log_action('set_role:' || p_role, 'profile', p_user, p_reason);
end $$;

create or replace function public.admin_hide_content(p_type text, p_id uuid, p_hidden boolean, p_reason text, p_report uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  case p_type
    when 'post'          then update public.posts set is_hidden = p_hidden where id = p_id;
    when 'comment'       then update public.comments set is_hidden = p_hidden where id = p_id;
    when 'support_post'  then update public.support_posts set is_hidden = p_hidden where id = p_id;
    when 'support_reply' then update public.support_replies set is_hidden = p_hidden where id = p_id;
    when 'group'         then update public.groups set is_hidden = p_hidden where id = p_id;
    else raise exception 'invalid_type' using errcode = 'P0400';
  end case;
  perform app_private.log_action(case when p_hidden then 'hide' else 'unhide' end, p_type, p_id, p_reason, p_report);
end $$;

create or replace function public.admin_resolve_report(p_report uuid, p_status text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('reviewing','actioned','dismissed') then raise exception 'invalid_status' using errcode = 'P0400'; end if;
  update public.reports set status = p_status,
         resolved_at = case when p_status = 'reviewing' then null else now() end,
         resolved_by = auth.uid() where id = p_report;
  perform app_private.log_action('report:' || p_status, 'report', p_report, p_reason, p_report);
end $$;

create or replace function public.admin_review_event(p_event uuid, p_status text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('published','rejected','cancelled') then raise exception 'invalid_status' using errcode = 'P0400'; end if;
  update public.events set status = p_status where id = p_event;
  perform app_private.log_action('event:' || p_status, 'event', p_event, p_reason);
end $$;

create or replace function public.admin_review_image(p_message uuid, p_status text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('approved','rejected') then raise exception 'invalid_status' using errcode = 'P0400'; end if;
  update public.messages set image_status = p_status,
         image_path = case when p_status = 'rejected' then null else image_path end
   where id = p_message and image_path is not null;
  if p_status = 'rejected' then
    update public.messages set image_status = null where id = p_message and image_path is null;
  end if;
  perform app_private.log_action('image:' || p_status, 'message', p_message, p_reason);
end $$;

-- Verifica età adulta: SOLO esito, nessun documento (D4)
create or replace function public.admin_set_age_verification(p_user uuid, p_status text, p_method text, p_reason text, p_provider_ref text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status = 'verified' and (select age_band from public.profiles where id = p_user) <> 'adult' then
    raise exception 'not_adult_band' using errcode = 'P0400';
  end if;
  insert into public.age_verifications (user_id, method, status, provider_reference, verified_at)
  values (p_user, p_method, p_status, p_provider_ref, case when p_status = 'verified' then now() end);
  perform app_private.log_action('age_verification:' || p_status, 'profile', p_user, p_reason);
end $$;

-- D7: accesso a un messaggio SOLO tramite segnalazione + motivazione registrata
create or replace function public.admin_read_reported_message(p_report uuid, p_justification text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.reports;
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  if char_length(coalesce(p_justification, '')) < 10 then
    raise exception 'justification_required' using errcode = 'P0400';
  end if;
  select * into r from public.reports where id = p_report and target_type in ('message','image');
  if r.id is null then raise exception 'report_not_found' using errcode = 'P0404'; end if;
  insert into public.admin_access_log (actor_id, resource, resource_id, justification)
  values (auth.uid(), 'message', r.target_id, p_justification);
  return jsonb_build_object('report_id', r.id, 'message_id', r.target_id, 'evidence', r.evidence);
end $$;

create or replace function public.admin_stats()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  return jsonb_build_object(               -- solo dati aggregati
    'users_total', (select count(*) from public.profiles),
    'users_active', (select count(*) from public.profiles where status = 'active'),
    'users_by_band', (select jsonb_object_agg(age_band, n) from (select age_band, count(*) n from public.profiles group by 1) s),
    'reports_open', (select count(*) from public.reports where status in ('open','reviewing')),
    'events_pending', (select count(*) from public.events where status = 'pending_review'),
    'images_pending', (select count(*) from public.messages where image_status = 'pending'),
    'posts_7d', (select count(*) from public.posts where created_at > now() - interval '7 days'),
    'matches_7d', (select count(*) from public.matches where created_at > now() - interval '7 days')
  );
end $$;

-- ---------------------------------------------------------------------
-- Permessi sulle funzioni
-- ---------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon;
revoke execute on all functions in schema app_private from public, anon, authenticated;
grant execute on all functions in schema public to authenticated, service_role;
grant execute on all functions in schema app_private to service_role;
-- Solo gli helper in sola lettura servono alle policy RLS
grant execute on function
  app_private.cfg_bool(text), app_private.current_band(), app_private.current_role_name(),
  app_private.is_staff(), app_private.is_admin(), app_private.is_creator_or_admin(),
  app_private.is_blocked_between(uuid, uuid), app_private.can_interact(uuid, uuid),
  app_private.is_verified_adult(uuid), app_private.is_conversation_member(uuid, uuid),
  app_private.age_from_birth(date)
to authenticated;
