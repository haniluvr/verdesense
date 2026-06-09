import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../auth/screens/login_screen.dart';

// ── Onboarding slide data ──────────────────────────────────────────────────

class _SlideData {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color iconBorderColor;

  const _SlideData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.iconBorderColor,
  });
}

const List<_SlideData> _slides = [
  _SlideData(
    title: '24/7 Fire Guard',
    description:
        'Quickly senses smoke or flames from a distance to stop fires early and protect your harvest.',
    icon: Icons.local_fire_department_rounded,
    iconColor: Color(0xFFEF4444),
    iconBgColor: Color(0x1AEF4444),
    iconBorderColor: Color(0x33EF4444),
  ),
  _SlideData(
    title: 'Smart Tracker',
    description:
        'Keeps track of how many people enter or leave the storage building for safety during emergencies.',
    icon: Icons.groups_rounded,
    iconColor: Color(0xFF60A5FA),
    iconBgColor: Color(0x1A1D4ED8),
    iconBorderColor: Color(0x333B82F6),
  ),
  _SlideData(
    title: 'Real-Time Alerts',
    description:
        'Sends an instant alert to your mobile phone so you can monitor the farm from anywhere.',
    icon: Icons.notifications_active_rounded,
    iconColor: Color(0xFF9D5B65),
    iconBgColor: Color(0x1A9D5B65),
    iconBorderColor: Color(0x339D5B65),
  ),
];

// ── Onboarding Screen ──────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isAnimating = false;

  void _navigateToLogin() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _goToNext() {
    if (_isAnimating) return;
    if (_currentIndex >= _slides.length - 1) {
      _navigateToLogin();
      return;
    }
    _isAnimating = true;
    _pageController
        .nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    )
        .then((_) => _isAnimating = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // ── Subtle radial glow ────────────────────────────────────────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            top: 100,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOutCubic,
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    _slides[_currentIndex].iconColor.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),

          Column(
            children: [
              // ── Skip button ─────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _navigateToLogin,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textGrey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Slides ──────────────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _OnboardingSlide(data: _slides[index]);
                  },
                ),
              ),

              // ── Bottom controls ──────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.only(left: 28, right: 28, bottom: 48, top: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.backgroundDark,
                      AppColors.backgroundDark,
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    // ── Dot indicators ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: index == _currentIndex ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: index == _currentIndex
                                ? AppColors.primaryRose
                                : AppColors.borderDark,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Next / Get Started button ─────────────────────────
                    GestureDetector(
                      onTap: _goToNext,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRose,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryRose.withValues(alpha: 0.30),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentIndex == _slides.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textLight,
                              ),
                            ),
                            if (_currentIndex < _slides.length - 1) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Individual Slide Widget ────────────────────────────────────────────────

class _OnboardingSlide extends StatefulWidget {
  final _SlideData data;
  const _OnboardingSlide({required this.data});

  @override
  State<_OnboardingSlide> createState() => _OnboardingSlideState();
}

class _OnboardingSlideState extends State<_OnboardingSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: SlideTransition(
            position: _slide,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon circle
            Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.data.iconBgColor,
                border: Border.all(
                  color: widget.data.iconBorderColor,
                  width: 1.5,
                ),
              ),
              child: Icon(
                widget.data.icon,
                size: 64,
                color: widget.data.iconColor,
              ),
            ),
            const SizedBox(height: 36),

            // Title
            Text(
              widget.data.title,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              widget.data.description,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: AppColors.textGrey,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
