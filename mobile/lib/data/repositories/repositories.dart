import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/authentication/data/auth_repository.dart';
import '../models/models.dart';

String get _uid => Supabase.instance.client.auth.currentUser!.id;

final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(supabaseProvider).auth.currentUser?.id;
});

// =====================================================================
// PROFILO
// =====================================================================
final profileRepoProvider = Provider((ref) => ProfileRepository(ref.watch(supabaseProvider)));

final myProfileProvider = FutureProvider<MyProfile?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  final row = await ref.watch(supabaseProvider).from('profiles').select().eq('id', uid).maybeSingle();
  return row == null ? null : MyProfile(row);
});

final profileCardProvider = FutureProvider.family<ProfileCard?, String>((ref, id) async {
  final res = await ref.watch(supabaseProvider).rpc('get_profile', params: {'p_user': id});
  return res == null ? null : ProfileCard.fromJson(Map<String, dynamic>.from(res as Map));
});

final myPreferencesProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  return ref.watch(supabaseProvider).from('user_preferences').select().eq('user_id', uid).maybeSingle();
});

/// URL firmato (temporaneo) per un file in un bucket privato. Cache per sessione.
final signedUrlProvider = FutureProvider.family<String?, ({String bucket, String path})>((ref, f) async {
  try {
    return await ref.watch(supabaseProvider).storage.from(f.bucket).createSignedUrl(f.path, 60 * 60);
  } catch (_) {
    return null;
  }
});

class ProfileRepository {
  ProfileRepository(this._c);
  final SupabaseClient _c;

  Future<void> update(Map<String, dynamic> fields) =>
      _c.from('profiles').update(fields).eq('id', _uid);

  Future<void> updatePreferences(Map<String, dynamic> fields) =>
      _c.from('user_preferences').update(fields).eq('user_id', _uid);

  Future<String> uploadAvatar(Uint8List bytes) async {
    final path = '$_uid/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _c.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    await update({'avatar_path': path});
    return path;
  }

  Future<Map<String, dynamic>> exportData() async =>
      Map<String, dynamic>.from(await _c.rpc('export_my_data') as Map);

  Future<List<Map<String, dynamic>>> blockedUsers() async =>
      List<Map<String, dynamic>>.from(await _c.rpc('get_blocked_users') as List);

  Future<void> unblock(String userId) => _c.rpc('unblock_user', params: {'p_target': userId});

  Future<Map<String, bool>> consents() async {
    final rows = await _c
        .from('user_consents')
        .select('consent_type, granted, created_at')
        .order('created_at', ascending: false);
    final out = <String, bool>{};
    for (final r in rows) {
      out.putIfAbsent(r['consent_type'] as String, () => r['granted'] as bool);
    }
    return out;
  }

  Future<void> setConsent(String type, bool granted) =>
      _c.rpc('set_consent', params: {'p_type': type, 'p_granted': granted});

  /// Elimina i file dell'utente dai bucket e poi l'account (cascade sul database).
  Future<void> deleteAccount() async {
    for (final bucket in ['avatars', 'post-images', 'chat-images']) {
      try {
        final files = await _c.storage.from(bucket).list(path: _uid);
        if (files.isNotEmpty) {
          await _c.storage.from(bucket).remove([for (final f in files) '$_uid/${f.name}']);
        }
      } catch (_) {/* bucket vuoto o non accessibile: si prosegue */}
    }
    await _c.rpc('delete_my_account');
    await _c.auth.signOut();
  }
}

// =====================================================================
// DISCOVER, FANFINDER, MATCH, AMICIZIE, DATING
// =====================================================================
final discoverRepoProvider = Provider((ref) => DiscoverRepository(ref.watch(supabaseProvider)));

final datingStatusProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(currentUserIdProvider);
  return Map<String, dynamic>.from(await ref.watch(supabaseProvider).rpc('my_dating_status') as Map);
});

final pendingFriendRequestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return [];
  final rows = await ref
      .watch(supabaseProvider)
      .from('friendships')
      .select('id, requester_id, created_at')
      .eq('addressee_id', uid)
      .eq('status', 'pending')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
});

class DiscoverFilter {
  const DiscoverFilter({this.mode = 'friendship', this.city, this.interest, this.minAge, this.maxAge});
  final String mode;
  final String? city;
  final String? interest;
  final int? minAge;
  final int? maxAge;
}

class DiscoverRepository {
  DiscoverRepository(this._c);
  final SupabaseClient _c;

