import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/game_provider.dart';
import '../services/auth_repository.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../theme/app_assets.dart';
import '../widgets/themed_button.dart';

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
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true;

  // Supabase persists sessions to local storage by default, so a returning
  // user already has a valid currentUserId the moment this screen builds.
  // Without this check every cold start forced a fresh login - unacceptable
  // for an idle manager game where players expect to reopen straight into
  // their club.
  bool _checkingExistingSession = true;

  @override
  void initState() {
    super.initState();
    _tryResumeSession();
  }

  Future<void> _tryResumeSession() async {
    if (widget._authRepository.currentUserId == null) {
      setState(() => _checkingExistingSession = false);
      return;
    }
    await _enterApp();
    if (mounted) setState(() => _checkingExistingSession = false);
  }

  /// Loads game state for the already-authenticated user and navigates to
  /// the appropriate next screen. Shared by the resumed-session path and by
  /// a fresh sign in/sign up.
  Future<void> _enterApp() async {
    try {
      await context.read<GameProvider>().refreshGameState();
    } catch (e) {
      print('[AUTH] refreshGameState failed while entering app: $e');
      if (mounted) {
        _showSnackbar('auth.generic_error'.tr(namedArgs: {'error': e.toString()}));
      }
      return;
    }

    if (!mounted) return;
    final gameProvider = context.read<GameProvider>();
    final hasClub = gameProvider.activeClub != null;
    final navigator = Navigator.of(context);
    // OSM-style: no offline rewards. Matches and income only happen on the
    // server-side schedule (auto_resolve_matches cron), whether or not
    // anyone was online to see them - reopening the app just shows whatever
    // already happened.
    navigator.pushReplacementNamed(hasClub ? '/root' : '/setup-club');
  }

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

  String? _validateUsername(String? value) {
    if (_isLoginMode) return null;
    if (value == null || value.trim().isEmpty) {
      return 'auth.username_required'.tr();
    }
    if (value.trim().length < 3) {
      return 'auth.username_short'.tr();
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
    final username = _usernameController.text.trim();
    print('[AUTH] Form is valid, setting loading state');
    setState(() => _isLoading = true);

    try {
      print('[AUTH] Starting auth flow. Mode: ${_isLoginMode ? 'login' : 'signup'}');
      final response = _isLoginMode
          ? await widget._authRepository.signIn(email, password)
          : await widget._authRepository.signUp(email, password, username: username);

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

      try {
        if (!_isLoginMode) {
          AnalyticsService.instance.logEvent('register');
        }
      } catch (_) {}

      print('[AUTH] About to enter app');
      await _enterApp();
      print('[AUTH] Enter app complete');
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
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingExistingSession) {
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(AppAssets.bgStadiumNight, fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.25)),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.bgStadiumNight, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoginMode ? 'auth.login'.tr() : 'auth.signup'.tr(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'auth.subtitle'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 28),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (!_isLoginMode) ...[
                            TextFormField(
                              controller: _usernameController,
                              autocorrect: false,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'auth.username'.tr(),
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.35),
                              ),
                              validator: _validateUsername,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'auth.email'.tr(),
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.email_outlined, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.35),
                            ),
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'auth.password'.tr(),
                              labelStyle: const TextStyle(color: Colors.white70),
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                              filled: true,
                              fillColor: Colors.black.withValues(alpha: 0.35),
                            ),
                            validator: _validatePassword,
                          ),
                          const SizedBox(height: 24),
                          GoldButton(
                            onPressed: _isLoading ? null : _submit,
                            isLoading: _isLoading,
                            label: _isLoginMode ? 'auth.login'.tr() : 'auth.signup'.tr(),
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
                              style: const TextStyle(color: Colors.white),
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
        ],
      ),
    );
  }
}
