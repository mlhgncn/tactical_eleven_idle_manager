import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/auth_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_assets.dart';
import '../widgets/app_snackbar.dart';

/// App entry gate. Never shows a login/signup form - Apple guideline 5.1.1
/// requires non-account-based features to be reachable without forcing
/// registration, so this screen silently resumes an existing session or
/// starts a brand new anonymous one, then drops straight into the game.
/// Players who want a real email/password account (e.g. to keep their club
/// across devices) get that from Settings > Profile ("Save my account" /
/// "Sign in with another account"), never as a gate in front of the game.
class AuthScreen extends StatefulWidget {
  AuthScreen({super.key, AuthRepository? authRepository}) : _authRepository = authRepository ?? AuthService();

  final AuthRepository _authRepository;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _enterApp();
  }

  Future<void> _enterApp() async {
    try {
      if (widget._authRepository.currentUserId == null) {
        await widget._authRepository.signInAnonymously();
      }
      await context.read<GameProvider>().refreshGameState();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      return;
    }

    if (!mounted) return;
    final gameProvider = context.read<GameProvider>();
    final hasClub = gameProvider.activeClub != null;
    final hasMultipleClubs = gameProvider.myClubs.length > 1;
    final navigator = Navigator.of(context);
    // OSM-style: no offline rewards. Matches and income only happen on the
    // server-side schedule (auto_resolve_matches cron), whether or not
    // anyone was online to see them - reopening the app just shows whatever
    // already happened. A user managing more than one league lands on the
    // league picker first instead of jumping straight into whichever club
    // happened to load as "active".
    final destination = !hasClub ? '/setup-club' : (hasMultipleClubs ? '/league-selector' : '/root');
    navigator.pushReplacementNamed(destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.bgStadiumNight, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          Center(
            child: _error == null
                ? const CircularProgressIndicator(color: Colors.white)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: Colors.white),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _error = null);
                            _enterApp();
                          },
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Explicit "I already have an account" path, reached only from Settings/
/// Profile - not part of the app-launch gate. Lets a returning player (new
/// device, reinstall) sign back into a previously claimed account, or a
/// current anonymous player sign into a different, pre-existing account.
class LoginScreen extends StatefulWidget {
  LoginScreen({super.key, AuthRepository? authRepository}) : _authRepository = authRepository ?? AuthService();

  final AuthRepository _authRepository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'auth.email_required'.tr();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) return 'auth.email_invalid'.tr();
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'auth.password_required'.tr();
    if (value.length < 6) return 'auth.password_short'.tr();
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final response = await widget._authRepository.signIn(_emailController.text.trim(), _passwordController.text);
      if (response.user == null) {
        _showSnackbar('auth.verification_failed'.tr());
        return;
      }
      if (!mounted) return;
      await context.read<GameProvider>().refreshGameState();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    } catch (e) {
      _showSnackbar('auth.generic_error'.tr(namedArgs: {'error': e.toString()}));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    AppSnackBar.show(context, message);
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
      appBar: AppBar(title: Text('auth.login'.tr())),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('auth.loginExistingAccountNotice'.tr(), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: 'auth.email'.tr(), prefixIcon: const Icon(Icons.email_outlined)),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'auth.password'.tr(), prefixIcon: const Icon(Icons.lock_outline)),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('auth.login'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
