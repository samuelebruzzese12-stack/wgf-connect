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
