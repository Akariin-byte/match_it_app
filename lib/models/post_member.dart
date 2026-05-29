/// 组局已加入成员
class PostMember {
  const PostMember({
    required this.username,
    this.userId,
    this.role = 'member',
    this.joinedAt,
  });

  factory PostMember.fromJson(Map<String, dynamic> json) {
    DateTime? joined;
    final raw = json['joinedAt'];
    if (raw is String && raw.isNotEmpty) {
      joined = DateTime.tryParse(raw)?.toLocal();
    }
    return PostMember(
      userId: json['userId'] as String?,
      username: json['username'] as String? ?? '用户',
      role: json['role'] as String? ?? 'member',
      joinedAt: joined,
    );
  }

  final String? userId;
  final String username;
  final String role;
  final DateTime? joinedAt;

  bool get isHost => role == 'host';

  String get displayName {
    final name = username.trim();
    return name.isEmpty ? '用户' : name;
  }

  String get initial {
    final name = displayName;
    return name.isNotEmpty ? name.substring(0, 1) : '用';
  }
}
