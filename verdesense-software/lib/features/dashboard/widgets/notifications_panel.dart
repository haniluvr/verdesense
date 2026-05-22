import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';

// Notification model
class AppNotification {
  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color iconColor;
  final DateTime time;
  final bool isUrgent; // Urgent = won't clear until resolved/admin clears
  bool isRead;
  bool isResolved; // Only for urgent ones
  final String? resolvedBy; // Email of whoever resolved it (shared across users)

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
    required this.time,
    this.isUrgent = false,
    this.isRead = false,
    this.isResolved = false,
    this.resolvedBy,
  });
}

class NotificationsPanel extends StatefulWidget {
  final List<AppNotification> notifications;
  final VoidCallback onClose;
  final Function(String id) onMarkAsRead;
  final Function(String id) onResolveUrgent;
  final Function(String id)? onNotificationTap;

  const NotificationsPanel({
    super.key,
    required this.notifications,
    required this.onClose,
    required this.onMarkAsRead,
    required this.onResolveUrgent,
    this.onNotificationTap,
  });

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onClose();
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final urgent = widget.notifications.where((n) => n.isUrgent && !n.isResolved).toList();
    final standard = widget.notifications.where((n) => !n.isUrgent && !n.isRead).toList();

    return GestureDetector(
      onTap: _close,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: Colors.black.withValues(alpha: 0.35),
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () {}, // Prevent tap-through
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: const Alignment(0.75, -1.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.75,
                    ),
                    decoration: ShapeDecoration(
                      color: isDark
                          ? const Color(0xFF010614).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                      shape: _ChatBubbleBorder(
                        borderRadius: 24.0,
                        arrowWidth: 18.0,
                        arrowHeight: 12.0,
                        arrowOffset: 58.0,
                        side: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ),
                      shadows: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                          child: Row(
                            children: [
                              Icon(
                                urgent.isNotEmpty
                                    ? Icons.notifications_active
                                    : Icons.notifications_outlined,
                                color: urgent.isNotEmpty
                                    ? AppColors.statusDanger
                                    : Theme.of(context).colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'NOTIFICATIONS',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              if (standard.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    for (final n in standard) {
                                      widget.onMarkAsRead(n.id);
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Clear all',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                                onPressed: _close,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),

                        Flexible(
                          child: (urgent.isEmpty && standard.isEmpty)
                              ? _buildEmpty()
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // URGENT section
                                      if (urgent.isNotEmpty) ...[
                                        _sectionLabel('🚨  URGENT — Requires Action', AppColors.statusDanger),
                                        const SizedBox(height: 6),
                                        ...urgent.map((n) => _NotificationTile(
                                              notification: n,
                                              timeAgo: _timeAgo(n.time),
                                              onTap: () {
                                                if (widget.onNotificationTap != null) {
                                                  widget.onNotificationTap!(n.id);
                                                } else {
                                                  widget.onMarkAsRead(n.id);
                                                }
                                              },
                                              onResolve: () => widget.onResolveUrgent(n.id),
                                              isUrgent: true,
                                            )),
                                        const SizedBox(height: 12),
                                      ],
                                      // STANDARD section
                                      if (standard.isNotEmpty) ...[
                                        _sectionLabel('New', Theme.of(context).colorScheme.primary),
                                        const SizedBox(height: 6),
                                        ...standard.map((n) => _NotificationTile(
                                              notification: n,
                                              timeAgo: _timeAgo(n.time),
                                              onTap: () {
                                                if (widget.onNotificationTap != null) {
                                                  widget.onNotificationTap!(n.id);
                                                } else {
                                                  widget.onMarkAsRead(n.id);
                                                }
                                              },
                                              onResolve: null,
                                              isUrgent: false,
                                            )),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'You\'re all caught up!',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback? onResolve;
  final bool isUrgent;

  const _NotificationTile({
    required this.notification,
    required this.timeAgo,
    required this.onTap,
    required this.onResolve,
    required this.isUrgent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isUrgent
        ? AppColors.statusDanger.withValues(alpha: 0.4)
        : notification.iconColor.withValues(alpha: 0.2);
    final bgColor = isUrgent
        ? AppColors.statusDanger.withValues(alpha: isDark ? 0.04 : 0.02)
        : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.01));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? borderColor.withValues(alpha: 0.1) 
              : borderColor.withValues(alpha: 0.15)
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: notification.iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(notification.icon, color: notification.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isUrgent) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.statusDanger,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'URGENT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Resolve button / resolved label for urgent connectivity logs
                    if (isUrgent) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: notification.isResolved || notification.resolvedBy != null
                            // Already resolved — show who resolved it
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 14, color: AppColors.statusSafe),
                                  const SizedBox(width: 6),
                                  Text(
                                    notification.resolvedBy != null
                                        ? 'Resolved by ${notification.resolvedBy}'
                                        : 'Marked resolved',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.statusSafe,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            // Not yet resolved — show button
                            : onResolve != null
                                ? OutlinedButton.icon(
                                    onPressed: onResolve,
                                    icon: Icon(Icons.check_circle_outline_rounded,
                                        size: 16, color: AppColors.statusSafe),
                                    label: const Text('MARK RESOLVED',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.statusSafe,
                                      side: BorderSide(
                                          color: AppColors.statusSafe.withValues(alpha: 0.5)),
                                      backgroundColor:
                                          AppColors.statusSafe.withValues(alpha: 0.05),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _ChatBubbleBorder extends ShapeBorder {
  final double borderRadius;
  final double arrowWidth;
  final double arrowHeight;
  final double arrowOffset;
  final BorderSide side;

  const _ChatBubbleBorder({
    this.borderRadius = 24.0,
    this.arrowWidth = 18.0,
    this.arrowHeight = 12.0,
    this.arrowOffset = 58.0,
    this.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(top: arrowHeight) + EdgeInsets.all(side.width);

  Path _getPath(Rect rect) {
    final mainRect = Rect.fromLTWH(rect.left, rect.top + arrowHeight, rect.width, rect.height - arrowHeight);
    final rrect = RRect.fromRectAndRadius(mainRect, Radius.circular(borderRadius));
    
    final path = Path();
    path.moveTo(rrect.left, rrect.top + borderRadius);
    path.arcToPoint(Offset(rrect.left + borderRadius, rrect.top), radius: Radius.circular(borderRadius));
    
    path.lineTo(rect.right - arrowOffset - arrowWidth, rect.top + arrowHeight);
    path.lineTo(rect.right - arrowOffset - arrowWidth / 2, rect.top);
    path.lineTo(rect.right - arrowOffset, rect.top + arrowHeight);
    
    path.lineTo(rrect.right - borderRadius, rrect.top);
    path.arcToPoint(Offset(rrect.right, rrect.top + borderRadius), radius: Radius.circular(borderRadius));
    
    path.lineTo(rrect.right, rrect.bottom - borderRadius);
    path.arcToPoint(Offset(rrect.right - borderRadius, rrect.bottom), radius: Radius.circular(borderRadius));
    
    path.lineTo(rrect.left + borderRadius, rrect.bottom);
    path.arcToPoint(Offset(rrect.left, rrect.bottom - borderRadius), radius: Radius.circular(borderRadius));
    
    path.close();

    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _getPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _getPath(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final paint = side.toPaint();
    canvas.drawPath(_getPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) {
    return _ChatBubbleBorder(
      borderRadius: borderRadius * t,
      arrowWidth: arrowWidth * t,
      arrowHeight: arrowHeight * t,
      arrowOffset: arrowOffset * t,
      side: side.scale(t),
    );
  }
}
