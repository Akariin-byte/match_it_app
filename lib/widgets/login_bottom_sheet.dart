import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'phone_auth_form.dart';

/// 手机号 + 验证码登录/绑定弹窗（BottomSheet）
class LoginBottomSheet extends StatelessWidget {
  const LoginBottomSheet({
    super.key,
    this.initialSession,
    required this.onLoginSuccess,
  });

  final AuthSession? initialSession;
  final ValueChanged<AuthSession> onLoginSuccess;

  static const Color sheetBackground = Color(0xFFF5F5F7);
  static const String devVerificationCode = PhoneAuthForm.devVerificationCode;

  static Future<void> show(
    BuildContext context, {
    AuthSession? initialSession,
    required ValueChanged<AuthSession> onLoginSuccess,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: LoginBottomSheet(
          initialSession: initialSession,
          onLoginSuccess: onLoginSuccess,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: const BoxDecoration(
        color: sheetBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            '手机号登录 / 注册',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '已注册自动登录并拉取昵称；未注册可填昵称（选填）',
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 20),
          PhoneAuthForm(
            compact: true,
            initialSession: initialSession,
            onSuccess: (session) {
              onLoginSuccess(session);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
