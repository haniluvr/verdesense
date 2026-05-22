import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/providers/user_provider.dart';

/// A three-step password update dialog:
///   Step 1 — Identity (re-authenticate with current password)
///   Step 2 — Credentials (new password + confirm)
///   Step 3 — Secured (success confirmation)
///
/// Usage: `await UpdatePasswordDialog.show(context);`
class UpdatePasswordDialog {
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _UpdatePasswordDialogWidget(),
    );
  }
}

enum _Step { reauth, newPassword, finalized }

class _UpdatePasswordDialogWidget extends StatefulWidget {
  const _UpdatePasswordDialogWidget();

  @override
  State<_UpdatePasswordDialogWidget> createState() =>
      _UpdatePasswordDialogWidgetState();
}

class _UpdatePasswordDialogWidgetState extends State<_UpdatePasswordDialogWidget>
    with SingleTickerProviderStateMixin {
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _currentVisible = false;
  bool _newVisible = false;
  bool _confirmVisible = false;
  String? _errorText;
  _Step _step = _Step.reauth;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _transitionTo(_Step next) {
    _animCtrl.reverse().then((_) {
      if (mounted) {
        setState(() {
          _step = next;
          _errorText = null;
        });
        _animCtrl.forward();
      }
    });
  }

  // ── Step 1: Re-authenticate ───────────────────────────────────────────────
  Future<void> _reauth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Session expired. Please log in again.');
      }

      final email = context.read<UserProvider>().email;
      
      // Re-authenticate by signing in again
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _currentPasswordCtrl.text,
      );

      _transitionTo(_Step.newPassword);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = _mapAuthError(e.code);
      });
    } catch (e) {
      setState(() {
        _errorText = 'Authentication failed. Please check your credentials.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Step 2: Update Password ───────────────────────────────────────────────
  Future<void> _updatePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Session expired. Please log in again.');
      }

      await user.updatePassword(_newPasswordCtrl.text);

      _transitionTo(_Step.finalized);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorText = _mapAuthError(e.code);
      });
    } catch (e) {
      setState(() {
        _errorText = 'Failed to update password. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect current password.';
      case 'requires-recent-login':
        return 'For security, please log out and back in before changing your password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'weak-password':
        return 'The new password is too weak.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Container(
            width: 460,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F2E) : cs.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.06),
                  blurRadius: 20,
                ),
              ],
            ),
            child: switch (_step) {
              _Step.reauth => _buildReauthView(cs),
              _Step.newPassword => _buildNewPasswordView(cs),
              _Step.finalized => _buildFinalizedView(cs),
            },
          ),
        ),
      ),
    );
  }

  // ── Progress indicator strip ──────────────────────────────────────────────
  Widget _buildStepStrip(ColorScheme cs) {
    final labels = ['Identity', 'Credentials', 'Secured'];
    int currentIndex = 0;
    if (_step == _Step.newPassword) currentIndex = 1;
    if (_step == _Step.finalized) currentIndex = 2;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (index) {
          if (index.isEven) {
            final i = index ~/ 2;
            final active = i == currentIndex;
            final done = i < currentIndex;
            final color = done || active
                ? AppColors.primaryBlue
                : cs.onSurfaceVariant.withValues(alpha: 0.25);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppColors.primaryBlue
                        : active
                            ? AppColors.primaryBlue.withValues(alpha: 0.15)
                            : cs.onSurfaceVariant.withValues(alpha: 0.1),
                    border: Border.all(
                      color: color,
                      width: active ? 2 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded,
                            size: 13, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: active
                                  ? AppColors.primaryBlue
                                  : cs.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active
                        ? AppColors.primaryBlue
                        : cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ],
            );
          } else {
            final i = index ~/ 2;
            final done = i < currentIndex;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.primaryBlue
                        : cs.onSurfaceVariant.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            );
          }
        }),
      ),
    );
  }

  // ── Step 1 View ───────────────────────────────────────────────────────────
  Widget _buildReauthView(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepStrip(cs),
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: AppColors.primaryBlue, size: 28),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Verify Your Identity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'For security, please confirm your current password before creating a new one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _currentPasswordCtrl,
              obscureText: !_currentVisible,
              autofocus: true,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline, color: cs.onSurfaceVariant),
                suffixIcon: IconButton(
                  icon: Icon(
                    _currentVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _currentVisible = !_currentVisible),
                ),
                errorText: _errorText,
              ),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Please enter your current password.'
                  : null,
              onFieldSubmitted: (_) => _reauth(),
            ),
            const SizedBox(height: 28),
            _ActionButton(
              label: 'Verify & Continue',
              isLoading: _isLoading,
              onPressed: _reauth,
            ),
            const SizedBox(height: 12),
            _CancelButton(onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }

  // ── Step 2 View ───────────────────────────────────────────────────────────
  Widget _buildNewPasswordView(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStepStrip(cs),
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.primaryBlue, size: 28),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create New Password',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose a strong password that you haven\'t used before.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _newPasswordCtrl,
              obscureText: !_newVisible,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.vpn_key_outlined, color: cs.onSurfaceVariant),
                suffixIcon: IconButton(
                  icon: Icon(
                    _newVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _newVisible = !_newVisible),
                ),
                helperText: 'Min. 8 characters with a number and special char.',
                helperStyle: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required.';
                if (v.length < 8) return 'Password must be at least 8 characters.';
                if (!RegExp(r'[0-9]').hasMatch(v)) return 'Must contain a number.';
                if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(v)) return 'Must contain a special character.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordCtrl,
              obscureText: !_confirmVisible,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.check_circle_outline, color: cs.onSurfaceVariant),
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _confirmVisible = !_confirmVisible),
                ),
                errorText: _errorText,
              ),
              validator: (v) {
                if (v != _newPasswordCtrl.text) return 'Passwords do not match.';
                return null;
              },
              onFieldSubmitted: (_) => _updatePassword(),
            ),
            const SizedBox(height: 32),
            _ActionButton(
              label: 'Update Password',
              isLoading: _isLoading,
              onPressed: _updatePassword,
            ),
            const SizedBox(height: 12),
            _CancelButton(onPressed: () => _transitionTo(_Step.reauth), label: 'Back'),
          ],
        ),
      ),
    );
  }

  // ── Step 3 View ───────────────────────────────────────────────────────────
  Widget _buildFinalizedView(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepStrip(cs),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.statusSafe.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.statusSafe,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Password Secured!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.statusSafe,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your account password has been successfully updated. Please use your new credentials for future sign-ins.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helper widgets ─────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryBlue.withValues(alpha: 0.4),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _CancelButton({
    required this.onPressed,
    this.label = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
