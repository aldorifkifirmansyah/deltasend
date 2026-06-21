import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../utils/app_assets.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();

  bool _showValidation = false;
  bool _emailSent = false;

  static const Color _primaryBlue = Color(0xFF133D87);
  static const Color _titleBlue = Color(0xFF608BC0);
  static const Color _textGrey = Color(0xFF6F7A8A);

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
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

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _showValidation = true;
    });

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) return;

    final auth = context.read<AuthViewModel>();

    final success = await auth.sendPasswordResetEmail(_emailCtrl.text.trim());

    if (!mounted) return;

    if (success) {
      setState(() {
        _emailSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link reset password berhasil dikirim.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Gagal mengirim reset password.'),
        ),
      );
    }
  }

  void _backToLogin() {
    Navigator.of(context).pop();
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
                    const SizedBox(height: 58),

                    SvgPicture.asset(AppAssets.logo, width: 205),

                    const SizedBox(height: 58),

                    _GradientBorderCard(
                      child: Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Forgot Password',
                                style: GoogleFonts.getFont(
                                  'ADLaM Display',
                                  fontSize: 29,
                                  color: _titleBlue,
                                  height: 1.1,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Text(
                                _emailSent
                                    ? 'Check your email and follow the instructions to reset your password.'
                                    : 'Enter the email associated with your account and we will send you a reset link.',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: _titleBlue,
                                  fontWeight: FontWeight.w400,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 28),

                              if (_emailSent)
                                _SuccessState(email: _emailCtrl.text.trim())
                              else
                                _AuthTextField(
                                  controller: _emailCtrl,
                                  hintText: 'Email',
                                  prefixIcon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  validator: _validateEmail,
                                  showValidation: _showValidation,
                                  onFieldSubmitted: (_) {
                                    if (!auth.isLoading) {
                                      _sendResetEmail();
                                    }
                                  },
                                ),

                              const SizedBox(height: 24),

                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading
                                      ? null
                                      : _emailSent
                                      ? _backToLogin
                                      : _sendResetEmail,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryBlue,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: _primaryBlue
                                        .withValues(alpha: 0.65),
                                    elevation: 4,
                                    shadowColor: Colors.black.withValues(
                                      alpha: 0.20,
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
                                          _emailSent
                                              ? 'BACK TO SIGN IN'
                                              : 'SEND RESET LINK',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                ),
                              ),

                              if (!_emailSent) ...[
                                const SizedBox(height: 14),

                                Center(
                                  child: TextButton.icon(
                                    onPressed: auth.isLoading
                                        ? null
                                        : _backToLogin,
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      size: 18,
                                      color: _primaryBlue,
                                    ),
                                    label: Text(
                                      'Back to Sign in',
                                      style: GoogleFonts.inter(
                                        color: _primaryBlue,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      'Make sure you can access the email address registered to your account.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: _textGrey,
                        fontSize: 12,
                        height: 1.4,
                      ),
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

class _SuccessState extends StatelessWidget {
  final String email;

  const _SuccessState({required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF608BC0).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF608BC0).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Color(0xFF133D87),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            'Email sent',
            style: GoogleFonts.inter(
              color: const Color(0xFF133D87),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            email,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFF6F7A8A),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
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
