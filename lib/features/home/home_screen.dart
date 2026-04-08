import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/mind_map.dart';
import '../../models/mind_folder.dart';
import '../../models/node_style.dart';
import '../canvas/canvas_screen.dart';
import 'home_notifier.dart';

// ── Name formatter: Korean=2 units, others=1, max 12 units (6 Korean / 12 English)
class _FolderNameFormatter extends TextInputFormatter {
  static const int _maxUnits = 12;

  static int _units(String text) {
    int u = 0;
    for (final r in text.runes) {
      u += (r >= 0xAC00 && r <= 0xD7A3) ? 2 : 1;
    }
    return u;
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    return _units(next.text) <= _maxUnits ? next : old;
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeProvider);
    final notifier = ref.read(homeProvider.notifier);

    final focusedFolder = state.focusedFolderId != null
        ? state.folders.where((f) => f.id == state.focusedFolderId).firstOrNull
        : null;

    final allMaps = state.mindMaps.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final visibleMaps = focusedFolder != null
        ? allMaps.where((m) => m.folderId == focusedFolder.id).toList()
        : <MindMap>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Mind Maps'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) =>
                _onMenuSelected(context, ref, v, focusedFolder, state),
            itemBuilder: (_) => _buildMenuItems(state, focusedFolder),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Folders ───────────────────────────────────────────────
                if (state.folders.isNotEmpty) ...[
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: state.folders.map((folder) {
                      return DragTarget<MindMap>(
                        onWillAcceptWithDetails: (d) =>
                            d.data.folderId != folder.id,
                        onAcceptWithDetails: (d) =>
                            notifier.moveMapToFolder(d.data.id, folder.id),
                        builder: (ctx, candidates, _) => _FolderTile(
                          folder: folder,
                          isFocused: state.focusedFolderId == folder.id,
                          isDraggingOver: candidates.isNotEmpty,
                          onTap: () => notifier.toggleFolderFocus(folder.id),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Divider(thickness: 2, color: Color(0xFFB0B0B0)),
                  const SizedBox(height: 8),
                ],
                // ── Maps ──────────────────────────────────────────────────
                if (focusedFolder == null)
                  _buildNoFolderSelected(context)
                else if (visibleMaps.isEmpty)
                  _buildEmptyMaps(context)
                else
                  ...visibleMaps.map((map) => LongPressDraggable<MindMap>(
                        data: map,
                        hapticFeedbackOnStart: true,
                        feedback: Material(
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 300,
                            child: _MindMapCard(
                                mindMap: map, onTap: () {}, onDelete: () {}),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _MindMapCard(
                              mindMap: map, onTap: () {}, onDelete: () {}),
                        ),
                        child: _MindMapCard(
                          mindMap: map,
                          onTap: () => _openCanvas(context, ref, map),
                          onDelete: () => notifier.deleteMindMap(map.id),
                        ),
                      )),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Map'),
      ),
    );
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  List<PopupMenuEntry<String>> _buildMenuItems(
      HomeState state, MindFolder? focused) {
    final atMax = state.folders.length >= HomeNotifier.maxFolders;
    if (focused != null) {
      return [
        const PopupMenuItem(value: 'rename', child: Text('폴더명 변경')),
        const PopupMenuItem(value: 'color', child: Text('폴더 색상 변경')),
        if (focused.name != '기본')
          const PopupMenuItem(
            value: 'delete',
            child: Text('폴더 삭제', style: TextStyle(color: Colors.red)),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'create_folder',
          enabled: !atMax,
          child: Text(
              '폴더생성 (${state.folders.length}/${HomeNotifier.maxFolders})'),
        ),
      ];
    }
    return [
      PopupMenuItem(
        value: 'create_folder',
        enabled: !atMax,
        child: Text(
            '폴더생성 (${state.folders.length}/${HomeNotifier.maxFolders})'),
      ),
    ];
  }

  void _onMenuSelected(BuildContext context, WidgetRef ref, String value,
      MindFolder? focused, HomeState state) {
    switch (value) {
      case 'create_folder':
        _showCreateFolderDialog(context, ref);
      case 'rename':
        if (focused != null) _showRenameFolderDialog(context, ref, focused);
      case 'color':
        if (focused != null) _showColorPickerDialog(context, ref, focused);
      case 'delete':
        if (focused != null) _confirmDeleteFolder(context, ref, focused);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더생성'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          inputFormatters: [_FolderNameFormatter()],
          decoration: const InputDecoration(
            labelText: '폴더 이름',
            hintText: '한글 최대 6자 / 영문 최대 12자',
          ),
          onSubmitted: (_) => _createFolder(ctx, ref, ctrl.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => _createFolder(ctx, ref, ctrl.text),
              child: const Text('생성')),
        ],
      ),
    );
  }

  void _createFolder(BuildContext context, WidgetRef ref, String name) {
    if (name.trim().isEmpty) return;
    Navigator.of(context).pop();
    ref.read(homeProvider.notifier).createFolder(name.trim());
  }

