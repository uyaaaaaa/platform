import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/dependencies.dart';
import '../../../routing/routes.dart';
import '../../core/widgets/async_value_view.dart';
import '../view_models/item_list_view_model.dart';

class ItemListScreen extends ConsumerWidget {
  const ItemListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemListViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Items'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'サインアウト',
          ),
        ],
      ),
      body: AsyncValueView(
        value: items,
        onRetry: () => ref.read(itemListViewModelProvider.notifier).refresh(),
        builder: (context, data) => RefreshIndicator(
          onRefresh: () async =>
              ref.read(itemListViewModelProvider.notifier).refresh(),
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return ListTile(
                key: ValueKey(item.id),
                title: Text(item.title),
                leading: Icon(
                  item.done ? Icons.check_circle : Icons.circle_outlined,
                ),
                onTap: () => context.go(Routes.itemEditorOf(item.id)),
              );
            },
          ),
        ),
      ),
    );
  }
}
