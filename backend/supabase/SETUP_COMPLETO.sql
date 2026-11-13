-- WGF CONNECT – SETUP COMPLETO DEL DATABASE (un solo file). Incolla nello SQL Editor di Supabase e premi RUN, una sola volta su un progetto nuovo.

-- >>> 20261113000001_schema.sql
-- =====================================================================
-- WGF CONNECT – Migrazione 0001: schema delle tabelle
-- Progetto indipendente, non affiliato ai WGF.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Configurazione applicativa (flag di sicurezza)
-- ---------------------------------------------------------------------
create table public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

insert into public.app_config (key, value) values
  ('minors_registration_enabled', 'false'::jsonb),  -- D1: v1 solo 18+
  ('dating_enabled',              'false'::jsonb),  -- D4: acceso solo dopo aver scelto la verifica età
  ('min_registration_age',        '13'::jsonb),
  ('adult_age',                   '18'::jsonb);

-- ---------------------------------------------------------------------
-- Profili
-- ---------------------------------------------------------------------
create table public.profiles (
  id                     uuid primary key references auth.users(id) on delete cascade,
  username               text not null unique
                           check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name           text check (char_length(display_name) between 1 and 40),
  bio                    text check (char_length(bio) <= 500),
  avatar_path            text,
  country                text not null check (country ~ '^[A-Z]{2}$'),  -- ISO 3166-1 alpha-2
  city                   text not null check (char_length(city) between 1 and 80),
  interests              text[] not null default '{}' check (cardinality(interests) <= 20),
  favorite_games         text[] not null default '{}' check (cardinality(favorite_games) <= 20),
  favorite_wgf_characters text[] not null default '{}' check (cardinality(favorite_wgf_characters) <= 20),
  friendship_preferences text[] not null default '{}' check (cardinality(friendship_preferences) <= 10),
  -- Campi protetti: scritti solo dal server (vedi trigger protect_profile_columns)
  age_band               text not null check (age_band in ('teen','adult')),
  role                   text not null default 'user'
                           check (role in ('user','moderator','admin','creator')),
  status                 text not null default 'active'
                           check (status in ('active','suspended','banned')),
  -- Privacy
  show_age               boolean not null default true,
  discoverable           boolean not null default true,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index profiles_band_city_idx on public.profiles (age_band, country, city) where status = 'active';
create index profiles_interests_idx on public.profiles using gin (interests);

-- Dati privati: mai esposti ad altri utenti (D2)
create table public.profiles_private (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  birth_date date not null check (birth_date > date '1900-01-01')
);

create table public.user_preferences (
  user_id             uuid primary key references public.profiles(id) on delete cascade,
  discover_mode       text not null default 'friendship'
                        check (discover_mode in ('friendship','dating','both')),
  min_age             int  not null default 18 check (min_age between 13 and 120),
  max_age             int  not null default 99 check (max_age between 13 and 120),
  preferred_cities    text[] not null default '{}',
  notify_matches      boolean not null default true,
  notify_messages     boolean not null default true,
  notify_likes        boolean not null default true,
  notify_comments     boolean not null default true,
  notify_events       boolean not null default true,
  notify_community    boolean not null default true,
  notify_creator      boolean not null default true,
  updated_at          timestamptz not null default now(),
  check (min_age <= max_age)
);

-- Verifica dell'età adulta: nessun documento, solo esito (D4)
create table public.age_verifications (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references public.profiles(id) on delete cascade,
  method             text not null check (method in ('manual_review','provider','other')),
  status             text not null default 'pending'
                       check (status in ('pending','verified','rejected','expired')),
  provider_reference text check (char_length(provider_reference) <= 200),
  verified_at        timestamptz,
  created_at         timestamptz not null default now()
);
create index age_verifications_user_idx on public.age_verifications (user_id, status);

create table public.user_consents (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  consent_type text not null check (consent_type in
                 ('terms','privacy_policy','community_guidelines','marketing','push_notifications','analytics')),
  version      text not null,
  granted      boolean not null,
  created_at   timestamptz not null default now()
);
create index user_consents_user_idx on public.user_consents (user_id, consent_type, created_at desc);

-- ---------------------------------------------------------------------
-- Relazioni tra utenti
-- ---------------------------------------------------------------------
create table public.blocked_users (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index blocked_users_blocked_idx on public.blocked_users (blocked_id);

create table public.friendships (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  addressee_id uuid not null references public.profiles(id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id)
);
-- Una sola amicizia per coppia, indipendentemente dalla direzione
create unique index friendships_pair_uidx on public.friendships
  (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create table public.likes (
  liker_id   uuid not null references public.profiles(id) on delete cascade,
  likee_id   uuid not null references public.profiles(id) on delete cascade,
  mode       text not null check (mode in ('friendship','dating')),
  action     text not null default 'like' check (action in ('like','pass','super_like')),
  created_at timestamptz not null default now(),
  primary key (liker_id, likee_id, mode),
  check (liker_id <> likee_id)
);
create index likes_likee_idx on public.likes (likee_id, mode);

create table public.matches (
  id           uuid primary key default gen_random_uuid(),
  user_a       uuid not null references public.profiles(id) on delete cascade,
  user_b       uuid not null references public.profiles(id) on delete cascade,
  mode         text not null check (mode in ('friendship','dating')),
  created_at   timestamptz not null default now(),
  unmatched_at timestamptz,
  unmatched_by uuid references public.profiles(id) on delete set null,
  check (user_a < user_b),
  unique (user_a, user_b, mode)
);

-- ---------------------------------------------------------------------
-- Messaggistica
-- ---------------------------------------------------------------------
create table public.conversations (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null check (kind in ('match','friendship')),
  match_id   uuid unique references public.matches(id) on delete cascade,
  friendship_id uuid unique references public.friendships(id) on delete cascade,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  check ((kind = 'match' and match_id is not null) or (kind = 'friendship' and friendship_id is not null))
);

create table public.conversation_participants (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  last_read_at    timestamptz,
  primary key (conversation_id, user_id)
);
create index conversation_participants_user_idx on public.conversation_participants (user_id);

create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid not null references public.profiles(id) on delete cascade,
  body            text check (char_length(body) between 1 and 2000),
  image_path      text,
  image_status    text check (image_status in ('pending','approved','rejected')),
  created_at      timestamptz not null default now(),
  delivered_at    timestamptz,
  read_at         timestamptz,
  deleted_at      timestamptz,
  -- Un messaggio eliminato conserva solo i metadati (regola trasparente: vedi PRIVACY.md)
  check (deleted_at is not null or body is not null or image_path is not null or image_status = 'rejected'),
  check (image_path is null or image_status is not null)  -- immagine sempre con stato; 'rejected' senza file
);
create index messages_conversation_idx on public.messages (conversation_id, created_at desc);

-- ---------------------------------------------------------------------
-- Community
-- ---------------------------------------------------------------------
create table public.groups (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (char_length(name) between 3 and 60),
  description   text check (char_length(description) <= 1000),
  category      text not null check (category in ('wgf','gaming','fanart','city','other')),
  audience_band text not null check (audience_band in ('teen','adult')),
  created_by    uuid references public.profiles(id) on delete set null,
  is_hidden     boolean not null default false,
  created_at    timestamptz not null default now()
);

create table public.group_members (
  group_id  uuid not null references public.groups(id) on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  role      text not null default 'member' check (role in ('member','moderator','owner')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user_idx on public.group_members (user_id);

create table public.posts (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid not null references public.profiles(id) on delete cascade,
  group_id      uuid references public.groups(id) on delete cascade,
  kind          text not null default 'text' check (kind in ('text','image','fanart','poll','share','discussion')),
  body          text check (char_length(body) <= 5000),
  image_path    text,
  hashtags      text[] not null default '{}' check (cardinality(hashtags) <= 15),
  poll_options  jsonb,
  shared_post_id uuid references public.posts(id) on delete set null,
  audience_band text not null check (audience_band in ('teen','adult')),
  is_hidden     boolean not null default false,   -- moderazione
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check (body is not null or image_path is not null or shared_post_id is not null)
);
create index posts_feed_idx on public.posts (audience_band, created_at desc) where not is_hidden;
create index posts_hashtags_idx on public.posts using gin (hashtags);
create index posts_group_idx on public.posts (group_id, created_at desc);

create table public.poll_votes (
  post_id    uuid not null references public.posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  option_idx int  not null check (option_idx between 0 and 9),
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  author_id  uuid not null references public.profiles(id) on delete cascade,
  parent_id  uuid references public.comments(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 2000),
  is_hidden  boolean not null default false,
  created_at timestamptz not null default now()
);
create index comments_post_idx on public.comments (post_id, created_at);

create table public.reactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  post_id     uuid references public.posts(id) on delete cascade,
  comment_id  uuid references public.comments(id) on delete cascade,
  kind        text not null default 'like' check (kind in ('like','love','fire','laugh','support')),
  created_at  timestamptz not null default now(),
  check (num_nonnulls(post_id, comment_id) = 1)
);
create unique index reactions_post_uidx on public.reactions (user_id, post_id) where post_id is not null;
create unique index reactions_comment_uidx on public.reactions (user_id, comment_id) where comment_id is not null;

-- NON SEI SOLO
create table public.support_posts (
  id            uuid primary key default gen_random_uuid(),
  author_id     uuid not null references public.profiles(id) on delete cascade,
  body          text not null check (char_length(body) between 1 and 3000),
  is_anonymous  boolean not null default false,
  audience_band text not null check (audience_band in ('teen','adult')),
  is_hidden     boolean not null default false,
  created_at    timestamptz not null default now()
);
create index support_posts_feed_idx on public.support_posts (audience_band, created_at desc) where not is_hidden;

create table public.support_replies (
  id              uuid primary key default gen_random_uuid(),
  support_post_id uuid not null references public.support_posts(id) on delete cascade,
  author_id       uuid not null references public.profiles(id) on delete cascade,
  body            text not null check (char_length(body) between 1 and 1000),
  is_hidden       boolean not null default false,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Eventi
-- ---------------------------------------------------------------------
create table public.events (
  id               uuid primary key default gen_random_uuid(),
  organizer_id     uuid references public.profiles(id) on delete set null,
  title            text not null check (char_length(title) between 3 and 100),
  description      text not null check (char_length(description) <= 3000),
  category         text not null check (category in ('meetup','gathering','gaming','online','other')),
  country          text not null check (country ~ '^[A-Z]{2}$'),
  city             text not null,
  venue_public     text check (char_length(venue_public) <= 200), -- solo luoghi pubblici, mai indirizzi privati
  starts_at        timestamptz not null,
  ends_at          timestamptz,
  max_participants int check (max_participants between 2 and 10000),
  audience_band    text not null check (audience_band in ('teen','adult')),
  status           text not null default 'pending_review'
                     check (status in ('pending_review','published','rejected','cancelled')),
  created_at       timestamptz not null default now(),
  check (ends_at is null or ends_at > starts_at)
);
create index events_calendar_idx on public.events (audience_band, status, starts_at);

create table public.event_participants (
  event_id  uuid not null references public.events(id) on delete cascade,
  user_id   uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

-- ---------------------------------------------------------------------
-- Fondatore – SENTINEL
-- ---------------------------------------------------------------------
create table public.creator_updates (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid references public.profiles(id) on delete set null,
  kind        text not null check (kind in ('update','devlog','manifesto','future_project','bio')),
  title       text not null check (char_length(title) between 1 and 150),
  body        text not null check (char_length(body) <= 20000),
  published   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index creator_updates_pub_idx on public.creator_updates (kind, created_at desc) where published;

create table public.creator_ideas (       -- "Proponi un'idea" / "Messaggi dalla community"
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid not null references public.profiles(id) on delete cascade,
  kind       text not null check (kind in ('idea','message','volunteer')),
  body       text not null check (char_length(body) between 1 and 2000),
  is_public  boolean not null default false,  -- reso pubblico solo dal fondatore
  created_at timestamptz not null default now()
);

create table public.creator_followers (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Notifiche, segnalazioni, moderazione
-- ---------------------------------------------------------------------
create table public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null check (kind in
               ('match','message','like','comment','reply','event','community','creator','friend_request','moderation')),
  payload    jsonb not null default '{}',
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id, created_at desc);

create table public.reports (
  id           uuid primary key default gen_random_uuid(),
  reporter_id  uuid references public.profiles(id) on delete set null,
  target_type  text not null check (target_type in
                 ('profile','message','image','post','comment','event','support_post','support_reply','group')),
  target_id    uuid not null,
  reason       text not null check (reason in
                 ('harassment','spam','inappropriate','minor_safety','impersonation','hate','self_harm','scam','other')),
  details      text check (char_length(details) <= 1000),
  evidence     jsonb,   -- copia del contenuto segnalato (es. messaggio), scritta solo dal server
  status       text not null default 'open' check (status in ('open','reviewing','actioned','dismissed')),
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz,
  resolved_by  uuid references public.profiles(id) on delete set null
);
create index reports_queue_idx on public.reports (status, created_at);

create table public.moderation_actions (     -- registro delle azioni amministrative
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references public.profiles(id) on delete set null,
  action      text not null,
  target_type text not null,
  target_id   uuid,
  report_id   uuid references public.reports(id) on delete set null,
  reason      text not null check (char_length(reason) >= 3),
  created_at  timestamptz not null default now()
);

create table public.admin_access_log (       -- D7: accessi ai dati privati con motivazione
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid references public.profiles(id) on delete set null,
  resource    text not null,
  resource_id uuid not null,
  justification text not null check (char_length(justification) >= 10),
  created_at  timestamptz not null default now()
);

create table public.rate_limit_events (
  user_id    uuid not null,
  action     text not null,
  created_at timestamptz not null default now()
);
create index rate_limit_events_idx on public.rate_limit_events (user_id, action, created_at desc);

-- >>> 20261113000002_functions.sql
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
   where id = p_message and image_path is not null and image_status = 'pending';
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

-- >>> 20261113000003_rls.sql
-- =====================================================================
-- WGF CONNECT – Migrazione 0003: Row Level Security
-- Regola generale: RLS attiva su TUTTE le tabelle di public.
-- Il ruolo "anon" non ha alcuna policy → nessun accesso.
-- =====================================================================

do $$
declare t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
  end loop;
end $$;

-- Protezione colonne di moderazione: l'utente non può cambiare fascia,
-- visibilità o autore dei propri contenuti
create or replace function app_private.protect_content_columns()
returns trigger language plpgsql as $$
begin
  if current_user in ('authenticated','anon') then
    if to_jsonb(new) ->> 'audience_band' is distinct from to_jsonb(old) ->> 'audience_band'
       or to_jsonb(new) ->> 'is_hidden'   is distinct from to_jsonb(old) ->> 'is_hidden'
       or to_jsonb(new) ->> 'author_id'   is distinct from to_jsonb(old) ->> 'author_id'
       or to_jsonb(new) ->> 'created_by'  is distinct from to_jsonb(old) ->> 'created_by' then
      raise exception 'forbidden: campo protetto' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger posts_protect before update on public.posts for each row execute function app_private.protect_content_columns();
create trigger comments_protect before update on public.comments for each row execute function app_private.protect_content_columns();
create trigger groups_protect before update on public.groups for each row execute function app_private.protect_content_columns();
create trigger support_posts_protect before update on public.support_posts for each row execute function app_private.protect_content_columns();

-- Notifica "Mi piace" all'autore del post
create or replace function app_private.after_insert_reaction()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_author uuid;
begin
  if new.post_id is not null then
    select author_id into v_author from public.posts where id = new.post_id;
    if v_author is not null and v_author <> new.user_id then
      perform app_private.notify(v_author, 'like', jsonb_build_object('post_id', new.post_id));
    end if;
  end if;
  return null;
end $$;
create trigger reactions_after_insert after insert on public.reactions
  for each row execute function app_private.after_insert_reaction();

create or replace function app_private.support_post_band(p_id uuid)
returns text language sql stable security definer set search_path = '' as $$
  select audience_band from public.support_posts where id = p_id and not is_hidden;
$$;
grant execute on function app_private.support_post_band(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- app_config
-- ---------------------------------------------------------------------
create policy app_config_read on public.app_config for select to authenticated using (true);
create policy app_config_admin_write on public.app_config for update to authenticated
  using (app_private.is_admin()) with check (app_private.is_admin());

-- ---------------------------------------------------------------------
-- Profili
-- ---------------------------------------------------------------------
create policy profiles_select_self on public.profiles for select to authenticated
  using (id = auth.uid());
create policy profiles_select_same_band on public.profiles for select to authenticated
  using (discoverable and app_private.can_interact(auth.uid(), id));
create policy profiles_select_staff on public.profiles for select to authenticated
  using (app_private.is_staff());
create policy profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- Nessuna policy INSERT/DELETE: creazione via complete_onboarding(), cancellazione via delete_my_account()

create policy profiles_private_self on public.profiles_private for select to authenticated
  using (user_id = auth.uid());

create policy user_preferences_self_read on public.user_preferences for select to authenticated
  using (user_id = auth.uid());
create policy user_preferences_self_update on public.user_preferences for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy age_verifications_self on public.age_verifications for select to authenticated
  using (user_id = auth.uid());

create policy user_consents_self on public.user_consents for select to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Relazioni
-- ---------------------------------------------------------------------
create policy blocked_users_self on public.blocked_users for select to authenticated
  using (blocker_id = auth.uid());

create policy friendships_participant on public.friendships for select to authenticated
  using (auth.uid() in (requester_id, addressee_id));
create policy friendships_remove on public.friendships for delete to authenticated
  using (auth.uid() in (requester_id, addressee_id));

create policy likes_own on public.likes for select to authenticated
  using (liker_id = auth.uid());

create policy matches_participant on public.matches for select to authenticated
  using (auth.uid() in (user_a, user_b));

-- ---------------------------------------------------------------------
-- Messaggistica
-- ---------------------------------------------------------------------
create policy conversations_member on public.conversations for select to authenticated
  using (app_private.is_conversation_member(id, auth.uid()));

create policy conversation_participants_member on public.conversation_participants for select to authenticated
  using (app_private.is_conversation_member(conversation_id, auth.uid()));

create policy messages_member_read on public.messages for select to authenticated
  using (app_private.is_conversation_member(conversation_id, auth.uid()));

create policy messages_member_send on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and app_private.is_conversation_member(conversation_id, auth.uid())
    and exists (select 1 from public.conversations c where c.id = conversation_id and c.is_active)
    -- tutte le altre persone nella chat devono essere compatibili (fascia, blocchi, stato)
    and not exists (
      select 1 from public.conversation_participants p
      where p.conversation_id = messages.conversation_id
        and p.user_id <> auth.uid()
        and not app_private.can_interact(auth.uid(), p.user_id)
    )
  );
-- Nessun UPDATE/DELETE diretto: mark_conversation_read(), delete_message()

-- ---------------------------------------------------------------------
-- Community
-- ---------------------------------------------------------------------
create policy groups_read on public.groups for select to authenticated
  using ((audience_band = app_private.current_band() and not is_hidden) or app_private.is_staff());
create policy groups_create on public.groups for insert to authenticated
  with check (created_by = auth.uid());
create policy groups_owner_update on public.groups for update to authenticated
  using (exists (select 1 from public.group_members m where m.group_id = id and m.user_id = auth.uid() and m.role = 'owner'))
  with check (exists (select 1 from public.group_members m where m.group_id = id and m.user_id = auth.uid() and m.role = 'owner'));

create policy group_members_read on public.group_members for select to authenticated
  using (exists (select 1 from public.groups g where g.id = group_id));
create policy group_members_join on public.group_members for insert to authenticated
  with check (user_id = auth.uid() and role = 'member'
              and exists (select 1 from public.groups g where g.id = group_id
                          and g.audience_band = app_private.current_band() and not g.is_hidden));
create policy group_members_leave on public.group_members for delete to authenticated
  using (user_id = auth.uid());

create policy posts_read on public.posts for select to authenticated
  using (
    author_id = auth.uid()
    or app_private.is_staff()
    or (audience_band = app_private.current_band() and not is_hidden
        and not app_private.is_blocked_between(auth.uid(), author_id))
  );
create policy posts_create on public.posts for insert to authenticated
  with check (
    author_id = auth.uid()
    and (group_id is null or exists (select 1 from public.group_members m
                                     where m.group_id = posts.group_id and m.user_id = auth.uid()))
  );
create policy posts_update_own on public.posts for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy posts_delete_own on public.posts for delete to authenticated
  using (author_id = auth.uid());

create policy poll_votes_read on public.poll_votes for select to authenticated
  using (exists (select 1 from public.posts p where p.id = post_id));
create policy poll_votes_vote on public.poll_votes for insert to authenticated
  with check (user_id = auth.uid()
              and exists (select 1 from public.posts p where p.id = post_id and p.kind = 'poll'
                          and option_idx < jsonb_array_length(coalesce(p.poll_options, '[]'))));

create policy comments_read on public.comments for select to authenticated
  using (
    exists (select 1 from public.posts p where p.id = post_id)
    and (author_id = auth.uid() or app_private.is_staff()
         or (not is_hidden and not app_private.is_blocked_between(auth.uid(), author_id)))
  );
create policy comments_create on public.comments for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (select 1 from public.posts p where p.id = post_id and p.audience_band = app_private.current_band()
                and not app_private.is_blocked_between(auth.uid(), p.author_id))
  );
create policy comments_delete_own on public.comments for delete to authenticated
  using (author_id = auth.uid());

create policy reactions_read on public.reactions for select to authenticated
  using (
    (post_id is not null and exists (select 1 from public.posts p where p.id = post_id))
    or (comment_id is not null and exists (select 1 from public.comments c where c.id = comment_id))
  );
create policy reactions_create on public.reactions for insert to authenticated
  with check (
    user_id = auth.uid()
    and ((post_id is not null and exists (select 1 from public.posts p where p.id = post_id and p.audience_band = app_private.current_band()))
      or (comment_id is not null and exists (select 1 from public.comments c where c.id = comment_id)))
  );
create policy reactions_delete_own on public.reactions for delete to authenticated
  using (user_id = auth.uid());

-- NON SEI SOLO: lettura diretta solo dei propri post (l'autore anonimo
-- non deve essere esposto). Il feed passa da list_support_posts().
create policy support_posts_own on public.support_posts for select to authenticated
  using (author_id = auth.uid() or app_private.is_staff());
create policy support_posts_create on public.support_posts for insert to authenticated
  with check (author_id = auth.uid());
create policy support_posts_delete_own on public.support_posts for delete to authenticated
  using (author_id = auth.uid());

create policy support_replies_read on public.support_replies for select to authenticated
  using (app_private.support_post_band(support_post_id) = app_private.current_band()
         and (not is_hidden or author_id = auth.uid() or app_private.is_staff())
         and not app_private.is_blocked_between(auth.uid(), author_id));
create policy support_replies_create on public.support_replies for insert to authenticated
  with check (author_id = auth.uid()
              and app_private.support_post_band(support_post_id) = app_private.current_band());
create policy support_replies_delete_own on public.support_replies for delete to authenticated
  using (author_id = auth.uid());

-- ---------------------------------------------------------------------
-- Eventi
-- ---------------------------------------------------------------------
create policy events_read on public.events for select to authenticated
  using ((status = 'published' and audience_band = app_private.current_band())
         or organizer_id = auth.uid() or app_private.is_staff());
create policy events_create on public.events for insert to authenticated
  with check (organizer_id = auth.uid());
create policy events_delete_own on public.events for delete to authenticated
  using (organizer_id = auth.uid());

create policy event_participants_read on public.event_participants for select to authenticated
  using (exists (select 1 from public.events e where e.id = event_id));
create policy event_participants_join on public.event_participants for insert to authenticated
  with check (user_id = auth.uid());
create policy event_participants_leave on public.event_participants for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- SENTINEL (pagina del fondatore): visibile a tutti gli utenti autenticati
-- ---------------------------------------------------------------------
create policy creator_updates_read on public.creator_updates for select to authenticated
  using (published or app_private.is_creator_or_admin());
create policy creator_updates_write on public.creator_updates for insert to authenticated
  with check (app_private.is_creator_or_admin() and author_id = auth.uid());
create policy creator_updates_edit on public.creator_updates for update to authenticated
  using (app_private.is_creator_or_admin()) with check (app_private.is_creator_or_admin());
create policy creator_updates_delete on public.creator_updates for delete to authenticated
  using (app_private.is_creator_or_admin());

create policy creator_ideas_read on public.creator_ideas for select to authenticated
  using (author_id = auth.uid() or is_public or app_private.is_creator_or_admin());
create policy creator_ideas_create on public.creator_ideas for insert to authenticated
  with check (author_id = auth.uid());
create policy creator_ideas_moderate on public.creator_ideas for update to authenticated
  using (app_private.is_creator_or_admin()) with check (app_private.is_creator_or_admin());

create policy creator_followers_self on public.creator_followers for select to authenticated
  using (user_id = auth.uid());
create policy creator_followers_follow on public.creator_followers for insert to authenticated
  with check (user_id = auth.uid());
create policy creator_followers_unfollow on public.creator_followers for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------
-- Notifiche, segnalazioni, moderazione
-- ---------------------------------------------------------------------
create policy notifications_own on public.notifications for select to authenticated
  using (user_id = auth.uid());
create policy notifications_mark_read on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notifications_delete on public.notifications for delete to authenticated
  using (user_id = auth.uid());

create policy reports_create on public.reports for insert to authenticated
  with check (true);  -- reporter_id viene forzato dal trigger
create policy reports_read on public.reports for select to authenticated
  using (reporter_id = auth.uid() or app_private.is_staff());

create policy moderation_actions_staff on public.moderation_actions for select to authenticated
  using (app_private.is_staff());

create policy admin_access_log_admin on public.admin_access_log for select to authenticated
  using (app_private.is_admin());

-- rate_limit_events: nessuna policy (solo funzioni di sistema)

-- ---------------------------------------------------------------------
-- RPC aggiuntive che dipendono dalle policy
-- ---------------------------------------------------------------------
create or replace function public.list_support_posts(p_limit int default 20, p_offset int default 0)
returns table (id uuid, body text, author_id uuid, author_username text, is_anonymous boolean,
               created_at timestamptz, replies bigint)
language sql stable security definer set search_path = '' as $$
  select s.id, s.body,
         case when s.is_anonymous and s.author_id <> auth.uid() then null else s.author_id end,
         case when s.is_anonymous and s.author_id <> auth.uid() then null else p.username end,
         s.is_anonymous, s.created_at,
         (select count(*) from public.support_replies r where r.support_post_id = s.id and not r.is_hidden)
  from public.support_posts s join public.profiles p on p.id = s.author_id
  where s.audience_band = app_private.current_band()
    and not s.is_hidden
    and not app_private.is_blocked_between(auth.uid(), s.author_id)
  order by s.created_at desc
  limit least(greatest(p_limit, 1), 50) offset greatest(p_offset, 0);
$$;

create or replace function public.creator_follower_count()
returns bigint language sql stable security definer set search_path = '' as $$
  select count(*) from public.creator_followers;
$$;

revoke execute on function public.list_support_posts(int, int), public.creator_follower_count() from public, anon;
grant execute on function public.list_support_posts(int, int), public.creator_follower_count() to authenticated;
revoke execute on function app_private.protect_content_columns(), app_private.after_insert_reaction() from public, anon, authenticated;

-- >>> 20261113000004_storage_realtime.sql
-- =====================================================================
-- WGF CONNECT – Migrazione 0004: Storage e Realtime (solo su Supabase)
-- Su un PostgreSQL senza gli schemi di Supabase questa migrazione
-- non fa nulla (blocchi protetti), così i test locali restano eseguibili.
-- =====================================================================

do $outer$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    -- Bucket PRIVATI: le immagini si leggono con URL firmati a scadenza
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
      ('avatars',     'avatars',     false, 2097152, array['image/jpeg','image/png','image/webp']),
      ('post-images', 'post-images', false, 5242880, array['image/jpeg','image/png','image/webp']),
      ('chat-images', 'chat-images', false, 5242880, array['image/jpeg','image/png','image/webp'])
    on conflict (id) do nothing;

    -- Ogni utente scrive solo nella propria cartella: <bucket>/<user_id>/<file>
    execute $p$
      create policy storage_own_upload on storage.objects for insert to authenticated
      with check (bucket_id in ('avatars','post-images','chat-images')
                  and (storage.foldername(name))[1] = auth.uid()::text)
    $p$;
    execute $p$
      create policy storage_own_delete on storage.objects for delete to authenticated
      using (bucket_id in ('avatars','post-images','chat-images')
             and (storage.foldername(name))[1] = auth.uid()::text)
    $p$;
    -- Avatar: leggibili dal proprietario e da chi può interagire con lui
    execute $p$
      create policy storage_avatar_read on storage.objects for select to authenticated
      using (bucket_id = 'avatars' and (
               (storage.foldername(name))[1] = auth.uid()::text
               or app_private.can_interact(auth.uid(), ((storage.foldername(name))[1])::uuid)))
    $p$;
    -- Immagini dei post: stessa visibilità del post che le contiene
    execute $p$
      create policy storage_post_image_read on storage.objects for select to authenticated
      using (bucket_id = 'post-images' and (
               (storage.foldername(name))[1] = auth.uid()::text
               or exists (select 1 from public.posts p where p.image_path = name)))
    $p$;
    -- Immagini in chat: il destinatario le vede solo dopo l'approvazione
    execute $p$
      create policy storage_chat_image_read on storage.objects for select to authenticated
      using (bucket_id = 'chat-images' and (
               (storage.foldername(name))[1] = auth.uid()::text
               or exists (select 1 from public.messages m
                          where m.image_path = name and m.image_status = 'approved'
                            and app_private.is_conversation_member(m.conversation_id, auth.uid()))))
    $p$;
  end if;

  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages, public.notifications, public.matches;
  end if;
end
$outer$;

-- >>> 20261113000005_app_features.sql
-- =====================================================================
-- WGF CONNECT – Migrazione 0005: funzioni per le schermate dell'app,
-- verifica età manuale per il dating, strumenti amministrativi.
-- =====================================================================

-- ---------------------------------------------------------------------
-- DATING LEGALE – Verifica manuale dell'età adulta (gratuita)
-- L'utente chiede la verifica; un admin la esegue fuori dall'app
-- (es. videochiamata breve senza registrazione) e salva SOLO l'esito.
-- Nessun documento, foto o dato biometrico entra nel database.
-- ---------------------------------------------------------------------
create or replace function public.request_age_verification()
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid();
begin
  if app_private.current_band() is distinct from 'adult' then
    raise exception 'forbidden: solo utenti maggiorenni' using errcode = '42501';
  end if;
  if exists (select 1 from public.age_verifications
             where user_id = v_uid and status in ('pending','verified')) then
    raise exception 'already_requested' using errcode = 'P0409';
  end if;
  perform app_private.enforce_rate_limit('age_verification', 3, interval '1 day');
  insert into public.age_verifications (user_id, method, status) values (v_uid, 'manual_review', 'pending');
end $$;

-- L'esito aggiorna la richiesta in attesa (o ne crea una nuova)
create or replace function public.admin_set_age_verification(p_user uuid, p_status text, p_method text, p_reason text, p_provider_ref text default null)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_status not in ('verified','rejected','expired') then raise exception 'invalid_status' using errcode = 'P0400'; end if;
  if p_status = 'verified' and (select age_band from public.profiles where id = p_user) is distinct from 'adult' then
    raise exception 'not_adult_band' using errcode = 'P0400';
  end if;
  if p_status = 'expired' then
    update public.age_verifications set status = 'expired' where user_id = p_user and status = 'verified';
  else
    update public.age_verifications
       set status = p_status, method = p_method, provider_reference = p_provider_ref,
           verified_at = case when p_status = 'verified' then now() end
     where user_id = p_user and status = 'pending';
    if not found then
      insert into public.age_verifications (user_id, method, status, provider_reference, verified_at)
      values (p_user, p_method, p_status, p_provider_ref, case when p_status = 'verified' then now() end);
    end if;
  end if;
  perform app_private.log_action('age_verification:' || p_status, 'profile', p_user, p_reason);
end $$;

create or replace function public.admin_list_age_verifications()
returns table (id uuid, user_id uuid, username text, status text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app_private.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  return query select v.id, v.user_id, p.username, v.status, v.created_at
    from public.age_verifications v join public.profiles p on p.id = v.user_id
   where v.status = 'pending' order by v.created_at;
end $$;

create or replace function public.my_dating_status()
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'dating_enabled', app_private.cfg_bool('dating_enabled'),
    'adult', app_private.current_band() = 'adult',
    'verification', (select status from public.age_verifications where user_id = auth.uid()
                     order by created_at desc limit 1)
  );
$$;

-- Configurazione (es. accendere il dating) solo per admin, con registro
create or replace function public.admin_set_config(p_key text, p_value jsonb, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_key = 'minors_registration_enabled' and p_value = 'true'::jsonb then
    raise exception 'minors_require_review: attivare i minori richiede una revisione legale documentata' using errcode = 'P0403';
  end if;
  update public.app_config set value = p_value, updated_at = now() where key = p_key;
  if not found then raise exception 'unknown_key' using errcode = 'P0404'; end if;
  insert into public.moderation_actions (actor_id, action, target_type, target_id, reason)
  values (auth.uid(), 'config:' || p_key || '=' || p_value::text, 'config', null, p_reason);
end $$;

-- ---------------------------------------------------------------------
-- Le prove delle segnalazioni NON sono leggibili via API: solo tramite
-- admin_read_reported_message() che registra l'accesso.
-- ---------------------------------------------------------------------
revoke select on public.reports from authenticated, anon;
grant select (id, reporter_id, target_type, target_id, reason, details, status, created_at, resolved_at, resolved_by)
  on public.reports to authenticated;

-- ---------------------------------------------------------------------
-- Funzioni di lettura per l'app: SECURITY INVOKER → valgono le RLS
-- ---------------------------------------------------------------------
create or replace function public.post_json(p public.posts)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id, 'author_id', p.author_id, 'username', a.username, 'display_name', a.display_name,
    'avatar_path', a.avatar_path, 'kind', p.kind, 'body', p.body, 'image_path', p.image_path,
    'hashtags', p.hashtags, 'poll_options', p.poll_options, 'group_id', p.group_id,
    'shared_post_id', p.shared_post_id, 'created_at', p.created_at,
    'likes', (select count(*) from public.reactions r where r.post_id = p.id),
    'comments', (select count(*) from public.comments c where c.post_id = p.id and not c.is_hidden),
    'liked', exists (select 1 from public.reactions r where r.post_id = p.id and r.user_id = auth.uid()),
    'poll_counts', case when p.kind = 'poll' then
        (select jsonb_object_agg(option_idx::text, n) from
           (select option_idx, count(*) n from public.poll_votes v where v.post_id = p.id group by 1) s) end,
    'my_vote', (select option_idx from public.poll_votes v where v.post_id = p.id and v.user_id = auth.uid()),
    'shared', case when p.shared_post_id is not null then
        (select jsonb_build_object('id', s.id, 'body', s.body, 'username', sa.username)
           from public.posts s left join public.profiles sa on sa.id = s.author_id
          where s.id = p.shared_post_id and not s.is_hidden) end
  )
  from (select 1) one
  left join public.profiles a on a.id = p.author_id;
$$;

create or replace function public.get_feed(
  p_hashtag text default null, p_group uuid default null, p_author uuid default null,
  p_limit int default 20, p_before timestamptz default null)
returns setof jsonb language sql stable security invoker set search_path = '' as $$
  select public.post_json(p)
  from public.posts p
  where not p.is_hidden
    and (p_hashtag is null or lower(p_hashtag) = any(p.hashtags))
    and (p_group is null or p.group_id = p_group)
    and (p_author is null or p.author_id = p_author)
    and (p_before is null or p.created_at < p_before)
  order by p.created_at desc
  limit least(greatest(p_limit, 1), 50);
$$;

create or replace function public.get_post(p_id uuid)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select public.post_json(p) from public.posts p where p.id = p_id and not p.is_hidden;
$$;

create or replace function public.get_blocked_users()
returns table (user_id uuid, username text, blocked_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select b.blocked_id, p.username, b.created_at
  from public.blocked_users b join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = auth.uid() order by b.created_at desc;
$$;

create or replace function public.get_conversations()
returns setof jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'kind', c.kind, 'is_active', c.is_active, 'created_at', c.created_at,
    'match_mode', (select m.mode from public.matches m where m.id = c.match_id),
    'other', (select jsonb_build_object('id', o.id, 'username', o.username,
                       'display_name', o.display_name, 'avatar_path', o.avatar_path)
                from public.conversation_participants op join public.profiles o on o.id = op.user_id
               where op.conversation_id = c.id and op.user_id <> auth.uid() limit 1),
    'other_id', (select op.user_id from public.conversation_participants op
                  where op.conversation_id = c.id and op.user_id <> auth.uid() limit 1),
    'last_message', (select jsonb_build_object('body', m.body, 'has_image', m.image_path is not null,
                       'sender_id', m.sender_id, 'created_at', m.created_at, 'deleted', m.deleted_at is not null)
                       from public.messages m where m.conversation_id = c.id order by m.created_at desc limit 1),
    'unread', (select count(*) from public.messages m
                where m.conversation_id = c.id and m.sender_id <> auth.uid() and m.read_at is null)
  )
  from public.conversations c
  order by coalesce((select max(m.created_at) from public.messages m where m.conversation_id = c.id), c.created_at) desc;
$$;

create or replace function public.get_events(p_city text default null, p_include_past boolean default false)
returns setof jsonb language sql stable security invoker set search_path = '' as $$
  select to_jsonb(e) || jsonb_build_object(
    'participants', (select count(*) from public.event_participants ep where ep.event_id = e.id),
    'joined', exists (select 1 from public.event_participants ep where ep.event_id = e.id and ep.user_id = auth.uid()),
    'organizer_username', (select username from public.profiles o where o.id = e.organizer_id),
    'is_mine', e.organizer_id = auth.uid()
  )
  from public.events e
  where (p_city is null or lower(e.city) = lower(p_city))
    and (p_include_past or e.starts_at > now() - interval '6 hours')
    and e.status in ('published','pending_review')
  order by e.starts_at;
$$;

create or replace function public.get_groups()
returns setof jsonb language sql stable security invoker set search_path = '' as $$
  select to_jsonb(g) || jsonb_build_object(
    'members', (select count(*) from public.group_members m where m.group_id = g.id),
    'joined', exists (select 1 from public.group_members m where m.group_id = g.id and m.user_id = auth.uid())
  )
  from public.groups g
  order by (select count(*) from public.group_members m where m.group_id = g.id) desc, g.created_at desc;
$$;

-- Like ricevuti in modalità amicizia (per la sezione "Ti hanno notato")
create or replace function public.unread_counts()
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'notifications', (select count(*) from public.notifications where user_id = auth.uid() and read_at is null),
    'messages', (select count(*) from public.messages m
                  where m.sender_id <> auth.uid() and m.read_at is null)
  );
$$;

-- ---------------------------------------------------------------------
-- Moderazione immagini in chat: coda per lo staff (solo immagini in attesa)
-- ---------------------------------------------------------------------
create or replace function public.admin_list_pending_images()
returns table (message_id uuid, image_path text, sender_id uuid, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  return query select m.id, m.image_path, m.sender_id, m.created_at
    from public.messages m where m.image_status = 'pending' order by m.created_at;
end $$;

create or replace function public.admin_list_reports(p_status text default 'open')
returns setof jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not app_private.is_staff() then raise exception 'forbidden' using errcode = '42501'; end if;
  return query
  select jsonb_build_object('id', r.id, 'target_type', r.target_type, 'target_id', r.target_id,
           'reason', r.reason, 'details', r.details, 'status', r.status, 'created_at', r.created_at,
           'reporter', (select username from public.profiles where id = r.reporter_id),
           'has_evidence', r.evidence is not null,
           'preview', case r.target_type
              when 'post' then (select left(body, 200) from public.posts where id = r.target_id)
              when 'comment' then (select left(body, 200) from public.comments where id = r.target_id)
              when 'support_post' then (select left(body, 200) from public.support_posts where id = r.target_id)
              when 'support_reply' then (select left(body, 200) from public.support_replies where id = r.target_id)
              when 'profile' then (select username || ' – ' || coalesce(left(bio, 150), '') from public.profiles where id = r.target_id)
              when 'event' then (select title from public.events where id = r.target_id)
              when 'group' then (select name from public.groups where id = r.target_id)
              else null end)
  from public.reports r
  where (p_status = 'all' or r.status = p_status or (p_status = 'open' and r.status = 'reviewing'))
  order by r.created_at;
end $$;

do $outer$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    execute $p$
      create policy storage_chat_image_staff_review on storage.objects for select to authenticated
      using (bucket_id = 'chat-images' and app_private.is_staff()
             and exists (select 1 from public.messages m where m.image_path = name and m.image_status = 'pending'))
    $p$;
  end if;
end
$outer$;

revoke execute on function
  public.request_age_verification(), public.admin_list_age_verifications(), public.my_dating_status(),
  public.admin_set_config(text, jsonb, text), public.get_feed(text, uuid, uuid, int, timestamptz),
  public.get_conversations(), public.get_events(text, boolean), public.get_groups(), public.unread_counts(),
  public.admin_list_pending_images(), public.admin_list_reports(text),
  public.admin_set_age_verification(uuid, text, text, text, text),
  public.post_json(public.posts), public.get_post(uuid), public.get_blocked_users()
from public, anon;
grant execute on function
  public.request_age_verification(), public.admin_list_age_verifications(), public.my_dating_status(),
  public.admin_set_config(text, jsonb, text), public.get_feed(text, uuid, uuid, int, timestamptz),
  public.get_conversations(), public.get_events(text, boolean), public.get_groups(), public.unread_counts(),
  public.admin_list_pending_images(), public.admin_list_reports(text),
  public.admin_set_age_verification(uuid, text, text, text, text),
  public.post_json(public.posts), public.get_post(uuid), public.get_blocked_users()
to authenticated;

-- Hashtag normalizzati: minuscoli, senza '#', estratti anche dal testo
create or replace function app_private.normalize_hashtags()
returns trigger language plpgsql as $$
begin
  new.hashtags := array(
    select distinct lower(regexp_replace(h, '^#', ''))
    from (select unnest(coalesce(new.hashtags, '{}')) h
          union all
          select (regexp_matches(coalesce(new.body, ''), '#([[:alnum:]_]{2,40})', 'g'))[1]) s
    where h <> ''
    limit 15);
  return new;
end $$;
create trigger posts_normalize_hashtags before insert or update of body, hashtags on public.posts
  for each row execute function app_private.normalize_hashtags();
revoke execute on function app_private.normalize_hashtags() from public, anon, authenticated;

-- >>> 20261113000006_wgf_official.sql
-- =====================================================================
-- WGF CONNECT – Migrazione 0006: contenuti ufficiali WGF (con autorizzazione)
-- Logo, foto e contenuti forniti dai titolari vengono caricati dal
-- fondatore/admin dal pannello: nessun contenuto è incluso nel codice.
-- =====================================================================

insert into public.app_config (key, value) values
  ('wgf_content_authorized', 'false'::jsonb),
  ('wgf_permission_note', '"Logo, foto e contenuti WGF utilizzati con l''autorizzazione dei titolari."'::jsonb)
on conflict (key) do nothing;

create table public.official_content (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null check (kind in ('news','gallery','video','info','logo')),
  title      text not null check (char_length(title) between 1 and 150),
  body       text check (char_length(body) <= 10000),
  image_path text,
  link_url   text check (link_url ~ '^https://'),
  credits    text check (char_length(credits) <= 200),   -- es. "Foto: © titolare, uso autorizzato"
  published  boolean not null default false,
  sort_order int not null default 0,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create index official_content_pub_idx on public.official_content (kind, sort_order, created_at desc) where published;

alter table public.official_content enable row level security;
alter table public.official_content force row level security;

-- Visibili a tutti gli utenti autenticati SOLO se pubblicati e se l'autorizzazione è attiva
create policy official_content_read on public.official_content for select to authenticated
  using ((published and app_private.cfg_bool('wgf_content_authorized')) or app_private.is_creator_or_admin());
create policy official_content_write on public.official_content for insert to authenticated
  with check (app_private.is_creator_or_admin() and created_by = auth.uid());
create policy official_content_edit on public.official_content for update to authenticated
  using (app_private.is_creator_or_admin()) with check (app_private.is_creator_or_admin());
create policy official_content_delete on public.official_content for delete to authenticated
  using (app_private.is_creator_or_admin());

do $outer$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('official', 'official', false, 10485760, array['image/jpeg','image/png','image/webp','image/svg+xml'])
    on conflict (id) do nothing;
    execute $p$
      create policy storage_official_read on storage.objects for select to authenticated
      using (bucket_id = 'official'
             and (app_private.cfg_bool('wgf_content_authorized') or app_private.is_creator_or_admin()))
    $p$;
    execute $p$
      create policy storage_official_write on storage.objects for insert to authenticated
      with check (bucket_id = 'official' and app_private.is_creator_or_admin())
    $p$;
    execute $p$
      create policy storage_official_delete on storage.objects for delete to authenticated
      using (bucket_id = 'official' and app_private.is_creator_or_admin())
    $p$;
  end if;
end
$outer$;

-- Le stringhe di config non booleane sono modificabili solo dall'admin con registro
create or replace function public.admin_set_config_text(p_key text, p_value text, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_key <> 'wgf_permission_note' then raise exception 'invalid_key' using errcode = 'P0400'; end if;
  update public.app_config set value = to_jsonb(p_value), updated_at = now() where key = p_key;
  insert into public.moderation_actions (actor_id, action, target_type, target_id, reason)
  values (auth.uid(), 'config:' || p_key, 'config', null, p_reason);
end $$;
revoke execute on function public.admin_set_config_text(text, text, text) from public, anon;
grant execute on function public.admin_set_config_text(text, text, text) to authenticated;

-- >>> 20261113000007_fix_search_path.sql
-- WGF CONNECT – Migrazione 0007: search_path fisso sulle funzioni trigger (avviso del linter Supabase)
alter function app_private.protect_profile_columns() set search_path = '';
alter function app_private.set_updated_at() set search_path = '';
alter function app_private.protect_content_columns() set search_path = '';
alter function app_private.normalize_hashtags() set search_path = '';

-- >>> 20261113000008_wgf_quiz.sql
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

-- >>> 20261113000009_wgf_fan_card.sql
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

-- >>> 20261113000010_announcements.sql
-- =====================================================================
-- WGF CONNECT – Migrazione 0010: comunicazioni ufficiali (alert admin)
-- Il fondatore/admin invia un avviso: tutti lo vedono come finestra a
-- comparsa (una volta) e come notifica nella campanella.
-- =====================================================================
create table public.announcements (
  id         uuid primary key default gen_random_uuid(),
  author_id  uuid references public.profiles(id) on delete set null,
  title      text not null check (char_length(title) between 3 and 120),
  body       text not null check (char_length(body) between 1 and 3000),
  level      text not null default 'important' check (level in ('info','important','urgent')),
  link_url   text check (link_url ~ '^https://'),
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  expires_at timestamptz
);
create index announcements_active_idx on public.announcements (created_at desc) where active;

create table public.announcement_dismissals (
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  user_id         uuid not null references public.profiles(id) on delete cascade,
  dismissed_at    timestamptz not null default now(),
  primary key (announcement_id, user_id)
);

alter table public.announcements enable row level security;
alter table public.announcements force row level security;
alter table public.announcement_dismissals enable row level security;
alter table public.announcement_dismissals force row level security;

-- Tutti gli utenti attivi leggono gli avvisi; scrivono solo tramite RPC
create policy announcements_read on public.announcements for select to authenticated
  using (app_private.current_band() is not null or app_private.is_creator_or_admin());
create policy announcement_dismissals_own on public.announcement_dismissals for select to authenticated
  using (user_id = auth.uid());

-- nuovo tipo di notifica
alter table public.notifications drop constraint if exists notifications_kind_check;
alter table public.notifications add constraint notifications_kind_check check (kind in
  ('match','message','like','comment','reply','event','community','creator','friend_request','moderation','announcement'));

create or replace function public.admin_send_announcement(
  p_title text, p_body text, p_level text default 'important',
  p_expires_hours int default 72, p_link text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not app_private.is_creator_or_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  if p_level not in ('info','important','urgent') then raise exception 'invalid_level' using errcode = 'P0400'; end if;
  perform app_private.enforce_rate_limit('announcements', 10, interval '1 hour');
  insert into public.announcements (author_id, title, body, level, link_url, expires_at)
  values (auth.uid(), p_title, p_body, p_level, nullif(p_link, ''),
          case when p_expires_hours is null or p_expires_hours <= 0 then null
               else now() + make_interval(hours => least(p_expires_hours, 24 * 90)) end)
  returning id into v_id;
  -- notifica a tutti gli utenti attivi (le comunicazioni ufficiali ignorano le preferenze)
  insert into public.notifications (user_id, kind, payload)
  select p.id, 'announcement', jsonb_build_object('announcement_id', v_id, 'title', p_title, 'level', p_level)
  from public.profiles p where p.status = 'active';
  insert into public.moderation_actions (actor_id, action, target_type, target_id, reason)
  values (auth.uid(), 'announcement:' || p_level, 'announcement', v_id, left(p_title, 200));
  return v_id;
end $$;

create or replace function public.admin_end_announcement(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not app_private.is_creator_or_admin() then raise exception 'forbidden' using errcode = '42501'; end if;
  update public.announcements set active = false where id = p_id;
  insert into public.moderation_actions (actor_id, action, target_type, target_id, reason)
  values (auth.uid(), 'announcement:ended', 'announcement', p_id, 'Comunicazione terminata');
end $$;

-- Avvisi attivi non ancora chiusi dall'utente (per la finestra a comparsa)
create or replace function public.get_pending_announcements()
returns setof public.announcements language sql stable security definer set search_path = '' as $$
  select a.* from public.announcements a
  where a.active and (a.expires_at is null or a.expires_at > now())
    and app_private.current_band() is not null
    and not exists (select 1 from public.announcement_dismissals d
                    where d.announcement_id = a.id and d.user_id = auth.uid())
  order by a.created_at desc limit 5;
$$;

create or replace function public.dismiss_announcement(p_id uuid)
returns void language sql security definer set search_path = '' as $$
  insert into public.announcement_dismissals (announcement_id, user_id)
  select p_id, auth.uid() where auth.uid() is not null
  on conflict do nothing;
$$;

revoke execute on function public.admin_send_announcement(text, text, text, int, text), public.admin_end_announcement(uuid),
  public.get_pending_announcements(), public.dismiss_announcement(uuid) from public, anon;
grant execute on function public.admin_send_announcement(text, text, text, int, text), public.admin_end_announcement(uuid),
  public.get_pending_announcements(), public.dismiss_announcement(uuid) to authenticated;

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.announcements;
  end if;
end $$;
