import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/dependencies.dart';
import '../domain/models/auth_status.dart';
import '../ui/auth/widgets/sign_in_screen.dart';
import '../ui/items/widgets/item_editor_screen.dart';
import '../ui/items/widgets/item_list_screen.dart';
import 'routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.items,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authRepositoryProvider).status;
      if (status == AuthStatus.unknown) return null;

      final signedIn = status == AuthStatus.signedIn;
      final atSignIn = state.matchedLocation == Routes.signIn;
      if (!signedIn && !atSignIn) return Routes.signIn;
      if (signedIn && atSignIn) return Routes.items;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.items,
        builder: (context, state) => const ItemListScreen(),
      ),
      GoRoute(
        path: Routes.itemEditor,
        builder: (context, state) =>
            ItemEditorScreen(itemId: state.pathParameters['id']!),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    _subscription = ref
        .read(authRepositoryProvider)
        .statusChanges
        .listen((_) => notifyListeners());
  }

  StreamSubscription<AuthStatus>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
