import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/mind_map.dart';
import '../../models/mind_folder.dart';
import '../canvas/canvas_screen.dart';
import 'home_notifier.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Mind Maps'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'create_folder') {
                _showCreateFolderDialog(context, ref);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'create_folder', child: Text('폴더생성')),
            ],
          ),
        ],
      ),
      body: homeState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : homeState.folders.isEmpty && homeState.mindMaps.isEmpty
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildTree(context, ref, homeState, null, 0),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Map'),
      ),
    );
  }

  List<Widget> _buildTree(
    BuildContext context,
    WidgetRef ref,
    HomeState state,
    String? parentId,
    int depth,
  ) {
    final indent = depth * 16.0;
    final widgets = <Widget>[];
    final notifier = ref.read(homeProvider.notifier);

    final foldersAtLevel =
        state.folders.where((f) => f.parentId == parentId).toList();

    for (final folder in foldersAtLevel) {
      final isFocused = state.focusedFolderId == folder.id;
      final mapsInFolder = state.mindMaps
          .where((m) => m.folderId == folder.id)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // Folder row
      widgets.add(
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: _FolderTile(
            folder: folder,
            isFocused: isFocused,
            onTap: () => notifier.toggleFolderFocus(folder.id),
            onDelete: () => _confirmDeleteFolder(context, ref, folder),
          ),
        ),
      );

      // Maps inside folder
      for (final map in mapsInFolder) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: indent + 16.0),
            child: _MindMapCard(
              mindMap: map,
              onTap: () => _openCanvas(context, ref, map),
              onDelete: () => notifier.deleteMindMap(map.id),
            ),
          ),
        );
      }

      // Subfolders (recursive)
      widgets.addAll(_buildTree(context, ref, state, folder.id, depth + 1));
    }

    return widgets;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No mind maps yet',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text('Tap the button below to create your first mind map'),
        ],
      ),
    );
  }

  void _openCanvas(BuildContext context, WidgetRef ref, MindMap mindMap) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CanvasScreen(mindMap: mindMap)))
        .then((_) => ref.read(homeProvider.notifier).loadAll());
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Mind Map'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Title',
            hintText: 'e.g. Project Ideas',
          ),
          onSubmitted: (_) => _create(ctx, ref, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _create(ctx, ref, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _create(
      BuildContext context, WidgetRef ref, String title) async {
    if (title.trim().isEmpty) return;
    Navigator.of(context).pop();
    final mindMap =
        await ref.read(homeProvider.notifier).createMindMap(title.trim());
    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => CanvasScreen(mindMap: mindMap)))
          .then((_) => ref.read(homeProvider.notifier).loadAll());
    }
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더생성'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: '폴더 이름'),
          onSubmitted: (_) => _createFolder(ctx, ref, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => _createFolder(ctx, ref, controller.text),
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }

  void _createFolder(BuildContext context, WidgetRef ref, String name) {
    if (name.trim().isEmpty) return;
    Navigator.of(context).pop();
    ref.read(homeProvider.notifier).createFolder(name.trim());
  }

  void _confirmDeleteFolder(
      BuildContext context, WidgetRef ref, MindFolder folder) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('폴더 삭제'),
        content: Text('"${folder.name}" 폴더와 포함된 모든 맵을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(homeProvider.notifier).deleteFolder(folder.id);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ─── Folder Tile ──────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final MindFolder folder;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _FolderTile({
    required this.folder,
    required this.isFocused,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: isFocused ? scheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Icon(
          Icons.folder_rounded,
          color: isFocused ? scheme.primary : Colors.amber.shade600,
          size: 28,
        ),
        title: Text(
          folder.name,
          style: TextStyle(
            fontWeight: isFocused ? FontWeight.bold : FontWeight.w500,
            color: isFocused ? scheme.primary : null,
          ),
        ),
        trailing: folder.name == '기본'
            ? null
            : IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
              ),
        onTap: onTap,
      ),
    );
  }
}

// ─── MindMap Card ─────────────────────────────────────────────────────────────

class _MindMapCard extends StatelessWidget {
  final MindMap mindMap;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MindMapCard({
    required this.mindMap,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMM d, yyyy').format(mindMap.updatedAt);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_tree,
              color: Color(0xFF007AFF), size: 22),
        ),
        title: Text(
          mindMap.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${mindMap.nodes.length} nodes · $dateStr',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _confirmDelete(context),
        ),
        onTap: onTap,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Mind Map'),
        content: Text('Delete "${mindMap.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
