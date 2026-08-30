/// Utilitaires de conversion défensive de types pour la désérialisation JSON/Firestore/Supabase.
///
/// Protège l'application contre les [TypeError] si une API renvoie des nombres
/// sous forme de chaînes de caractères, des entiers pour des booléens, etc.
library;

/// Convertit une valeur dynamique en [double] de façon défensive.
double parseDouble(dynamic val, {double defaultValue = 0.0}) {
  if (val == null) return defaultValue;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  if (val is String) {
    final cleaned = val.replaceAll(',', '.').trim();
    return double.tryParse(cleaned) ?? defaultValue;
  }
  return defaultValue;
}

/// Convertit une valeur dynamique en [double?] nullable.
double? parseDoubleOrNull(dynamic val) {
  if (val == null) return null;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  if (val is String) {
    final cleaned = val.replaceAll(',', '.').trim();
    return double.tryParse(cleaned);
  }
  return null;
}

/// Convertit une valeur dynamique en [int] de façon défensive.
int parseInt(dynamic val, {int defaultValue = 0}) {
  if (val == null) return defaultValue;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null) return parsed;
    final asDouble = double.tryParse(val.replaceAll(',', '.').trim());
    if (asDouble != null) return asDouble.toInt();
  }
  return defaultValue;
}

/// Convertit une valeur dynamique en [int?] nullable.
int? parseIntOrNull(dynamic val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is num) return val.toInt();
  if (val is String) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null) return parsed;
    final asDouble = double.tryParse(val.replaceAll(',', '.').trim());
    if (asDouble != null) return asDouble.toInt();
  }
  return null;
}

/// Convertit une valeur dynamique en [bool] de façon défensive.
bool parseBool(dynamic val, {bool defaultValue = false}) {
  if (val == null) return defaultValue;
  if (val is bool) return val;
  if (val is num) return val != 0;
  if (val is String) {
    final lower = val.trim().toLowerCase();
    if (lower == 'true' || lower == '1' || lower == 'yes' || lower == 'oui') {
      return true;
    }
    if (lower == 'false' || lower == '0' || lower == 'no' || lower == 'non') {
      return false;
    }
  }
  return defaultValue;
}

/// Convertit une valeur dynamique en [String] de façon défensive.
String parseString(dynamic val, {String defaultValue = ''}) {
  if (val == null) return defaultValue;
  if (val is String) return val.trim();
  return val.toString().trim();
}

/// Convertit une valeur dynamique en [String?] nullable.
String? parseStringOrNull(dynamic val) {
  if (val == null) return null;
  final str = val is String ? val.trim() : val.toString().trim();
  return str.isEmpty ? null : str;
}

/// Convertit une valeur dynamique en [List<String>] de façon défensive.
List<String> parseStringList(dynamic val) {
  if (val == null) return [];
  if (val is List) {
    return val
        .where((e) => e != null)
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (val is String) {
    final trimmed = val.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      // Tableau encodé en chaîne simple
      return trimmed
          .substring(1, trimmed.length - 1)
          .split(',')
          .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [trimmed];
  }
  return [];
}

/// Convertit une valeur dynamique en [DateTime] de façon défensive.
DateTime parseDate(dynamic val, {DateTime? defaultDate}) {
  if (val == null) return defaultDate ?? DateTime.now();
  if (val is DateTime) return val;
  if (val.runtimeType.toString().contains('Timestamp')) {
    try {
      return (val as dynamic).toDate();
    } catch (_) {}
  }
  if (val is String) {
    final parsed = DateTime.tryParse(val.trim());
    if (parsed != null) return parsed;
  }
  if (val is num) {
    try {
      // Millisecondes timestamp
      return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    } catch (_) {}
  }
  return defaultDate ?? DateTime.now();
}

/// Convertit une valeur dynamique en [DateTime?] nullable.
DateTime? parseDateOrNull(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  if (val.runtimeType.toString().contains('Timestamp')) {
    try {
      return (val as dynamic).toDate();
    } catch (_) {}
  }
  if (val is String) {
    return DateTime.tryParse(val.trim());
  }
  if (val is num) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    } catch (_) {}
  }
  return null;
}