  Future<List<ProfileCard>> discover(DiscoverFilter f, {int limit = 20, int offset = 0}) async {
    final res = await _c.rpc('discover_profiles', params: {
      'p_mode': f.mode,
      'p_city': (f.city?.trim().isEmpty ?? true) ? null : f.city!.trim(),
      'p_interest': f.interest,
      'p_min_age': f.minAge,
      'p_max_age': f.maxAge,
      'p_limit': limit,
      'p_offset': offset,
    });
    return [for (final r in res as List) ProfileCard.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  /// action: like | pass | super_like
  Future<Map<String, dynamic>> swipe(String target, String mode, String action) async =>
      Map<String, dynamic>.from(await _c.rpc('like_user', params: {
        'p_target': target,
        'p_mode': mode,
        'p_action': action,
      }) as Map);

  Future<void> unmatch(String matchId) => _c.rpc('unmatch', params: {'p_match': matchId});

  Future<void> sendFriendRequest(String target) =>
      _c.rpc('send_friend_request', params: {'p_target': target});

  Future<String?> respondFriendRequest(String id, bool accept) async =>
      await _c.rpc('respond_friend_request', params: {'p_friendship': id, 'p_accept': accept}) as String?;

  Future<void> requestAgeVerification() => _c.rpc('request_age_verification');

  Future<String?> matchIdForConversation(String conversationId) async {
    final row = await _c.from('conversations').select('match_id').eq('id', conversationId).maybeSingle();
    return row?['match_id'] as String?;
  }
}

// =====================================================================
// CHAT
// =====================================================================
final chatRepoProvider = Provider((ref) => ChatRepository(ref.watch(supabaseProvider)));

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  ref.watch(currentUserIdProvider);
  final res = await ref.watch(supabaseProvider).rpc('get_conversations');
  return [for (final r in res as List) Conversation(Map<String, dynamic>.from(r as Map))];
});

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, conversationId) {
  return ref
      .watch(supabaseProvider)
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true)
      .map((rows) => [for (final r in rows) ChatMessage(r)]);
});

class ChatRepository {
  ChatRepository(this._c);
  final SupabaseClient _c;

  Future<void> sendText(String conversationId, String text) => _c.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': _uid,
        'body': text,
      });

  /// L'immagine resta "in revisione" finché un moderatore non la approva.
  Future<void> sendImage(String conversationId, Uint8List bytes) async {
    final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _c.storage.from('chat-images').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    await _c.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _uid,
      'image_path': path,
      'image_status': 'pending',
    });
  }

  Future<void> markRead(String conversationId) =>
      _c.rpc('mark_conversation_read', params: {'p_conversation': conversationId});

  Future<void> deleteMessage(String id) => _c.rpc('delete_message', params: {'p_message': id});
}

// =====================================================================
// COMMUNITY E GRUPPI
// =====================================================================
final communityRepoProvider = Provider((ref) => CommunityRepository(ref.watch(supabaseProvider)));

class FeedQuery {
  const FeedQuery({this.hashtag, this.groupId, this.authorId});
  final String? hashtag;
  final String? groupId;
  final String? authorId;

  @override
  bool operator ==(Object other) =>
      other is FeedQuery && other.hashtag == hashtag && other.groupId == groupId && other.authorId == authorId;
  @override
  int get hashCode => Object.hash(hashtag, groupId, authorId);
}

final feedProvider = FutureProvider.family<List<FeedPost>, FeedQuery>((ref, q) async {
  ref.watch(currentUserIdProvider);
  final res = await ref.watch(supabaseProvider).rpc('get_feed', params: {
    'p_hashtag': q.hashtag,
    'p_group': q.groupId,
    'p_author': q.authorId,
    'p_limit': 40,
  });
  return [for (final r in res as List) FeedPost(Map<String, dynamic>.from(r as Map))];
});

final postProvider = FutureProvider.family<FeedPost?, String>((ref, id) async {
  final res = await ref.watch(supabaseProvider).rpc('get_post', params: {'p_id': id});
  return res == null ? null : FeedPost(Map<String, dynamic>.from(res as Map));
});

final commentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, postId) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('comments')
      .select('id, body, author_id, parent_id, created_at, profiles(username, display_name, avatar_path)')
      .eq('post_id', postId)
      .eq('is_hidden', false)
      .order('created_at', ascending: true);
  return List<Map<String, dynamic>>.from(rows);
});

final groupsProvider = FutureProvider<List<GroupItem>>((ref) async {
  ref.watch(currentUserIdProvider);
  final res = await ref.watch(supabaseProvider).rpc('get_groups');
  return [for (final r in res as List) GroupItem(Map<String, dynamic>.from(r as Map))];
});

class CommunityRepository {
  CommunityRepository(this._c);
  final SupabaseClient _c;

