import 'package:flutter/material.dart';
import 'main_feed_page.dart';

class MatchItLoginPage extends StatefulWidget {
  const MatchItLoginPage({super.key});

  @override
  State<MatchItLoginPage> createState() => _MatchItLoginPageState();
}

class _MatchItLoginPageState extends State<MatchItLoginPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final String _selectedArea = 'BoardGames'; // 确保这里与 match_post.dart 里的 category 一致

  Future<void> _goToMainFeed() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MainFeedPage(
          name: _nameController.text.isNotEmpty ? _nameController.text : '玩家',
          area: _selectedArea,
          score: 50, // 示例分值，你可以加个滑块来动态获取
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录 MATCHit')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '名字')),
            TextField(controller: _accountController, decoration: const InputDecoration(labelText: '手机号')),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _goToMainFeed, child: const Text('进入大厅')),
          ],
        ),
      ),
    );
  }
}