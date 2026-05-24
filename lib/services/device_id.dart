/// 本地设备 ID，用于后端「同一设备同一游客账号」
/// Web 下同一会话内不变；生产环境建议改用 shared_preferences 持久化
class DeviceId {
  DeviceId._();

  static String? _cached;

  /// 获取或生成本机 device_id，对应 POST /auth/guest-login 的 device_id 字段
  static String get() {
    _cached ??= 'device_${DateTime.now().microsecondsSinceEpoch}';
    return _cached!;
  }
}
