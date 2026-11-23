import 'package:flutter_test/flutter_test.dart';

import 'package:carjobfinance/core/l10n/strings.dart';

const _tags = ['pt_BR', 'es_MX', 'en_US', 'id_ID', 'hi_IN'];

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
  'premium.deleteAccount.warning',
  'premium.settings.tile',
];

void main() {
  group('premium strings', () {
    for (final tag in _tags) {
      test('$tag defines every premium key', () {
        for (final key in _keys) {
          final value = Strings.t(key, tag);
          expect(value, isNotEmpty, reason: '$tag $key');
          expect(value, isNot(key), reason: '$tag $key');
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
      for (final tag in ['pt_PT', 'es_AR', 'es_CO', 'es_CL', 'es_ES']) {
        for (final key in _keys) {
          expect(Strings.t(key, tag), isNot(key), reason: '$tag $key');
        }
      }
    });
  });
}
