import 'dart:async';

import 'package:flutter/material.dart';
import '../models/transfer_market_item.dart';

class TransferMarketCard extends StatefulWidget {
  final TransferMarketItem item;
  final VoidCallback? onBidPressed;

  const TransferMarketCard({
    super.key,
    required this.item,
    this.onBidPressed,
  });

  @override
  State<TransferMarketCard> createState() => _TransferMarketCardState();
}

class _TransferMarketCardState extends State<TransferMarketCard> {
  bool _isSold = false;
  Timer? _saleTimer;

  @override
  void initState() {
    super.initState();
    _isSold = widget.item.isSold;
    _scheduleSaleAnimation();
  }

  @override
  void didUpdateWidget(covariant TransferMarketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.endTime != widget.item.endTime) {
      _saleTimer?.cancel();
      _isSold = widget.item.isSold;
      _scheduleSaleAnimation();
    }
  }

  void _scheduleSaleAnimation() {
    if (_isSold) {
      return;
    }
    final now = DateTime.now();
    final remaining = widget.item.endTime.difference(now);
    if (remaining.isNegative) {
      setState(() => _isSold = true);
      return;
    }
    _saleTimer = Timer(remaining, () {
      if (!mounted) return;
      setState(() => _isSold = true);
    });
  }

  @override
  void dispose() {
    _saleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.item.isSold ? Colors.grey.shade900 : theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.item.playerName} (${widget.item.playerPosition})', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Text('Mevcut En Yüksek Teklif: ${widget.item.currentHighestBid} GP', style: theme.textTheme.bodyLarge),
                const SizedBox(height: 6),
                Text('Teklif Sahibi: ${widget.item.highestBidderId ?? 'Bekliyor'}', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text('Bitiş Tarihi: ${widget.item.endTime.toLocal()}', style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: widget.onBidPressed,
                      child: const Text('Teklif Ver'),
                    ),
                    Icon(
                      _isSold ? Icons.check_circle : Icons.access_time,
                      color: _isSold ? Colors.greenAccent : theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _isSold
                  ? Container(
                      key: const ValueKey('soldLabel'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Satıldı',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
