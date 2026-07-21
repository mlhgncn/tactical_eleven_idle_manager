import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/transfer_offer.dart';

class TransferOfferCard extends StatelessWidget {
  final TransferOffer offer;
  final bool isIncoming;
  final Future<void> Function(bool accept)? onRespond;
  final Future<void> Function()? onWithdraw;
  final Future<void> Function()? onReoffer;
  final Future<void> Function(int counterAmount)? onCounter;

  const TransferOfferCard({
    super.key,
    required this.offer,
    required this.isIncoming,
    this.onRespond,
    this.onWithdraw,
    this.onReoffer,
    this.onCounter,
  });

  /// Bu kartı görüntüleyen kulübün pazarlıktaki rolü - isIncoming
  /// (oyuncu bu kulübe ait, teklif dışarıdan geldi) = seller, aksi halde buyer.
  String get _myRole => isIncoming ? 'seller' : 'buyer';

  /// Sırada karşı taraf mı var (yani offer.initiatedBy BENİM rolümse, en
  /// son hamleyi ben yaptım demektir, cevap karşıdan bekleniyor).
  bool get _isMyTurn => offer.initiatedBy != _myRole;

  Future<void> _showCounterDialog(BuildContext context) async {
    final controller = TextEditingController(text: offer.offerAmount.toString());
    final amount = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('transferOffer.counterDialogTitle'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'transferOffer.counterAmountLabel'.tr()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(int.tryParse(controller.text.trim())),
            child: Text('transferOffer.counterAction'.tr()),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    await onCounter?.call(amount);
  }

  Color _statusColor() {
    switch (offer.status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'withdrawn':
        return Colors.grey;
      default:
        return Colors.amber;
    }
  }

  String _statusLabel() {
    switch (offer.status) {
      case 'accepted':
        return 'transferOffer.accepted'.tr();
      case 'rejected':
        return 'transferOffer.rejected'.tr();
      case 'withdrawn':
        return 'transferOffer.withdrawn'.tr();
      default:
        return 'transferOffer.pending'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counterpartLabel = isIncoming ? offer.fromClubName : offer.toClubName;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(offer.playerName, style: theme.textTheme.titleMedium)),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(_statusLabel()),
                backgroundColor: _statusColor().withValues(alpha: 0.15),
                labelStyle: TextStyle(color: _statusColor(), fontWeight: FontWeight.bold),
                side: BorderSide.none,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(isIncoming
              ? 'transferOffer.fromLabel'.tr(namedArgs: {'name': counterpartLabel})
              : 'transferOffer.toLabel'.tr(namedArgs: {'name': counterpartLabel})),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${offer.offerAmount} GP', style: theme.textTheme.bodyLarge),
              if (offer.isNegotiated) ...[
                const SizedBox(width: 8),
                Text(
                  'transferOffer.roundLabel'.tr(namedArgs: {'round': offer.roundNumber.toString()}),
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ],
          ),
          if (offer.isPending) ...[
            const SizedBox(height: 12),
            if (!_isMyTurn) ...[
              Text('transferOffer.waitingOnOtherSide'.tr(), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey, fontStyle: FontStyle.italic)),
              if (!isIncoming && onWithdraw != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: onWithdraw,
                  child: Text('transferOffer.withdrawAction'.tr()),
                ),
              ],
            ] else ...[
              if (onRespond != null)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => onRespond!(true),
                        child: Text('transferOffer.accept'.tr()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onRespond!(false),
                        child: Text('transferOffer.reject'.tr()),
                      ),
                    ),
                  ],
                ),
              if (offer.canCounter && onCounter != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showCounterDialog(context),
                    child: Text('transferOffer.counterAction'.tr()),
                  ),
                ),
              ],
            ],
          ],
          if (!offer.isPending && !isIncoming && offer.status == 'rejected' && onReoffer != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onReoffer,
              child: Text('transferOffer.reofferAction'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
