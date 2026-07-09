import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<GameProvider>();
    try {
      _users = await provider.repo.adminListUsers();
    } catch (e) {
      _users = [];
      _error = 'Kullanıcılar yüklenemedi: ${e.toString().replaceAll('Exception: ', '')}';
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatDate(dynamic value) {
    if (value is! String) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return DateFormat('dd.MM.yyyy').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcılar')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    ],
                  )
                : _users.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: Text('Kullanıcı bulunamadı')),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final u = _users[index];
                          return Card(
                            child: ListTile(
                              title: Text(u['full_name'] ?? u['id'] ?? 'Anonim'),
                              subtitle: Text(u['email'] ?? ''),
                              trailing: Text(_formatDate(u['created_at'])),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
