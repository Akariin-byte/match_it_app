import 'package:flutter/material.dart';

import '../constants/scene_categories.dart';
import '../constants/user_hashtags.dart';
import '../widgets/hashtag_chip.dart';

/// 个人中心 · 个性化定制（# 标签，可选）
class PersonalizationPage extends StatefulWidget {
  const PersonalizationPage({
    super.key,
    required this.initialIntensityScore,
    required this.initialPreferredSceneId,
    required this.initialHashtags,
    required this.onSave,
  });

  final int initialIntensityScore;
  final String initialPreferredSceneId;
  final List<String> initialHashtags;
  final void Function(
    int intensityScore,
    String preferredSceneId,
    List<String> hashtags,
  ) onSave;

  @override
  State<PersonalizationPage> createState() => _PersonalizationPageState();
}

class _PersonalizationPageState extends State<PersonalizationPage> {
  static const _brand = Color(0xFF002FA7);
  static const _labels = ['新手', '普通', '进阶', '硬核', '大神'];
  static const _scores = [0, 25, 50, 75, 100];

  late int _level;
  late String _preferredSceneId;
  late List<String> _selectedHashtags;
  final _tagController = TextEditingController();
  final _tagFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _level = _scores.indexOf(widget.initialIntensityScore);
    if (_level < 0) _level = 2;
    _preferredSceneId = widget.initialPreferredSceneId;
    _selectedHashtags = UserHashtags.normalizeAll(widget.initialHashtags);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  int get _score => _scores[_level.clamp(0, _scores.length - 1)];

  List<String> get _suggestions =>
      UserHashtags.suggestedFor(_preferredSceneId);

  void _toggleTag(String tag) {
    final n = UserHashtags.normalize(tag);
    if (n.isEmpty) return;
    setState(() {
      if (_selectedHashtags.contains(n)) {
        _selectedHashtags = List<String>.from(_selectedHashtags)..remove(n);
      } else if (_selectedHashtags.length < UserHashtags.maxSelected) {
        _selectedHashtags = List<String>.from(_selectedHashtags)..add(n);
      }
    });
  }

  void _addCustomTag() {
    final n = UserHashtags.normalize(_tagController.text);
    _tagController.clear();
    if (n.isEmpty) return;
    if (_selectedHashtags.contains(n)) return;
    if (_selectedHashtags.length >= UserHashtags.maxSelected) return;
    setState(() => _selectedHashtags = List<String>.from(_selectedHashtags)..add(n));
    _tagFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('个性化定制'),
        backgroundColor: const Color(0xFFF2F2F7),
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            '用 # 标签描述你的兴趣和组局偏好，推荐与匹配会更准。可随时修改。',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 20),
          _sectionCard(
            title: '我的 # 标签',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已选 ${_selectedHashtags.length}/${UserHashtags.maxSelected}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 10),
                if (_selectedHashtags.isEmpty)
                  Text(
                    '还没有标签，从下方推荐中选择或自己输入',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedHashtags
                        .map(
                          (t) => HashtagChip(
                            tag: t,
                            selected: true,
                            onDeleted: () => _toggleTag(t),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        focusNode: _tagFocus,
                        decoration: InputDecoration(
                          hintText: '输入标签，如 桌游',
                          prefixText: '# ',
                          prefixStyle: const TextStyle(
                            color: _brand,
                            fontWeight: FontWeight.w700,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addCustomTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addCustomTag,
                      style: IconButton.styleFrom(backgroundColor: _brand),
                      icon: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '推荐标签',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map((t) {
                    final selected = _selectedHashtags.contains(t);
                    return HashtagChip(
                      tag: t,
                      selected: selected,
                      onTap: () => _toggleTag(t),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: '参与强度',
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('休闲娱乐'),
                    Text('硬核竞技'),
                  ],
                ),
                Slider(
                  value: _level.toDouble(),
                  min: 0,
                  max: 4,
                  divisions: 4,
                  activeColor: _brand,
                  label: _labels[_level],
                  onChanged: (v) => setState(() => _level = v.round()),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '当前：${_labels[_level]} · $_score 分',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: '常逛方向',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SceneCategories.publishable.map((scene) {
                final selected = _preferredSceneId == scene.id;
                return FilterChip(
                  label: Text(scene.label),
                  selected: selected,
                  selectedColor: _brand.withValues(alpha: 0.12),
                  checkmarkColor: _brand,
                  onSelected: (_) =>
                      setState(() => _preferredSceneId = scene.id),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {
              final tags = _selectedHashtags.isNotEmpty
                  ? _selectedHashtags
                  : UserHashtags.defaultsFor(_preferredSceneId, _score);
              widget.onSave(_score, _preferredSceneId, tags);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
