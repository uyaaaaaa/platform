import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/dependencies.dart';
import 'data/services/response_cache.dart';
import 'routing/router.dart';
import 'ui/core/themes/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cache = await SqfliteResponseCache.open();

  runApp(
    ProviderScope(
      retry: noAutomaticRetry,
      overrides: [responseCacheProvider.overrideWithValue(cache)],
      child: const App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    routerConfig: ref.watch(routerProvider),
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
  );
}
