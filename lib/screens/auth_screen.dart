import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/auth_repository.dart';
import '../services/auth_service.dart';
import '../theme/app_assets.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/themed_button.dart';

/// App entry gate. A returning session (real or anonymous) resumes silently
/// - no form, straight into the game. A brand-new session sees a welcome
/// screen offering a real choice between creating/signing into an account
/// and continuing as a guest (anonymous sign-in), never a form forced in
/// front of the game - Apple guideline 5.1.1 requires non-account-based
/// features to be reachable without forcing registration, and "guest" is
/// offered right alongside "account" here to satisfy that while still
/// letting players opt into a permanent account from the very start.
class AuthScreen extends StatefulWidget {
  AuthScreen({super.key, AuthRepository? authRepository}) : _authRepository = authRepository ?? AuthService();

  final AuthRepository _authRepository;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _checkingExistingSession = true;
  String? _error;

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

  Future<void> _continueAsGuest() async {
    setState(() {
      _checkingExistingSession = true;
      _error = null;
    });
    try {
      await widget._authRepository.signInAnonymously();
      await _enterApp();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _checkingExistingSession = false;
      });
    }
  }

  /// Loads game state for the already-authenticated user and navigates to
  /// the appropriate next screen. Shared by the resumed-session path, the
  /// guest path, and a fresh sign in/sign up (via _AccountFormSheet).
  Future<void> _enterApp() async {
    try {
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

  Future<void> _openAccountForm() async {
    final entered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AccountFormScreen(authRepository: widget._authRepository)),
    );
    if (entered == true) {
      await _enterApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(AppAssets.bgStadiumNight, fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.25)),
          if (_checkingExistingSession)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _error = null),
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              ),
            )
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'app.title'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'auth.subtitle'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 40),
                    GoldButton(
                      onPressed: _openAccountForm,
                      label: 'auth.createOrSignIn'.tr(),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _continueAsGuest,
                      child: Text('auth.continueAsGuest'.tr()),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'auth.guestNotice'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
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

/// Reached from the welcome screen's "Create account / Sign in" button (a
/// brand-new session, no user yet) - lets the player either sign up for a
/// fresh real account or sign into an existing one, then pops back to
/// AuthScreen with `true` so it can finish entering the game. Distinct from
/// LoginScreen (Settings/Profile-only, login only, always has an existing
/// anonymous session in the background) - this one offers signUp too and
/// has no anonymous session yet when it opens.
class AccountFormScreen extends StatefulWidget {
  AccountFormScreen({super.key, AuthRepository? authRepository}) : _authRepository = authRepository ?? AuthService();

  final AuthRepository _authRepository;

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _referralCodeController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true;

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

  String? _validateUsername(String? value) {
    if (_isLoginMode) return null;
    if (value == null || value.trim().isEmpty) return 'auth.username_required'.tr();
    if (value.trim().length < 3) return 'auth.username_short'.tr();
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();
    setState(() => _isLoading = true);

    try {
      final referralCode = _referralCodeController.text.trim();
      final response = _isLoginMode
          ? await widget._authRepository.signIn(email, password)
          : await widget._authRepository.signUp(email, password, username: username, referralCode: referralCode);

      if (response.user == null) {
        _showSnackbar('auth.verification_failed'.tr());
        return;
      }

      final isVerified = response.session?.user.emailConfirmedAt != null;

      if (!_isLoginMode && response.session == null) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/email-verification');
        return;
      }

      if (response.session != null && !isVerified) {
        await widget._authRepository.signOut();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/email-verification');
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    _usernameController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text('auth.subtitle'.tr(), style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70)),
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
                          if (!_isLoginMode) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _referralCodeController,
                              autocorrect: false,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'auth.referralCode'.tr(),
                                labelStyle: const TextStyle(color: Colors.white70),
                                prefixIcon: const Icon(Icons.card_giftcard, color: Colors.white70),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.35),
                              ),
                            ),
                          ],
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
