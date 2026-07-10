import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

class TransferHistoryScreen extends StatefulWidget {
  const TransferHistoryScreen({super.key});

  @override
  State<TransferHistoryScreen> createState() => _TransferHistoryScreenState();
}

class _TransferHistoryScreenState extends State<TransferHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameProvider>().loadTransferHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final clubId = provider.activeClub?.id;
    final entries = provider.transferHistory;

    return Scaffold(
      appBar: AppBar(title: Text('finance.transferHistoryButton'.tr())),
      body: RefreshIndicator(
        onRefresh: () => context.read<GameProvider>().loadTransferHistory(),
        child: provider.isLoadingTransferHistory
            ? const Center(child: CircularProgressIndicator())
            : provider.transferHistoryErrorMessage != null
                ? _ErrorState(message: provider.transferHistoryErrorMessage!)
                : entries.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(child: Text('transferHistory.notFound'.tr())),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isSale = entry.sellerClubId == clubId;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Icon(
                                isSale ? Icons.call_made : Icons.call_received,
                                color: isSale ? AppColors.green : AppColors.blue,
                              ),
                              title: Text(entry.playerName),
                              subtitle: Text(isSale
                                  ? 'transferHistory.soldTo'.tr(namedArgs: {'club': entry.buyerClubName})
                                  : 'transferHistory.boughtFrom'.tr(namedArgs: {'club': entry.sellerClubName})),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('finance.amountGp'.tr(namedArgs: {'value': entry.price.toString()}), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    DateFormat('dd.MM.yyyy').format(entry.completedAt.toLocal()),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}
