import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'role_selection_screen.dart';
import 'role_home.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isPasswordVisible = false;
  bool _showValidation = false;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textGrey = Color(0xFF6F7A8A);
  static const Color _hintGrey = Color(0xFFA0AAB8);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _goHome() {
    final String role = context.read<AuthViewModel>().currentUser?.role ?? '';

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => homeForRole(role)));
  }

  void _showError() {
    final String? message = context.read<AuthViewModel>().errorMessage;

    if (message == null || message.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _showValidation = true;
    });

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    final AuthViewModel auth = context.read<AuthViewModel>();

    final bool success = await auth.signInWithEmailPassword(
      _emailCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;

    if (success) {
      _goHome();
    } else {
      _showError();
    }
  }

  Future<void> _loginGoogle() async {
    FocusScope.of(context).unfocus();

    final AuthViewModel auth = context.read<AuthViewModel>();
    final bool success = await auth.signInWithGoogle();

    if (!mounted) return;

    if (success) {
      _goHome();
    } else if (auth.errorMessage != null) {
      _showError();
    }
  }

  void _goToRegisterRole() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
  }

  void _goToForgotPassword() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
  }

  String? _validateEmail(String? value) {
    final String email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email wajib diisi';
    }

    final RegExp emailPattern = RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Format email tidak valid';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }

    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AuthViewModel auth = context.watch<AuthViewModel>();

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            AppAssets.loginBackground,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return const ColoredBox(color: Color(0xFFF7F9FC));
            },
          ),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).top -
                      MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 52),
                    SvgPicture.asset(AppAssets.logo, width: 205),
                    const SizedBox(height: 44),
                    _GradientBorderCard(
                      child: Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 30, 24, 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sign in',
                                style: GoogleFonts.getFont(
                                  'ADLaM Display',
                                  fontSize: 31,
                                  color: _titleBlue,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Access your account to create, track,\n'
                                'and manage your deliveries.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: _titleBlue,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 26),
                              _AuthTextField(
                                controller: _emailCtrl,
                                hintText: 'Email',
                                prefixIcon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _validateEmail,
                                showValidation: _showValidation,
                              ),
                              const SizedBox(height: 14),
                              _AuthTextField(
                                controller: _passwordCtrl,
                                hintText: 'Password',
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: !_isPasswordVisible,
                                suffixIcon: _isPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                onSuffixTap: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                                textInputAction: TextInputAction.done,
                                validator: _validatePassword,
                                showValidation: _showValidation,
                                onFieldSubmitted: (_) {
                                  if (!auth.isLoading) {
                                    _login();
                                  }
                                },
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: auth.isLoading
                                    ? null
                                    : _goToForgotPassword,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 34),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.inter(
                                    color: _primaryBlue,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryBlue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: _primaryBlue
                                        .withValues(alpha: 0.65),
                                    elevation: 4,
                                    shadowColor: Colors.black.withValues(
                                      alpha: 0.22,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.4,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'SIGN IN',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              const _DividerText(text: 'Sign in with'),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : _loginGoogle,
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Color(0xFFE3E8F0),
                                      width: 1.1,
                                    ),
                                    elevation: 3,
                                    shadowColor: Colors.black.withValues(
                                      alpha: 0.16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/images/ic_google.png',
                                        width: 20,
                                        height: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Google Account',
                                        style: GoogleFonts.inter(
                                          color: _hintGrey,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don’t have account? ",
                          style: GoogleFonts.inter(
                            color: _textGrey,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: auth.isLoading ? null : _goToRegisterRole,
                          child: Text(
                            'Sign up',
                            style: GoogleFonts.inter(
                              color: _primaryBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientBorderCard extends StatelessWidget {
  final Widget child;

  const _GradientBorderCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00133D87), Color(0xFF133D87)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF133D87).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(3, 1, 3, 5),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(29),
        ),
        child: child,
      ),
    );
  }
}

class _AuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool showValidation;

  const _AuthTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.showValidation,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixTap,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  State<_AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<_AuthTextField> {
  bool _hasInteracted = false;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      autovalidateMode: widget.showValidation
          ? AutovalidateMode.always
          : AutovalidateMode.disabled,
      builder: (FormFieldState<String> field) {
        final String? errorMessage = field.errorText;
        final bool hasError = errorMessage != null && errorMessage.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasError
                      ? const Color(0xFFD14343)
                      : const Color(0xFFE7EBF2),
                  width: hasError ? 1.2 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 7,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: widget.controller,
                obscureText: widget.obscureText,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onFieldSubmitted,
                onChanged: (value) {
                  field.didChange(value);

                  if (!_hasInteracted) {
                    setState(() {
                      _hasInteracted = true;
                    });
                  }

                  if (_hasInteracted || widget.showValidation) {
                    field.validate();
                  }
                },
                style: GoogleFonts.inter(
                  color: const Color(0xFF374151),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFFA0AAB8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(
                    widget.prefixIcon,
                    color: const Color(0xFF606873),
                    size: 21,
                  ),
                  suffixIcon: widget.suffixIcon == null
                      ? null
                      : IconButton(
                          onPressed: widget.onSuffixTap,
                          icon: Icon(
                            widget.suffixIcon,
                            color: const Color(0xFF9CA3AF),
                            size: 19,
                          ),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: hasError
                  ? Padding(
                      padding: const EdgeInsets.only(top: 7, left: 4, right: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 14,
                            color: Color(0xFFD14343),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              errorMessage,
                              style: GoogleFonts.inter(
                                color: const Color(0xFFD14343),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _DividerText extends StatelessWidget {
  final String text;

  const _DividerText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: const Color(0xFF6F7A8A).withValues(alpha: 0.65),
            thickness: 1,
            endIndent: 14,
          ),
        ),
        Text(
          text,
          style: GoogleFonts.inter(
            color: const Color(0xFF6F7A8A),
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Divider(
            color: const Color(0xFF6F7A8A).withValues(alpha: 0.65),
            thickness: 1,
            indent: 14,
          ),
        ),
      ],
    );
  }
}
