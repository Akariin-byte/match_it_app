/// 搭子帖模型（Feed / 详情 / API 共用）
class MatchPost {
  const MatchPost({
    required this.id,
    required this.title,
    required this.description,
    required this.currentMembers,
    required this.maxMembers,
    this.maxPeople,
    required this.area,
    required this.tab,
    required this.hardcoreScore,
    required this.hostFaceTraits,
    required this.interactionCount,
    required this.lastActiveTime,
    required this.matchScore,
    this.hostUserId,
    required this.hostNickname,
    required this.hostCreditScore,
    required this.eventDateTime,
    required this.eventLocation,
    this.isPinned = false,
    this.pinPriority = 0,
    this.hasApplied = false,
    this.applicationStatus,
  });

  factory MatchPost.fromApiJson(Map<String, dynamic> json) {
    DateTime parseTime(dynamic v, {DateTime? fallback}) {
      if (v == null) return fallback ?? DateTime.now();
      if (v is String && v.isNotEmpty) {
        return DateTime.parse(v).toLocal();
      }
      return fallback ?? DateTime.now();
    }

    final maxMembers = (json['maxMembers'] as num?)?.toInt() ?? 4;
    final traits = json['hostFaceTraits'];
    return MatchPost(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      currentMembers: (json['currentMembers'] as num?)?.toInt() ?? 1,
      maxMembers: maxMembers,
      maxPeople: (json['maxPeople'] as num?)?.toInt() ?? maxMembers,
      area: json['area'] as String? ?? '',
      tab: json['tab'] as String? ?? '推荐',
      hardcoreScore: (json['hardcoreScore'] as num?)?.toInt() ?? 50,
      hostFaceTraits: traits is List
          ? traits.map((e) => e.toString()).toList()
          : const <String>[],
      interactionCount: (json['interactionCount'] as num?)?.toInt() ?? 0,
      lastActiveTime: parseTime(json['lastActiveTime']),
      matchScore: (json['matchScore'] as num?)?.toDouble() ?? 0,
      hostUserId: json['hostUserId'] as String?,
      hostNickname: json['hostNickname'] as String? ?? '用户',
      hostCreditScore: (json['hostCreditScore'] as num?)?.toInt() ?? 80,
      eventDateTime: parseTime(
        json['eventDateTime'],
        fallback: DateTime.now().add(const Duration(days: 1)),
      ),
      eventLocation: json['eventLocation'] as String? ?? '',
      isPinned: json['isPinned'] as bool? ?? false,
      pinPriority: (json['pinPriority'] as num?)?.toInt() ?? 0,
      hasApplied: json['hasApplied'] as bool? ?? false,
      applicationStatus: json['applicationStatus'] as String?,
    );
  }

  final String id;
  final String title;
  final String description;
  final int currentMembers;
  final int maxMembers;
  final int? maxPeople;
  final String area;
  final String tab;
  final int hardcoreScore;
  final List<String> hostFaceTraits;
  final int interactionCount;
  final DateTime lastActiveTime;
  final double matchScore;
  final String? hostUserId;
  final String hostNickname;
  final int hostCreditScore;
  final DateTime eventDateTime;
  final String eventLocation;
  final bool isPinned;
  final int pinPriority;
  final bool hasApplied;
  final String? applicationStatus;

  bool get isFull => currentMembers >= peopleLimit;

  bool get hasPendingApplication =>
      hasApplied || applicationStatus == 'pending';

  bool get hasApprovedApplication => applicationStatus == 'approved';

  int get peopleLimit => maxPeople ?? maxMembers;
}
