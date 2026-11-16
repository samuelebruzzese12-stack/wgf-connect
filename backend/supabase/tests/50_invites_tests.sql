\echo '--- 22. Inviti e classifica ---'
begin;
select tests.eq('tutti hanno un codice invito', $$select count(*) from public.profiles where invite_code is null$$, '0');
select tests.login('11111111-1111-1111-1111-111111111111');
set local role authenticated;
select tests.denied('non posso cambiarmi il contatore inviti',
  $$update public.profiles set invite_count = 99 where id = auth.uid()$$);
select tests.denied('non posso cambiarmi il codice',
  $$update public.profiles set invite_code = 'WGF-AAAAAA' where id = auth.uid()$$);
select tests.denied('non posso usare il mio codice',
  $$select public.redeem_invite((select invite_code from public.profiles where id = auth.uid()))$$);
select tests.denied('codice inesistente rifiutato', $$select public.redeem_invite('WGF-NOPE00')$$);
select tests.denied('un adulto non può usare il codice di un minore',
  $$select public.redeem_invite((select invite_code from public.profiles where id = '44444444-4444-4444-4444-444444444444'))$$);
select tests.eq('A usa il codice di B', $$select public.redeem_invite(lower((select invite_code from public.profiles where id = '22222222-2222-2222-2222-222222222222')))$$, 'test_adulto_b');
select tests.denied('un solo codice per persona',
  $$select public.redeem_invite((select invite_code from public.profiles where id = '33333333-3333-3333-3333-333333333333'))$$);
select tests.login('22222222-2222-2222-2222-222222222222');
select tests.denied('B non può usare il codice di chi ha invitato (giro)',
  $$select public.redeem_invite((select invite_code from public.profiles where id = '11111111-1111-1111-1111-111111111111'))$$);
select tests.eq('B ha 1 invito e il grado Reclutatore', $$select (public.my_invite_info())->>'level'$$, 'Reclutatore');
select tests.eq('B riceve la notifica', $$select count(*) from public.notifications where payload->>'type' = 'invite'$$, '1');
select tests.eq('B primo nella classifica inviti', $$select username from public.fan_leaderboard('invites') where rank = 1$$, 'test_adulto_b');
select tests.eq('la classifica di un adulto non mostra minori',
  $$select count(*) from public.fan_leaderboard('quiz') where username = 'test_minore'$$, '0');
select tests.denied('tipo classifica non valido', $$select * from public.fan_leaderboard('soldi')$$);
select tests.login('44444444-4444-4444-4444-444444444444');
select tests.eq('il minore vede solo la fascia teen',
  $$select count(*) from public.fan_leaderboard('invites') where username like 'test_adulto%'$$, '0');
rollback;
