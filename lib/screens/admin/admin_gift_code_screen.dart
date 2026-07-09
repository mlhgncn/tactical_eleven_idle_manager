import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';

class AdminGiftCodeScreen extends StatefulWidget {
  const AdminGiftCodeScreen({super.key});

  @override
  State<AdminGiftCodeScreen> createState() => _AdminGiftCodeScreenState();
}

class _AdminGiftCodeScreenState extends State<AdminGiftCodeScreen> {
  final _codeController = TextEditingController();
  final _amountController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    final provider = context.read<GameProvider>();
    try {
      await provider.repo.adminCreateGiftCode(code: _codeController.text.trim(), amount: int.parse(_amountController.text.trim()));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hediye kodu oluşturuldu')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.toString().replaceAll('Exception: ', '')}')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hediye Kodu Oluştur')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _codeController, decoration: const InputDecoration(labelText: 'Kod')),
            TextField(controller: _amountController, decoration: const InputDecoration(labelText: 'Miktar'), keyboardType: TextInputType.number),
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
