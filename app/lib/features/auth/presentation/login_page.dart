import 'package:agenda_app/features/auth/presentation/session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});
  static const routePath = '/login';

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionControllerProvider, (_, next) {
      if (next.valueOrNull == true) context.go('/today');
    });
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, size: 56),
                    const SizedBox(height: 12),
                    Text(
                      'Tempo',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    if (_register) ...[
                      TextField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Nom'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'E-mail'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Mot de passe',
                      ),
                    ),
                    if (session.hasError) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Connexion impossible. Vérifiez vos informations et le serveur.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: session.isLoading ? null : _submit,
                      child: session.isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _register ? 'Créer le compte' : 'Se connecter',
                            ),
                    ),
                    TextButton(
                      onPressed: session.isLoading
                          ? null
                          : () => setState(() => _register = !_register),
                      child: Text(
                        _register
                            ? 'J’ai déjà un compte'
                            : 'Créer mon compte personnel',
                      ),
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

  Future<void> _submit() async {
    if (_email.text.trim().isEmpty || _password.text.length < 8) return;
    if (_register) {
      if (_name.text.trim().length < 2) return;
      await ref
          .read(sessionControllerProvider.notifier)
          .register(_name.text, _email.text, _password.text);
    } else {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(_email.text, _password.text);
    }
  }
}
