import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/sign_in_view_model.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signInViewModelProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'メールアドレス'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                  obscureText: true,
                ),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(state.message!),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: state.submitting ? null : _submit,
                  child: Text(state.submitting ? 'サインイン中...' : 'サインイン'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submit() => ref
      .read(signInViewModelProvider.notifier)
      .signIn(email: _email.text, password: _password.text);
}
