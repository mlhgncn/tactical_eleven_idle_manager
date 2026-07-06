import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/game_provider.dart';
import '../services/auth_repository.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';

class AuthScreen extends StatefulWidget {
  AuthScreen({super.key, AuthRepository? authRepository}) : _authRepository = authRepository ?? AuthService();

  final AuthRepository _authRepository;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true;

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'auth.email_required'.tr();
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'auth.email_invalid'.tr();
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'auth.password_required'.tr();
    }
    if (value.length < 6) {
      return 'auth.password_short'.tr();
    }
    return null;
  }

  Future<void> _submit() async {
    print('[AUTH] _submit called, validating form');
    if (!(_formKey.currentState?.validate() ?? false)) {
      print('[AUTH] Form validation failed');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    print('[AUTH] Form is valid, setting loading state');
    setState(() => _isLoading = true);

    try {
      print('[AUTH] Starting auth flow. Mode: ${_isLoginMode ? 'login' : 'signup'}');
      final response = _isLoginMode
          ? await widget._authRepository.signIn(email, password)
          : await widget._authRepository.signUp(email, password);

      print('[AUTH] Got response. User: ${response.user}, Session: ${response.session}');
      
      if (response.user == null) {
        print('[AUTH] User is null, showing error');
        _showSnackbar('auth.verification_failed'.tr());
        return;
      }

      final isVerified = response.session?.user.emailConfirmedAt != null;
      print('[AUTH] isVerified: $isVerified, emailConfirmedAt: ${response.session?.user.emailConfirmedAt}');
      
      if (!_isLoginMode && response.session == null) {
        print('[AUTH] No session on signup, navigating to email verification');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/email-verification');
        return;
      }

      if (response.session != null && !isVerified) {
        print('[AUTH] Session exists but not verified, navigating to email verification');
        await widget._authRepository.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/email-verification');
        return;
      }

      print('[AUTH] About to refresh game state');
      await context.read<GameProvider>().refreshGameState();
        try {
          if (!_isLoginMode) {
            AnalyticsService.instance.logEvent('register');
          }
        } catch (_) {}
      print('[AUTH] Game state refreshed');
      
      if (!mounted) {
        print('[AUTH] Not mounted after refresh, returning');
        return;
      }
      
      final nextRoute = context.read<GameProvider>().activeClub == null ? '/setup-club' : '/root';
      print('[AUTH] Navigating to: $nextRoute');
      Navigator.of(context).pushReplacementNamed(nextRoute);
      print('[AUTH] Navigation complete');
    } on AuthException catch (error) {
      print('[AUTH] AuthException: ${error.message}');
      _showSnackbar(error.message);
    } catch (e) {
      print('[AUTH] Exception: $e');
      _showSnackbar('auth.generic_error'.tr(namedArgs: {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLoginMode ? 'auth.login'.tr() : 'auth.signup'.tr(),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'auth.subtitle'.tr(),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: InputDecoration(
                          labelText: 'auth.email'.tr(),
                          prefixIcon: const Icon(Icons.email_outlined),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'auth.password'.tr(),
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(_isLoginMode ? 'auth.login'.tr() : 'auth.signup'.tr()),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() => _isLoginMode = !_isLoginMode);
                              },
                        child: Text(
                          _isLoginMode ? 'auth.no_account'.tr() : 'auth.have_account'.tr(),
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
    );
  }
}
