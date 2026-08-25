/// Parses dates from the value shapes used by the application data sources.
DateTime? tryParseDynamicDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value.runtimeType.toString().contains('Timestamp')) {
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {}
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Parses a dynamic date, falling back to the current time when invalid.
DateTime parseDynamicDate(dynamic value) {
  return tryParseDynamicDate(value) ?? DateTime.now();
}
