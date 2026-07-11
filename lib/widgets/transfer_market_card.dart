import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/transfer_market_item.dart';

class TransferMarketCard extends StatelessWidget {
  final TransferMarketItem item;
  final String? activeClubId;
  final Future<void> Function(int offerAmount)? onMakeOffer;
  final VoidCallback? onTap;

  const TransferMarketCard({
    super.key,
    required this.item,
    this.activeClubId,
    this.onMakeOffer,
    this.onTap,
  });

  Future<void> _showOfferDialog(BuildContext context) async {
    final controller = TextEditingController(text: item.askingPrice.toString());
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('transferMarket.offerDialogTitle'.tr(namedArgs: {'playerName': item.playerName})),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'transferMarket.offerAmountLabel'.tr()),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.of(dialogContext).pop(value);
            },
            child: Text('transferMarket.submitOffer'.tr()),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0 || onMakeOffer == null) return;
    await onMakeOffer!(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwnPlayer = activeClubId != null && activeClubId == item.sellerClubId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.playerName} (${item.playerPosition})', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('transferMarket.sellerClub'.tr(namedArgs: {'name': item.sellerClubDisplayName}), style: theme.textTheme.bodyLarge),
                if (isOwnPlayer)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text('transferMarket.yourClub'.tr()),
                    ),
                  ),
                const SizedBox(height: 10),
                Text('transferMarket.askingPrice'.tr(namedArgs: {'price': item.askingPrice.toString()}), style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                if (!isOwnPlayer)
                  ElevatedButton(
                    onPressed: onMakeOffer == null ? null : () => _showOfferDialog(context),
                    child: Text('transferMarket.makeOffer'.tr()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
