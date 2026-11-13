// Modelli dati di WGF CONNECT. Costruiti dalle risposte JSON di Supabase.

List<String> _strings(dynamic v) => v == null ? const [] : List<String>.from(v as List);
DateTime _date(dynamic v) => DateTime.parse(v as String).toLocal();
DateTime? _dateOrNull(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
int _int(dynamic v) => v == null ? 0 : (v as num).toInt();

class ProfileCard {
  ProfileCard({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarPath,
    required this.country,
    required this.city,
    required this.interests,
    required this.favoriteGames,
    required this.favoriteWgfCharacters,
    required this.friendshipPreferences,
    this.age,
    this.verifiedAdult = false,
    this.wgfQuizScore = 0,
    this.isFounder = false,
    this.favoriteSeries,
    this.fanSince,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarPath;
  final String country;
  final String city;
  final List<String> interests;
  final List<String> favoriteGames;
  final List<String> favoriteWgfCharacters;
  final List<String> friendshipPreferences;
  final int? age;
  final bool verifiedAdult;
  final int wgfQuizScore;
  final bool isFounder;
  final String? favoriteSeries;
  final int? fanSince;

  String get name => (displayName?.isNotEmpty ?? false) ? displayName! : username;

  factory ProfileCard.fromJson(Map<String, dynamic> j) => ProfileCard(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: j['display_name'] as String?,
        bio: j['bio'] as String?,
        avatarPath: j['avatar_path'] as String?,
        country: (j['country'] ?? '') as String,
        city: (j['city'] ?? '') as String,
        interests: _strings(j['interests']),
        favoriteGames: _strings(j['favorite_games']),
        favoriteWgfCharacters: _strings(j['favorite_wgf_characters']),
        friendshipPreferences: _strings(j['friendship_preferences']),
        age: j['age'] == null ? null : _int(j['age']),
        verifiedAdult: (j['verified_adult'] ?? false) as bool,
        wgfQuizScore: _int(j['wgf_quiz_score']),
        isFounder: j['role'] == 'founder',
        favoriteSeries: j['wgf_favorite_series'] as String?,
        fanSince: j['wgf_fan_since'] == null ? null : _int(j['wgf_fan_since']),
      );
}

/// Il proprio profilo completo (riga di public.profiles).
class MyProfile {
  MyProfile(this.raw);
  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  String get username => raw['username'] as String;
  String? get displayName => raw['display_name'] as String?;
  String? get bio => raw['bio'] as String?;
  String? get avatarPath => raw['avatar_path'] as String?;
  String get country => raw['country'] as String;
  String get city => raw['city'] as String;
  List<String> get interests => _strings(raw['interests']);
  List<String> get favoriteGames => _strings(raw['favorite_games']);
  List<String> get favoriteWgfCharacters => _strings(raw['favorite_wgf_characters']);
  List<String> get friendshipPreferences => _strings(raw['friendship_preferences']);
  String get ageBand => raw['age_band'] as String;
  String get role => raw['role'] as String;
  bool get showAge => raw['show_age'] as bool;
  bool get discoverable => raw['discoverable'] as bool;
  bool get isCreator => role == 'creator' || role == 'admin';
  int get wgfQuizScore => _int(raw['wgf_quiz_score']);
  int? get wgfFanSince => raw['wgf_fan_since'] == null ? null : _int(raw['wgf_fan_since']);
  String? get wgfFavoriteSeries => raw['wgf_favorite_series'] as String?;
  DateTime get createdAt => _date(raw['created_at']);
  bool get isStaff => role == 'admin' || role == 'moderator';
  String get name => (displayName?.isNotEmpty ?? false) ? displayName! : username;
}

class FeedPost {
  FeedPost(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get authorId => j['author_id'] as String;
  String get username => (j['username'] ?? 'utente') as String;
  String? get displayName => j['display_name'] as String?;
  String? get avatarPath => j['avatar_path'] as String?;
  String get kind => j['kind'] as String;
  String? get body => j['body'] as String?;
  String? get imagePath => j['image_path'] as String?;
  List<String> get hashtags => _strings(j['hashtags']);
  List<String> get pollOptions => _strings(j['poll_options']);
  Map<String, dynamic> get pollCounts => Map<String, dynamic>.from((j['poll_counts'] ?? {}) as Map);
  int? get myVote => j['my_vote'] == null ? null : _int(j['my_vote']);
  int get likes => _int(j['likes']);
  int get comments => _int(j['comments']);
  bool get liked => (j['liked'] ?? false) as bool;
  DateTime get createdAt => _date(j['created_at']);
  Map<String, dynamic>? get shared =>
      j['shared'] == null ? null : Map<String, dynamic>.from(j['shared'] as Map);
  String get name => (displayName?.isNotEmpty ?? false) ? displayName! : username;
}

class Conversation {
  Conversation(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  bool get isActive => j['is_active'] as bool;
  String get kind => j['kind'] as String;
  String? get matchMode => j['match_mode'] as String?;
  String? get otherId => j['other_id'] as String?;
  Map<String, dynamic>? get other =>
      j['other'] == null ? null : Map<String, dynamic>.from(j['other'] as Map);
  String get otherName {
    final o = other;
    if (o == null) return 'Utente non disponibile';
    final dn = o['display_name'] as String?;
    return (dn?.isNotEmpty ?? false) ? dn! : o['username'] as String;
  }

  String? get otherAvatar => other?['avatar_path'] as String?;
  Map<String, dynamic>? get lastMessage =>
      j['last_message'] == null ? null : Map<String, dynamic>.from(j['last_message'] as Map);
  int get unread => _int(j['unread']);
  DateTime get lastActivity =>
      lastMessage != null ? _date(lastMessage!['created_at']) : _date(j['created_at']);
}

class ChatMessage {
  ChatMessage(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get senderId => j['sender_id'] as String;
  String? get body => j['body'] as String?;
  String? get imagePath => j['image_path'] as String?;
  String? get imageStatus => j['image_status'] as String?;
  DateTime get createdAt => _date(j['created_at']);
  DateTime? get deliveredAt => _dateOrNull(j['delivered_at']);
  DateTime? get readAt => _dateOrNull(j['read_at']);
  bool get isDeleted => j['deleted_at'] != null;
}

class EventItem {
  EventItem(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get title => j['title'] as String;
  String get description => j['description'] as String;
  String get category => j['category'] as String;
  String get city => j['city'] as String;
  String? get venue => j['venue_public'] as String?;
  DateTime get startsAt => _date(j['starts_at']);
  DateTime? get endsAt => _dateOrNull(j['ends_at']);
  int? get maxParticipants => j['max_participants'] == null ? null : _int(j['max_participants']);
  int get participants => _int(j['participants']);
  bool get joined => (j['joined'] ?? false) as bool;
  bool get isMine => (j['is_mine'] ?? false) as bool;
  String get status => j['status'] as String;
  String? get organizer => j['organizer_username'] as String?;
  bool get isFull => maxParticipants != null && participants >= maxParticipants!;
}

class GroupItem {
  GroupItem(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get name => j['name'] as String;
  String? get description => j['description'] as String?;
  String get category => j['category'] as String;
  int get members => _int(j['members']);
  bool get joined => (j['joined'] ?? false) as bool;
}

class CreatorUpdate {
  CreatorUpdate(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get kind => j['kind'] as String;
  String get title => j['title'] as String;
  String get body => j['body'] as String;
  bool get published => j['published'] as bool;
  DateTime get createdAt => _date(j['created_at']);
}

class SupportPost {
  SupportPost(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get body => j['body'] as String;
  String? get authorId => j['author_id'] as String?;
  String? get username => j['author_username'] as String?;
  bool get anonymous => (j['is_anonymous'] ?? false) as bool;
  DateTime get createdAt => _date(j['created_at']);
  int get replies => _int(j['replies']);
}

class AppNotification {
  AppNotification(this.j);
  final Map<String, dynamic> j;

  String get id => j['id'] as String;
  String get kind => j['kind'] as String;
  Map<String, dynamic> get payload => Map<String, dynamic>.from((j['payload'] ?? {}) as Map);
  bool get isRead => j['read_at'] != null;
  DateTime get createdAt => _date(j['created_at']);
}
