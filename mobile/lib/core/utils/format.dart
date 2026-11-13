import 'package:intl/intl.dart';

String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'ora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} g';
  return DateFormat('d MMM', 'it').format(d);
}

String clock(DateTime d) => DateFormat('HH:mm').format(d);

String eventDate(DateTime d) => DateFormat("EEE d MMMM · HH:mm", 'it').format(d);

String dayNumber(DateTime d) => DateFormat('d').format(d);

String monthShort(DateTime d) => DateFormat('MMM', 'it').format(d).toUpperCase();

/// Divide un testo libero in tag: "Minecraft, Fortnite" → [Minecraft, Fortnite]
List<String> splitTags(String text) => text
    .split(RegExp(r'[,;\n]'))
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .take(20)
    .toList();
