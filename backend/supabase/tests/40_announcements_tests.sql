\echo '--- 21. Comunicazioni ufficiali ---'
begin;
select tests.login('22222222-2222-2222-2222-222222222222');
set local role authenticated;
select tests.denied('un utente normale non può mandare avvisi',
  $$select public.admin_send_announcement('Falso avviso', 'testo', 'urgent')$$);
select tests.denied('un utente normale non può inserire avvisi in tabella',
  $$insert into public.announcements (title, body) values ('falso', 'x')$$);
select tests.login('66666666-6666-6666-6666-666666666666');
select tests.ok('Sentinel invia una comunicazione importante',
  $$select public.admin_send_announcement('Manutenzione stasera', 'L''app sarà ferma dalle 23 alle 24.', 'important', 24)$$);
select tests.denied('livello non valido rifiutato', $$select public.admin_send_announcement('Titolo', 'x', 'boh')$$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.eq('B riceve la notifica', $$select count(*) from public.notifications where kind = 'announcement'$$, '1');
select tests.eq('B vede l''avviso in attesa', $$select title from public.get_pending_announcements()$$, 'Manutenzione stasera');
select tests.ok('B chiude l''avviso', $$select public.dismiss_announcement((select id from public.get_pending_announcements()))$$);
select tests.eq('non ricompare più', $$select count(*) from public.get_pending_announcements()$$, '0');
select tests.login('44444444-4444-4444-4444-444444444444');
select tests.eq('arriva anche alla fascia teen', $$select count(*) from public.get_pending_announcements()$$, '1');
select tests.login('77777777-7777-7777-7777-777777777777');
select tests.eq('un utente sospeso non la riceve', $$select count(*) from public.notifications where kind = 'announcement'$$, '0');
select tests.login('55555555-5555-5555-5555-555555555555');
select tests.ok('l''admin termina la comunicazione', $$select public.admin_end_announcement((select id from public.announcements limit 1))$$);
select tests.login('44444444-4444-4444-4444-444444444444');
select tests.eq('terminata: non compare più a nessuno', $$select count(*) from public.get_pending_announcements()$$, '0');
rollback;
