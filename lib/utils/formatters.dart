/// Shared formatting helpers for currency, dates, times, and percentages.
class AppFormat {
  static String fcfa(num v) => '${v.toStringAsFixed(0)} FCFA';

  static String fcfaShort(num v) => '${v.toStringAsFixed(0)} F';

  static String fcfaCompact(num v) {
    return v >= 1000000
        ? '${(v / 1000000).toStringAsFixed(1)}M FCFA'
        : '${(v / 1000).toStringAsFixed(0)}k FCFA';
  }

  static String date(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String dateShort(DateTime d) => '${d.day}/${d.month}';

  static String time(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String relativeFromNow(DateTime d) {
    final now = DateTime.now();
    final difference = now.difference(d);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${d.day}/${d.month}';
    }
  }

  static String percent(double ratio, {int decimals = 0}) {
    return '${(ratio * 100).toStringAsFixed(decimals)}%';
  }

  static DateTime? parseFrenchOrIsoDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) return null;

    final isoDate = DateTime.tryParse(trimmed);
    if (isoDate != null) return isoDate;

    final frenchMatch = RegExp(
      r'^(\d{2})[\/\-](\d{2})[\/\-](\d{4})$',
    ).firstMatch(trimmed);
    if (frenchMatch != null) {
      final day = int.parse(frenchMatch.group(1)!);
      final month = int.parse(frenchMatch.group(2)!);
      final year = int.parse(frenchMatch.group(3)!);
      return DateTime(year, month, day);
    }

    final dashFormat = RegExp(
      r'^(\d{4})[\/\-](\d{2})[\/\-](\d{2})$',
    ).firstMatch(trimmed);
    if (dashFormat != null) {
      final year = int.parse(dashFormat.group(1)!);
      final month = int.parse(dashFormat.group(2)!);
      final day = int.parse(dashFormat.group(3)!);
      return DateTime(year, month, day);
    }

    return null;
  }
}
