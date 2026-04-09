import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/mind_map.dart';
import '../../models/mind_folder.dart';
import '../../models/node_style.dart';
import '../../services/file_service.dart';
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
    final focusedMap = state.focusedMapId != null
        ? state.mindMaps.where((m) => m.id == state.focusedMapId).firstOrNull
        : null;

    final allMaps = state.mindMaps.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final visibleMaps = focusedFolder != null
        ? allMaps.where((m) => m.folderId == focusedFolder.id).toList()
        : <MindMap>[];

    // Map count per folder for badges
    final mapCountByFolder = <String, int>{};
    for (final m in state.mindMaps) {
      if (m.folderId != null) {
        mapCountByFolder[m.folderId!] =
            (mapCountByFolder[m.folderId!] ?? 0) + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Mind Maps'),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) =>
                _onMenuSelected(context, ref, v, focusedFolder, focusedMap, state),
            itemBuilder: (_) =>
                _buildMenuItems(state, focusedFolder, focusedMap),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Fixed Folder Area ────────────────────────────────────
                if (state.folders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Wrap(
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
                            mapCount: mapCountByFolder[folder.id] ?? 0,
                            onTap: () => notifier.toggleFolderFocus(folder.id),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                // ── Fixed Divider ─────────────────────────────────────────
                const Divider(thickness: 2, color: Color(0xFFB0B0B0), height: 1),
                // ── Scrollable Map Area ───────────────────────────────────
                Expanded(
                  child: focusedFolder == null
                      ? _buildNoFolderSelected(context)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Folder name header
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 8),
                              child: Text(
                                focusedFolder.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1C1C1E),
                                ),
                              ),
                            ),
                            // Map grid
                            Expanded(
                              child: visibleMaps.isEmpty
                                  ? _buildEmptyMaps(context)
                                  : SingleChildScrollView(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 0, 16, 24),
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: visibleMaps.map((map) {
                                          return LongPressDraggable<MindMap>(
                                            data: map,
                                            hapticFeedbackOnStart: true,
                                            feedback: Material(
                                              elevation: 6,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: _MapTile(
                                                mindMap: map,
                                                isFocused: false,
                                                onTap: () {},
                                                onDoubleTap: () {},
                                              ),
                                            ),
                                            childWhenDragging: Opacity(
                                              opacity: 0.35,
                                              child: _MapTile(
                                                mindMap: map,
                                                isFocused: false,
                                                onTap: () {},
                                                onDoubleTap: () {},
                                              ),
                                            ),
                                            child: _MapTile(
                                              mindMap: map,
                                              isFocused: state.focusedMapId ==
                                                  map.id,
                                              onTap: () =>
                                                  notifier.toggleMapFocus(
                                                      map.id),
                                              onDoubleTap: () =>
                                                  _openCanvas(context, ref, map),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
      floatingActionButton: focusedFolder == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showCreateDialog(context, ref),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(
                      child: Icon(Icons.account_tree, size: 22),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade400,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.add,
                            size: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Menu ──────────────────────────────────────────────────────────────────

  List<PopupMenuEntry<String>> _buildMenuItems(
      HomeState state, MindFolder? focused, MindMap? focusedMap) {
    final atMax = state.folders.length >= HomeNotifier.maxFolders;
    final items = <PopupMenuEntry<String>>[];

    if (focused != null) {
      items.addAll([
        const PopupMenuItem(value: 'rename', child: Text('폴더명 변경')),
        const PopupMenuItem(value: 'color', child: Text('폴더 색상 변경')),
        if (focused.name != '기본')
          const PopupMenuItem(
            value: 'delete_folder',
            child: Text('폴더 삭제', style: TextStyle(color: Colors.red)),
          ),
        const PopupMenuDivider(),
      ]);
    }

    if (focusedMap != null) {
      items.addAll([
        const PopupMenuItem(value: 'export_map', child: Text('내보내기 (JSON)')),
        const PopupMenuItem(
          value: 'delete_map',
          child: Text('맵 삭제', style: TextStyle(color: Colors.red)),
        ),
        const PopupMenuDivider(),
      ]);
    }

    items.add(PopupMenuItem(
      value: 'create_folder',
      enabled: !atMax,
      child:
          Text('폴더생성 (${state.folders.length}/${HomeNotifier.maxFolders})'),
    ));

    items.addAll([
      const PopupMenuDivider(),
      const PopupMenuItem(value: 'import_map', child: Text('맵 가져오기 (JSON)')),
    ]);

    return items;
  }

  void _onMenuSelected(BuildContext context, WidgetRef ref, String value,
      MindFolder? focused, MindMap? focusedMap, HomeState state) {
    switch (value) {
      case 'create_folder':
        _showCreateFolderDialog(context, ref);
      case 'rename':
        if (focused != null) _showRenameFolderDialog(context, ref, focused);
      case 'color':
        if (focused != null) _showColorPickerDialog(context, ref, focused);
      case 'delete_folder':
        if (focused != null) _confirmDeleteFolder(context, ref, focused);
      case 'delete_map':
        if (focusedMap != null) _confirmDeleteMap(context, ref, focusedMap);
      case 'export_map':
        if (focusedMap != null) _exportMap(context, focusedMap);
      case 'import_map':
        _importMap(context, ref);
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
                  ref
                      .read(homeProvider.notifier)
                      .updateFolderColor(folder.id, cv);
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

  void _confirmDeleteMap(
      BuildContext context, WidgetRef ref, MindMap map) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('맵 삭제'),
        content: Text('"${map.title}"을 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(homeProvider.notifier).deleteMindMap(map.id);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportMap(BuildContext context, MindMap map) async {
    try {
      final jsonStr = jsonEncode(map.toJson());
      final safeTitle = map.title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
      final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
      final fileName = '${safeTitle}_${timestamp}_map.json';
      await downloadJsonFile(jsonStr, fileName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$fileName" 저장됨'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('내보내기 실패'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Import ────────────────────────────────────────────────────────────────

  Future<void> _importMap(BuildContext context, WidgetRef ref) async {
    try {
      final content = await pickJsonFile();
      if (content == null) return; // user cancelled

      final Map<String, dynamic> json =
          jsonDecode(content) as Map<String, dynamic>;
      final map = MindMap.fromJson(json);

      await ref.read(homeProvider.notifier).importMapToDefaultFolder(map);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${map.title}" 가져오기 완료 (기본 폴더에 저장됨)'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('올바른 맵 JSON 파일이 아닙니다'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('가져오기 실패: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('폴더를 선택하면 맵 목록이 표시됩니다',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildEmptyMaps(BuildContext context) {
    return Center(
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
    );
  }
}

// ── Folder Tile ───────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final MindFolder folder;
  final bool isFocused;
  final bool isDraggingOver;
  final int mapCount;
  final VoidCallback onTap;

  const _FolderTile({
    required this.folder,
    required this.isFocused,
    required this.isDraggingOver,
    required this.mapCount,
    required this.onTap,
  });

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
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 110,
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                decoration: BoxDecoration(
                  color: _bg(),
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
              // Map count badge
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '$mapCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Map Tile (compact, folder-sized) ─────────────────────────────────────────

class _MapTile extends StatelessWidget {
  final MindMap mindMap;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  const _MapTile({
    required this.mindMap,
    required this.isFocused,
    required this.onTap,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yy.MM.dd').format(mindMap.updatedAt);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 110,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFocused
                ? const Color(0xFF007AFF)
                : Colors.grey.withAlpha(40),
            width: isFocused ? 2.5 : 1.0,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: const Color(0xFF007AFF).withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_tree,
                  color: Color(0xFF007AFF), size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              mindMap.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isFocused ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF1C1C1E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dateStr,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
