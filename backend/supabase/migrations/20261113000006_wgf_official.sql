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
