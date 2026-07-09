import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../providers/game_provider.dart';
import '../theme/app_theme.dart';
import 'player_detail_screen.dart';
import 'transfer_market_screen.dart';

class SquadScreen extends StatefulWidget {
  const SquadScreen({super.key});

  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  static const positionFilters = ['All', 'GK', 'DEF', 'MID', 'FOR'];
  String _selectedFilter = positionFilters.first;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final squad = provider.squadPlayers;
    final isLoading = provider.isLoading;
    final startingIds = squad.take(11).map((player) => player.id).toSet();
    final filteredPlayers = _selectedFilter == 'All'
        ? squad
        : squad.where((player) => player.positionGroup == _selectedFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('squad.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'squad.transferMarketTooltip'.tr(),
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransferMarketScreen()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : squad.isEmpty
              ? Center(child: Text('squad.noSquad'.tr()))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'squad.position'.tr(),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _selectedFilter,
                            dropdownColor: AppColors.cardTop,
                            items: positionFilters
                                .map(
                                  (filter) => DropdownMenuItem(
                                    value: filter,
                                    child: Text(filter),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedFilter = value);
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredPlayers.isEmpty
                          ? Center(child: Text('squad.noPlayersInPosition'.tr()))
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredPlayers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final player = filteredPlayers[index];
                                final isStarter = startingIds.contains(player.id);
                                return Card(
                                  elevation: 1,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => PlayerDetailScreen(player: player),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  player.name,
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                              ),
                                              if (player.hasActiveInjury)
                                                const Icon(Icons.healing, color: AppColors.red),
                                              if (player.isSuspended)
                                                const Padding(
                                                  padding: EdgeInsets.only(left: 8),
                                                  child: Icon(Icons.block, color: AppColors.red),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildStarRow(player.starRating),
                                              const SizedBox(width: 10),
                                              Text(player.position),
                                              const SizedBox(width: 12),
                                              Chip(
                                                label: Text(isStarter ? 'squad.starter'.tr() : 'squad.bench'.tr()),
                                                backgroundColor:
                                                    isStarter ? AppColors.green.withValues(alpha: 0.16) : AppColors.cardBottom,
                                                labelStyle: TextStyle(
                                                  color: isStarter ? AppColors.green : AppColors.textMuted,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                side: BorderSide(color: isStarter ? AppColors.green.withValues(alpha: 0.4) : AppColors.cardBorder),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 6,
                                            children: [
                                              _buildInfoChip('squad.age'.tr(), player.age.toString()),
                                              _buildInfoChip('squad.ca'.tr(), player.currentAbility.toString()),
                                              _buildInfoChip('squad.pa'.tr(), player.potentialAbility.toString()),
                                              _buildInfoChip('squad.morale'.tr(), player.morale.toString()),
                                              _buildInfoChip('squad.fitness'.tr(), player.fitness.toString()),
                                              _buildInfoChip('squad.form'.tr(), player.formRating.toStringAsFixed(1)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 6,
                                            children: [
                                              _buildInfoChip('squad.salary'.tr(), player.salaryLabel),
                                              _buildInfoChip('squad.marketValue'.tr(), player.marketValueLabel),
                                              _buildInfoChip(
                                                'squad.status'.tr(),
                                                player.hasActiveInjury
                                                    ? player.injuryDisplayLabel
                                                    : player.isSuspended
                                                        ? 'squad.suspended'.tr()
                                                        : 'squad.healthy'.tr(),
                                                highlight: player.hasActiveInjury || player.isSuspended,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                isStarter ? 'squad.starting11'.tr() : 'squad.benchLabel'.tr(),
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => const TransferMarketScreen(),
                                                    ),
                                                  );
                                                },
                                                icon: const Icon(Icons.swap_horiz),
                                                label: Text('squad.transfer'.tr()),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStarRow(double starRating) {
    final fullStars = starRating.floor();
    final hasHalf = (starRating - fullStars) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < fullStars) {
          return const Icon(Icons.star, size: 16, color: AppColors.goldLight);
        }
        if (index == fullStars && hasHalf) {
          return const Icon(Icons.star_half, size: 16, color: AppColors.goldLight);
        }
        return const Icon(Icons.star_border, size: 16, color: AppColors.goldLight);
      }),
    );
  }

  Widget _buildInfoChip(String label, String value, {bool highlight = false}) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label: $value'),
      backgroundColor: highlight ? AppColors.red.withValues(alpha: 0.14) : AppColors.cardBottom,
      labelStyle: TextStyle(color: highlight ? AppColors.red : AppColors.textPrimary, fontSize: 12),
      side: BorderSide(color: highlight ? AppColors.red.withValues(alpha: 0.35) : AppColors.cardBorder),
    );
  }
}
