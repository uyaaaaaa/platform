import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/dependencies.dart';
import '../../../domain/models/sign_in_outcome.dart';

class SignInState {
  const SignInState({this.submitting = false, this.message});

  final bool submitting;

  final String? message;
}

class SignInViewModel extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  Future<void> signIn({required String email, required String password}) async {
    if (state.submitting) return;
    state = const SignInState(submitting: true);

    final outcome = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);

    state = switch (outcome) {
      SignInSucceeded() => const SignInState(),
      SignInRejected(:final message) => SignInState(message: message),
    };
  }
}

final signInViewModelProvider = NotifierProvider<SignInViewModel, SignInState>(
  SignInViewModel.new,
);
