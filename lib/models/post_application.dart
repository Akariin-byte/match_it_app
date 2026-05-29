/// 主理人收到的组局申请（消息中心 · 申请 Tab）
class ReceivedApplicationItem {
  const ReceivedApplicationItem({
    required this.id,
    required this.postId,
    required this.applicantUserId,
    required this.status,
    required this.postTitle,
    required this.postArea,
    required this.applicantUsername,
    this.applicantPhoneMasked,
    this.wechatContact,
    this.message,
    this.createdAt,
  });

  factory ReceivedApplicationItem.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['createdAt'];
    if (raw is String && raw.isNotEmpty) {
      created = DateTime.tryParse(raw)?.toLocal();
    }
    return ReceivedApplicationItem(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      applicantUserId: json['userId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String?,
      postTitle: json['postTitle'] as String? ?? '',
      postArea: json['postArea'] as String? ?? '',
      applicantUsername: json['applicantUsername'] as String? ?? '用户',
      applicantPhoneMasked: json['applicantPhoneMasked'] as String?,
      wechatContact: json['wechatContact'] as String? ?? '',
      createdAt: created,
    );
  }

  final String id;
  final String postId;
  final String applicantUserId;
  final String status;
  final String? message;
  final String postTitle;
  final String postArea;
  final String applicantUsername;
  final String? applicantPhoneMasked;
  final String wechatContact;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';

  String get statusLabel {
    switch (status) {
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已拒绝';
      case 'cancelled':
        return '已取消';
      default:
        return '待确认';
    }
  }

  String get applicantDisplayName {
    final name = applicantUsername.trim();
    if (name.isEmpty) return '用户';
    return name;
  }
}

/// 我发出的申请（保留供后续「我的申请」使用）
class PostApplicationItem {
  const PostApplicationItem({
    required this.id,
    required this.postId,
    required this.status,
    required this.postTitle,
    required this.postArea,
    required this.hostNickname,
    this.message,
    this.eventLocation,
    this.createdAt,
  });

  factory PostApplicationItem.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final raw = json['createdAt'];
    if (raw is String && raw.isNotEmpty) {
      created = DateTime.tryParse(raw)?.toLocal();
    }
    return PostApplicationItem(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String?,
      postTitle: json['postTitle'] as String? ?? '',
      postArea: json['postArea'] as String? ?? '',
      hostNickname: json['hostNickname'] as String? ?? '用户',
      eventLocation: json['eventLocation'] as String?,
      createdAt: created,
    );
  }

  final String id;
  final String postId;
  final String status;
  final String? message;
  final String postTitle;
  final String postArea;
  final String hostNickname;
  final String? eventLocation;
  final DateTime? createdAt;

  String get statusLabel {
    switch (status) {
      case 'approved':
        return '已通过';
      case 'rejected':
        return '已拒绝';
      case 'cancelled':
        return '已取消';
      default:
        return '待确认';
    }
  }
}

class ReceivedApplicationsResult {
  const ReceivedApplicationsResult({
    required this.items,
    required this.pendingCount,
  });

  final List<ReceivedApplicationItem> items;
  final int pendingCount;
}
