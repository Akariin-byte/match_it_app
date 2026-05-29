import 'package:flutter/material.dart';

import 'package:match_it_app/main.dart';
import 'package:match_it_app/pages/main_shell_page.dart';
import 'package:match_it_app/services/auth_service.dart';
import 'package:match_it_app/services/token_storage.dart';

/// 启动页：静默游客登录后直达 Feed（先预览后引导）
class AppBootstrapPage extends StatefulWidget {
  const AppBootstrapPage({super.key});

  @override
  State<AppBootstrapPage> createState() => _AppBootstrapPageState();
}

class _AppBootstrapPageState extends State<AppBootstrapPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    AuthSession? session = await tokenStorage.loadSession();

    if (session == null) {
      try {
        session = await authService.guestLogin();
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = '无法连接后端，请确认 API 已启动');
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MainShellPage(
          user: UserProfile.guestDefault(
            userId: session!.userId,
            name: session.displayName,
          ),
          authSession: session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() => _error = null);
                        _bootstrap();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在进入 MATCHit…'),
                ],
              ),
      ),
    );
  }
}
