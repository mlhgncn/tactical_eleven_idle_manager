class Bank {
  final String id;
  final String name;
  final double dailyInterestRate;
  final int lockUpDays;
  final int minDeposit;
  final int maxDeposit;

  const Bank({
    required this.id,
    required this.name,
    required this.dailyInterestRate,
    required this.lockUpDays,
    required this.minDeposit,
    required this.maxDeposit,
  });

  String get dailyRatePercentLabel => '${(dailyInterestRate * 100).toStringAsFixed(2)}%';

  factory Bank.fromMap(Map<String, dynamic> map) {
    return Bank(
      id: map['id'] as String,
      name: map['name'] as String,
      dailyInterestRate: (map['daily_interest_rate'] as num).toDouble(),
      lockUpDays: (map['lock_up_days'] as num).toInt(),
      minDeposit: (map['min_deposit'] as num).toInt(),
      maxDeposit: (map['max_deposit'] as num).toInt(),
    );
  }
}

class BankDeposit {
  final String id;
  final String bankId;
  final int principal;
  final int balance;
  final DateTime depositedAt;
  final DateTime unlocksAt;

  const BankDeposit({
    required this.id,
    required this.bankId,
    required this.principal,
    required this.balance,
    required this.depositedAt,
    required this.unlocksAt,
  });

  bool get isLocked => unlocksAt.isAfter(DateTime.now());

  factory BankDeposit.fromMap(Map<String, dynamic> map) {
    return BankDeposit(
      id: map['id'] as String,
      bankId: map['bank_id'] as String,
      principal: (map['principal'] as num).toInt(),
      balance: (map['balance'] as num).toInt(),
      depositedAt: DateTime.parse(map['deposited_at'] as String),
      unlocksAt: DateTime.parse(map['unlocks_at'] as String),
    );
  }
}
