-- =====================================================================
-- WGF CONNECT – Test delle funzioni usate dalle schermate (migrazione 0005)
-- =====================================================================
\echo '--- 14. Dating legale: verifica manuale dell''età ---'
begin;
select tests.login('33333333-3333-3333-3333-333333333333');
set local role authenticated;
select tests.eq('stato dating iniziale', $$select public.my_dating_status() ->> 'dating_enabled'$$, 'false');
select tests.ok('C chiede la verifica', $$select public.request_age_verification()$$);
select tests.denied('richiesta doppia bloccata', $$select public.request_age_verification()$$);
select tests.eq('stato: in attesa', $$select public.my_dating_status() ->> 'verification'$$, 'pending');
select tests.login('44444444-4444-4444-4444-444444444444');
select tests.denied('un minore non può chiedere la verifica', $$select public.request_age_verification()$$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.denied('un utente normale non vede la coda verifiche', $$select * from public.admin_list_age_verifications()$$);
select tests.denied('un utente normale non può accendere il dating',
  $$select public.admin_set_config('dating_enabled', 'true', 'test')$$);
select tests.login('55555555-5555-5555-5555-555555555555');
select tests.eq('l''admin vede la richiesta', $$select username from public.admin_list_age_verifications()$$, 'test_adulto_c');
select tests.ok('l''admin approva', $$select public.admin_set_age_verification('33333333-3333-3333-3333-333333333333', 'verified', 'manual_review', 'Videochiamata senza registrazione')$$);
select tests.ok('l''admin accende il dating', $$select public.admin_set_config('dating_enabled', 'true', 'Lancio dating')$$);
select tests.denied('i minori non si attivano senza revisione legale',
  $$select public.admin_set_config('minors_registration_enabled', 'true', 'test')$$);
select tests.login('33333333-3333-3333-3333-333333333333');
select tests.eq('C ora è verificato', $$select public.my_dating_status() ->> 'verification'$$, 'verified');
select tests.eq('C vede A e B nel dating (verificati)',
  $$select count(*) from public.discover_profiles('dating')$$, '2');
select tests.eq('like dating ora consentito',
  $$select public.like_user('11111111-1111-1111-1111-111111111111', 'dating') ->> 'matched'$$, 'false');
rollback;

\echo '--- 15. Prove delle segnalazioni non leggibili via API ---'
begin;
select tests.login('55555555-5555-5555-5555-555555555555');
set local role authenticated;
select tests.denied('lo staff non legge la colonna evidence direttamente', $$select evidence from public.reports$$);
select tests.ok('lo staff legge la coda segnalazioni (senza prove)', $$select * from public.admin_list_reports('all')$$);
rollback;

\echo '--- 16. Feed, hashtag, sondaggi, conversazioni, eventi, gruppi ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
insert into public.posts (author_id, body, audience_band) values (auth.uid(), 'Chi viene al raduno? #WGF #Raduno', 'adult');
select tests.eq('hashtag estratti e normalizzati',
  $$select string_agg(h, ',' order by h) from public.posts p, unnest(p.hashtags) h where p.author_id = auth.uid()$$, 'raduno,wgf');
select tests.eq('filtro feed per hashtag', $$select count(*) from public.get_feed('WGF')$$, '1');
insert into public.posts (author_id, kind, body, poll_options, audience_band)
  values (auth.uid(), 'poll', 'Gioco preferito?', '["A","B"]', 'adult');
select tests.ok('voto sondaggio', $$insert into public.poll_votes (post_id, user_id, option_idx) select id, auth.uid(), 1 from public.posts where kind = 'poll'$$);
select tests.denied('voto su opzione inesistente', $$insert into public.poll_votes (post_id, user_id, option_idx) select id, '22222222-2222-2222-2222-222222222222', 5 from public.posts where kind = 'poll'$$);
select tests.eq('conteggio voti nel feed', $$select f -> 'poll_counts' ->> '1' from public.get_feed() f where f ->> 'kind' = 'poll'$$, '1');
select tests.eq('feed adulto: 3 post visibili (seed B + 2 di A)', $$select count(*) from public.get_feed()$$, '3');
select tests.eq('gruppi visibili alla fascia adulta', $$select count(*) from public.get_groups()$$, '1');
select tests.eq('eventi visibili', $$select count(*) from public.get_events()$$, '1');
select public.like_user('22222222-2222-2222-2222-222222222222', 'friendship');
select tests.login('22222222-2222-2222-2222-222222222222');
select public.like_user('11111111-1111-1111-1111-111111111111', 'friendship');
insert into public.messages (conversation_id, sender_id, body) select id, auth.uid(), 'Ciao A' from public.conversations limit 1;
select tests.login('11111111-1111-1111-1111-111111111111');
select tests.eq('lista conversazioni con non letti', $$select (f ->> 'unread') from public.get_conversations() f$$, '1');
select tests.eq('contatori non letti', $$select public.unread_counts() ->> 'messages'$$, '1');
select tests.eq('get_post restituisce il post', $$select public.get_post('bbbbbbbb-0000-0000-0000-000000000001') ->> 'username'$$, 'test_adulto_b');
select public.block_user('33333333-3333-3333-3333-333333333333');
select tests.eq('lista utenti bloccati con username', $$select username from public.get_blocked_users()$$, 'test_adulto_c');
select tests.login('44444444-4444-4444-4444-444444444444');
select tests.eq('il minore non apre un post adulto via get_post', $$select public.get_post('bbbbbbbb-0000-0000-0000-000000000001') is null$$, 'true');
select tests.eq('il minore non vede il feed adulto nemmeno via get_feed',
  $$select count(*) from public.get_feed() f where f ->> 'author_id' <> '44444444-4444-4444-4444-444444444444'$$, '0');
select tests.eq('il minore non vede eventi adulti', $$select count(*) from public.get_events()$$, '0');
rollback;

\echo '--- 17. Moderazione immagini in chat ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select public.like_user('22222222-2222-2222-2222-222222222222', 'friendship');
select tests.login('22222222-2222-2222-2222-222222222222');
select public.like_user('11111111-1111-1111-1111-111111111111', 'friendship');
select tests.ok('B invia un''immagine (il client prova a dichiararla approvata)',
  $$insert into public.messages (conversation_id, sender_id, image_path, image_status)
    select id, auth.uid(), '22222222-2222-2222-2222-222222222222/a.jpg', 'approved' from public.conversations limit 1$$);
select tests.eq('lo stato è forzato a pending', $$select image_status from public.messages limit 1$$, 'pending');
select tests.login('55555555-5555-5555-5555-555555555555');
select tests.eq('lo staff vede la coda immagini', $$select count(*) from public.admin_list_pending_images()$$, '1');
select tests.ok('lo staff rifiuta l''immagine', $$select public.admin_review_image((select message_id from public.admin_list_pending_images()), 'rejected', 'Contenuto non consentito')$$);
select tests.login('11111111-1111-1111-1111-111111111111');
select tests.eq('il destinatario vede solo "rifiutata", senza file', $$select image_status || ':' || coalesce(image_path, 'nessun file') from public.messages limit 1$$, 'rejected:nessun file');
select tests.denied('un utente normale non vede la coda immagini', $$select * from public.admin_list_pending_images()$$);
rollback;
