import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';
import '../../widgets/app_snackbar.dart';

class AdminPushScreen extends StatefulWidget {
  const AdminPushScreen({super.key});

  @override
  State<AdminPushScreen> createState() => _AdminPushScreenState();
}

class _AdminPushScreenState extends State<AdminPushScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _targetController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _loading = true);
    final provider = context.read<GameProvider>();
    try {
      await provider.repo.adminSendPush(title: _titleController.text.trim(), body: _bodyController.text.trim(), targetUserId: _targetController.text.trim().isEmpty ? null : _targetController.text.trim());
      AppSnackBar.showSuccess(context, 'Bildirim kuyruğa alındı');
    } catch (e) {
      AppSnackBar.showErrorFromException(context, e);
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Bildirim Gönder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Başlık')),
            TextField(controller: _bodyController, decoration: const InputDecoration(labelText: 'İçerik')),
            TextField(controller: _targetController, decoration: const InputDecoration(labelText: 'Hedef Kullanıcı ID (boş = tümüne)')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _loading ? null : _send, child: const Text('Gönder')),
            ),
          ],
        ),
      ),
    );
  }
}
