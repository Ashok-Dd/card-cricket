class Wallet {
  const Wallet({required this.balance});

  final int balance;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(balance: json['balance'] as int);
}

class CoinTransaction {
  const CoinTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String type;
  final int amount;
  final int balanceAfter;
  final String? description;
  final DateTime createdAt;

  factory CoinTransaction.fromJson(Map<String, dynamic> json) => CoinTransaction(
        id: json['id'] as String,
        type: json['type'] as String,
        amount: json['amount'] as int,
        balanceAfter: json['balanceAfter'] as int,
        description: json['description'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
