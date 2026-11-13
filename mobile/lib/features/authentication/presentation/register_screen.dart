import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/brand_header.dart';
import '../../../core/widgets/visuals.dart';
import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).signUp(_email.text, _password.text);
      setState(() => _sent = true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _sent
                ? Column(
                    children: [
                      const BrandHeader(subtitle: 'Controlla la tua email'),
                      const SizedBox(height: 24),
                      const Text(
                        'Ti abbiamo inviato un link di conferma. Dopo la verifica potrai accedere e completare il profilo.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(onPressed: () => context.go('/login'), child: const Text('Vai al login')),
                    ],
                  )
                : Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BrandHeader(subtitle: 'Unisciti alla community dei fan WGF'),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (v) => (v != null && v.contains('@')) ? null : 'Email non valida',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password (min. 8 caratteri)'),
                          validator: (v) => (v != null && v.length >= 8) ? null : 'Minimo 8 caratteri',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirm,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Conferma password'),
                          validator: (v) => v == _password.text ? null : 'Le password non coincidono',
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(onPressed: _busy ? null : _submit, child: const Text('Registrati')),
                        TextButton(onPressed: () => context.go('/login'), child: const Text('Hai già un account? Accedi')),
                        const SizedBox(height: 16),
                        Text(
                          'WGF CONNECT è un progetto indipendente creato da un fan e non è affiliato ai WGF.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
    );
  }
}
