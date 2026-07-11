import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isUpdatingEmail = false;
  bool _isUpdatingPassword = false;
  bool _isUpdatingUsername = false;
  bool _usernamePrefilled = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = _authService.currentUserEmail ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GameProvider>().refreshGameState();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.username_short'.tr())),
      );
      return;
    }

    setState(() => _isUpdatingUsername = true);
    try {
      await context.read<GameProvider>().updateUsername(newUsername);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.usernameUpdated'.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingUsername = false);
    }
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.invalidEmail'.tr())),
      );
      return;
    }

    setState(() => _isUpdatingEmail = true);
    try {
      await _authService.updateEmail(newEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.emailUpdateSent'.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingEmail = false);
    }
  }

  Future<void> _updatePassword() async {
    final newPassword = _passwordController.text;
    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.passwordTooShort'.tr())),
      );
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.passwordsMismatch'.tr())),
      );
      return;
    }

    setState(() => _isUpdatingPassword = true);
    try {
      await _authService.updatePassword(newPassword);
      if (!mounted) return;
      _passwordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.passwordUpdated'.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<GameProvider>().profile;
    final leagueTitles = profile?.leagueTitles ?? 0;

    if (!_usernamePrefilled && profile?.username != null) {
      _usernameController.text = profile!.username!;
      _usernamePrefilled = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text('profile.title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$leagueTitles', style: Theme.of(context).textTheme.headlineMedium),
                          Text('profile.leagueTitlesLabel'.tr(), style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('profile.usernameTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _usernameController,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: 'auth.username'.tr()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingUsername ? null : _updateUsername,
                      child: _isUpdatingUsername
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('profile.updateUsernameButton'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('profile.emailAddressTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'auth.email'.tr()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingEmail ? null : _updateEmail,
                      child: _isUpdatingEmail
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('profile.updateEmailButton'.tr()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('profile.changePasswordTitle'.tr(), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'profile.newPasswordLabel'.tr()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'profile.confirmNewPasswordLabel'.tr()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingPassword ? null : _updatePassword,
                      child: _isUpdatingPassword
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('profile.updatePasswordButton'.tr()),
                    ),
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
