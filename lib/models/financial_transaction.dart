class FinancialTransaction {
  final String id;
  final String clubId;
  final String type;
  final int amount;
  final String description;
  final String source;
  final DateTime createdAt;

  FinancialTransaction({
    required this.id,
    required this.clubId,
    required this.type,
    required this.amount,
    required this.description,
    required this.source,
    required this.createdAt,
  });

  factory FinancialTransaction.fromMap(Map<String, dynamic> map) {
    return FinancialTransaction(
      id: map['id'] as String,
      clubId: map['club_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toInt(),
      description: map['description'] as String? ?? '',
      source: map['source'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
