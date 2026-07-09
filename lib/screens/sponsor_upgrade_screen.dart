import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

class SponsorUpgradeScreen extends StatefulWidget {
  const SponsorUpgradeScreen({super.key});

  @override
  State<SponsorUpgradeScreen> createState() => _SponsorUpgradeScreenState();
}

class _SponsorUpgradeScreenState extends State<SponsorUpgradeScreen> {
  bool _isUpgrading = false;
  String? _errorMessage;

  void _handleUpgrade() async {
    final provider = context.read<GameProvider>();

    setState(() {
      _isUpgrading = true;
      _errorMessage = null;
    });

    try {
      await provider.upgradeSponsor();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Sponsorluğu başarıyla yükselttiniz!'),
            backgroundColor: AppColors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        setState(() {
          _errorMessage = msg;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isUpgrading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final club = provider.activeClub;

    if (club == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sponsorluğu Yükselt')),
        body: const Center(child: Text('Aktif kulüp bulunamadı.')),
      );
    }

    final currentLevel = club.sponsorLevel;
    final maxLevel = 5;
    final isMaxed = currentLevel >= maxLevel;
    final upgradeCost = 5000 * currentLevel;
    final newLevel = currentLevel + 1;
    final newRevenuePerMatch = newLevel * 500;
    final currentRevenuePerMatch = currentLevel * 500;
    final revenueIncrease = newRevenuePerMatch - currentRevenuePerMatch;
    final canAfford = club.budget >= upgradeCost;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sponsorluğu Yükselt'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sponsorluk Anlaşması',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),

            // Mevcut Durum
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Mevcut Seviye'),
                        Text(
                          'Level $currentLevel',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Maç Başına Gelir'),
                        Text(
                          '$currentRevenuePerMatch GP',
                          style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: currentLevel / maxLevel,
                        minHeight: 8,
                        backgroundColor: AppColors.cardBottom,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isMaxed ? AppColors.green : AppColors.blue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$currentLevel / $maxLevel',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (!isMaxed) ...[
              // Yükseltme Bilgisi
              Card(
                color: AppColors.blue.withValues(alpha: 0.10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.blue.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yükseltilecek Seviye',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Yeni Seviye'),
                          Text(
                            'Level $newLevel',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Yeni Maç Geliri'),
                          Text(
                            '$newRevenuePerMatch GP',
                            style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up, color: AppColors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '+$revenueIncrease GP / maç',
                              style: const TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Maliyet
              Card(
                color: AppColors.gold.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yükseltme Maliyeti',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gerekli Bütçe'),
                          Text(
                            '$upgradeCost GP',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.goldLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mevcut Bütçe'),
                          Text(
                            '${club.budget} GP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: canAfford ? AppColors.green : AppColors.red,
                            ),
                          ),
                        ],
                      ),
                      if (!canAfford) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.red.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: AppColors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Yeterli bütçeniz yok',
                                  style: const TextStyle(
                                    color: AppColors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Geri Dönüş Hesaplaması
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Geri Dönüş Hesaplaması',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bu yükseltme şu kadar maçta kendini amorti edecek:',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(upgradeCost / revenueIncrease).ceil()} maç',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: AppColors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Upgrade Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (canAfford && !_isUpgrading) ? _handleUpgrade : null,
                  icon: _isUpgrading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldOnGoldText),
                          ),
                        )
                      : const Icon(Icons.upgrade),
                  label: Text(_isUpgrading ? 'Yükseltiliyor...' : 'Sponsorluğu Yükselt'),
                ),
              ),
            ] else ...[
              // Maksimum Seviyeye Ulaşıldı
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Icon(Icons.star, size: 64, color: AppColors.goldLight),
                    const SizedBox(height: 16),
                    Text(
                      'Maksimum Seviyeye Ulaştınız!',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Maç başına $currentRevenuePerMatch GP sponsor geliri kazanıyorsunuz.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
