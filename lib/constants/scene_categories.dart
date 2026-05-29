import 'package:flutter/material.dart';

/// 组局场景词表：首页筛选 & 发布分类共用（后端 `area` 字段存 id）
class SceneCategory {
  const SceneCategory({
    required this.id,
    required this.label,
    required this.icon,
    this.legacyArea,
  });

  final String id;
  final String label;
  final IconData icon;

  /// 兼容 mock 帖旧 area（BoardGames / Food / Sport）
  final String? legacyArea;
}

class SceneCategories {
  SceneCategories._();

  static const String allId = 'all';

  static const List<SceneCategory> publishable = [
    SceneCategory(id: 'AnimeCon', label: '漫展同行', icon: Icons.celebration_outlined),
    SceneCategory(id: 'Photo', label: '摄影约拍', icon: Icons.camera_alt_outlined),
    SceneCategory(
      id: 'BoardGames',
      label: '桌游剧本',
      icon: Icons.sports_esports_outlined,
      legacyArea: 'BoardGames',
    ),
    SceneCategory(
      id: 'Sport',
      label: '运动健身',
      icon: Icons.sports_basketball_outlined,
      legacyArea: 'Sport',
    ),
    SceneCategory(
      id: 'Food',
      label: '美食探店',
      icon: Icons.restaurant_outlined,
      legacyArea: 'Food',
    ),
    SceneCategory(id: 'Travel', label: '旅行出行', icon: Icons.flight_takeoff_outlined),
    SceneCategory(id: 'Study', label: '学习自习', icon: Icons.menu_book_outlined),
    SceneCategory(id: 'Game', label: '游戏开黑', icon: Icons.headphones_outlined),
    SceneCategory(id: 'Pet', label: '宠物社交', icon: Icons.pets_outlined),
    SceneCategory(id: 'Music', label: '音乐 live', icon: Icons.music_note_outlined),
    SceneCategory(id: 'Outdoor', label: '户外露营', icon: Icons.park_outlined),
    SceneCategory(id: 'Drive', label: '自驾拼车', icon: Icons.directions_car_outlined),
    SceneCategory(id: 'Other', label: '其他组局', icon: Icons.more_horiz_rounded),
  ];

  static SceneCategory? byId(String? id) {
    if (id == null || id.isEmpty || id == allId) return null;
    for (final s in publishable) {
      if (s.id == id) return s;
    }
    return null;
  }

  static String labelFor(String? id) {
    if (id == null || id.isEmpty || id == allId) return '全部';
    return byId(id)?.label ?? id;
  }

  /// Feed 筛选：全部 / 指定场景（兼容 mock 旧 area）
  static bool postAreaMatchesBrowse(String postArea, String browseSceneId) {
    if (browseSceneId.isEmpty || browseSceneId == allId) return true;
    if (postArea == browseSceneId) return true;
    final scene = byId(browseSceneId);
    if (scene?.legacyArea != null && postArea == scene!.legacyArea) return true;
    return false;
  }
}
