import 'package:easy_localization/src/missing_keys_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── flattenTranslationKeys ────────────────────────────────────────────────

  group('flattenTranslationKeys', () {
    test('returns a single flat key unchanged', () {
      final result = flattenTranslationKeys({'title': 'Hello'});
      expect(result, equals({'title'}));
    });

    test('flattens one level of nesting', () {
      final result = flattenTranslationKeys({
        'amount': {'zero': '0', 'one': '1', 'other': 'n'},
      });
      expect(result, equals({'amount.zero', 'amount.one', 'amount.other'}));
    });

    test('flattens multiple levels of nesting', () {
      final result = flattenTranslationKeys({
        'profile': {
          'reset_password': {
            'label': 'Reset',
            'username': 'User',
          }
        }
      });
      expect(result, equals({
        'profile.reset_password.label',
        'profile.reset_password.username',
      }));
    });

    test('handles mix of flat and nested keys', () {
      final result = flattenTranslationKeys({
        'title': 'Hello',
        'gender': {'male': 'Mr', 'female': 'Ms'},
      });
      expect(result, equals({'title', 'gender.male', 'gender.female'}));
    });

    test('returns empty set for empty map', () {
      expect(flattenTranslationKeys({}), isEmpty);
    });

    test('does not include intermediate node keys — only leaf values', () {
      final result = flattenTranslationKeys({
        'a': {'b': 'leaf'},
      });
      expect(result, contains('a.b'));
      expect(result, isNot(contains('a')));
    });
  });

  // ── scanTranslations ─────────────────────────────────────────────────────

  group('scanTranslations', () {
    final reference = {
      'title': 'Hello',
      'amount': {'zero': '0', 'one': '1', 'other': 'n'},
      'reset_locale': 'Reset',
    };

    test('complete locale has empty missing and extra sets', () {
      final results = scanTranslations(
        reference: reference,
        locales: {
          'de': {
            'title': 'Hallo',
            'amount': {'zero': '0', 'one': '1', 'other': 'n'},
            'reset_locale': 'Zurücksetzen',
          }
        },
      );
      expect(results, hasLength(1));
      expect(results.first.isComplete, isTrue);
      expect(results.first.missing, isEmpty);
      expect(results.first.extra, isEmpty);
    });

    test('reports keys missing from a locale', () {
      final results = scanTranslations(
        reference: reference,
        locales: {
          'de': {
            'title': 'Hallo',
            // amount and reset_locale missing
          }
        },
      );
      expect(results.first.missing, containsAll([
        'amount.zero', 'amount.one', 'amount.other', 'reset_locale',
      ]));
    });

    test('reports extra keys in a locale', () {
      final results = scanTranslations(
        reference: reference,
        locales: {
          'de': {
            'title': 'Hallo',
            'amount': {'zero': '0', 'one': '1', 'other': 'n'},
            'reset_locale': 'Zurücksetzen',
            'extra_key': 'Bonus', // not in reference
          }
        },
      );
      expect(results.first.extra, equals({'extra_key'}));
    });

    test('returns one result per locale', () {
      final results = scanTranslations(
        reference: reference,
        locales: {
          'de': {'title': 'Hallo', 'amount': {'zero': '0', 'one': '1', 'other': 'n'}, 'reset_locale': 'x'},
          'fr': {'title': 'Bonjour', 'amount': {'zero': '0', 'one': '1', 'other': 'n'}, 'reset_locale': 'y'},
          'ru': {'title': 'Привет'}, // incomplete
        },
      );
      expect(results, hasLength(3));
      expect(results.where((r) => r.isComplete), hasLength(2));
      expect(results.where((r) => !r.isComplete), hasLength(1));
    });

    test('handles empty locales map', () {
      final results = scanTranslations(reference: reference, locales: {});
      expect(results, isEmpty);
    });

    test('locale with no keys has all reference keys as missing', () {
      final results = scanTranslations(
        reference: {'a': '1', 'b': '2'},
        locales: {'de': {}},
      );
      expect(results.first.missing, equals({'a', 'b'}));
    });

    test('locale name is preserved in the result', () {
      final results = scanTranslations(
        reference: {'x': '1'},
        locales: {'ar-DZ': {'x': '1'}},
      );
      expect(results.first.name, equals('ar-DZ'));
    });
  });

  // ── LocaleScanResult ─────────────────────────────────────────────────────

  group('LocaleScanResult', () {
    test('isComplete is true when missing and extra are both empty', () {
      const result = LocaleScanResult(
        name: 'de',
        missing: {},
        extra: {},
      );
      expect(result.isComplete, isTrue);
    });

    test('isComplete is false when missing is non-empty', () {
      const result = LocaleScanResult(
        name: 'de',
        missing: {'some.key'},
        extra: {},
      );
      expect(result.isComplete, isFalse);
    });

    test('isComplete is false when extra is non-empty', () {
      const result = LocaleScanResult(
        name: 'de',
        missing: {},
        extra: {'extra.key'},
      );
      expect(result.isComplete, isFalse);
    });
  });
}
