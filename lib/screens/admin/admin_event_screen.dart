import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';

class AdminEventScreen extends StatefulWidget {
  const AdminEventScreen({super.key});

  @override
  State<AdminEventScreen> createState() => _AdminEventScreenState();
}

class _AdminEventScreenState extends State<AdminEventScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    final provider = context.read<GameProvider>();
    try {
      await provider.repo.adminCreateEvent(title: _titleController.text.trim(), body: _bodyController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik oluşturuldu')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Etkinlik Oluştur')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Başlık')),
            TextField(controller: _bodyController, decoration: const InputDecoration(labelText: 'İçerik')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _loading ? null : _create, child: const Text('Oluştur')),
            ),
          ],
        ),
      ),
    );
  }
}
