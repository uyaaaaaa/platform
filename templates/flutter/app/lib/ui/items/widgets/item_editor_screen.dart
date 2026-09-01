import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/item.dart';
import '../../../routing/routes.dart';
import '../view_models/item_editor_view_model.dart';
import '../view_models/item_list_view_model.dart';

class ItemEditorScreen extends ConsumerStatefulWidget {
  const ItemEditorScreen({required this.itemId, super.key});

  final String itemId;

  @override
  ConsumerState<ItemEditorScreen> createState() => _ItemEditorScreenState();
}

class _ItemEditorScreenState extends ConsumerState<ItemEditorScreen> {
  final _title = TextEditingController();
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final items = ref.read(itemListViewModelProvider).value ?? const [];
    final item = items.where((e) => e.id == widget.itemId).firstOrNull;
    _title.text = item?.title ?? '';
    _done = item?.done ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itemEditorViewModelProvider);

    ref.listen(itemEditorViewModelProvider, (previous, next) {
      if (next.saved && previous?.saved != true) context.go(Routes.items);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Edit item')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: 'タイトル',
                errorText: state.fieldErrors['title'],
              ),
            ),
            SwitchListTile(
              value: _done,
              title: const Text('完了'),
              onChanged: (value) => setState(() => _done = value),
            ),
            if (state.conflicted)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('他の端末で更新されています。開き直してください。'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.saving ? null : _save,
              child: Text(state.saving ? '保存中...' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final item = Item(
      id: widget.itemId,
      title: _title.text,
      done: _done,
      updatedAt: DateTime.now(),
    );
    ref.read(itemEditorViewModelProvider.notifier).save(item);
  }
}
