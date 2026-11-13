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
