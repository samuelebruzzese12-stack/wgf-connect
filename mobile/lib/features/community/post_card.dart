import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/visuals.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../moderation/report_sheet.dart';
import 'compose_post_screen.dart';

class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.onChanged, this.openOnTap = true});
  final FeedPost post;
  final VoidCallback? onChanged;
  final bool openOnTap;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late bool _liked = widget.post.liked;
  late int _likes = widget.post.likes;
  int? _vote;
  Map<String, dynamic>? _pollCounts;

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    if (old.post.j != widget.post.j) {
      _liked = widget.post.liked;
      _likes = widget.post.likes;
      _vote = null;
      _pollCounts = null;
    }
  }

  Future<void> _toggleLike() async {
    final before = (_liked, _likes);
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    try {
      await ref.read(communityRepoProvider).toggleLike(FeedPost({...widget.post.j, 'liked': before.$1}));
    } catch (_) {
      setState(() {
        _liked = before.$1;
        _likes = before.$2;
      });
    }
  }

  Future<void> _castVote(int i) async {
    if (widget.post.myVote != null || _vote != null) return;
    final counts = Map<String, dynamic>.from(widget.post.pollCounts);
    counts['$i'] = ((counts['$i'] ?? 0) as num).toInt() + 1;
    setState(() {
      _vote = i;
      _pollCounts = counts;
    });
    try {
      await ref.read(communityRepoProvider).vote(widget.post.id, i);
    } catch (_) {
      setState(() {
        _vote = null;
        _pollCounts = null;
      });
    }
  }

  Future<void> _menu() async {
    final me = ref.read(currentUserIdProvider);
    final p = widget.post;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: WgfColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.authorId == me)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Elimina post'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              )
            else ...[
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text('Vedi profilo di ${p.name}'),
                onTap: () => Navigator.pop(ctx, 'profile'),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: WgfColors.danger),
                title: const Text('Segnala post'),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'delete':
        await ref.read(communityRepoProvider).deletePost(p.id);
        ref.invalidate(feedProvider);
        widget.onChanged?.call();
      case 'profile':
        context.push('/user/${p.authorId}');
      case 'report':
        await showReportSheet(context, ref, targetType: 'post', targetId: p.id, userIdToBlock: p.authorId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final t = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      onTap: widget.openOnTap ? () => context.push('/post/${p.id}') : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/user/${p.authorId}'),
                child: UserAvatar(name: p.name, path: p.avatarPath, size: 40, ring: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('@${p.username} · ${timeAgo(p.createdAt)}',
                        style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (p.kind == 'fanart') const TagChip('Fan art', icon: Icons.brush_rounded),
              IconButton(onPressed: _menu, icon: const Icon(Icons.more_horiz_rounded)),
            ],
          ),
          if (p.body != null && p.body!.isNotEmpty) ...[
            const SizedBox(height: 10),
            HashtagText(p.body!, style: t.bodyLarge),
          ],
          if (p.imagePath != null) ...[
            const SizedBox(height: 10),
            PrivateImage(bucket: 'post-images', path: p.imagePath!, height: 260),
          ],
          if (p.kind == 'poll' && p.pollOptions.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Poll(
              options: p.pollOptions,
              counts: _pollCounts ?? p.pollCounts,
              myVote: _vote ?? p.myVote,
              onVote: _castVote,
            ),
          ],
          if (p.shared != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: WgfColors.electricViolet.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('@${p.shared!['username'] ?? 'utente'}', style: const TextStyle(color: WgfColors.muted)),
                  const SizedBox(height: 4),
                  Text((p.shared!['body'] ?? '') as String, maxLines: 4, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              LikeButton(liked: _liked, count: _likes, onTap: _toggleLike),
              TextButton.icon(
                onPressed: () => context.push('/post/${p.id}'),
                icon: const Icon(Icons.mode_comment_outlined, size: 20),
                label: Text('${p.comments}'),
              ),
              TextButton.icon(
                onPressed: () => context.push('/compose', extra: ComposeOptions(sharedPostId: p.id, sharedPreview: p.body)),
                icon: const Icon(Icons.repeat_rounded, size: 20),
                label: const Text('Condividi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cuore con animazione "pop" e particelle.
class LikeButton extends StatefulWidget {
  const LikeButton({super.key, required this.liked, required this.count, required this.onTap});
  final bool liked;
  final int count;
  final VoidCallback onTap;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  int _burst = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    if (!widget.liked) {
      _c.forward(from: 0);
      setState(() => _burst++);
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (_burst > 0)
                  Positioned(
                    left: -28,
                    top: -28,
                    child: ParticleBurst(key: ValueKey(_burst), size: 76, count: 14, duration: const Duration(milliseconds: 600)),
                  ),
                ScaleTransition(
                  scale: scale,
                  child: Icon(
                    widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: widget.liked ? WgfColors.electricViolet : null,
                    size: 21,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => SlideTransition(
                position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(a),
                child: FadeTransition(opacity: a, child: c),
              ),
              child: Text('${widget.count}', key: ValueKey(widget.count)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Poll extends StatelessWidget {
  const _Poll({required this.options, required this.counts, required this.myVote, required this.onVote});
  final List<String> options;
  final Map<String, dynamic> counts;
  final int? myVote;
  final void Function(int) onVote;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (a, b) => a + (b as num).toInt());
    final voted = myVote != null;
    return Column(
      children: [
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: voted ? null : () => onVote(i),
              child: Stack(
                children: [
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: WgfColors.anthracite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: myVote == i ? WgfColors.electricViolet : Colors.transparent),
                    ),
                  ),
                  if (voted)
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: total == 0 ? 0 : (((counts['$i'] ?? 0) as num).toInt() / total),
                      ),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => FractionallySizedBox(
                        widthFactor: v,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: WgfColors.brandGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    height: 42,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(options[i])),
                          if (voted)
                            Text(total == 0
                                ? '0%'
                                : '${((((counts['$i'] ?? 0) as num).toInt() / total) * 100).round()}%'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('$total voti', style: const TextStyle(color: WgfColors.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

/// Testo con #hashtag evidenziati.
class HashtagText extends StatelessWidget {
  const HashtagText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final re = RegExp(r'#[\p{L}\p{N}_]{2,40}', unicode: true);
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
        text: m.group(0),
        style: const TextStyle(color: Color(0xFFC084FC), fontWeight: FontWeight.w600),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
