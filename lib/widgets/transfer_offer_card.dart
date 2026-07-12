import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/transfer_offer.dart';

class TransferOfferCard extends StatelessWidget {
  final TransferOffer offer;
  final bool isIncoming;
  final Future<void> Function(bool accept)? onRespond;
  final Future<void> Function()? onWithdraw;
  final Future<void> Function()? onReoffer;

  const TransferOfferCard({
    super.key,
    required this.offer,
    required this.isIncoming,
    this.onRespond,
    this.onWithdraw,
    this.onReoffer,
  });

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
          Text('${offer.offerAmount} GP', style: theme.textTheme.bodyLarge),
          if (offer.isPending) ...[
            const SizedBox(height: 12),
            if (isIncoming && onRespond != null)
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
              )
            else if (!isIncoming && onWithdraw != null)
              OutlinedButton(
                onPressed: onWithdraw,
                child: Text('transferOffer.withdrawAction'.tr()),
              ),
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
