class AccountModel {
  final String id;
  final String name;
  final String currency;
  final double balance;
  final bool isArchived;
  final String scope;
  final bool includeInTotals;

  AccountModel({
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
    required this.isArchived,
    required this.scope,
    bool? includeInTotals,
  }) : includeInTotals = includeInTotals ?? true;

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    final rawScope = json['scope']?.toString();
    final normalizedScope =
        rawScope != null && rawScope.isNotEmpty ? rawScope.toUpperCase() : 'PERSONAL';
    return AccountModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      isArchived: json['isArchived'] as bool? ?? false,
      scope: normalizedScope,
      includeInTotals: _parseIncludeInTotals(json['includeInTotals']),
    );
  }

  static bool _parseIncludeInTotals(dynamic raw) {
    if (raw == null) return true;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty) return true;
      return normalized != 'false' && normalized != '0' && normalized != 'no';
    }
    return true;
  }
}

class AccountGroup {
  final String id;
  final String name;
  final String kind; // e.g. BANK_ACCOUNTS
  final List<AccountModel> accounts;

  AccountGroup({
    required this.id,
    required this.name,
    required this.kind,
    required this.accounts,
  });

  factory AccountGroup.fromJson(Map<String, dynamic> json) {
    final accountsJson = json['accounts'] as List<dynamic>? ?? [];
    final accounts = accountsJson
        .map((a) => AccountModel.fromJson(a as Map<String, dynamic>? ?? {}))
        .toList();

    return AccountGroup(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      accounts: accounts,
    );
  }
}
