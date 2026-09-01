/// サインインの結果のうち、呼び出し側が必ず分岐すべきもの。
sealed class SignInOutcome {
  const SignInOutcome();
}

final class SignInSucceeded extends SignInOutcome {
  const SignInSucceeded();
}

final class SignInRejected extends SignInOutcome {
  const SignInRejected(this.message);

  final String message;
}
