import 'package:flutter_test/flutter_test.dart';

import 'package:carjobfinance/core/l10n/strings.dart';

const _tags = ['pt_BR', 'es_MX', 'en_US', 'id_ID', 'hi_IN'];
const _derivedSpanishTags = ['es_AR', 'es_CO', 'es_CL', 'es_ES'];

const _sameAsPortuguese = {
  'premium.title',
  'premium.locked',
  'premium.settings.tile',
};

const _sameAsPortugueseInSpanish = {'premium.restore'};

void _expectTranslated(String key, String tag, {bool spanish = false}) {
  final value = Strings.t(key, tag);
  expect(value, isNotEmpty, reason: '$tag $key');
  expect(value, isNot(key), reason: '$tag $key');
  if (_sameAsPortuguese.contains(key)) return;
  if (spanish && _sameAsPortugueseInSpanish.contains(key)) return;
  expect(
    value,
    isNot(Strings.t(key, 'pt_BR')),
    reason: '$tag $key falls back to pt_BR',
  );
}

const _keys = [
  'premium.title',
  'premium.tagline',
  'premium.benefit.reports',
  'premium.benefit.goals',
  'premium.benefit.export',
  'premium.benefit.backup',
  'premium.benefit.reminders',
  'premium.cta',
  'premium.price.year',
  'premium.price.perMonth',
  'premium.trial',
  'premium.restore',
  'premium.terms',
  'premium.privacy',
  'premium.manage',
  'premium.active',
  'premium.renews',
  'premium.expires',
  'premium.locked',
  'premium.reports.sampleBanner',
  'premium.backup.locked',
  'premium.reminders.limit',
  'premium.error.purchase',
  'premium.error.unavailable',
  'premium.error.pending',
  'premium.restore.none',
  'premium.deleteAccount.warning',
  'premium.settings.tile',
];

void main() {
  group('premium strings', () {
    for (final tag in _tags) {
      test('$tag defines every premium key', () {
        for (final key in _keys) {
          if (tag == 'pt_BR') {
            final value = Strings.t(key, tag);
            expect(value, isNotEmpty, reason: '$tag $key');
            expect(value, isNot(key), reason: '$tag $key');
          } else {
            _expectTranslated(key, tag, spanish: tag == 'es_MX');
          }
        }
      });

      test('$tag keeps placeholders', () {
        expect(Strings.t('premium.price.year', tag), contains('{price}'));
        expect(Strings.t('premium.price.perMonth', tag), contains('{price}'));
        expect(Strings.t('premium.trial', tag), contains('{days}'));
        expect(Strings.t('premium.renews', tag), contains('{date}'));
        expect(Strings.t('premium.expires', tag), contains('{date}'));
      });
    }

    test('derived tags resolve premium keys', () {
      for (final key in _keys) {
        expect(Strings.t(key, 'pt_PT'), Strings.t(key, 'pt_BR'), reason: key);
        for (final tag in _derivedSpanishTags) {
          expect(Strings.t(key, tag), Strings.t(key, 'es_MX'),
              reason: '$tag $key');
        }
      }
    });
  });
}
