import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/siren_provider.dart';
import '../../../../core/widgets/custom_notification_modal.dart';
import '../../../../core/widgets/siren_active_dialog.dart';
import '../../../../core/widgets/page_title.dart';

class OverrideSirenScreen extends StatefulWidget {
  final int activeIndex;

  const OverrideSirenScreen({super.key, required this.activeIndex});

  @override
  State<OverrideSirenScreen> createState() => _OverrideSirenScreenState();
}

class _OverrideSirenScreenState extends State<OverrideSirenScreen>
    with TickerProviderStateMixin {
  // Carousel page state
  int _carouselIndex = 0;
  late final PageController _carouselController;

  // Ripple animations for override buttons
  late final List<AnimationController> _rippleControllers;
  late final List<Animation<double>> _rippleAnimations;

  // Arm/Disarm animation for the command strip
  late final AnimationController _armController;
  late final Animation<double> _armAnimation;

  static const _overrides = [
    {
      'title': 'EVACUATION\nSIREN',
      'subtitle': 'Triggers general\nevacuation alarm',
      'icon': Icons.warning_amber_rounded,
      'color': AppColors.statusDanger,
      'sirenTitle': 'EVACUATION SIREN',
      'sirenIcon': Icons.warning_amber_rounded,
    },
    {
      'title': 'SAFETY\nALERT',
      'subtitle': 'Signals area-clear\nall-safe status',
      'icon': Icons.health_and_safety_rounded,
      'color': AppColors.statusWarning,
      'sirenTitle': 'SAFETY ALERT',
      'sirenIcon': Icons.health_and_safety_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(
      viewportFraction: 0.72,
      initialPage: 0,
    );

    _rippleControllers = List.generate(
      _overrides.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat(),
    );

    _rippleAnimations = _rippleControllers
        .map(
          (c) => Tween<double>(begin: 0.8, end: 1.6).animate(
            CurvedAnimation(parent: c, curve: Curves.easeOut),
          ),
        )
        .toList();

    _armController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _armAnimation = CurvedAnimation(
      parent: _armController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _carouselController.dispose();
    for (final c in _rippleControllers) {
      c.dispose();
    }
    _armController.dispose();
    super.dispose();
  }

  // ── Siren Command Strip ────────────────────────────────────────────────────

  Widget _buildSirenCommandStrip() {
    final sirenProvider = context.watch<SirenProvider>();
    final isActive = sirenProvider.isSirenActive;
    final isArmed = sirenProvider.isSirenArmed;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color accentColor =
        isActive ? AppColors.statusDanger : AppColors.primaryRose;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          // Status orb
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withValues(alpha: 0.15),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Icon(
              isActive
                  ? Icons.campaign_rounded
                  : (isArmed
                      ? Icons.shield_rounded
                      : Icons.shield_outlined),
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    key: ValueKey(isActive
                        ? sirenProvider.activeSirenTitle
                        : (isArmed ? 'SYSTEM ARMED' : 'SYSTEM DISARMED')),
                    isActive
                        ? (sirenProvider.activeSirenTitle ?? 'ACTIVE')
                        : (isArmed ? 'SYSTEM ARMED' : 'SYSTEM DISARMED'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isActive
                      ? 'Tap to view / terminate'
                      : (isArmed
                          ? 'Overrides enabled · Ready'
                          : 'Overrides locked · Tap to arm'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          // Arm toggle / active tap
          GestureDetector(
            onTap: () {
              if (isActive) {
                SirenActiveDialog.show(context, sirenProvider);
              } else {
                sirenProvider.setSirenArmed(!isArmed);
                if (!isArmed) {
                  _armController.forward(from: 0);
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.statusDanger.withValues(alpha: 0.12)
                    : (isArmed
                        ? AppColors.statusSafe.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.10)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? AppColors.statusDanger.withValues(alpha: 0.4)
                      : (isArmed
                          ? AppColors.statusSafe.withValues(alpha: 0.35)
                          : Colors.grey.withValues(alpha: 0.25)),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive
                        ? Icons.power_settings_new_rounded
                        : (isArmed
                            ? Icons.lock_open_rounded
                            : Icons.lock_rounded),
                    size: 14,
                    color: isActive
                        ? AppColors.statusDanger
                        : (isArmed
                            ? AppColors.statusSafe
                            : Colors.grey),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isActive ? 'ACTIVE' : (isArmed ? 'ARMED' : 'DISARMED'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isActive
                          ? AppColors.statusDanger
                          : (isArmed
                              ? AppColors.statusSafe
                              : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Circular Override Carousel ─────────────────────────────────────────────

  Widget _buildCircularOverrideCarousel() {
    final sirenProvider = context.watch<SirenProvider>();
    final isArmed = sirenProvider.isSirenArmed;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        SizedBox(
          height: 330,
          child: PageView.builder(
            controller: _carouselController,
            itemCount: _overrides.length,
            onPageChanged: (i) => setState(() => _carouselIndex = i),
            itemBuilder: (context, index) {
              final item = _overrides[index];
              final color = item['color'] as Color;
              final title = item['title'] as String;
              final subtitle = item['subtitle'] as String;
              final icon = item['icon'] as IconData;
              final sirenTitle = item['sirenTitle'] as String;
              final sirenIcon = item['sirenIcon'] as IconData;

              final isThisSirenActive =
                  sirenProvider.activeSirenTitle == sirenTitle;
              final scale = _carouselIndex == index ? 1.0 : 0.88;

              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildOverrideCard(
                    color: color,
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    sirenTitle: sirenTitle,
                    sirenIcon: sirenIcon,
                    isActive: isThisSirenActive,
                    isArmed: isArmed,
                    rippleController: _rippleControllers[index],
                    rippleAnimation: _rippleAnimations[index],
                    isDark: isDark,
                    sirenProvider: sirenProvider,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _overrides.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _carouselIndex == i ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _carouselIndex == i
                    ? AppColors.primaryRose
                    : AppColors.primaryRose.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverrideCard({
    required Color color,
    required String title,
    required String subtitle,
    required IconData icon,
    required String sirenTitle,
    required IconData sirenIcon,
    required bool isActive,
    required bool isArmed,
    required AnimationController rippleController,
    required Animation<double> rippleAnimation,
    required bool isDark,
    required SirenProvider sirenProvider,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.95)
            : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.6)
              : color.withValues(alpha: 0.18),
          width: isActive ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isActive ? 0.25 : 0.08),
            blurRadius: isActive ? 30 : 16,
            spreadRadius: isActive ? 4 : 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ripple icon orb
            AnimatedBuilder(
              animation: rippleAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isActive)
                      ...List.generate(3, (i) {
                        final delay = i / 3;
                        final rawVal =
                            (rippleAnimation.value - delay) % 1.0;
                        final val = rawVal < 0 ? rawVal + 1 : rawVal;
                        return Transform.scale(
                          scale: 0.9 + val * 0.8,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color
                                  .withValues(alpha: (1 - val) * 0.15),
                            ),
                          ),
                        );
                      }),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withValues(
                            alpha: isActive ? 0.18 : 0.10),
                        border: Border.all(
                          color: color.withValues(
                              alpha: isActive ? 0.5 : 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(icon, color: color, size: 38),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                height: 1.15,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 24),
            // Activate / Terminate button
            SizedBox(
              width: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isActive
                      ? color.withValues(alpha: 0.12)
                      : (!isArmed
                          ? Colors.grey.withValues(alpha: 0.08)
                          : color.withValues(alpha: 0.10)),
                  border: Border.all(
                    color: isActive
                        ? color.withValues(alpha: 0.55)
                        : (!isArmed
                            ? Colors.grey.withValues(alpha: 0.2)
                            : color.withValues(alpha: 0.30)),
                    width: 1.2,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: !isArmed && !isActive
                        ? () {
                            CustomNotificationModal.show(
                              context: context,
                              title: "System Disarmed",
                              message:
                                  "Arm the system first before activating an override.",
                              isSuccess: false,
                            );
                          }
                        : () async {
                            if (isActive) {
                              sirenProvider.terminateSiren();
                              CustomNotificationModal.show(
                                context: context,
                                title: "Signal Terminated",
                                message:
                                    "$sirenTitle has been DEACTIVATED.",
                                isSuccess: true,
                              );
                            } else {
                              sirenProvider.activateSiren(
                                sirenTitle,
                                sirenIcon,
                                color,
                              );
                              await Future.delayed(
                                  const Duration(milliseconds: 300));
                              if (mounted) {
                                await SirenActiveDialog.show(
                                    context, sirenProvider);
                              }
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive
                                ? Icons.power_settings_new_rounded
                                : (!isArmed
                                    ? Icons.lock_rounded
                                    : Icons.campaign_rounded),
                            size: 16,
                            color: !isArmed && !isActive
                                ? Colors.grey
                                : (isActive ? color : color),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isActive
                                ? 'TERMINATE OVERRIDE'
                                : (!isArmed
                                    ? 'SYSTEM DISARMED'
                                    : 'ACTIVATE OVERRIDE'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.3,
                              color: !isArmed && !isActive
                                  ? Colors.grey
                                  : color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Status Banner (shown when a siren is active) ───────────────────────────

  Widget _buildActiveSirenBanner(SirenProvider sirenProvider) {
    final color = sirenProvider.activeSirenColor ?? AppColors.statusDanger;
    final icon =
        sirenProvider.activeSirenIcon ?? Icons.campaign_rounded;
    final title = sirenProvider.activeSirenTitle ?? 'ACTIVE';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, val, child) => Opacity(
        opacity: val,
        child: Transform.translate(
          offset: Offset(0, (1 - val) * -12),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () => SirenActiveDialog.show(context, sirenProvider),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? color.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: color.withValues(alpha: 0.45), width: 1.4),
          ),
          child: Row(
            children: [
              _PulsingIcon(icon: icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title IS ACTIVE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                        color: color,
                      ),
                    ),
                    Text(
                      'Tap to view or terminate',
                      style: TextStyle(
                        fontSize: 10,
                        color: color.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sirenProvider = context.watch<SirenProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageTitle(
          key: ValueKey('override_siren_${widget.activeIndex}'),
          title: "Override Siren",
        ),
        const SizedBox(height: 16),

        // Active siren banner (only when a siren is running)
        if (sirenProvider.isSirenActive)
          _buildActiveSirenBanner(sirenProvider),

        // Tactical command strip console
        _buildSirenCommandStrip(),
        const SizedBox(height: 20),

        // Section header
        Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "EMERGENCY OVERRIDES",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color:
                        Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  "MANUAL SIREN CONTROL CONSOLE",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCircularOverrideCarousel(),

        const SizedBox(height: 24),

        // Safety disclaimer
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.statusWarning.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.statusWarning.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16,
                  color:
                      AppColors.statusWarning.withValues(alpha: 0.8)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Manual overrides broadcast to ALL registered devices simultaneously. "
                  "Only authorised personnel should activate emergency sirens.",
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Small helper widget ────────────────────────────────────────────────────

class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _PulsingIcon({required this.icon, required this.color});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _a = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: Icon(widget.icon, color: widget.color, size: 22),
    );
  }
}
