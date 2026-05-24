import 'package:flutter/material.dart';

import '../models/match_post.dart';

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({
    super.key,
    required this.post,
    required this.onApply,
  });

  final MatchPost post;
  final ValueChanged<String> onApply;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late bool _hasApplied;

  @override
  void initState() {
    super.initState();
    _hasApplied = widget.post.hasApplied;
  }

  void _apply() {
    if (_hasApplied || widget.post.isFull) {
      return;
    }
    setState(() {
      _hasApplied = true;
    });
    widget.onApply(widget.post.id);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('申请已发送'),
          content: const Text('申请已发送，等待主理人确认。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('好的'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final progress = post.currentMembers / post.maxMembers;
    final statusLabel = post.isFull
        ? '已满员'
        : _hasApplied
            ? '已申请'
            : '组队中';
    final statusColor = post.isFull
        ? Colors.black54
        : _hasApplied
            ? Colors.orange.shade700
            : const Color(0xFF002FA7);

    final joinedAvatars = List.generate(
      post.currentMembers,
      (index) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade300,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('帖子详情'),
      ),
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFECECF7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image,
                    size: 56,
                    color: Colors.black26,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                post.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '组队进度',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${post.currentMembers}/${post.maxMembers} 人',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  color: const Color(0xFF002FA7),
                  backgroundColor: Colors.black12,
                ),
              ),
              const SizedBox(height: 16),
              Row(children: joinedAvatars),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: post.isFull || _hasApplied
                        ? Colors.grey.shade400
                        : const Color(0xFF002FA7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: post.isFull || _hasApplied ? null : _apply,
                  child: Text(
                    post.isFull
                        ? '已满员'
                        : _hasApplied
                            ? '已申请'
                            : '申请加入',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
