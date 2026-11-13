import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/visuals.dart';
import '../../data/repositories/repositories.dart';
import '../authentication/data/auth_repository.dart';

class ComposeOptions {
  const ComposeOptions({this.groupId, this.sharedPostId, this.sharedPreview, this.hashtag});
  final String? groupId;
  final String? sharedPostId;
  final String? sharedPreview;
  final String? hashtag;
}

/// Crea post, fan art, sondaggi, discussioni o condivisioni interne.
class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({super.key, required this.options});
  final ComposeOptions options;

  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  static const _kinds = {
    'text': ('Post', Icons.notes_rounded),
    'fanart': ('Fan art', Icons.brush_rounded),
    'poll': ('Sondaggio', Icons.poll_rounded),
    'discussion': ('Discussione', Icons.forum_rounded),
  };
  late String _kind = widget.options.hashtag == 'fanart'
      ? 'fanart'
      : widget.options.hashtag == 'discussione'
          ? 'discussion'
          : 'text';
  late final _body = TextEditingController(
    text: widget.options.hashtag != null && widget.options.hashtag != 'fanart' && widget.options.hashtag != 'discussione'
        ? '#${widget.options.hashtag} '
        : '',
  );
  final _options = [TextEditingController(), TextEditingController()];
  Uint8List? _image;
  bool _busy = false;
  String? _error;

  bool get _isShare => widget.options.sharedPostId != null;

  @override
  void dispose() {
    _body.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 82);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      setState(() => _error = 'Immagine troppo grande (max 5 MB).');
      return;
    }
    setState(() => _image = bytes);
  }

  Future<void> _publish() async {
    final text = _body.text.trim();
    final opts = _options.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
    if (_kind == 'poll' && (text.isEmpty || opts.length < 2)) {
      setState(() => _error = 'Scrivi la domanda e almeno 2 opzioni.');
      return;
    }
    if (_kind == 'fanart' && _image == null) {
      setState(() => _error = 'Aggiungi la tua fan art (solo opere tue o con permesso).');
      return;
    }
    if (text.isEmpty && _image == null && !_isShare) {
      setState(() => _error = 'Scrivi qualcosa.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final tags = <String>[
        if (_kind == 'fanart') 'fanart',
        if (_kind == 'discussion') 'discussione',
      ];
      await ref.read(communityRepoProvider).createPost(
            kind: _isShare ? 'share' : _kind,
            body: text.isEmpty ? null : text,
            image: _image,
            hashtags: tags,
            pollOptions: _kind == 'poll' ? opts : null,
            groupId: widget.options.groupId,
            sharedPostId: widget.options.sharedPostId,
          );
      ref.invalidate(feedProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isShare ? 'Condividi' : 'Nuovo post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _busy ? null : _publish, child: const Text('Pubblica')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_isShare)
            Wrap(
              spacing: 8,
              children: [
                for (final e in _kinds.entries)
                  ChoiceChip(
                    avatar: Icon(e.value.$2, size: 18),
                    label: Text(e.value.$1),
                    selected: _kind == e.key,
                    onSelected: (_) => setState(() => _kind = e.key),
                  ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            autofocus: true,
            maxLines: null,
            minLines: 4,
            maxLength: 5000,
            decoration: InputDecoration(
              hintText: _kind == 'poll'
                  ? 'La tua domanda…'
                  : 'Cosa vuoi condividere con la community? Usa #hashtag',
            ),
          ),
          if (_isShare && widget.options.sharedPreview != null)
            GlassCard(child: Text(widget.options.sharedPreview!, maxLines: 5, overflow: TextOverflow.ellipsis)),
          if (_kind == 'poll' && !_isShare) ...[
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _options[i],
                  maxLength: 80,
                  decoration: InputDecoration(labelText: 'Opzione ${i + 1}', counterText: ''),
                ),
              ),
            if (_options.length < 6)
              TextButton.icon(
                onPressed: () => setState(() => _options.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Aggiungi opzione'),
              ),
          ],
          if (!_isShare && _kind != 'poll') ...[
            const SizedBox(height: 8),
            if (_image != null)
              Stack(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(_image!, fit: BoxFit.cover)),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filled(
                      onPressed: () => setState(() => _image = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pick,
                icon: const Icon(Icons.image_outlined),
                label: Text(_kind == 'fanart' ? 'Carica la tua fan art' : 'Aggiungi immagine'),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: WgfColors.danger)),
            ),
          const SizedBox(height: 16),
          const Text(
            'Ricorda: niente dati personali (indirizzi, numeri di telefono) e niente immagini di altri senza permesso.',
            style: TextStyle(color: WgfColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