  void _showRenameFolderDialog(
      BuildContext context, WidgetRef ref, MindFolder folder) {
    final ctrl = TextEditingController(text: folder.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더명 변경'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          inputFormatters: [_FolderNameFormatter()],
          decoration: const InputDecoration(
            labelText: '새 폴더 이름',
            hintText: '한글 최대 6자 / 영문 최대 12자',
          ),
          onSubmitted: (_) => _renameFolder(ctx, ref, folder.id, ctrl.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => _renameFolder(ctx, ref, folder.id, ctrl.text),
              child: const Text('변경')),
        ],
      ),
    );
  }

  void _renameFolder(
      BuildContext context, WidgetRef ref, String id, String name) {
    if (name.trim().isEmpty) return;
    Navigator.of(context).pop();
    ref.read(homeProvider.notifier).renameFolder(id, name.trim());
  }

  void _showColorPickerDialog(
      BuildContext context, WidgetRef ref, MindFolder folder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더 색상 변경'),
        content: SizedBox(
          width: double.maxFinite,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: NodeStyle.presetColors.map((cv) {
              final isSel = folder.colorValue == cv;
              return GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(homeProvider.notifier).updateFolderColor(folder.id, cv);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(cv),
                    shape: BoxShape.circle,
                    border: isSel
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                          color: Color(cv).withAlpha(80),
                          blurRadius: isSel ? 12 : 4)
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
        ],
      ),
    );
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
              child: const Text('취소')),
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

  void _openCanvas(BuildContext context, WidgetRef ref, MindMap mindMap) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CanvasScreen(mindMap: mindMap)))
        .then((_) => ref.read(homeProvider.notifier).loadAll());
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Mind Map'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Title', hintText: 'e.g. Project Ideas'),
          onSubmitted: (_) => _create(ctx, ref, ctrl.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _create(ctx, ref, ctrl.text),
              child: const Text('Create')),
        ],
      ),
    );
  }

  Future<void> _create(
      BuildContext context, WidgetRef ref, String title) async {
    if (title.trim().isEmpty) return;
    Navigator.of(context).pop();
    final map =
        await ref.read(homeProvider.notifier).createMindMap(title.trim());
    if (context.mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => CanvasScreen(mindMap: map)))
          .then((_) => ref.read(homeProvider.notifier).loadAll());
    }
  }

  Widget _buildNoFolderSelected(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('폴더를 선택하면 맵 목록이 표시됩니다',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMaps(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('맵이 없습니다',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ── Folder Tile ───────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final MindFolder folder;
  final bool isFocused;
  final bool isDraggingOver;
  final VoidCallback onTap;

  const _FolderTile({
    required this.folder,
    required this.isFocused,
    required this.isDraggingOver,
    required this.onTap,
  });

  // Accent color for icon/text – ensure it's dark enough to read on light bg
  Color _accent() {
    if (folder.colorValue != null) {
      final c = Color(folder.colorValue!);
      final lum = c.computeLuminance();
      if (lum > 0.5) {
        return HSLColor.fromColor(c).withLightness(0.35).toColor();
      }
      return c;
    }
    return Colors.amber.shade700;
  }

  Color _bg() {
    if (folder.colorValue != null) {
      return Color(folder.colorValue!).withAlpha(22);
    }
    return Colors.amber.shade50;
  }

  Color _tab() {
    if (folder.colorValue != null) {
      return Color(folder.colorValue!).withAlpha(55);
    }
    return Colors.amber.shade200;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    // Border color: focused = blue gradient indicator, drag-over = green, default = subtle
    Color borderColor;
    double borderWidth;
    if (isDraggingOver) {
      borderColor = Colors.green.shade400;
      borderWidth = 2.5;
    } else if (isFocused) {
      borderColor = const Color(0xFF007AFF);
      borderWidth = 2.5;
    } else {
      borderColor = accent.withAlpha(60);
      borderWidth = 1.0;
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab (decorative, no text)
          Container(
            width: 44,
            height: 9,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: isDraggingOver
                  ? Colors.green.shade200
                  : isFocused
                      ? const Color(0xFF007AFF).withAlpha(55)
                      : _tab(),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(10),
              ),
            ),
          ),
          // Body — border-only focus indicator, bg unchanged
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 110,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: _bg(), // always same regardless of focus
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: const Color(0xFF007AFF).withAlpha(50),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFocused
                      ? Icons.folder_open_rounded
                      : Icons.folder_rounded,
                  color: accent,
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  folder.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isFocused ? FontWeight.w700 : FontWeight.w500,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── MindMap Card ──────────────────────────────────────────────────────────────

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
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.account_tree,
              color: Color(0xFF007AFF), size: 20),
        ),
        title: Text(mindMap.title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          '${mindMap.nodes.length} nodes · $dateStr',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline,
              color: Colors.redAccent, size: 20),
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
              child: const Text('Cancel')),
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
