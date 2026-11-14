import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/env.dart';

/// Notifiche ad app chiusa SENZA Firebase:
/// Android avvia un controllo periodico in sottofondo (circa ogni 15 minuti,
/// solo con connessione) che legge le comunicazioni ufficiali e le notifiche
/// non lette e mostra una notifica di sistema.
const _taskName = 'wgf-background-check';
const _channelId = 'wgf_alerts';
const _channelName = 'Comunicazioni e novità WGF';

final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

Future<void> _initNotifications() async {
  await _notifications.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
}

NotificationDetails _details({bool urgent = false}) => NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Avvisi del fondatore, messaggi, match e novità della community',
        importance: Importance.max,
        priority: Priority.high,
        color: urgent ? const Color(0xFFFF4D6A) : const Color(0xFFFFB627),
        styleInformation: const BigTextStyleInformation(''),
      ),
    );

/// Da chiamare all'avvio dell'app.
Future<void> setupBackgroundAlerts() async {
  try {
    await _initNotifications();
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (e) {
    debugPrint('Notifiche in sottofondo non disponibili: $e');
  }
}

@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await _initNotifications();
      await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return true; // utente non connesso
      await _checkAndNotify(client);
    } catch (e) {
      debugPrint('Controllo in sottofondo fallito: $e');
    }
    return true;
  });
}

Future<void> _checkAndNotify(SupabaseClient client) async {
  final prefs = await SharedPreferences.getInstance();
  final notified = prefs.getStringList('wgf_notified_announcements') ?? <String>[];

  // 1. Comunicazioni ufficiali non ancora viste
  final pending = List<Map<String, dynamic>>.from(await client.rpc('get_pending_announcements') as List);
  for (final a in pending.reversed) {
    final id = a['id'] as String;
    if (notified.contains(id)) continue;
    final level = (a['level'] ?? 'important') as String;
    final label = switch (level) { 'urgent' => '🚨 URGENTE', 'info' => 'ℹ️ Info', _ => '📢 Comunicazione' };
    await _notifications.show(
      id.hashCode & 0x7fffffff,
      '$label · ${a['title']}',
      (a['body'] ?? '') as String,
      _details(urgent: level == 'urgent'),
    );
    notified.add(id);
  }
  await prefs.setStringList('wgf_notified_announcements', notified.length > 50 ? notified.sublist(notified.length - 50) : notified);

  // 2. Riepilogo delle altre notifiche non lette arrivate dall'ultimo controllo
  final since = prefs.getString('wgf_last_check') ?? DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();
  final rows = await client
      .from('notifications')
      .select('kind')
      .isFilter('read_at', null)
      .neq('kind', 'announcement')
      .gt('created_at', since);
  await prefs.setString('wgf_last_check', DateTime.now().toUtc().toIso8601String());
  if (rows.isEmpty) return;

  final counts = <String, int>{};
  for (final r in rows) {
    counts.update(r['kind'] as String, (v) => v + 1, ifAbsent: () => 1);
  }
  final parts = <String>[
    if (counts['message'] != null) '${counts['message']} ${counts['message'] == 1 ? 'messaggio' : 'messaggi'}',
    if (counts['match'] != null) '${counts['match']} match',
    if (counts['friend_request'] != null) '${counts['friend_request']} richieste di amicizia',
    if ((counts['like'] ?? 0) + (counts['comment'] ?? 0) + (counts['reply'] ?? 0) > 0)
      '${(counts['like'] ?? 0) + (counts['comment'] ?? 0) + (counts['reply'] ?? 0)} interazioni ai tuoi post',
    if (counts['creator'] != null) 'novità da SENTINEL',
    if (counts['event'] != null) 'novità sugli eventi',
  ];
  await _notifications.show(
    424242,
    '🦁 Novità su WGF CONNECT',
    parts.isEmpty ? 'Hai nuove notifiche' : 'Hai ${parts.join(', ')}',
    _details(),
  );
}