  Future<void> createPost({
    required String kind,
    String? body,
    Uint8List? image,
    List<String> hashtags = const [],
    List<String>? pollOptions,
    String? groupId,
    String? sharedPostId,
  }) async {
    String? imagePath;
    if (image != null) {
      imagePath = '$_uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _c.storage.from('post-images').uploadBinary(
            imagePath,
            image,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    }
    await _c.from('posts').insert({
      'author_id': _uid,
      'kind': kind,
      'body': body,
      'image_path': imagePath,
      'hashtags': hashtags,
      'poll_options': pollOptions,
      'group_id': groupId,
      'shared_post_id': sharedPostId,
      'audience_band': 'adult', // ignorato: il server imposta la fascia reale dell'autore
    });
  }

  Future<void> deletePost(String id) => _c.from('posts').delete().eq('id', id);

  Future<void> toggleLike(FeedPost p) async {
    if (p.liked) {
      await _c.from('reactions').delete().eq('post_id', p.id).eq('user_id', _uid);
    } else {
      await _c.from('reactions').insert({'user_id': _uid, 'post_id': p.id, 'kind': 'like'});
    }
  }

  Future<void> vote(String postId, int option) =>
      _c.from('poll_votes').insert({'post_id': postId, 'user_id': _uid, 'option_idx': option});

  Future<void> comment(String postId, String body, {String? parentId}) => _c.from('comments').insert({
        'post_id': postId,
        'author_id': _uid,
        'body': body,
        'parent_id': parentId,
      });

  Future<void> deleteComment(String id) => _c.from('comments').delete().eq('id', id);

  Future<void> joinGroup(String id) => _c.from('group_members').insert({'group_id': id, 'user_id': _uid});

  Future<void> leaveGroup(String id) =>
      _c.from('group_members').delete().eq('group_id', id).eq('user_id', _uid);

  Future<void> createGroup(String name, String description, String category) => _c.from('groups').insert({
        'name': name,
        'description': description,
        'category': category,
        'created_by': _uid,
        'audience_band': 'adult', // ignorato: impostato dal server
      });
}

// =====================================================================
// EVENTI
// =====================================================================
final eventsRepoProvider = Provider((ref) => EventsRepository(ref.watch(supabaseProvider)));

final eventsProvider = FutureProvider.family<List<EventItem>, String?>((ref, city) async {
  ref.watch(currentUserIdProvider);
  final res = await ref.watch(supabaseProvider).rpc('get_events', params: {'p_city': city});
  return [for (final r in res as List) EventItem(Map<String, dynamic>.from(r as Map))];
});

final eventParticipantsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('event_participants')
      .select('user_id, joined_at, profiles(username, display_name, avatar_path)')
      .eq('event_id', id)
      .order('joined_at');
  return List<Map<String, dynamic>>.from(rows);
});

class EventsRepository {
  EventsRepository(this._c);
  final SupabaseClient _c;

  Future<void> create(Map<String, dynamic> fields) => _c.from('events').insert({
        ...fields,
        'organizer_id': _uid,
        'audience_band': 'adult', // ignorato: impostato dal server
        'status': 'pending_review', // gli eventi vengono sempre moderati
      });

  Future<void> join(String id) => _c.from('event_participants').insert({'event_id': id, 'user_id': _uid});

  Future<void> leave(String id) =>
      _c.from('event_participants').delete().eq('event_id', id).eq('user_id', _uid);

  Future<void> delete(String id) => _c.from('events').delete().eq('id', id);
}

// =====================================================================
// NON SEI SOLO
// =====================================================================
final supportRepoProvider = Provider((ref) => SupportRepository(ref.watch(supabaseProvider)));

final supportPostsProvider = FutureProvider<List<SupportPost>>((ref) async {
  ref.watch(currentUserIdProvider);
  final res = await ref.watch(supabaseProvider).rpc('list_support_posts', params: {'p_limit': 50});
  return [for (final r in res as List) SupportPost(Map<String, dynamic>.from(r as Map))];
});

final supportRepliesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final rows = await ref
      .watch(supabaseProvider)
      .from('support_replies')
      .select('id, body, author_id, created_at, profiles(username, display_name, avatar_path)')
      .eq('support_post_id', id)
      .order('created_at');
  return List<Map<String, dynamic>>.from(rows);
});

class SupportRepository {
  SupportRepository(this._c);
  final SupabaseClient _c;

  Future<void> post(String body, bool anonymous) => _c.from('support_posts').insert({
        'author_id': _uid,
        'body': body,
        'is_anonymous': anonymous,
        'audience_band': 'adult', // ignorato: impostato dal server
      });

