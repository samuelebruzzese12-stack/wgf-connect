\echo '--- 18. Contenuti ufficiali WGF ---'
begin;
select tests.login('66666666-6666-6666-6666-666666666666');
set local role authenticated;
select tests.ok('Sentinel carica un contenuto ufficiale',
  $$insert into public.official_content (kind, title, body, published, created_by) values ('news', '[TEST] Notizia', 'testo', true, auth.uid())$$);
select tests.ok('Sentinel carica una bozza',
  $$insert into public.official_content (kind, title, published, created_by) values ('gallery', '[TEST] Bozza', false, auth.uid())$$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.eq('senza autorizzazione attiva gli utenti non vedono nulla', 'select count(*) from public.official_content', '0');
select tests.denied('un utente normale non può caricare contenuti ufficiali',
  $$insert into public.official_content (kind, title, published, created_by) values ('news', 'falso', true, auth.uid())$$);
select tests.denied('un utente normale non può attivare l''autorizzazione',
  $$select public.admin_set_config('wgf_content_authorized', 'true', 'test')$$);
select tests.login('55555555-5555-5555-5555-555555555555');
select tests.ok('l''admin attiva l''autorizzazione', $$select public.admin_set_config('wgf_content_authorized', 'true', 'Permesso scritto ricevuto')$$);
select tests.ok('l''admin aggiorna la nota di autorizzazione', $$select public.admin_set_config_text('wgf_permission_note', 'Contenuti WGF usati con autorizzazione', 'test')$$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.eq('ora gli utenti vedono solo i contenuti pubblicati', 'select count(*) from public.official_content', '1');
select tests.login('44444444-4444-4444-4444-444444444444');
select tests.eq('visibili anche alla fascia teen', 'select count(*) from public.official_content', '1');
rollback;

\echo '--- 19. Quiz WGF ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.eq('quiz: 8 su 10 = 80', $$select public.submit_wgf_quiz(8, 10)::text$$, '80');
select tests.eq('quiz: un punteggio più basso non sovrascrive il migliore', $$select public.submit_wgf_quiz(3, 10)::text$$, '80');
select tests.denied('quiz: risposte impossibili rifiutate', $$select public.submit_wgf_quiz(11, 10)$$);
select tests.denied('quiz: il punteggio non si modifica a mano', $$update public.profiles set wgf_quiz_score = 100 where id = auth.uid()$$);
select tests.eq('il badge è visibile nella scheda profilo', $$select public.get_profile(auth.uid()) ->> 'wgf_quiz_score'$$, '80');
rollback;

\echo '--- 20. Tessera Fan WGF ---'
begin;
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.ok('salvo "fan dal" e serie preferita', $$update public.profiles set wgf_fan_since = 2016, wgf_favorite_series = 'Le storie del mistero' where id = auth.uid()$$);
select tests.denied('anno impossibile rifiutato', $$update public.profiles set wgf_fan_since = 1990 where id = auth.uid()$$);
select tests.eq('numero tessera calcolato', $$select (public.my_member_number() > 0)::text$$, 'true');
select tests.eq('serie preferita nella scheda profilo', $$select public.get_profile(auth.uid()) ->> 'wgf_favorite_series'$$, 'Le storie del mistero');
rollback;
