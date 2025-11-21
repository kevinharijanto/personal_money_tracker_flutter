import 'package:intl/intl.dart';

class MoneyFormatter {
  /// Formats a double amount into:
  ///  Rp 10,000.20 (standard format with comma as thousand separator, period as decimal)
  /// Always shows full number with proper thousand separators
  static String formatIDR(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_US', // Use en_US for standard format (comma thousand, period decimal)
      symbol: '',
      decimalDigits: 2,
    );
    return 'Rp ${formatter.format(amount)}';
  }

  /// Formats number only (e.g. 10,000.20)
  static String formatNumber(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  /// Parse from formatted string back to double
  /// Example: "Rp 10,000.20" -> 10000.20
  static double parse(String formatted) {
    final clean = formatted
        .replaceAll('Rp', '')
        .replaceAll(' ', '');
    
    // Handle standard format: 10,000.20 -> 10000.20
    if (clean.contains('.')) {
      // Split on period to separate decimal part
      final parts = clean.split('.');
      final integerPart = parts[0].replaceAll(',', ''); // Remove thousand separators
      final decimalPart = parts.length > 1 ? parts[1] : '00';
      return double.tryParse('$integerPart.$decimalPart') ?? 0.0;
    } else {
      // No decimal part, just remove thousand separators
      return double.tryParse(clean.replaceAll(',', '')) ?? 0.0;
    }
  }
}
