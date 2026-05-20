import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const PhotoLiteApp());
}

class PhotoLiteApp extends StatelessWidget {
  const PhotoLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PhotoLite',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A84FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PhotoLiteHome(),
    );
  }
}

enum ReviewAction { keep, previous, delete }
enum SwipeDecision { none, keep, previous, delete }
enum ScreenPhase { empty, reviewing, confirming, done }
enum LibraryMode { auto, system, folder }
enum PhotoDatePreference {
  oneMonth('近一个月'),
  threeMonths('近三个月'),
  sixMonths('近半年'),
  oneYear('近一年'),
  fiveYears('近五年'),
  all('全部照片');

  const PhotoDatePreference(this.label);
  final String label;

  DateTime? cutoff(DateTime now) {
    return switch (this) {
      PhotoDatePreference.oneMonth => DateTime(now.year, now.month - 1, now.day),
      PhotoDatePreference.threeMonths => DateTime(now.year, now.month - 3, now.day),
      PhotoDatePreference.sixMonths => DateTime(now.year, now.month - 6, now.day),
      PhotoDatePreference.oneYear => DateTime(now.year - 1, now.month, now.day),
      PhotoDatePreference.fiveYears => DateTime(now.year - 5, now.month, now.day),
      PhotoDatePreference.all => null,
    };
  }
}

class PhotoLiteHome extends StatefulWidget {
  const PhotoLiteHome({super.key});

  @override
  State<PhotoLiteHome> createState() => _PhotoLiteHomeState();
}

