import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';

class AdminClubListScreen extends StatefulWidget {
  const AdminClubListScreen({super.key});

  @override
  State<AdminClubListScreen> createState() => _AdminClubListScreenState();
}

class _AdminClubListScreenState extends State<AdminClubListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _clubs = [];

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
      _clubs = await provider.repo.adminListClubs();
    } catch (e) {
      _clubs = [];
      _error = 'Kulüpler yüklenemedi: ${e.toString().replaceAll('Exception: ', '')}';
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
      appBar: AppBar(title: const Text('Kulüpler')),
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
                : _clubs.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 80),
                            child: Center(child: Text('Kulüp bulunamadı')),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _clubs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final c = _clubs[index];
                          return Card(
                            child: ListTile(
                              title: Text(c['name'] ?? 'Bilinmiyor'),
                              subtitle: Text('Bütçe: ${c['budget'] ?? 0} GP'),
                              trailing: Text(_formatDate(c['created_at'])),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
