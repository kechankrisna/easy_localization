/// Utilities for auditing translation completeness across locales.
library;

/// Recursively flattens a nested translation map into dot-separated leaf paths.
///
/// Example:
/// ```dart
/// flattenTranslationKeys({'amount': {'zero': '0', 'one': '1'}})
/// // → {'amount.zero', 'amount.one'}
/// ```
Set<String> flattenTranslationKeys(
  Map<String, dynamic> map, [
  String prefix = '',
]) {
  final keys = <String>{};
  for (final entry in map.entries) {
    final fullKey =
        prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
    if (entry.value is Map<String, dynamic>) {
      keys.addAll(
          flattenTranslationKeys(entry.value as Map<String, dynamic>, fullKey));
    } else {
      keys.add(fullKey);
    }
  }
  return keys;
}

/// Result of comparing one locale against a reference.
class LocaleScanResult {
  final String name;

  /// Keys present in the reference but absent in this locale.
  final Set<String> missing;

  /// Keys present in this locale but absent in the reference.
  final Set<String> extra;

  const LocaleScanResult({
    required this.name,
    required this.missing,
    required this.extra,
  });

  bool get isComplete => missing.isEmpty && extra.isEmpty;
}

/// Compares each locale in [locales] against the [reference] translation map.
///
/// Returns one [LocaleScanResult] per locale entry.
List<LocaleScanResult> scanTranslations({
  required Map<String, dynamic> reference,
  required Map<String, Map<String, dynamic>> locales,
}) {
  final referenceKeys = flattenTranslationKeys(reference);
  return locales.entries.map((entry) {
    final localeKeys = flattenTranslationKeys(entry.value);
    return LocaleScanResult(
      name: entry.key,
      missing: referenceKeys.difference(localeKeys),
      extra: localeKeys.difference(referenceKeys),
    );
  }).toList();
}
