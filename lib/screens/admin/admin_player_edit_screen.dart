import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';

class AdminPlayerEditScreen extends StatefulWidget {
  const AdminPlayerEditScreen({super.key});

  @override
  State<AdminPlayerEditScreen> createState() => _AdminPlayerEditScreenState();
}

class _AdminPlayerEditScreenState extends State<AdminPlayerEditScreen> {
  final _playerIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _positionController = TextEditingController();
  final _ageController = TextEditingController();
  final _currentAbilityController = TextEditingController();
  final _potentialAbilityController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _playerIdController.dispose();
    _nameController.dispose();
    _positionController.dispose();
    _ageController.dispose();
    _currentAbilityController.dispose();
    _potentialAbilityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    final provider = context.read<GameProvider>();
    try {
      await provider.repo.adminUpdatePlayer(
        playerId: _playerIdController.text.trim(),
        name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
        position: _positionController.text.trim().isEmpty ? null : _positionController.text.trim(),
        age: _ageController.text.trim().isEmpty ? null : int.parse(_ageController.text.trim()),
        currentAbility: _currentAbilityController.text.trim().isEmpty ? null : int.parse(_currentAbilityController.text.trim()),
        potentialAbility: _potentialAbilityController.text.trim().isEmpty ? null : int.parse(_potentialAbilityController.text.trim()),
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oyuncu güncellendi')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oyuncu Düzenle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _playerIdController, decoration: const InputDecoration(labelText: 'Oyuncu ID')),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'İsim')),
            TextField(controller: _positionController, decoration: const InputDecoration(labelText: 'Pozisyon')),
            TextField(controller: _ageController, decoration: const InputDecoration(labelText: 'Yaş'), keyboardType: TextInputType.number),
            TextField(controller: _currentAbilityController, decoration: const InputDecoration(labelText: 'Mevcut Yeteneği'), keyboardType: TextInputType.number),
            TextField(controller: _potentialAbilityController, decoration: const InputDecoration(labelText: 'Potansiyel Yeteneği'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _save,
                child: _loading ? const CircularProgressIndicator() : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
