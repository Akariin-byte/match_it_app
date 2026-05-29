import 'dart:typed_data';

import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/scene_categories.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../constants/user_hashtags.dart';
import '../widgets/login_bottom_sheet.dart';
import '../widgets/scene_picker_sheet.dart';
import '../widgets/hashtag_chip.dart';

/// 组队费用规则（与后端 cost_type / amount 对齐）
class CostRule {
  const CostRule._({required this.costType, this.amount});

  factory CostRule.free() => const CostRule._(costType: 'free');
  factory CostRule.aa() => const CostRule._(costType: 'aa');
  factory CostRule.negotiate() => const CostRule._(costType: 'negotiate');
  factory CostRule.fixed(double amountPerPerson) =>
      CostRule._(costType: 'fixed', amount: amountPerPerson);

  final String costType;
  final double? amount;

  String get displayLabel {
    switch (costType) {
      case 'free':
        return '免费参与';
      case 'aa':
        return 'AA制';
      case 'negotiate':
        return '面议';
      case 'fixed':
        final value = amount;
        if (value == null) return '设定金额';
        final text = value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toStringAsFixed(2);
        return '¥$text/人';
      default:
        return '费用/规则';
    }
  }

  Map<String, dynamic> toApiFields() => {
        'costType': costType,
        if (amount != null) 'amount': amount,
      };
}

/// 发布页底部已选信息（地点 / 时间 / 费用 / 人数）
class SelectedInfo {
  const SelectedInfo({
    this.sceneId,
    this.location,
    this.time,
    this.costRule,
    this.maxPeople,
  });

  final String? sceneId;
  final String? location;
  final DateTime? time;
  final CostRule? costRule;
  final int? maxPeople;

  bool get hasAny =>
      (sceneId?.isNotEmpty ?? false) ||
      (location?.isNotEmpty ?? false) ||
      time != null ||
      costRule != null ||
      maxPeople != null;

  String? get sceneLabel =>
      sceneId != null ? SceneCategories.labelFor(sceneId) : null;

  String? get maxPeopleLabel =>
      maxPeople != null ? '👥 $maxPeople 人' : null;

  SelectedInfo copyWith({
    String? sceneId,
    String? location,
    DateTime? time,
    CostRule? costRule,
    int? maxPeople,
    bool clearScene = false,
    bool clearLocation = false,
    bool clearTime = false,
    bool clearCost = false,
    bool clearMaxPeople = false,
  }) {
    return SelectedInfo(
      sceneId: clearScene ? null : (sceneId ?? this.sceneId),
      location: clearLocation ? null : (location ?? this.location),
      time: clearTime ? null : (time ?? this.time),
      costRule: clearCost ? null : (costRule ?? this.costRule),
      maxPeople: clearMaxPeople ? null : (maxPeople ?? this.maxPeople),
    );
  }
}

/// X 式发布页：顶栏发布、头像+正文、横向图片条、键盘上方工具栏
class PublishPage extends StatefulWidget {
  const PublishPage({
    super.key,
    required this.hostName,
    required this.suggestedSceneId,
    required this.hostFaceTraits,
    required this.intensityScore,
    this.authSession,
  });

  final String hostName;
  final String suggestedSceneId;
  final List<String> hostFaceTraits;
  final int intensityScore;
  final AuthSession? authSession;

  static const Color brandColor = Color(0xFF002FA7);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _toolbarIcon = Color(0xFF1D9BF0);
  static Color get _surfaceFill => Colors.grey.shade50;
  static const int _charLimit = 500;
  static const int _maxImages = 4;

  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final _contentController = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();

  final List<Uint8List> _images = [];
  SelectedInfo _selectedInfo = const SelectedInfo();
  bool _isSubmitting = false;
  AuthSession? _authSession;

  static const _locationPresets = [
    '线上',
    '上海市 · 待定',
    '北京市 · 待定',
    '广州市 · 待定',
    '深圳市 · 待定',
  ];

  int get _charCount => _contentController.text.characters.length;

