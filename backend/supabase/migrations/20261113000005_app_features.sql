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
