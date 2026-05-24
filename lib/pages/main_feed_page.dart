import 'package:flutter/material.dart';
import '../models/match_post.dart';

class MainFeedPage extends StatefulWidget {
  const MainFeedPage({
    super.key,
    required this.name,
    required this.area,
    required this.score,
  });

  final String name;
  final String area;
  final int score;

  @override
  State<MainFeedPage> createState() => _MainFeedPageState();
}

class _MainFeedPageState extends State<MainFeedPage> {
  static bool _matchesScoreTier(int postScore, int userScore) {
    switch (userScore) {
      case 0:
        return postScore < 25;
      case 25:
        return postScore >= 25 && postScore < 50;
      case 50:
        return postScore >= 50 && postScore < 75;
      case 75:
        return postScore >= 75 && postScore < 90;
      case 100:
        return postScore >= 90;
      default:
        return false;
    }
  }

  List<MatchPost> get _filteredPosts {
    final targetCategory = widget.area.trim();
    final userScore = widget.score;

    return mockMatchPosts.where((post) {
      if (post.category.trim() != targetCategory) return false;
      return _matchesScoreTier(post.competitiveness, userScore);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredPosts = _filteredPosts;

    return Scaffold(
      appBar: AppBar(title: Text('分类：${widget.area}')),
      body: filteredPosts.isEmpty
          ? const Center(child: Text('当前分类下暂无内容'))
          : ListView.builder(
              itemCount: filteredPosts.length,
              itemBuilder: (context, index) {
                final post = filteredPosts[index];
                return ListTile(
                  title: Text(post.title),
                  subtitle: Text(
                    '类别: ${post.category} | 分数: ${post.competitiveness}',
                  ),
                );
              },
            ),
    );
  }
}
