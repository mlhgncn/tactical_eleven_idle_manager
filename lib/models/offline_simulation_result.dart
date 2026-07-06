class OfflineSimulationResult {
  final int matchesSimulated;
  final int totalIncome;
  final int playersImproved;
  final int transferOffersReceived;
  final int inboxMessagesAdded;
  final Duration offlineDuration;
  final String? serverSummary;

  OfflineSimulationResult({
    required this.matchesSimulated,
    required this.totalIncome,
    required this.playersImproved,
    required this.transferOffersReceived,
    required this.inboxMessagesAdded,
    required this.offlineDuration,
    this.serverSummary,
  });

  String get summary {
    if ((serverSummary ?? '').trim().isNotEmpty) {
      return serverSummary!;
    }

    return '$matchesSimulated maç oynandı, $totalIncome GP gelir, '
        '$playersImproved oyuncu gelişti, $transferOffersReceived teklif geldi';
  }

  String get durationString {
    final hours = offlineDuration.inHours;
    final days = offlineDuration.inDays;

    if (days > 0) {
      return '$days gün $hours saat';
    } else if (hours > 0) {
      return '$hours saat ${offlineDuration.inMinutes % 60} dakika';
    } else {
      return '${offlineDuration.inMinutes} dakika';
    }
  }
}
