import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/force_password_change_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Scale + fade for the whole center content (spring entry)
  late AnimationController _entryController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  // Fade for the bottom loading dots (delayed)
  late AnimationController _dotsController;
  late Animation<double> _dotsFade;

  // Bouncing dots
  late AnimationController _bounce1;
  late AnimationController _bounce2;
  late AnimationController _bounce3;

  // Auth-mode support (passed in via route args)
  bool _isAuthMode = false;
  Future<dynamic>? _authFuture;
  bool _authCompleted = false;
  String _targetRoute = '/onboarding';
  Map<String, dynamic>? _routeArgs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && !_isAuthMode) {
      if (args.containsKey('authFuture')) {
        _isAuthMode = true;
        _authFuture = args['authFuture'];
        _authFuture?.then((result) {
          if (mounted) {
            if (result is Map<String, dynamic> &&
                result.containsKey('route')) {
              _targetRoute = result['route'] as String;
              _routeArgs = result['args'] as Map<String, dynamic>?;
            } else {
              _targetRoute = '/login';
            }
            setState(() => _authCompleted = true);
          }
        }).catchError((error) {
          if (mounted) {
            _targetRoute = '/login';
            setState(() => _authCompleted = true);
          }
        });
      }
      if (!_isAuthMode && args.containsKey('nextRoute')) {
        _targetRoute = args['nextRoute'];
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // Spring entry animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeIn),
    );

    // Dots fade in after delay
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _dotsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dotsController, curve: Curves.easeIn),
    );

    // Bouncing dot controllers
    _bounce1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _bounce2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _bounce2.repeat(reverse: true);
    });

    _bounce3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bounce3.repeat(reverse: true);
    });

    _runSequence();
  }

  void _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    // Play entry spring animation
    _entryController.forward();

    // Show dots after 1 second
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    _dotsController.forward();

    // Wait for either 2.5s total OR auth to complete (if in auth mode)
    if (_isAuthMode) {
      // Minimum display: 2 seconds after entry
      await Future.delayed(const Duration(milliseconds: 2000));
      // Then wait until auth resolves
      while (!_authCompleted && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 2500));
    }
    if (!mounted) return;
    _navigateToTarget();
  }

  void _navigateToTarget() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) {
          switch (_targetRoute) {
            case '/login':
              return const LoginScreen(animate: false);
            case '/dashboard':
              return const DashboardScreen();
            case '/force-password-change':
              return ForcePasswordChangeScreen(
                email: (_routeArgs?['email'] as String?) ?? '',
                userData:
                    (_routeArgs?['userData'] as Map<String, dynamic>?) ?? {},
              );
            case '/onboarding':
            default:
              return const OnboardingScreen();
          }
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _dotsController.dispose();
    _bounce1.dispose();
    _bounce2.dispose();
    _bounce3.dispose();
    super.dispose();
  }

  Widget _buildBouncingDot(AnimationController ctrl) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, -6 * ctrl.value),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryRose,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          // ── Subtle radial glow in background ───────────────────────────────
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryRose.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  radius: 1.0,
                ),
              ),
            ),
          ),

          // ── Center content ──────────────────────────────────────────────────
          Center(
            child: AnimatedBuilder(
              animation: _entryController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Shield icon in glowing circle ─────────────────────────
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceDark,
                      border: Border.all(
                        color: AppColors.borderDark,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRose.withValues(alpha: 0.20),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.verified_user_rounded,
                      size: 80,
                      color: AppColors.primaryRose,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── App name ──────────────────────────────────────────────
                  Text(
                    'VerdeSense',
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── Tagline ───────────────────────────────────────────────
                  Text(
                    'Smart Farm Monitoring',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bouncing dots at bottom ─────────────────────────────────────────
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _dotsFade,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildBouncingDot(_bounce1),
                  const SizedBox(width: 8),
                  _buildBouncingDot(_bounce2),
                  const SizedBox(width: 8),
                  _buildBouncingDot(_bounce3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
