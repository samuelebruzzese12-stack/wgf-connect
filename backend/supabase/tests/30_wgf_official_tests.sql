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
