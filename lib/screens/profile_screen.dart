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
  bool _isUpdatingEmail = false;
  bool _isUpdatingPassword = false;

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
    super.dispose();
  }

  Future<void> _updateEmail() async {
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty || !newEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir e-posta adresi girin')),
      );
      return;
    }

    setState(() => _isUpdatingEmail = true);
    try {
      await _authService.updateEmail(newEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Onay için yeni adresine bir e-posta gönderildi.')),
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
        const SnackBar(content: Text('Şifre en az 6 karakter olmalı')),
      );
      return;
    }
    if (newPassword != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şifreler eşleşmiyor')),
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
        const SnackBar(content: Text('Şifre başarıyla güncellendi.')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
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
                          const Text('Lig Şampiyonluğu', style: TextStyle(color: Colors.grey)),
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
                  Text('E-posta Adresi', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-posta'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingEmail ? null : _updateEmail,
                      child: _isUpdatingEmail
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('E-postayı Güncelle'),
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
                  Text('Şifre Değiştir', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Yeni Şifre (Tekrar)'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingPassword ? null : _updatePassword,
                      child: _isUpdatingPassword
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Şifreyi Güncelle'),
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
