import 'package:flutter/material.dart';

/// 小红书式底栏：首页 | 消息 | + | 私信 | 我
class BottomPublishBar extends StatelessWidget {
  const BottomPublishBar({
    super.key,
    required this.onPublish,
    this.onHome,
    this.onMessages,
    this.onChat,
    this.onProfile,
    this.selectedIndex = 0,
    this.messageBadgeCount = 0,
    this.chatBadgeCount = 0,
  });

  final VoidCallback onPublish;
  final VoidCallback? onHome;
  final VoidCallback? onMessages;
  final VoidCallback? onChat;
  final VoidCallback? onProfile;

  /// 0=首页 1=消息(申请) 2=私信 3=我
  final int selectedIndex;
  final int messageBadgeCount;
  final int chatBadgeCount;

  static const Color brandColor = Color(0xFF002FA7);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_rounded,
                      label: '首页',
                      selected: selectedIndex == 0,
                      onTap: onHome,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.notifications_none_rounded,
                      label: '消息',
                      selected: selectedIndex == 1,
                      badgeCount: messageBadgeCount,
                      onTap: onMessages,
                    ),
                  ),
                  const Expanded(child: SizedBox.shrink()),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '私信',
                      selected: selectedIndex == 2,
                      badgeCount: chatBadgeCount,
                      onTap: onChat,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person_outline_rounded,
                      label: '我',
                      selected: selectedIndex == 3,
                      onTap: onProfile,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -18,
                child: _PublishButton(onTap: onPublish),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0038C7),
                BottomPublishBar.brandColor,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: BottomPublishBar.brandColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BottomPublishBar.brandColor : Colors.black45;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 22),
              if (badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
