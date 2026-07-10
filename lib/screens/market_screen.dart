import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';

import '../models/diamond_product.dart';
import '../models/player_fm.dart';
import '../models/player_pack.dart';
import '../providers/game_provider.dart';
import '../services/purchase_service.dart';
import '../theme/app_theme.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _purchaseService = PurchaseService.instance;
  Map<String, ProductDetails> _storeProducts = {};
  bool _isStoreAvailable = false;
  bool _isLoadingStore = true;
  String? _purchasingProductId;
  String? _openingPackId;

  @override
  void initState() {
    super.initState();
    _purchaseService.onPurchaseVerified = _handlePurchaseVerification;
    _initStore();
  }

  Future<void> _initStore() async {
    final available = await _purchaseService.initialize();
    if (!mounted) return;
    setState(() => _isStoreAvailable = available);
    if (!available) {
      setState(() => _isLoadingStore = false);
      return;
    }

    final productIds = context.read<GameProvider>().diamondProducts.map((p) => p.productId).toSet();
    final products = await _purchaseService.queryProducts(productIds);
    if (!mounted) return;
    setState(() {
      _storeProducts = {for (final p in products) p.id: p};
      _isLoadingStore = false;
    });
  }

  Future<bool> _handlePurchaseVerification(PurchaseDetails details) async {
    try {
      await context.read<GameProvider>().creditDiamondsFromPurchase(
            receiptData: details.verificationData.serverVerificationData,
            productId: details.productID,
            transactionId: details.purchaseID ?? details.verificationData.serverVerificationData,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Elmas bakiyene eklendi!'), backgroundColor: AppColors.green),
        );
        setState(() => _purchasingProductId = null);
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satın alma doğrulanamadı: ${error.toString().replaceAll('Exception: ', '')}')),
        );
        setState(() => _purchasingProductId = null);
      }
      return false;
    }
  }

  Future<void> _buyDiamonds(DiamondProduct product) async {
    final storeProduct = _storeProducts[product.productId];
    if (storeProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu ürün şu anda satın alınamıyor.')),
      );
      return;
    }
    setState(() => _purchasingProductId = product.productId);
    try {
      await _purchaseService.buy(storeProduct);
    } catch (error) {
      if (!mounted) return;
      setState(() => _purchasingProductId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _openPack(PlayerPack pack) async {
    setState(() => _openingPackId = pack.id);
    try {
      final newPlayers = await context.read<GameProvider>().openPlayerPack(packId: pack.id);
      if (!mounted) return;
      await _showPackResultDialog(pack, newPlayers);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _openingPackId = null);
    }
  }

  Future<void> _showPackResultDialog(PlayerPack pack, List<PlayerFM> newPlayers) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${pack.name} Açıldı!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final player in newPlayers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events, color: AppColors.goldLight, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${player.name} (${player.position}) — Güç: ${player.currentAbility}')),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Harika!'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _purchaseService.onPurchaseVerified = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final diamonds = provider.diamonds;
    final packs = provider.playerPacks;
    final products = provider.diamondProducts;

    return Scaffold(
      appBar: AppBar(title: const Text('Market')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.cardTop, AppColors.cardBottom]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.diamond, color: AppColors.blue, size: 28),
                const SizedBox(width: 12),
                Text('$diamonds Elmas', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Oyuncu Paketleri', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (packs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Paketler yükleniyor...', style: TextStyle(color: AppColors.textMuted)),
            )
          else
            for (final pack in packs) _PackCard(
              pack: pack,
              canAfford: diamonds >= pack.diamondCost,
              isLoading: _openingPackId == pack.id,
              onOpen: () => _openPack(pack),
            ),
          const SizedBox(height: 24),
          Text('Elmas Satın Al', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (!_isStoreAvailable && !_isLoadingStore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Bu cihazda satın alma şu anda kullanılamıyor.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else if (_isLoadingStore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final product in products)
              _DiamondProductCard(
                product: product,
                storeProduct: _storeProducts[product.productId],
                isLoading: _purchasingProductId == product.productId,
                onBuy: () => _buyDiamonds(product),
              ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.canAfford,
    required this.isLoading,
    required this.onOpen,
  });

  final PlayerPack pack;
  final bool canAfford;
  final bool isLoading;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pack.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(pack.contentsDescription, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canAfford && !isLoading ? onOpen : null,
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('${pack.diamondCost} 💎'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiamondProductCard extends StatelessWidget {
  const _DiamondProductCard({
    required this.product,
    required this.storeProduct,
    required this.isLoading,
    required this.onBuy,
  });

  final DiamondProduct product;
  final ProductDetails? storeProduct;
  final bool isLoading;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.diamond, color: AppColors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.label, style: Theme.of(context).textTheme.titleMedium),
                  if (product.bonusNote != null)
                    Text(product.bonusNote!, style: const TextStyle(color: AppColors.green, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: storeProduct != null && !isLoading ? onBuy : null,
              child: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(storeProduct?.price ?? '—'),
            ),
          ],
        ),
      ),
    );
  }
}
