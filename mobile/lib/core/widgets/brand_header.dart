import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Marchio testuale originale "WGF CONNECT" (nessun logo di terzi).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.subtitle});
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: WgfColors.brandGradient,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: WgfColors.electricViolet.withValues(alpha: 0.45), blurRadius: 28),
            ],
          ),
          child: const Icon(Icons.hub_rounded, size: 38, color: WgfColors.white),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (r) => WgfColors.brandGradient.createShader(r),
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