class _PhotoLiteHomeState extends State<PhotoLiteHome> {
  static const _supportedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.heic',
    '.heif',
  };

  ScreenPhase _phase = ScreenPhase.empty;
  LibraryMode _libraryMode = LibraryMode.auto;
  PhotoDatePreference _datePreference = PhotoDatePreference.all;
  Directory? _rootDirectory;
  Directory? _trashDirectory;
  List<PhotoItem> _queue = [];
  int _groupSize = 10;
  int _groupIndex = 0;
  int _currentIndex = 0;
  int _reviewedCount = 0;
  int _deletedCount = 0;
  int _savedBytes = 0;
  bool _hapticsEnabled = true;
  bool _busy = false;
  bool _showSettings = false;
  bool _loading = false;
  bool _currentFirstHint = false;
  bool _showSwipeHint = false;
  bool _showOperationTips = false;
  bool _neverShowOperationTips = false;
  bool _suppressOperationTipsThisWeek = false;
  String _statusText = '开始整理照片。';
  Offset _dragOffset = Offset.zero;
  Offset _dragTranslation = Offset.zero;
  double _dragRotationRadians = 0;
  bool _isAnimatingDecision = false;
  bool _disableNextMotionAnimation = false;
  LogicalKeyboardKey? _activeKeyboardKey;
  SwipeDecision? _activeKeyboardDecision;
  KeyboardDirection? _activeKeyboardDirection;
  final Set<String> _markedDelete = {};
  final Set<String> _preservedInConfirm = {};
  final List<ReviewedAction> _history = [];
  final FocusNode _reviewFocusNode = FocusNode(debugLabel: 'PhotoLite review keyboard');
  Timer? _hintTimer;

  PhotoItem? get _currentPhoto {
    if (_phase != ScreenPhase.reviewing) return null;
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  List<PhotoItem> get _currentGroup {
    final start = _groupIndex * _groupSize;
    final end = min(start + _groupSize, _queue.length);
    if (start >= end) return const [];
    return _queue.sublist(start, end);
  }

  List<PhotoItem> get _activeDeleteGroup {
    return _currentGroup.where((e) => _markedDelete.contains(e.id)).toList();
  }

  int get _groupProgressCount => _currentGroup.isEmpty ? 0 : (_currentIndex - (_groupIndex * _groupSize)) + 1;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  bool get _isMacOS => !kIsWeb && Platform.isMacOS;
  bool get _usesSystemGallery => _isAndroid || _libraryMode == LibraryMode.system || (_isMacOS && _libraryMode == LibraryMode.auto);
  @override
  void dispose() {
    _hintTimer?.cancel();
    _reviewFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_phase) {
                ScreenPhase.empty => _buildEmptyState(context),
                ScreenPhase.reviewing => _buildReviewState(context),
                ScreenPhase.confirming => _buildConfirmState(context),
                ScreenPhase.done => _buildDoneState(context),
              },
            ),
          ),
          if (_showSettings) _buildSettingsSheet(context),
          if (_showOperationTips) _buildOperationTipsOverlay(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final subtitle = _usesSystemGallery
        ? '从系统图库随机抽取照片，左滑下一张，右滑上一张，上滑删除。'
        : '从文件夹里随机抽取照片，左滑下一张，右滑上一张，上滑删除。';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_library_rounded, size: 54, color: Colors.white70),
              const SizedBox(height: 16),
              const Text('PhotoLite', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                _loading ? '正在加载照片...' : (_statusText.isEmpty ? subtitle : _statusText),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _startReview,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(_usesSystemGallery ? '开始访问图库' : '选择文件夹开始'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => setState(() => _showSettings = true),
                icon: const Icon(Icons.settings_rounded),
                label: const Text('设置'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewState(BuildContext context) {
    final photo = _currentPhoto;
    if (photo == null) return const SizedBox.shrink();
    final progressValue = _currentGroup.isEmpty ? 0.0 : (_groupProgressCount / _currentGroup.length).clamp(0.0, 1.0);
    final motionDuration = _disableNextMotionAnimation
        ? Duration.zero
        : (_isAnimatingDecision ? const Duration(milliseconds: 210) : Duration.zero);

    return Focus(
      focusNode: _reviewFocusNode,
      autofocus: true,
      onKeyEvent: _handleReviewKeyEvent,
      child: SafeArea(
        child: Column(
          children: [
            _topBar(context, photo: photo, progressValue: progressValue),
            Expanded(
              child: GestureDetector(
                onTap: _reviewFocusNode.requestFocus,
                onPanUpdate: _handlePanUpdate,
                onPanEnd: _handlePanEnd,
                onPanCancel: _resetDrag,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920, maxHeight: 1100),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    AnimatedContainer(
                                      duration: motionDuration,
                                      curve: Curves.easeOutCubic,
                                      transformAlignment: Alignment.center,
                                      transform: Matrix4.translationValues(_dragOffset.dx, _dragOffset.dy, 0)..rotateZ(_dragRotationRadians),
                                      child: RepaintBoundary(child: photo.preview(context, fit: BoxFit.contain)),
                                    ),
                                    if (_showSwipeHint || _currentFirstHint)
                                      Positioned(
                                        left: 20,
                                        right: 20,
                                        top: 18,
                                        child: Center(child: _swipeHintBanner()),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              _metadataPanel(photo),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmState(BuildContext context) {
    final deleteItems = _activeDeleteGroup;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: deleteItems.isEmpty
                ? const Center(child: Text('没有待删除照片', style: TextStyle(color: Colors.white70, fontSize: 17, fontWeight: FontWeight.w600)))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: deleteItems.length,
                    itemBuilder: (context, index) {
                      final item = deleteItems[index];
                      final selected = !_preservedInConfirm.contains(item.id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _preservedInConfirm.add(item.id);
                            } else {
                              _preservedInConfirm.remove(item.id);
                            }
                          });
                          _hapticSelection();
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              item.preview(context),
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Icon(
                                  selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: selected ? const Color(0xFF0A84FF) : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.34),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3B30),
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                  ),
                  onPressed: _busy ? null : _confirmDelete,
                  child: Text(
                    _busy ? '正在删除...' : '删除 ${_activeDeleteGroup.length - _preservedInConfirm.length} 张照片',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _busy ? null : () {
                    _advanceToNextGroup();
                    _hapticLight();
                  },
                  child: const Text('取消删除', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneState(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 64, color: Color(0xFF34C759)),
              const SizedBox(height: 16),
              const Text('本轮处理完成', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                '已筛选 $_reviewedCount 张，删除 $_deletedCount 张，节省约 ${_formatBytes(_savedBytes)}。',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _restart, child: const Text('重新开始')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, {PhotoItem? photo, double progressValue = 0, String title = 'PhotoLite'}) {
    final dateText = photo == null ? title : photo.timeText.split(' ').first;
    final timeText = photo == null ? _statusText : photo.timeText.split(' ').last;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.82), Colors.black.withValues(alpha: 0)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _glassButton(icon: Icons.settings_rounded, color: const Color(0xFF0A84FF), onTap: () => setState(() => _showSettings = true)),
              const SizedBox(width: 12),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 178, minWidth: 126),
                    child: _glassPanel(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(dateText, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 1),
                          Text(timeText, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _glassButton(
                icon: photo == null ? Icons.folder_open_rounded : Icons.ios_share_rounded,
                color: photo == null ? Colors.white : const Color(0xFF0A84FF),
                onTap: photo == null ? _startReview : _shareCurrentPhoto,
              ),
            ],
          ),
          if (photo != null) ...[
            const SizedBox(height: 10),
            _glassPanel(
              radius: 999,
              padding: const EdgeInsets.all(5),
              child: SizedBox(
                width: 142,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF0A84FF)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metadataPanel(PhotoItem photo) {
    return _glassPanel(
      radius: 26,
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _metaLine(Icons.location_on_outlined, photo.locationText ?? '地点未知'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _metaInline(Icons.aspect_ratio_rounded, photo.resolutionText),
              const SizedBox(width: 14),
              _metaInline(Icons.insert_drive_file_outlined, photo.storageText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaLine(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.white60),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _metaInline(IconData icon, String text) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white60),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _swipeHintBanner() {
    final text = _currentFirstHint ? '这是第一张' : (_statusText.isEmpty ? '左滑下一张 · 右滑上一张 · 上滑删除' : _statusText);
    final color = switch (text) {
      '删除' => const Color(0xFFFF453A),
      '下一张' => const Color(0xFF30D158),
      '上一张' => const Color(0xFF0A84FF),
      _ => Colors.white,
    };
    final icon = switch (text) {
      '删除' => Icons.delete_rounded,
      '下一张' => Icons.check_rounded,
      '这是第一张' => Icons.looks_one_rounded,
      _ => Icons.keyboard_return_rounded,
    };
    return _glassPanel(
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _glassButton({required IconData icon, required VoidCallback onTap, Color color = Colors.white}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: _glassPanel(
        radius: 999,
        width: 44,
        height: 44,
        padding: EdgeInsets.zero,
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _glassPanel({
    required Widget child,
    double radius = 24,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
    double? width,
    double? height,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSettingsSheet(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    if (_isMacOS) {
      return Positioned.fill(
        child: GestureDetector(
          onTap: () => setState(() => _showSettings = false),
          child: Container(
            color: Colors.black.withValues(alpha: 0.46),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {},
              child: _glassPanel(
                radius: 28,
                width: min(screen.width - 48, 460),
                height: min(screen.height - 80, 650),
                padding: EdgeInsets.zero,
                child: _settingsPanelContent(desktop: true),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: SafeArea(
          child: _settingsPanelContent(desktop: false),
        ),
      ),
    );
  }

  Widget _settingsPanelContent({required bool desktop}) {
    return Column(
      children: [
        Padding(
          padding: desktop ? const EdgeInsets.fromLTRB(18, 14, 12, 8) : const EdgeInsets.fromLTRB(16, 8, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: Text('设置', textAlign: desktop ? TextAlign.left : TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => setState(() => _showSettings = false),
                child: Text(desktop ? '关闭' : '完成', style: const TextStyle(color: Color(0xFF0A84FF), fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, desktop ? 8 : 12, 16, 30),
            children: [
              _settingsCard(
                child: Column(
                  children: [
                    _settingsRow(Icons.photo_library_outlined, '模式', _libraryModeLabel(), trailing: DropdownButton<LibraryMode>(
                      value: _libraryMode,
                      dropdownColor: const Color(0xFF1C1C1E),
                      underline: const SizedBox.shrink(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _libraryMode = value);
                      },
                      items: const [
                        DropdownMenuItem(value: LibraryMode.auto, child: Text('自动')),
                        DropdownMenuItem(value: LibraryMode.system, child: Text('系统图库')),
                        DropdownMenuItem(value: LibraryMode.folder, child: Text('文件夹')),
                      ],
                    )),
                    if (_usesSystemGallery) ...[
                      _settingsDivider(),
                      _settingsRow(Icons.calendar_month_rounded, '照片范围', _datePreference.label, trailing: DropdownButton<PhotoDatePreference>(
                        value: _datePreference,
                        dropdownColor: const Color(0xFF1C1C1E),
                        underline: const SizedBox.shrink(),
                        onChanged: (value) {
                          if (value == null) return;
                          _changeDatePreference(value);
                        },
                        items: PhotoDatePreference.values
                            .map((value) => DropdownMenuItem(value: value, child: Text(value.label)))
                            .toList(),
                      )),
                    ],
                    _settingsDivider(),
                    _settingsRow(Icons.collections_rounded, '每组照片数', '$_groupSize', trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(onPressed: _groupSize <= 5 ? null : () => _changeGroupSize(_groupSize - 1), icon: const Icon(Icons.remove_rounded)),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(onPressed: _groupSize >= 30 ? null : () => _changeGroupSize(_groupSize + 1), icon: const Icon(Icons.add_rounded)),
                      ],
                    )),
                    if (!_isMacOS) ...[
                      _settingsDivider(),
                      _settingsRow(Icons.vibration_rounded, '振动反馈', _hapticsEnabled ? '开启' : '关闭', trailing: Switch(
                        value: _hapticsEnabled,
                        activeThumbColor: const Color(0xFF0A84FF),
                        onChanged: (value) => setState(() => _hapticsEnabled = value),
                      )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _settingsCard(
                child: Column(
                  children: [
                    _settingsRow(Icons.check_circle_outline_rounded, '已筛选', '$_reviewedCount 张'),
                    _settingsDivider(),
                    _settingsRow(Icons.delete_outline_rounded, '已删除', '$_deletedCount 张'),
                    _settingsDivider(),
                    _settingsRow(Icons.storage_rounded, '节省空间', _formatBytes(_savedBytes)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _settingsCard(
                child: InkWell(
                  onTap: _restart,
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Color(0xFFFF453A), size: 22),
                      SizedBox(width: 12),
                      Expanded(child: Text('清空所有已处理记录', style: TextStyle(color: Color(0xFFFF453A), fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsCard({required Widget child}) {
    return _glassPanel(
      radius: 26,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: child,
    );
  }

  Widget _settingsDivider() {
    return Divider(height: 22, color: Colors.white.withValues(alpha: 0.10));
  }

  Widget _settingsRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 22),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
        Text(value, style: const TextStyle(color: Colors.white60)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }

  Widget _buildOperationTipsOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.36),
        alignment: Alignment.center,
        child: _glassPanel(
          radius: 30,
          width: 320,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gesture_rounded, size: 32, color: Color(0xFF0A84FF)),
              const SizedBox(height: 8),
              const Text('操作提示', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _gestureCue(Icons.arrow_back_rounded, '左滑', '下一张')),
                  const SizedBox(width: 8),
                  Expanded(child: _gestureCue(Icons.arrow_upward_rounded, '上滑', '删除')),
                  const SizedBox(width: 8),
                  Expanded(child: _gestureCue(Icons.arrow_forward_rounded, '右滑', '上一张')),
                ],
              ),
              const SizedBox(height: 18),
              const Text('左滑进入下一张', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 7),
              const Text('右滑返回上一张', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 7),
              const Text('上滑标记删除', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                '每组结束后会二次确认，确认后才会调用系统删除。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, height: 1.35, fontSize: 13),
              ),
              const SizedBox(height: 18),
              _tipsOptionPanel(),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A84FF),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                onPressed: _confirmOperationTips,
                child: const Text('确定', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gestureCue(IconData icon, String title, String subtitle) {
    return _glassPanel(
      radius: 17,
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: const Color(0xFF0A84FF).withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF0A84FF), size: 20),
          ),
          const SizedBox(height: 7),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tipsOptionPanel() {
    return _glassPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          _tipsCheckRow('再也不弹出', _neverShowOperationTips, () {
            setState(() {
              _neverShowOperationTips = !_neverShowOperationTips;
              if (_neverShowOperationTips) _suppressOperationTipsThisWeek = false;
            });
            _hapticSelection();
          }),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.10)),
          _tipsCheckRow('本周不弹出', _suppressOperationTipsThisWeek, () {
            setState(() {
              _suppressOperationTipsThisWeek = !_suppressOperationTipsThisWeek;
              if (_suppressOperationTipsThisWeek) _neverShowOperationTips = false;
            });
            _hapticSelection();
          }),
        ],
      ),
    );
  }

  Widget _tipsCheckRow(String title, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? const Color(0xFF0A84FF) : Colors.white38, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 16, color: Colors.white70))),
          ],
        ),
      ),
    );
  }

  Future<void> _startReview() async {
    if (_loading) return;
    if (_usesSystemGallery) {
      await _loadFromSystemGallery();
    } else {
      await _pickFolder();
    }
  }

  Future<void> _loadFromSystemGallery() async {
    setState(() {
      _loading = true;
      _phase = ScreenPhase.empty;
      _statusText = '正在请求图库权限...';
      _showSettings = false;
    });

    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        setState(() {
          _loading = false;
          _statusText = '没有获得图库权限。请在系统设置里开启。';
        });
        return;
      }

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
        ),
      );
      final albums = paths.toList();
      if (albums.isEmpty) {
        setState(() {
          _loading = false;
          _statusText = '没有找到可用图库。';
        });
        return;
      }

      final all = <AssetEntity>[];
      for (final album in albums) {
        final assets = await album.getAssetListPaged(page: 0, size: 500);
        all.addAll(assets);
      }
      final cutoff = _datePreference.cutoff(DateTime.now());
      final filtered = cutoff == null
          ? all
          : all.where((asset) => asset.createDateTime.isAfter(cutoff) || asset.createDateTime.isAtSameMomentAs(cutoff)).toList();
      filtered.shuffle(Random());

      final items = await Future.wait(filtered.map(PhotoItem.fromAsset));
      _applyLoadedItems(items, mode: LibraryMode.system);
    } catch (e) {
      setState(() {
        _loading = false;
        _statusText = '读取图库失败：$e';
      });
    }
  }

  Future<void> _pickFolder() async {
    if (kIsWeb) return;
    final dir = await getDirectoryPath(confirmButtonText: '选择照片文件夹');
    if (dir == null) return;

    setState(() {
      _loading = true;
      _phase = ScreenPhase.empty;
      _statusText = '正在扫描文件夹...';
      _showSettings = false;
    });

    try {
      final root = Directory(dir);
      final files = await _scanImages(root);
      files.shuffle(Random());
      final items = files.map((file) => PhotoItem.fromFile(file, root)).toList();
      _applyLoadedItems(items, mode: LibraryMode.folder, root: root);
    } catch (e) {
      setState(() {
        _loading = false;
        _statusText = '扫描失败：$e';
      });
    }
  }

  Future<void> _applyLoadedItems(List<PhotoItem> items, {required LibraryMode mode, Directory? root}) async {
    if (items.isEmpty) {
      setState(() {
        _rootDirectory = root;
        _trashDirectory = root == null ? null : Directory(p.join(root.path, '.photolite_trash'));
        _queue = [];
        _phase = ScreenPhase.empty;
        _statusText = _usesSystemGallery ? '没有可用的图片。' : '这个文件夹里没有可识别的图片。';
        _loading = false;
        _libraryMode = mode;
      });
      return;
    }

    setState(() {
      _rootDirectory = root;
      _trashDirectory = root == null ? null : Directory(p.join(root.path, '.photolite_trash'));
      _queue = items;
      _groupIndex = 0;
      _currentIndex = 0;
      _reviewedCount = 0;
      _deletedCount = 0;
      _savedBytes = 0;
      _markedDelete.clear();
      _preservedInConfirm.clear();
      _history.clear();
      _phase = ScreenPhase.reviewing;
      _statusText = '左滑下一张 · 右滑上一张 · 上滑删除';
      _loading = false;
      _libraryMode = mode;
    });
    _prepareGroup();
    _presentOperationTipsIfNeeded();
  }

  Future<List<File>> _scanImages(Directory root) async {
    final result = <File>[];
    final trashPath = p.normalize(p.join(root.path, '.photolite_trash'));
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final normalized = p.normalize(entity.path);
        if (normalized == trashPath || p.isWithin(trashPath, normalized)) continue;
        final ext = p.extension(entity.path).toLowerCase();
        if (!_supportedExtensions.contains(ext)) continue;
        result.add(entity);
      }
    }
    return result;
  }

  void _prepareGroup() {
    final currentGroup = _currentGroup;
    if (currentGroup.isEmpty) {
      setState(() {
        _phase = ScreenPhase.done;
        _statusText = '本轮处理完成';
      });
      return;
    }
    _currentIndex = _groupIndex * _groupSize;
    setState(() {
      _phase = ScreenPhase.reviewing;
      _statusText = '左滑下一张 · 右滑上一张 · 上滑删除';
      _currentFirstHint = false;
      _showSwipeHint = false;
      _dragOffset = Offset.zero;
      _dragTranslation = Offset.zero;
      _dragRotationRadians = 0;
      _activeKeyboardKey = null;
      _activeKeyboardDecision = null;
      _activeKeyboardDirection = null;
    });
  }

  void _presentOperationTipsIfNeeded() {
    if (_neverShowOperationTips || _suppressOperationTipsThisWeek) return;
    if (_phase != ScreenPhase.reviewing || _showOperationTips) return;
    setState(() => _showOperationTips = true);
  }

  void _confirmOperationTips() {
    setState(() => _showOperationTips = false);
    _hapticLight();
  }

  KeyEventResult _handleReviewKeyEvent(FocusNode node, KeyEvent event) {
    final keyboardIntent = _keyboardIntentForKey(event.logicalKey);
    if (keyboardIntent == null) return KeyEventResult.ignored;
    if (_busy || _phase != ScreenPhase.reviewing || _isAnimatingDecision || _showSettings || _showOperationTips) {
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      _beginKeyboardDecision(event.logicalKey);
      return KeyEventResult.handled;
    }
    if (event is KeyUpEvent) {
      _completeKeyboardDecision(event.logicalKey);
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  void _beginKeyboardDecision(LogicalKeyboardKey key) {
    final keyboardIntent = _keyboardIntentForKey(key);
    if (keyboardIntent == null) return;
    if (_activeKeyboardKey != null) {
      if (_isOppositeKeyboardDirection(_activeKeyboardDirection, keyboardIntent.direction)) {
        _resetDrag();
      }
      return;
    }

    if (keyboardIntent.decision == SwipeDecision.previous && _history.isEmpty) {
      setState(() {
        _activeKeyboardKey = key;
        _activeKeyboardDirection = keyboardIntent.direction;
      });
      _hintFirstPhoto();
      return;
    }

    final tracked = _trajectoryState(keyboardIntent.translation);
    setState(() {
      _activeKeyboardKey = key;
      _activeKeyboardDecision = keyboardIntent.decision;
      _activeKeyboardDirection = keyboardIntent.direction;
      _dragTranslation = keyboardIntent.translation;
      _dragOffset = tracked.offset;
      _dragRotationRadians = tracked.rotationRadians;
      _statusText = _statusTextForDecision(keyboardIntent.decision, keyboardIntent.translation);
      _showSwipeHint = true;
      _currentFirstHint = false;
    });
    _hapticSelection();
  }

  void _completeKeyboardDecision(LogicalKeyboardKey key) {
    if (_activeKeyboardKey != key) return;
    final decision = _activeKeyboardDecision;
    setState(() {
      _activeKeyboardKey = null;
      _activeKeyboardDecision = null;
      _activeKeyboardDirection = null;
    });
    if (decision == null) {
      _resetDrag();
      return;
    }
    _animateAndCompleteDecision(decision);
  }

  KeyboardIntent? _keyboardIntentForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      return const KeyboardIntent(SwipeDecision.keep, Offset(-60, 0), KeyboardDirection.left);
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      return const KeyboardIntent(SwipeDecision.previous, Offset(60, 0), KeyboardDirection.right);
    }
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      return const KeyboardIntent(SwipeDecision.delete, Offset(0, -60), KeyboardDirection.up);
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      return const KeyboardIntent(SwipeDecision.keep, Offset(0, 60), KeyboardDirection.down);
    }
    return null;
  }

  bool _isOppositeKeyboardDirection(KeyboardDirection? active, KeyboardDirection incoming) {
    return (active == KeyboardDirection.left && incoming == KeyboardDirection.right) ||
        (active == KeyboardDirection.right && incoming == KeyboardDirection.left) ||
        (active == KeyboardDirection.up && incoming == KeyboardDirection.down) ||
        (active == KeyboardDirection.down && incoming == KeyboardDirection.up);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_busy || _phase != ScreenPhase.reviewing || _isAnimatingDecision) return;
    final nextTranslation = _dragTranslation + details.delta;
    final decision = _swipeDecision(nextTranslation);
    final tracked = _trajectoryState(nextTranslation);
    setState(() {
      _dragTranslation = nextTranslation;
      _dragOffset = tracked.offset;
      _dragRotationRadians = tracked.rotationRadians;
      _statusText = _statusTextForDecision(decision, nextTranslation);
      _currentFirstHint = false;
      _showSwipeHint = decision != SwipeDecision.none;
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_busy || _phase != ScreenPhase.reviewing || _isAnimatingDecision) return;
    final decision = _swipeDecision(_dragTranslation);
    if (decision == SwipeDecision.none) {
      final shouldHintFirst = _isFirstPhotoPreviousAttempt(_dragTranslation);
      _resetDrag();
      if (shouldHintFirst) _hintFirstPhoto();
      return;
    }
    _animateAndCompleteDecision(decision);
  }

  void _resetDrag() {
    if (!mounted) return;
    setState(() {
      _dragOffset = Offset.zero;
      _dragTranslation = Offset.zero;
      _dragRotationRadians = 0;
      _statusText = '左滑下一张 · 右滑上一张 · 上滑删除';
      _showSwipeHint = false;
      _activeKeyboardKey = null;
      _activeKeyboardDecision = null;
      _activeKeyboardDirection = null;
    });
  }

  TrajectoryState _trajectoryState(Offset translation) {
    final screen = MediaQuery.of(context).size;
    final circleRadius = min(screen.width * 0.94, 430.0);
    const arcDragWidth = 92.0;
    final maxArcAngle = pi * 0.075;
    final horizontalDrag = translation.dx.abs() * 2.55;
    final horizontalProgress = min(horizontalDrag / arcDragWidth, 1.0);
    final easedProgress = 1 - pow(1 - horizontalProgress, 1.45).toDouble();

    if (translation.dy > 0 && translation.dy.abs() > translation.dx.abs()) {
      return TrajectoryState(
        offset: Offset(translation.dx * 0.08, min(translation.dy * 0.14, 28.0)),
        rotationRadians: 0,
      );
    }

    final isDeleteArc = translation.dy < 0 && translation.dy.abs() > translation.dx.abs() * 1.05;
    if (isDeleteArc) {
      final rotationDegrees = (translation.dx / 38).clamp(-12.0, 12.0);
      return TrajectoryState(
        offset: Offset(translation.dx * 0.34, translation.dy * 2.45),
        rotationRadians: rotationDegrees * pi / 180,
      );
    }

    if (translation.dx.abs() <= 1) {
      return TrajectoryState(
        offset: Offset(0, -circleRadius * easedProgress * 0.08),
        rotationRadians: 0,
      );
    }

    final side = translation.dx > 0 ? 1.0 : -1.0;
    final theta = side * easedProgress * maxArcAngle;
    final arcOffset = Offset(
      circleRadius * sin(theta),
      circleRadius * (1 - cos(theta)),
    );
    final extraDrag = max(horizontalDrag - arcDragWidth, 0.0);
    final exitX = side * extraDrag;
    final exitY = extraDrag * tan(maxArcAngle);

    return TrajectoryState(
      offset: Offset(arcOffset.dx + exitX, arcOffset.dy + exitY),
      rotationRadians: theta * 0.56,
    );
  }

  TrajectoryState _exitTrajectoryState(SwipeDecision decision, Offset translation) {
    final screen = MediaQuery.of(context).size;
    return switch (decision) {
      SwipeDecision.delete => TrajectoryState(
        offset: Offset(translation.dx * 0.08, -(screen.height + 220)),
        rotationRadians: (translation.dx / 36).clamp(-8.0, 8.0) * pi / 180,
      ),
      SwipeDecision.keep => TrajectoryState(
        offset: Offset(-(screen.width + 260), translation.dy * 0.12),
        rotationRadians: -24 * pi / 180,
      ),
      SwipeDecision.previous => TrajectoryState(
        offset: Offset(screen.width + 260, translation.dy * 0.12),
        rotationRadians: 24 * pi / 180,
      ),
      SwipeDecision.none => const TrajectoryState(offset: Offset.zero, rotationRadians: 0),
    };
  }

  SwipeDecision _swipeDecision(Offset translation) {
    final distance = sqrt(translation.dx * translation.dx + translation.dy * translation.dy);
    if (distance < 44) return SwipeDecision.none;

    final horizontalDominance = translation.dx.abs() >= translation.dy.abs() * 0.72;
    final verticalDominance = translation.dy.abs() >= translation.dx.abs() * 0.72;

    if (horizontalDominance && translation.dx <= -38) return SwipeDecision.keep;
    if (horizontalDominance && translation.dx >= 38 && _history.isNotEmpty) return SwipeDecision.previous;
    if (verticalDominance && translation.dy <= -38) return SwipeDecision.delete;
    return SwipeDecision.none;
  }

  bool _isFirstPhotoPreviousAttempt(Offset translation) {
    final horizontalDominance = translation.dx.abs() >= translation.dy.abs() * 0.72;
    return horizontalDominance && translation.dx >= 34 && _history.isEmpty;
  }

  String _statusTextForDecision(SwipeDecision decision, Offset translation) {
    return switch (decision) {
      SwipeDecision.delete => '删除',
      SwipeDecision.keep => '下一张',
      SwipeDecision.previous => '上一张',
      SwipeDecision.none => _isFirstPhotoPreviousAttempt(translation) ? '这是第一张' : '左滑下一张 · 右滑上一张 · 上滑删除',
    };
  }

  Future<void> _animateAndCompleteDecision(SwipeDecision decision) async {
    final exit = _exitTrajectoryState(decision, _dragTranslation);
    setState(() {
      _isAnimatingDecision = true;
      _dragOffset = exit.offset;
      _dragRotationRadians = exit.rotationRadians;
      _statusText = _statusTextForDecision(decision, _dragTranslation);
    });
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    setState(() {
      _isAnimatingDecision = false;
      _disableNextMotionAnimation = true;
      _dragTranslation = Offset.zero;
      _dragOffset = Offset.zero;
      _dragRotationRadians = 0;
      _showSwipeHint = false;
    });
    switch (decision) {
      case SwipeDecision.delete:
        _markDelete();
      case SwipeDecision.keep:
        _markKeep();
      case SwipeDecision.previous:
        _goPrevious();
      case SwipeDecision.none:
        break;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _disableNextMotionAnimation = false);
    });
  }

  void _hintFirstPhoto() {
    final indexInGroup = _currentIndex - (_groupIndex * _groupSize);
    if (indexInGroup <= 0) {
      setState(() {
        _currentFirstHint = true;
        _showSwipeHint = true;
      });
      _hapticWarning();
      _hintTimer?.cancel();
      _hintTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _currentFirstHint = false;
            _showSwipeHint = false;
          });
        }
      });
    }
  }

  void _markDelete() {
    final photo = _currentPhoto;
    if (photo == null) return;
    setState(() {
      _reviewedCount += 1;
      _markedDelete.add(photo.id);
      _history.add(ReviewedAction(photo.id, ReviewAction.delete));
      _statusText = '已标记删除';
      _dragOffset = Offset.zero;
      _dragTranslation = Offset.zero;
      _dragRotationRadians = 0;
      _showSwipeHint = false;
    });
    _hapticDelete();
    _advanceForward();
  }

  void _markKeep() {
    final photo = _currentPhoto;
    if (photo == null) return;
    setState(() {
      _reviewedCount += 1;
      _history.add(ReviewedAction(photo.id, ReviewAction.keep));
      _statusText = '保留';
      _dragOffset = Offset.zero;
      _dragTranslation = Offset.zero;
      _dragRotationRadians = 0;
      _showSwipeHint = false;
    });
    _hapticMedium();
    _advanceForward();
  }

  void _goPrevious() {
    if (_history.isEmpty) {
      _hintFirstPhoto();
      return;
    }

    final last = _history.removeLast();
    setState(() {
      _reviewedCount = max(0, _reviewedCount - 1);
      if (last.action == ReviewAction.delete) {
        _markedDelete.remove(last.path);
      }
      _currentIndex = max(_currentIndex - 1, _groupIndex * _groupSize);
      _statusText = '上一张';
      _dragOffset = Offset.zero;
      _dragTranslation = Offset.zero;
      _dragRotationRadians = 0;
      _showSwipeHint = false;
    });
    _hapticMedium();
  }

  void _advanceForward() {
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= min((_groupIndex + 1) * _groupSize, _queue.length)) {
      final hasDeletes = _activeDeleteGroup.isNotEmpty;
      setState(() {
        if (hasDeletes) {
          _phase = ScreenPhase.confirming;
        } else {
          _groupIndex += 1;
          _history.clear();
          _statusText = '本组没有删除，进入下一组';
        }
        _dragOffset = Offset.zero;
        _dragTranslation = Offset.zero;
        _dragRotationRadians = 0;
        _showSwipeHint = false;
      });
      if (!hasDeletes) {
        _prepareGroup();
      }
      return;
    }

    setState(() {
      _currentIndex = nextIndex;
      _statusText = '下一张';
      _dragOffset = Offset.zero;
      _dragTranslation = Offset.zero;
      _dragRotationRadians = 0;
      _showSwipeHint = false;
    });
    _hapticLight();
  }

  Future<void> _confirmDelete() async {
    if (_busy) return;
    final deleteItems = _activeDeleteGroup.where((e) => !_preservedInConfirm.contains(e.id)).toList();
    if (deleteItems.isEmpty) {
      setState(() {
        _phase = ScreenPhase.reviewing;
        _groupIndex += 1;
        _currentIndex = _groupIndex * _groupSize;
        _markedDelete.clear();
        _preservedInConfirm.clear();
      });
      _prepareGroup();
      return;
    }

    setState(() => _busy = true);
    int bytes = 0;
    try {
      if (_usesSystemGallery) {
        final result = await PhotoManager.editor.deleteWithIds(deleteItems.map((e) => e.id).toList());
        bytes = deleteItems.fold(0, (sum, item) => sum + item.sizeBytes);
        if (result.isEmpty) {
          throw StateError('系统取消了删除');
        }
      } else {
        await _trashDirectory?.create(recursive: true);
        for (final item in deleteItems) {
          final source = File(item.filePath!);
          if (!await source.exists()) continue;
          final stat = await source.stat();
          bytes += stat.size;
          final target = await _uniqueTrashPath(item);
          await source.rename(target);
        }
      }

      setState(() {
        _deletedCount += deleteItems.length;
        _savedBytes += bytes;
        _busy = false;
        _markedDelete.clear();
        _preservedInConfirm.clear();
        _groupIndex += 1;
        _history.clear();
      });
      _hapticSuccess();
      _prepareGroup();
    } catch (e) {
      setState(() {
        _busy = false;
        _statusText = '删除失败：$e';
        _phase = ScreenPhase.reviewing;
      });
      _hapticError();
    }
  }

  void _advanceToNextGroup() {
    if (_phase != ScreenPhase.confirming) return;
    setState(() {
      _busy = false;
      _markedDelete.clear();
      _preservedInConfirm.clear();
      _history.clear();
      _groupIndex += 1;
    });
    _prepareGroup();
  }

  void _changeGroupSize(int value) {
    final next = value.clamp(5, 30);
    if (next == _groupSize) return;
    setState(() => _groupSize = next);
    if (_queue.isNotEmpty) {
      final preservedQueue = _queue.where((entry) => entry.existsSync()).toList();
      preservedQueue.shuffle(Random(_groupSize * 17));
      setState(() {
        _queue = preservedQueue;
        _groupIndex = 0;
        _currentIndex = 0;
        _reviewedCount = 0;
        _markedDelete.clear();
        _preservedInConfirm.clear();
        _history.clear();
        _phase = ScreenPhase.reviewing;
        _statusText = '已调整每组数量，重新分组。';
      });
      _prepareGroup();
    }
  }

  Future<void> _changeDatePreference(PhotoDatePreference value) async {
    if (value == _datePreference) return;
    setState(() => _datePreference = value);
    if (_usesSystemGallery) {
      await _loadFromSystemGallery();
    }
  }

  Future<void> _shareCurrentPhoto() async {
    final photo = _currentPhoto;
    if (photo == null || _busy) return;
    try {
      File? file;
      if (photo.filePath != null) {
        file = File(photo.filePath!);
      } else if (photo.asset != null) {
        file = await photo.asset!.originFile ?? await photo.asset!.file;
      }
      if (file == null || !await file.exists()) {
        setState(() => _statusText = '无法分享这张照片');
        _hapticError();
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          title: '分享照片',
          files: [XFile(file.path)],
        ),
      );
      _hapticLight();
    } catch (e) {
      setState(() => _statusText = '分享失败：$e');
      _hapticError();
    }
  }

  Future<String> _uniqueTrashPath(PhotoItem item) async {
    final trash = _trashDirectory ?? Directory(p.join(_rootDirectory!.path, '.photolite_trash'));
    await trash.create(recursive: true);
    final base = p.basenameWithoutExtension(item.filePath!);
    final ext = p.extension(item.filePath!);
    var candidate = p.join(trash.path, '$base$ext');
    var counter = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(trash.path, '${base}_$counter$ext');
      counter += 1;
    }
    return candidate;
  }

  void _restart() {
    setState(() {
      _phase = ScreenPhase.empty;
      _queue = [];
      _groupIndex = 0;
      _currentIndex = 0;
      _reviewedCount = 0;
      _deletedCount = 0;
      _savedBytes = 0;
      _markedDelete.clear();
      _preservedInConfirm.clear();
      _history.clear();
      _statusText = '开始整理照片。';
      _showSettings = false;
    });
    _hapticLight();
  }

  void _hapticLight() { if (_hapticsEnabled) HapticFeedback.lightImpact(); }
  void _hapticMedium() { if (_hapticsEnabled) HapticFeedback.mediumImpact(); }
  void _hapticDelete() { if (_hapticsEnabled) HapticFeedback.heavyImpact(); }
  void _hapticSuccess() { if (_hapticsEnabled) HapticFeedback.vibrate(); }
  void _hapticWarning() { if (_hapticsEnabled) HapticFeedback.selectionClick(); }
  void _hapticError() { if (_hapticsEnabled) HapticFeedback.vibrate(); }
  void _hapticSelection() { if (_hapticsEnabled) HapticFeedback.selectionClick(); }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(value >= 10 || index == 0 ? 0 : 1)} ${units[index]}';
  }

  String _libraryModeLabel() {
    return switch (_libraryMode) {
      LibraryMode.auto => (_isAndroid || _isMacOS) ? '自动：系统图库' : '自动：文件夹',
      LibraryMode.system => '系统图库',
      LibraryMode.folder => '文件夹',
    };
  }
}

class PhotoItem {
  PhotoItem._({
    required this.id,
    required this.displayName,
    required this.modifiedAt,
    required this.sizeBytes,
    this.locationText,
    this.filePath,
    this.asset,
  });

  factory PhotoItem.fromFile(File file, Directory root) {
    final stat = file.statSync();
    return PhotoItem._(
      id: file.path,
      displayName: p.basename(file.path),
      modifiedAt: stat.modified,
      sizeBytes: stat.size,
      locationText: p.dirname(file.path) == root.path ? null : p.relative(p.dirname(file.path), from: root.path),
      filePath: file.path,
    );
  }

  static Future<PhotoItem> fromAsset(AssetEntity asset) async {
    var bytes = 0;
    try {
      final file = await asset.originFile ?? await asset.file;
      if (file != null && await file.exists()) {
        bytes = await file.length();
      }
    } catch (_) {
      bytes = 0;
    }
    return PhotoItem._(
      id: asset.id,
      displayName: asset.title ?? asset.id,
      modifiedAt: asset.createDateTime,
      sizeBytes: bytes,
      locationText: asset.latitude != null && asset.longitude != null ? '${asset.latitude!.toStringAsFixed(5)}, ${asset.longitude!.toStringAsFixed(5)}' : null,
      asset: asset,
    );
  }

  final String id;
  final String displayName;
  final DateTime modifiedAt;
  final int sizeBytes;
  final String? locationText;
  final String? filePath;
  final AssetEntity? asset;

  Widget preview(BuildContext context, {BoxFit fit = BoxFit.cover}) {
    if (asset != null) {
      return AssetEntityImage(
        asset!,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(1600),
        fit: fit,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const ColoredBox(
            color: Color(0xFF111111),
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 80, color: Colors.white38),
        ),
      );
    }
    return Image.file(
      File(filePath!),
      fit: fit,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_rounded, size: 80, color: Colors.white38),
      ),
    );
  }

  String get timeText {
    final y = modifiedAt.year.toString().padLeft(4, '0');
    final m = modifiedAt.month.toString().padLeft(2, '0');
    final d = modifiedAt.day.toString().padLeft(2, '0');
    final hh = modifiedAt.hour.toString().padLeft(2, '0');
    final mm = modifiedAt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String get resolutionText {
    if (asset != null) {
      return '${asset!.width} x ${asset!.height}';
    }
    return displayName;
  }

  String get storageText {
    if (sizeBytes <= 0) return '大小未知';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = sizeBytes.toDouble();
    var index = 0;
    while (value >= 1024 && index < units.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(value >= 10 || index == 0 ? 0 : 1)} ${units[index]}';
  }

  bool existsSync() {
    if (asset != null) return true;
    final path = filePath;
    return path != null && File(path).existsSync();
  }
}

class ReviewedAction {
  ReviewedAction(this.path, this.action);
  final String path;
  final ReviewAction action;
}

class TrajectoryState {
  const TrajectoryState({required this.offset, required this.rotationRadians});
  final Offset offset;
  final double rotationRadians;
}

class KeyboardIntent {
  const KeyboardIntent(this.decision, this.translation, this.direction);
  final SwipeDecision decision;
  final Offset translation;
  final KeyboardDirection direction;
}

enum KeyboardDirection { left, right, up, down }
