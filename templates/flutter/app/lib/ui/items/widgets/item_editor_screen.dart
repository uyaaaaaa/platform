import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/widgets/async_value_view.dart';
import '../view_models/item_editor_view_model.dart';

class ItemEditorScreen extends ConsumerWidget {
  const ItemEditorScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = itemEditorViewModelProvider(itemId);
    final state = ref.watch(provider);

    ref.listen(provider, (previous, next) {
      final saved = next.value?.saved ?? false;
      if (saved && previous?.value?.saved != true) context.go(Routes.items);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Edit item')),
      body: AsyncValueView(
        value: state,
        onRetry: () => ref.invalidate(provider),
        builder: (context, data) => _EditorForm(itemId: itemId, initial: data),
      ),
    );
  }
}

class _EditorForm extends ConsumerStatefulWidget {
  const _EditorForm({required this.itemId, required this.initial});

  final String itemId;
  final ItemEditorState initial;

  @override
  ConsumerState<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends ConsumerState<_EditorForm> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial.title,
  );

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = itemEditorViewModelProvider(widget.itemId);
    final state = ref.watch(provider).requireValue;
    final viewModel = ref.read(provider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            onChanged: viewModel.changeTitle,
            decoration: InputDecoration(
              labelText: 'タイトル',
              errorText: state.fieldErrors['title'],
            ),
          ),
          SwitchListTile(
            value: state.done,
            title: const Text('完了'),
            onChanged: viewModel.changeDone,
          ),
          if (state.conflicted)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('他の端末で更新されています。開き直してください。'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: state.saving ? null : viewModel.save,
            child: Text(state.saving ? '保存中...' : '保存'),
          ),
        ],
      ),
    );
  }
}
