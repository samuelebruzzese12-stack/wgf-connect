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
  check (deleted_at is not null or body is not null or image_path is not null),
  check ((image_path is null) = (image_status is null))
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
