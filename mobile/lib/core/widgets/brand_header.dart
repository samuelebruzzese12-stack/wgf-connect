import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'visuals.dart';

/// Marchio originale "WGF CONNECT" (nessun logo di terzi).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.subtitle, this.logoSize = 76});
  final String? subtitle;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Hero(tag: 'wgf-logo', child: WgfLogo(size: logoSize)),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(colors: [Colors.white, Color(0xFFC9A7FF)]).createShader(r),
          child: Text('WGF CONNECT', style: t.headlineLarge?.copyWith(color: Colors.white)),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: t.bodyMedium?.copyWith(color: WgfColors.muted)),
        ],
      ],
    );
  }
}
