import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/premium_button.dart';
import '../domain/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorText = null);

    await ref
        .read(authControllerProvider.notifier)
        .login(email: _emailController.text.trim(), password: _passwordController.text);

    final state = ref.read(authControllerProvider);
    if (state.hasError && mounted) {
      setState(() => _errorText = describeApiError(state.error!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(gradient: AppColors.goldGradient, shape: BoxShape.circle, boxShadow: [
                        BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 2),
                      ]),
                      child: const Icon(Icons.sports_cricket, size: 36, color: AppColors.navyDark),
                    ),
                    const SizedBox(height: 24),
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
                      child: Text(
                        'CARD CRICKET',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.hero.copyWith(fontSize: 32, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome back, champion',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 32),
                    GlassPanel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.alternate_email, size: 20),
                            ),
                            validator: (value) =>
                                (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, size: 20),
                            ),
                            validator: (value) =>
                                (value == null || value.length < 8) ? 'At least 8 characters' : null,
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 12),
                            Text(_errorText!, style: TextStyle(color: AppColors.danger)),
                          ],
                          const SizedBox(height: 20),
                          PremiumButton(label: 'Log in', onPressed: _submit, isLoading: isLoading),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: Text(
                        "Don't have an account? Register",
                        style: AppTextStyles.body,
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
