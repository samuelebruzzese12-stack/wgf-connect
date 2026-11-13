import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/repositories.dart';
import '../theme/app_theme.dart';

/// Avatar da bucket privato (URL firmato). Senza foto: iniziale su gradiente.
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key, required this.name, this.path, this.size = 44, this.ring = false});
  final String name;
  final String? path;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = path == null ? null : ref.watch(signedUrlProvider((bucket: 'avatars', path: path!))).valueOrNull;
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final inner = ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, __, ___) => _Fallback(initial: initial, size: size),
              )
            : _Fallback(initial: initial, size: size),
      ),
    );
    if (!ring) return inner;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: WgfColors.brandGradient),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: WgfColors.black),
        child: inner,
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.initial, required this.size});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: WgfColors.brandGradient),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      );
}

/// Immagine da bucket privato (post o chat).
class PrivateImage extends ConsumerWidget {
  const PrivateImage({super.key, required this.bucket, required this.path, this.height = 240});
  final String bucket;
  final String path;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(signedUrlProvider((bucket: bucket, path: path)));
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: url.when(
          data: (u) => u == null
              ? const ColoredBox(color: WgfColors.anthracite, child: Icon(Icons.broken_image_outlined))
              : Image.network(u, fit: BoxFit.cover, cacheWidth: 1080),
          loading: () => const ColoredBox(color: WgfColors.anthracite),
          error: (_, __) => const ColoredBox(color: WgfColors.anthracite),
        ),
      ),
    );
  }
}
