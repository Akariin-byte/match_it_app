import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/token_storage.dart';

/// 小红书式手机号登录/注册表单：已注册拉取昵称，新用户昵称选填
class PhoneAuthForm extends StatefulWidget {
  const PhoneAuthForm({
    super.key,
    this.initialSession,
    required this.onSuccess,
    this.compact = false,
  });

  final AuthSession? initialSession;
  final ValueChanged<AuthSession> onSuccess;
  final bool compact;

  static const Color brandColor = Color(0xFF002FA7);
  static const String devVerificationCode = '000000';

  @override
  State<PhoneAuthForm> createState() => _PhoneAuthFormState();
}

class _PhoneAuthFormState extends State<PhoneAuthForm> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _nicknameController = TextEditingController();

  bool _isLoading = false;
  bool _isSendingCode = false;
  bool? _phoneRegistered;
  String? _registeredUsername;
  String? _errorText;
  String? _hintText;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    final phone = value.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      setState(() {
        _phoneRegistered = null;
        _registeredUsername = null;
        _hintText = null;
      });
      return;
    }
    _checkPhone(phone);
  }

  Future<void> _checkPhone(String phone) async {
    try {
      final status = await authService.checkPhoneStatus(phone);
      if (!mounted) return;
      setState(() {
        _phoneRegistered = status.registered;
        _registeredUsername = status.username;
        if (status.registered && (status.username?.isNotEmpty ?? false)) {
          _hintText = '欢迎回来，${status.username}';
          _nicknameController.clear();
        } else {
          _hintText = '新手机号，可填写昵称（选填，留空自动生成）';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phoneRegistered = null;
        _registeredUsername = null;
        _hintText = null;
      });
    }
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      setState(() => _errorText = '请输入有效的 11 位手机号');
      return;
    }

    setState(() {
      _isSendingCode = true;
      _errorText = null;
    });

    try {
      if (_phoneRegistered == null) {
        await _checkPhone(phone);
      }
      final scene = (_phoneRegistered ?? false) ? 'login' : 'bind';
      await authService.sendCode(phone: phone, scene: scene);
      if (!mounted) return;
      setState(() {
        _hintText = '验证码已发送（开发环境可用 ${PhoneAuthForm.devVerificationCode}）';
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '发送验证码失败，请确认 API 已启动');
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      setState(() => _errorText = '请输入有效的 11 位手机号');
      return;
    }
    if (code.isEmpty) {
      setState(() => _errorText = '请输入验证码');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _checkPhone(phone);
      final isRegistered = _phoneRegistered ?? false;
      final AuthSession session;
      if (isRegistered) {
        session = await authService.loginWithPhone(
          phone: phone,
          verificationCode: code,
        );
      } else if (widget.initialSession?.isGuest == true) {
        final nickname = _nicknameController.text.trim();
        session = await authService.loginOrBindPhone(
          session: widget.initialSession,
          phone: phone,
          verificationCode: code,
          username: nickname.isEmpty ? null : nickname,
        );
      } else {
        final nickname = _nicknameController.text.trim();
        session = await authService.registerWithPhone(
          phone: phone,
          verificationCode: code,
          username: nickname.isEmpty ? null : nickname,
        );
      }

      await tokenStorage.saveSession(session);
      if (!mounted) return;
      widget.onSuccess(session);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = '无法连接后端，请确认 API 已启动');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNickname = _phoneRegistered == false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hintText != null) ...[
          Text(
            _hintText!,
            style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 12),
        ],
        _buildField(
          controller: _phoneController,
          label: '手机号',
          hint: '11 位中国大陆手机号',
          keyboardType: TextInputType.phone,
          onChanged: _onPhoneChanged,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildField(
                controller: _codeController,
                label: '验证码',
                hint: PhoneAuthForm.devVerificationCode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: _isSendingCode || _isLoading ? null : _sendCode,
                child: Text(_isSendingCode ? '发送中…' : '获取验证码'),
              ),
            ),
          ],
        ),
        if (showNickname) ...[
          const SizedBox(height: 12),
          _buildField(
            controller: _nicknameController,
            label: '昵称（选填）',
            hint: '留空将自动生成游客昵称',
          ),
        ],
        if (_phoneRegistered == true &&
            (_registeredUsername?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '将使用账号昵称：$_registeredUsername',
              style: const TextStyle(
                color: PhoneAuthForm.brandColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (_errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ],
        SizedBox(height: widget.compact ? 16 : 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _isLoading ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: PhoneAuthForm.brandColor,
              disabledBackgroundColor:
                  PhoneAuthForm.brandColor.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.compact ? 16 : 50),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _phoneRegistered == true ? '登录' : '注册 / 登录',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: const TextStyle(color: Colors.black54),
          hintStyle: TextStyle(color: Colors.black.withValues(alpha: 0.25)),
        ),
      ),
    );
  }
}