  List<String> get _contentHashtags =>
      UserHashtags.parseFromText(_contentController.text);

  bool get _canPost {
    final text = _contentController.text.trim();
    return text.isNotEmpty &&
        _charCount <= PublishPage._charLimit &&
        !_isSubmitting;
  }

  bool get _hasDraft =>
      _contentController.text.trim().isNotEmpty ||
      _images.isNotEmpty ||
      _selectedInfo.hasAny;

  @override
  void initState() {
    super.initState();
    _authSession = widget.authSession;
    _contentController.addListener(() => setState(() {}));
    final suggested = widget.suggestedSceneId.trim();
    if (suggested.isNotEmpty && suggested != SceneCategories.allId) {
      _selectedInfo = SelectedInfo(sceneId: suggested);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _maybePop() async {
    if (!_hasDraft) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('放弃编辑？'),
        content: const Text('当前内容尚未发布，确定要离开吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _pickImages() async {
    if (_images.length >= PublishPage._maxImages) {
      _toast('最多添加 ${PublishPage._maxImages} 张图片');
      return;
    }
    try {
      final files = await _picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (files.isEmpty) return;
      final room = PublishPage._maxImages - _images.length;
      final picked = files.take(room);
      final bytesList = await Future.wait(picked.map((f) => f.readAsBytes()));
      if (!mounted) return;
      setState(() => _images.addAll(bytesList));
    } catch (e) {
      _toast('无法选择图片：$e');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _pickEventTimeViaPickers() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedInfo.time ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '选择活动日期',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedInfo.time ?? now),
      helpText: '选择活动时间',
    );
    if (time == null || !mounted) return;

    setState(() {
      _selectedInfo = _selectedInfo.copyWith(
        time: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    });
  }

  Future<void> _openTimeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '选择时间',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (_selectedInfo.time != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.schedule,
                      color: PublishPage.brandColor,
                    ),
                    title: Text(_formatTime(_selectedInfo.time!)),
                    trailing: const Icon(Icons.check, color: PublishPage.brandColor),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.edit_calendar_outlined,
                    color: PublishPage.brandColor.withValues(alpha: 0.85),
                  ),
                  title: const Text('选择日期和时间'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickEventTimeViaPickers();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openLocationSheet() async {
    final customController =
        TextEditingController(text: _selectedInfo.location ?? '');
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '选择地点',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ..._locationPresets.map(
                (loc) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(loc),
                  trailing: _selectedInfo.location == loc
                      ? const Icon(Icons.check, color: PublishPage.brandColor)
                      : null,
                  onTap: () => Navigator.pop(context, loc),
                ),
              ),
              const Divider(),
              TextField(
                controller: customController,
                decoration: InputDecoration(
                  hintText: '自定义地点',
                  hintStyle: const TextStyle(color: PublishPage._hint),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final text = customController.text.trim();
                  Navigator.pop(context, text.isEmpty ? null : text);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: PublishPage.brandColor,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedInfo = _selectedInfo.copyWith(location: selected));
    }
  }

  Future<void> _openCostSheet() async {
    final result = await showModalBottomSheet<CostRule>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CostRuleSheet(initial: _selectedInfo.costRule),
    );

    if (result != null && mounted) {
      setState(() => _selectedInfo = _selectedInfo.copyWith(costRule: result));
    }
  }

  void _clearLocation() {
    setState(() => _selectedInfo = _selectedInfo.copyWith(clearLocation: true));
  }

  void _clearTime() {
    setState(() => _selectedInfo = _selectedInfo.copyWith(clearTime: true));
  }

  void _clearCost() {
    setState(() => _selectedInfo = _selectedInfo.copyWith(clearCost: true));
  }

  void _clearMaxPeople() {
    setState(() => _selectedInfo = _selectedInfo.copyWith(clearMaxPeople: true));
  }

  void _clearScene() {
    setState(() => _selectedInfo = _selectedInfo.copyWith(clearScene: true));
  }

  Future<void> _openSceneSheet() async {
    final picked = await ScenePickerSheet.show(
      context,
      selectedId: _selectedInfo.sceneId,
      includeAll: false,
      title: '🏷 组局类型',
      subtitle: '选择这条帖子属于哪种局（必填）',
    );
    if (picked != null && picked != SceneCategories.allId && mounted) {
      setState(() => _selectedInfo = _selectedInfo.copyWith(sceneId: picked));
    }
  }

  Future<void> _openPeopleSheet() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PeopleCountSheet(
        initial: _selectedInfo.maxPeople ?? 4,
      ),
    );

