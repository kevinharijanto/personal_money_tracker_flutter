class TransactionModel {
  final String id;
  final double amount;          // parsed from string
  final String type;            // "INCOME" or "EXPENSE"
  final DateTime date;
  final DateTime createdAt;     // when the transaction was created
  final String description;
  final String accountId;
  final String categoryId;
  final String accountName;
  final String accountCurrency;
  final String categoryName;
  final String? transferGroupId; // null for regular transactions, set for transfers

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.date,
    required this.createdAt,
    required this.description,
    required this.accountId,
    required this.categoryId,
    required this.accountName,
    required this.accountCurrency,
    required this.categoryName,
    this.transferGroupId,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    try {
      final account = json['account'] as Map<String, dynamic>?;
      final category = json['category'] as Map<String, dynamic>?;

      return TransactionModel(
        id: json['id']?.toString() ?? '',
        amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
        type: json['type']?.toString() ?? '',
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : DateTime.now(),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : (json['date'] != null
                ? DateTime.parse(json['date'] as String)
                : DateTime.now()),
        description: (json['description'] ?? '') as String,
        accountId: json['accountId']?.toString() ?? '',
        categoryId: json['categoryId']?.toString() ?? '',
        accountName: account?['name']?.toString() ?? 'Unknown Account',
        accountCurrency: account?['currency']?.toString() ?? 'IDR',
        categoryName: category?['name']?.toString() ?? 'Unknown Category',
        transferGroupId: json['transferGroupId']?.toString(),
      );
    } catch (e) {
      // Return a default transaction model if parsing fails
      return TransactionModel(
        id: '',
        amount: 0.0,
        type: 'EXPENSE',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        description: 'Error parsing transaction',
        accountId: '',
        categoryId: '',
        accountName: 'Error',
        accountCurrency: 'IDR',
        categoryName: 'Error',
        transferGroupId: null,
      );
    }
  }

}
