import 'package:flutter/material.dart';

import '../models/offline_simulation_result.dart';

class OfflineReturnScreen extends StatefulWidget {
  final OfflineSimulationResult result;

  const OfflineReturnScreen({super.key, required this.result});

  @override
  State<OfflineReturnScreen> createState() => _OfflineReturnScreenState();
}

class _OfflineReturnScreenState extends State<OfflineReturnScreen> {
  @override
  void initState() {
    super.initState();
    // 3 saniye sonra dismiss et
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  Text(
                    'Hoşgeldin! 👋',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${result.durationString} boyunca offline geçtiniz',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Offline Summary Cards
                  _SummaryCard(
                    icon: '⚽',
                    title: 'Maçlar',
                    value: '${result.matchesSimulated}',
                    subtitle: 'maç oynandı',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  
                  _SummaryCard(
                    icon: '💰',
                    title: 'Gelir',
                    value: '${result.totalIncome ~/ 1000}K',
                    subtitle: 'GP kazandı',
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),
                  
                  if (result.playersImproved > 0)
                    _SummaryCard(
                      icon: '⬆️',
                      title: 'Oyuncu Gelişimi',
                      value: '${result.playersImproved}',
                      subtitle: 'oyuncu gelişti',
                      color: Colors.amber,
                    ),
                  if (result.playersImproved > 0)
                    const SizedBox(height: 12),
                  
                  if (result.transferOffersReceived > 0)
                    _SummaryCard(
                      icon: '📨',
                      title: 'Transfer Teklifleri',
                      value: '${result.transferOffersReceived}',
                      subtitle: 'teklif geldi',
                      color: Colors.orange,
                    ),
                  
                  const SizedBox(height: 32),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.greenAccent, width: 1),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Offline Özeti',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.summary,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Dismiss Button
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Anladım'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'İnbox\'ta detaylı mesajlar bulunabilir',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
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

class _SummaryCard extends StatelessWidget {
  final String icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
