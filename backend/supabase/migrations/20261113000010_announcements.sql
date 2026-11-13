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
