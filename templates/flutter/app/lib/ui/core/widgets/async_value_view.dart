import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 読み込み中・失敗・再試行の表示を1箇所に集める。
///
/// 予期しない失敗は原因を利用者に見せても行動につながらないため、
/// 一律の文言と再試行だけを出す。これにより UI 層が data 層の例外型を
/// 知る必要がなくなる。
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    required this.value,
    required this.onRetry,
    required this.builder,
    super.key,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) => switch (value) {
    AsyncData(:final value) => builder(context, value),
    AsyncError() => _ErrorView(onRetry: onRetry),
    _ => const Center(child: CircularProgressIndicator()),
  };
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('読み込めませんでした。'),
        const SizedBox(height: 8),
        FilledButton(onPressed: onRetry, child: const Text('再試行')),
      ],
    ),
  );
}
