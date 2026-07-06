import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/game_provider.dart';

class AdminClubListScreen extends StatefulWidget {
  const AdminClubListScreen({super.key});

  @override
  State<AdminClubListScreen> createState() => _AdminClubListScreenState();
}

class _AdminClubListScreenState extends State<AdminClubListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _clubs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<GameProvider>();
    try {
      _clubs = await provider.repo.adminListClubs();
    } catch (e) {
      _clubs = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kulüpler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _clubs.isEmpty
              ? const Center(child: Text('Kulüp bulunamadı'))
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
                        trailing: Text(c['created_at'] ?? ''),
                      ),
                    );
                  },
                ),
    );
  }
}
