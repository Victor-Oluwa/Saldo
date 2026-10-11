import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saldo/app/theme/colors.dart';
import 'package:saldo/core/database/providers.dart';
import 'package:saldo/core/errors/failures.dart';
import 'package:saldo/core/widgets/confirm_dialog.dart';
import 'package:saldo/core/widgets/saldo_states.dart';
import 'package:saldo/core/widgets/saldo_tile.dart';
import 'package:saldo/core/widgets/skeleton.dart';
import 'package:saldo/features/categories/domain/category.dart';
import 'package:saldo/features/categories/presentation/categories_providers.dart';

/// Minimal category manager: list + create + rename + archive.
/// Needed so transaction forms can assign compatible categories.
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Expense'),
            Tab(text: 'Income'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _CategoryList(type: CategoryType.expense),
          _CategoryList(type: CategoryType.income),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('Category'),
      ),
    );
  }

  void _showCreate(BuildContext context) {
    final type = _tabs.index == 0 ? CategoryType.expense : CategoryType.income;
    showDialog(
      context: context,
      builder: (_) => _CategoryDialog(type: type),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.type});

  final CategoryType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(categoriesAllProvider);
    return cats.when(
      loading: () => const SaldoSkeletonList(count: 4, itemHeight: 72),
      error: (e, _) => SaldoErrorState(message: e.toString()),
      data: (all) {
        final list = all.where((c) => c.type == type).toList();
        if (list.isEmpty) {
          return const SaldoEmptyState(
            title: 'No categories',
            message: 'Create one to classify transactions.',
          );
        }
        final tint = type == CategoryType.income
            ? SaldoColors.primary
            : SaldoColors.expense;
        final icon = type == CategoryType.income
            ? Icons.arrow_downward
            : Icons.arrow_upward;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            return SaldoTile(
              leading: TileIcon(icon: icon, color: tint),
              title: Text(
                c.name + (c.isArchived ? ' (archived)' : ''),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(
                c.isSystem ? 'System' : 'Custom',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              onTap: () => _act(context, ref, c.id, 'rename'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => _act(context, ref, c.id, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(
                    value: 'archive',
                    child: Text('Archive / Unarchive'),
                  ),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String id,
    String action,
  ) async {
    final repo = ref.read(categoryRepositoryProvider);
    try {
      if (action == 'rename') {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (_) => _CategoryDialog(renameId: id),
        );
      } else if (action == 'archive') {
        final cur = await repo.getById(id);
        if (cur == null) return;
        await repo.setArchived(id: id, archived: !cur.isArchived);
        ref.invalidate(categoriesAllProvider);
      } else if (action == 'delete') {
        if (!context.mounted) return;
        final ok = await showSaldoConfirm(
          context: context,
          title: 'Delete category?',
          message:
              'Only works when no transactions or budgets use it. Otherwise archive it — history stays intact.',
        );
        if (!ok) return;
        await repo.delete(id);
        ref.invalidate(categoriesAllProvider);
      }
    } on Failure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  const _CategoryDialog({this.type, this.renameId});

  final CategoryType? type;
  final String? renameId;

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  final _name = TextEditingController();
  CategoryType _type = CategoryType.expense;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.type != null) _type = widget.type!;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(categoryRepositoryProvider);
      if (widget.renameId != null) {
        await repo.rename(id: widget.renameId!, name: _name.text);
      } else {
        await repo.create(name: _name.text, type: _type);
      }
      ref.invalidate(categoriesAllProvider);
      if (mounted) context.pop(true);
    } on Failure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRename = widget.renameId != null;
    return AlertDialog(
      title: Text(isRename ? 'Rename category' : 'New category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            autofocus: true,
          ),
          if (!isRename) ...[
            const SizedBox(height: 12),
            SegmentedButton<CategoryType>(
              segments: const [
                ButtonSegment(
                  value: CategoryType.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: CategoryType.income,
                  label: Text('Income'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