  Future<void> reply(String postId, String body) => _c.from('support_replies').insert({
        'support_post_id': postId,
        'author_id': _uid,
        'body': body,
      });
}

// =====================================================================
// SENTINEL
// =====================================================================
final creatorRepoProvider = Provider((ref) => CreatorRepository(ref.watch(supabaseProvider)));

final creatorUpdatesProvider = FutureProvider<List<CreatorUpdate>>((ref) async {
  ref.watch(currentUserIdProvider);
  final rows = await ref
      .watch(supabaseProvider)
      .from('creator_updates')
      .select()
      .order('created_at', ascending: false)
      .limit(100);
  return [for (final r in rows) CreatorUpdate(r)];
});

final communityMessagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentUserIdProvider);
  final rows = await ref
      .watch(supabaseProvider)
      .from('creator_ideas')
      .select('id, kind, body, created_at, is_public, author_id')
      .order('created_at', ascending: false)
      .limit(100);
  return List<Map<String, dynamic>>.from(rows);
});

final isFollowingSentinelProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return false;
  final row = await ref.watch(supabaseProvider).from('creator_followers').select().eq('user_id', uid).maybeSingle();
  return row != null;
});

final sentinelFollowersProvider = FutureProvider<int>((ref) async {
  final res = await ref.watch(supabaseProvider).rpc('creator_follower_count');
  return (res as num).toInt();
});

class CreatorRepository {
  CreatorRepository(this._c);
  final SupabaseClient _c;

  Future<void> follow() => _c.from('creator_followers').insert({'user_id': _uid});
  Future<void> unfollow() => _c.from('creator_followers').delete().eq('user_id', _uid);

  /// kind: idea | message | volunteer
  Future<void> sendIdea(String kind, String body) =>
      _c.from('creator_ideas').insert({'author_id': _uid, 'kind': kind, 'body': body});

  Future<void> publishUpdate(String kind, String title, String body, bool published) =>
      _c.from('creator_updates').insert({
        'author_id': _uid,
        'kind': kind,
        'title': title,
        'body': body,
        'published': published,
      });

  Future<void> setIdeaPublic(String id, bool value) =>
      _c.from('creator_ideas').update({'is_public': value}).eq('id', id);
}

// =====================================================================
// NOTIFICHE (in tempo reale)
// =====================================================================
final notificationsStreamProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(supabaseProvider)
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(100)
      .map((rows) => [for (final r in rows) AppNotification(r)]);
});

final unreadNotificationsProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsStreamProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead).length;
});

final unreadMessagesProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsStreamProvider).valueOrNull ?? const [];
  return list.where((n) => !n.isRead && n.kind == 'message').length;
});

final notificationRepoProvider = Provider((ref) => NotificationRepository(ref.watch(supabaseProvider)));

class NotificationRepository {
  NotificationRepository(this._c);
  final SupabaseClient _c;

  Future<void> markAllRead() => _c
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('user_id', _uid)
      .isFilter('read_at', null);

  Future<void> markRead(String id) =>
      _c.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  Future<void> markConversationRead(String conversationId) => _c
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('user_id', _uid)
      .eq('kind', 'message')
      .eq('payload->>conversation_id', conversationId)
      .isFilter('read_at', null);
}

// =====================================================================
// MODERAZIONE
// =====================================================================
final moderationRepoProvider = Provider((ref) => ModerationRepository(ref.watch(supabaseProvider)));

class ModerationRepository {
  ModerationRepository(this._c);
  final SupabaseClient _c;

  Future<void> report(String targetType, String targetId, String reason, String? details) =>
      _c.from('reports').insert({
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'details': details,
      });

  Future<void> block(String userId) => _c.rpc('block_user', params: {'p_target': userId});
}

// =====================================================================
// WGF ZONE – contenuti ufficiali caricati con autorizzazione
// =====================================================================
final wgfConfigProvider = FutureProvider<({bool authorized, String note})>((ref) async {
  ref.watch(currentUserIdProvider);
  final rows = await ref
      .watch(supabaseProvider)
      .from('app_config')
      .select('key, value')
      .inFilter('key', ['wgf_content_authorized', 'wgf_permission_note']);
  var authorized = false;
  var note = '';
  for (final r in rows) {
    if (r['key'] == 'wgf_content_authorized') authorized = r['value'] == true;
    if (r['key'] == 'wgf_permission_note') note = (r['value'] ?? '') as String;
  }
  return (authorized: authorized, note: note);
});

final officialContentProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentUserIdProvider);
  final rows = await ref
      .watch(supabaseProvider)
      .from('official_content')
      .select()
      .eq('published', true)
      .order('sort_order')
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(rows);
});
