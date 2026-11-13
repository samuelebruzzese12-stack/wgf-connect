import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

const _titles = {
  'privacy': 'Informativa privacy',
  'termini': 'Termini di servizio',
  'linee-guida': 'Linee guida della community',
  'sicurezza': 'Sicurezza negli incontri e nel dating',
};

/// Mostra i documenti legali da assets/legal/<doc>.md (formattazione semplice).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[doc] ?? 'Documento')),
      body: FutureBuilder<String>(
        future: rootBundle.loadString('assets/legal/$doc.md'),
        builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text('Documento non trovato'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final lines = snap.data!.split('\n');
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              for (final l in lines)
                if (l.startsWith('# '))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(l.substring(2), style: Theme.of(context).textTheme.headlineSmall),
                  )
                else if (l.startsWith('## '))
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 6),
                    child: Text(l.substring(3),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFFC9A7FF))),
                  )
                else if (l.startsWith('> '))
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: WgfColors.darkViolet.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(l.substring(2).replaceAll('**', '')),
                  )
                else if (l.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(l.replaceAll('**', ''), style: const TextStyle(height: 1.5)),
                  ),
            ],
          );
        },
      ),
    );
  }
}
