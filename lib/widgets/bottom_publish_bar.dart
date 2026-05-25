import 'package:flutter/material.dart';

/// 小红书式底部栏：中间凸起「+」发布入口
class BottomPublishBar extends StatelessWidget {
  const BottomPublishBar({
    super.key,
    required this.onPublish,
    this.onHome,
    this.onProfile,
    this.homeSelected = true,
  });

  final VoidCallback onPublish;
  final VoidCallback? onHome;
  final VoidCallback? onProfile;
  final bool homeSelected;

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
                      selected: homeSelected,
                      onTap: onHome,
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person_outline_rounded,
                      label: '我',
                      selected: !homeSelected,
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BottomPublishBar.brandColor : Colors.black45;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
