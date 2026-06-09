import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_notification_modal.dart';
import '../../../core/providers/user_provider.dart';
import '../services/auth_service.dart';
import '../widgets/forgot_password_dialog.dart';
import '../../splash/screens/splash_screen.dart';

class LoginScreen extends StatefulWidget {
  final bool animate;
  const LoginScreen({super.key, this.animate = true});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  // Entry animation
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    if (widget.animate) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _entryController.forward();
      });
    } else {
      _entryController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      CustomNotificationModal.show(
        context: context,
        title: "Login Failed",
        message: "Please enter both Email/Username and Password.",
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userProvider = context.read<UserProvider>();
      final payload = await _authService.login(identifier, password);
      userProvider.setUser(payload['user'], payload['userData']);

      final userData = payload['userData'] as Map<String, dynamic>;
      final bool requiresPasswordChange =
          userData['requiresPasswordChange'] == true;

      String targetRoute;
      Map<String, dynamic>? routeArgs;

      if (requiresPasswordChange) {
        targetRoute = '/force-password-change';
        routeArgs = {
          'email': payload['user'].email ?? '',
          'userData': userData
        };
      } else {
        targetRoute = '/dashboard';
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const SplashScreen(),
          settings: RouteSettings(
            arguments: {
              'authFuture': Future.value({
                'route': targetRoute,
                'args': routeArgs,
              }),
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final errorMsg = e.toString().replaceFirst('Exception: ', '');
      CustomNotificationModal.show(
        context: context,
        title: "Authentication Error",
        message: errorMsg,
        isSuccess: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: AnimatedBuilder(
        animation: _entryController,
        builder: (context, child) => Opacity(
          opacity: _fadeAnim.value,
          child: SlideTransition(
            position: _slideAnim,
            child: child,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ── Top section: icon + titles ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                      child: Column(
                        children: [
                          // Shield icon
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surfaceDark,
                              border: Border.all(
                                color: AppColors.borderDark,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRose
                                      .withValues(alpha: 0.15),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.verified_user_rounded,
                              size: 64,
                              color: AppColors.primaryRose,
                            ),
                          ),
                          const SizedBox(height: 24),

                          Text(
                            'Welcome Back',
                            style: GoogleFonts.inter(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textLight,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to monitor your farm with VerdeSense',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textGrey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Form section ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email label
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'EMAIL ADDRESS',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                          // Email input (pill style)
                          _PillTextField(
                            controller: _identifierController,
                            hintText: 'farmer@verdesense.com',
                            prefixIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            onSubmitted: (_) => _handleLogin(),
                          ),
                          const SizedBox(height: 20),

                          // Password label
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'PASSWORD',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                          // Password input (pill style)
                          _PillTextField(
                            controller: _passwordController,
                            hintText: '••••••••',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: !_isPasswordVisible,
                            onSubmitted: (_) => _handleLogin(),
                            suffixWidget: IconButton(
                              onPressed: () => setState(
                                  () => _isPasswordVisible = !_isPasswordVisible),
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: AppColors.textGrey,
                                size: 20,
                              ),
                            ),
                          ),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () =>
                                  ForgotPasswordDialog.show(context),
                              child: Text(
                                'Forgot Password?',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryRose,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sign In button (pill style)
                          GestureDetector(
                            onTap: _isLoading ? null : _handleLogin,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              decoration: BoxDecoration(
                                color: _isLoading
                                    ? AppColors.primaryRose.withValues(alpha: 0.6)
                                    : AppColors.primaryRose,
                                borderRadius: BorderRadius.circular(50),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryRose
                                        .withValues(alpha: 0.30),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: _isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Bottom: Contact admin link ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textGrey,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Contact admin placeholder
                              CustomNotificationModal.showToast(
                                context: context,
                                title: 'Contact Admin',
                                message:
                                    'Please reach out to your system administrator to create an account.',
                                color: AppColors.primaryRose,
                                icon: Icons.admin_panel_settings_rounded,
                              );
                            },
                            child: Text(
                              'Contact Admin',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pill-style text field ──────────────────────────────────────────────────

class _PillTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffixWidget;

  const _PillTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
    this.suffixWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: AppColors.borderDark,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: AppColors.textLight,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(
            fontSize: 15,
            color: AppColors.textGrey.withValues(alpha: 0.5),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              prefixIcon,
              color: AppColors.textGrey,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: suffixWidget,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}