    if (result != null && mounted) {
      setState(() => _selectedInfo = _selectedInfo.copyWith(maxPeople: result));
    }
  }

  Future<void> _openLoginSheet() async {
    await LoginBottomSheet.show(
      context,
      initialSession: _authSession,
      onLoginSuccess: (session) {
        if (!mounted) return;
        setState(() => _authSession = session);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登录成功${session.phone != null ? '，已绑定 ${session.phone}' : ''}'),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_canPost) return;

    final session = _authSession;
    if (session == null || session.isGuest) {
      _toast('请先登录后再发布');
      return;
    }

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _toast('写点内容再发布吧');
      return;
    }

    final sceneId = _selectedInfo.sceneId?.trim();
    if (sceneId == null || sceneId.isEmpty) {
      _toast('请选择组局类型');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now().toUtc();
      final eventTime =
          (_selectedInfo.time ?? now.add(const Duration(days: 1))).toUtc();
      final location = _selectedInfo.location?.trim() ?? '';
      final maxPeople = _selectedInfo.maxPeople ?? 4;

      final contentTags = UserHashtags.parseFromText(content);
      final tags = UserHashtags.normalizeAll([
        ...contentTags,
        ...widget.hostFaceTraits,
        if (contentTags.isEmpty) SceneCategories.labelFor(sceneId),
      ]);

      final payload = <String, dynamic>{
        'content': content,
        'area': sceneId,
        'maxPeople': maxPeople,
        'tags': tags,
        'hardcoreScore': widget.intensityScore,
        'eventDateTime': eventTime.toIso8601String(),
        if (location.isNotEmpty) 'eventLocation': location,
      };
      final costRule = _selectedInfo.costRule;
      if (costRule != null) {
        payload.addAll(costRule.toApiFields());
      }

      await postService.createPost(
        session: session,
        body: payload,
      );

      if (!mounted) return;
      Navigator.of(context).pop(sceneId);
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.action == 'bind_phone') {
        final goLogin = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('登录后发布'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('去登录'),
              ),
            ],
          ),
        );
        if (goLogin == true && mounted) {
          await _openLoginSheet();
        }
      } else {
        _toast(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _toast('发布失败：$e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}月${dt.day}日 '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  String _avatarLetter() {
    final name = widget.hostName.trim();
    if (name.isEmpty) return '?';
    return name.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _maybePop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close_rounded, color: Colors.grey.shade800, size: 22),
            onPressed: _maybePop,
          ),
          actions: [
            TextButton(
              onPressed: () => _toast('草稿功能开发中'),
              child: Text(
                '草稿',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _PostButton(
                  enabled: _canPost,
                  loading: _isSubmitting,
                  onTap: _submit,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: PublishPage._surfaceFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                PublishPage.brandColor.withValues(alpha: 0.12),
                            child: Text(
                              _avatarLetter(),
                              style: const TextStyle(
                                color: PublishPage.brandColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextField(
                              controller: _contentController,
                              focusNode: _focusNode,
                              maxLines: null,
                              minLines: 5,
                              maxLength: PublishPage._charLimit,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(
                                fontSize: 17,
                                height: 1.45,
                                color: Colors.grey.shade900,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.1,
                              ),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                counterText: '',
                                hintText: '分享你的搭子计划… 正文里写 #桌游 可打标签',
                                hintStyle: TextStyle(
                                  color: PublishPage._hint,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w400,
                                  height: 1.45,
                                ),
                                contentPadding: const EdgeInsets.only(top: 4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_contentHashtags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _contentHashtags
                              .map((t) => HashtagChip(tag: t, compact: true))
                              .toList(),
                        ),
                      ],
                      if (_images.isNotEmpty ||
                          _images.length < PublishPage._maxImages) ...[
                        const SizedBox(height: 16),
                        _MediaStrip(
                          images: _images,
                          onAdd: _pickImages,
                          onRemove: _removeImage,
                        ),
                      ],
                      if (_selectedInfo.sceneId != null ||
                          _selectedInfo.maxPeople != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_selectedInfo.sceneLabel != null)
                              _ContentMetaChip(
                                label: '🏷 ${_selectedInfo.sceneLabel!}',
                                onTap: _openSceneSheet,
                              ),
                            if (_selectedInfo.maxPeople != null)
                              _ContentMetaChip(
                                label: _selectedInfo.maxPeopleLabel!,
                                onTap: _openPeopleSheet,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _toast('当前默认为公开，所有人可见'),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                Icons.public_rounded,
                                size: 17,
                                color: PublishPage.brandColor.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '公开 · 所有人可报名',
                                style: TextStyle(
                                  color: PublishPage.brandColor
                                      .withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _ComposeToolbar(
              charCount: _charCount,
              charLimit: PublishPage._charLimit,
              canAddImage: _images.length < PublishPage._maxImages,
              selectedInfo: _selectedInfo,
              formatTime: _formatTime,
              onPickImage: _pickImages,
              onPickLocation: _openLocationSheet,
              onPickTime: _openTimeSheet,
              onPickCost: _openCostSheet,
              onPickPeople: _openPeopleSheet,
              onPickScene: _openSceneSheet,
              onClearLocation: _clearLocation,
              onClearTime: _clearTime,
              onClearCost: _clearCost,
              onClearMaxPeople: _clearMaxPeople,
              onClearScene: _clearScene,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  const _PostButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;
    return Material(
      elevation: active ? 2 : 0,
      shadowColor: PublishPage.brandColor.withValues(alpha: 0.35),
      color: active
          ? PublishPage.brandColor
          : PublishPage.brandColor.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: active ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '发布',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

class _MediaStrip extends StatelessWidget {
  const _MediaStrip({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<Uint8List> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  static const _tileSize = 88.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _tileSize,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (images.length < PublishPage._maxImages)
            _AddMediaTile(size: _tileSize, onTap: onAdd),
          for (var i = 0; i < images.length; i++) ...[
            if (i == 0 && images.length < PublishPage._maxImages)
              const SizedBox(width: 8),
            _MediaThumb(
              size: _tileSize,
              bytes: images[i],
              onRemove: () => onRemove(i),
            ),
            if (i < images.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _AddMediaTile extends StatelessWidget {
  const _AddMediaTile({required this.size, required this.onTap});

  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            Icons.add_photo_alternate_outlined,
            color: Colors.grey.shade500,
            size: 26,
          ),
        ),
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  const _MediaThumb({
    required this.size,
    required this.bytes,
    required this.onRemove,
  });

  final double size;
  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onRemove,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContentMetaChip extends StatelessWidget {
  const _ContentMetaChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PublishPage.brandColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: PublishPage.brandColor.withValues(alpha: 0.16),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PublishPage.brandColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedActionChip extends StatelessWidget {
  const _SelectedActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onDelete,
    this.emoji,
  });

  final IconData? icon;
  final String? emoji;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PublishPage.brandColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: PublishPage.brandColor.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.only(left: 10, top: 7, bottom: 7, right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null)
                Text(emoji!, style: const TextStyle(fontSize: 15, height: 1))
              else if (icon != null)
                Icon(icon, size: 16, color: PublishPage.brandColor),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PublishPage.brandColor,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: PublishPage.brandColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 未选：灰色图标胶囊；已选：品牌色文字胶囊
class _DynamicActionCapsule extends StatelessWidget {
  const _DynamicActionCapsule({
    this.icon,
    this.emoji,
    this.label,
    required this.onTap,
    this.onClear,
    this.enabled = true,
  });

  final IconData? icon;
  final String? emoji;
  final String? label;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool enabled;

  bool get _isSelected => label != null && label!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_isSelected) {
      return _SelectedActionChip(
        icon: icon,
        emoji: emoji,
        label: label!,
        onTap: onTap,
        onDelete: onClear ?? () {},
      );
    }
    return Material(
      color: enabled ? Colors.grey.shade100 : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Opacity(
            opacity: enabled ? 1 : 0.35,
            child: emoji != null
                ? Text(emoji!, style: const TextStyle(fontSize: 17, height: 1))
                : Icon(icon, size: 20, color: Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}

class _ComposeToolbar extends StatelessWidget {
  const _ComposeToolbar({
    required this.charCount,
    required this.charLimit,
    required this.canAddImage,
    required this.selectedInfo,
    required this.formatTime,
    required this.onPickImage,
    required this.onPickLocation,
    required this.onPickTime,
    required this.onPickCost,
    required this.onPickPeople,
    required this.onPickScene,
    required this.onClearLocation,
    required this.onClearTime,
    required this.onClearCost,
    required this.onClearMaxPeople,
    required this.onClearScene,
  });

  final int charCount;
  final int charLimit;
  final bool canAddImage;
  final SelectedInfo selectedInfo;
  final String Function(DateTime) formatTime;
  final VoidCallback onPickImage;
  final VoidCallback onPickLocation;
  final VoidCallback onPickTime;
  final VoidCallback onPickCost;
  final VoidCallback onPickPeople;
  final VoidCallback onPickScene;
  final VoidCallback onClearLocation;
  final VoidCallback onClearTime;
  final VoidCallback onClearCost;
  final VoidCallback onClearMaxPeople;
  final VoidCallback onClearScene;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: bottomInset > 0 ? 12 : MediaQuery.paddingOf(context).bottom + 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DynamicActionCapsule(
                  icon: Icons.image_outlined,
                  onTap: onPickImage,
                  enabled: canAddImage,
                ),
                _DynamicActionCapsule(
                  emoji: '🏷',
                  label: selectedInfo.sceneLabel,
                  onTap: onPickScene,
                  onClear: onClearScene,
                ),
                _DynamicActionCapsule(
                  icon: Icons.place_outlined,
                  label: selectedInfo.location,
                  onTap: onPickLocation,
                  onClear: onClearLocation,
                ),
                _DynamicActionCapsule(
                  icon: Icons.schedule_outlined,
                  label: selectedInfo.time != null
                      ? formatTime(selectedInfo.time!)
                      : null,
                  onTap: onPickTime,
                  onClear: onClearTime,
                ),
                _DynamicActionCapsule(
                  emoji: '💰',
                  label: selectedInfo.costRule?.displayLabel,
                  onTap: onPickCost,
                  onClear: onClearCost,
                ),
                _DynamicActionCapsule(
                  emoji: '👥',
                  label: selectedInfo.maxPeople != null
                      ? '${selectedInfo.maxPeople} 人'
                      : null,
                  onTap: onPickPeople,
                  onClear: onClearMaxPeople,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CharProgressRing(count: charCount, limit: charLimit),
        ],
      ),
    );
  }
}

class _CharProgressRing extends StatelessWidget {
  const _CharProgressRing({required this.count, required this.limit});

  final int count;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final ratio = (count / limit).clamp(0.0, 1.0);
    final over = count > limit;
    final near = count > limit * 0.9;
    final trackColor = Colors.black.withValues(alpha: 0.08);
    final progressColor = over
        ? Colors.redAccent
        : near
            ? Colors.orange
            : PublishPage.brandColor;

    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: ratio,
            strokeWidth: 2.5,
            backgroundColor: trackColor,
            color: progressColor,
          ),
          if (near || over)
            Text(
              '${limit - count}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: over ? Colors.redAccent : Colors.orange,
              ),
            ),
        ],
      ),
    );
  }
}

class _PeopleCountSheet extends StatefulWidget {
  const _PeopleCountSheet({required this.initial});

  final int initial;

  @override
  State<_PeopleCountSheet> createState() => _PeopleCountSheetState();
}

class _PeopleCountSheetState extends State<_PeopleCountSheet> {
  static const _min = 1;
  static const _max = 20;

  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initial.clamp(_min, _max);
  }

  void _decrement() {
    if (_count > _min) setState(() => _count--);
  }

  void _increment() {
    if (_count < _max) setState(() => _count++);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '👥 人数控制',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '设定本局最多招募几位搭子（含你自己）',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _StepperCircleButton(
                  icon: Icons.remove_rounded,
                  enabled: _count > _min,
                  onTap: _decrement,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      Text(
                        '$_count',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: PublishPage.brandColor,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '人',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _StepperCircleButton(
                  icon: Icons.add_rounded,
                  enabled: _count < _max,
                  onTap: _increment,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '范围 $_min – $_max 人',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, _count),
              style: FilledButton.styleFrom(
                backgroundColor: PublishPage.brandColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text('确认 · $_count 人'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperCircleButton extends StatelessWidget {
  const _StepperCircleButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? PublishPage.brandColor.withValues(alpha: 0.1)
          : Colors.grey.shade100,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            size: 26,
            color: enabled ? PublishPage.brandColor : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

class _CostRuleSheet extends StatefulWidget {
  const _CostRuleSheet({this.initial});

  final CostRule? initial;

  @override
  State<_CostRuleSheet> createState() => _CostRuleSheetState();
}

class _CostRuleSheetState extends State<_CostRuleSheet> {
  final _amountController = TextEditingController();
  String? _pendingFixed;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial?.costType == 'fixed' && initial?.amount != null) {
      _pendingFixed = 'fixed';
      final amount = initial!.amount!;
      _amountController.text = amount == amount.roundToDouble()
          ? amount.toInt().toString()
          : amount.toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _pickPreset(CostRule rule) {
    Navigator.pop(context, rule);
  }

  void _showFixedInput() {
    setState(() => _pendingFixed = 'fixed');
  }

  void _confirmFixed() {
    final text = _amountController.text.trim();
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的人均金额'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.pop(context, CostRule.fixed(amount));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '💰 费用 / 组队规则',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '提前声明费用，方便搭子筛选，避免线下尴尬',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 12),
          _CostOptionTile(
            title: '免费参与',
            subtitle: '适合纯娱乐、无需分摊',
            selected: widget.initial?.costType == 'free',
            onTap: () => _pickPreset(CostRule.free()),
          ),
          _CostOptionTile(
            title: 'AA 制',
            subtitle: '适合桌游、运动等共同消费',
            selected: widget.initial?.costType == 'aa',
            onTap: () => _pickPreset(CostRule.aa()),
          ),
          _CostOptionTile(
            title: '设定金额',
            subtitle: '例如 ¥50/人，适合场地租赁',
            selected: _pendingFixed == 'fixed' ||
                widget.initial?.costType == 'fixed',
            onTap: _showFixedInput,
          ),
          if (_pendingFixed == 'fixed') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '¥ ',
                suffixText: '/人',
                hintText: '50',
                hintStyle: const TextStyle(color: PublishPage._hint),
                filled: true,
                fillColor: const Color(0xFFF5F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _confirmFixed,
              style: FilledButton.styleFrom(
                backgroundColor: PublishPage.brandColor,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('确认金额'),
            ),
          ],
          _CostOptionTile(
            title: '面议 / 私聊',
            subtitle: '费用私下沟通',
            selected: widget.initial?.costType == 'negotiate',
            onTap: () => _pickPreset(CostRule.negotiate()),
          ),
        ],
      ),
    );
  }
}

class _CostOptionTile extends StatelessWidget {
  const _CostOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? PublishPage.brandColor : Colors.black38,
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: Colors.black.withValues(alpha: 0.45),
        ),
      ),
      onTap: onTap,
    );
  }
}
