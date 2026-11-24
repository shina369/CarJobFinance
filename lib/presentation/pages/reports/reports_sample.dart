// Reports sample - fictitious preview shown instead of the reports to free users

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_provider.dart';
import '../../../core/l10n/strings.dart';
import '../../widgets/premium_gate.dart';
import 'reports_page.dart';

/// Made-up figures; the user's rides and expenses are never read here.
class ReportsSampleData {
  const ReportsSampleData._();

  static const earnings = r'R$ 3.456,78';
  static const commissions = r'R$ 691,36';
  static const otherExpenses = r'R$ 812,40';
  static const totalExpenses = r'R$ 1.503,76';
  static const netProfit = r'R$ 1.953,02';
  static const rides = '87';
  static const distance = '1234.5 km';
  static const hours = '98.0h';
  static const perKm = r'R$ 2,80/km';
  static const perHour = r'R$ 35,27/h';
  static const perRide = r'R$ 39,73';
}

class ReportsLockedPreview extends ConsumerWidget {
  const ReportsLockedPreview({super.key = const Key('reports-locked')});

  static const _blur = 7.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: _blur,
                    sigmaY: _blur,
                    tileMode: TileMode.decal,
                  ),
                  child: const SingleChildScrollView(
                    key: Key('reports-sample'),
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.all(16),
                    child: _SampleBody(),
                  ),
                ),
              ),
            ),
          ),
        ),
        Align(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 6,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        key: const Key('reports-sample-banner'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lock_outline,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang.tr('premium.reports.sampleBanner'),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('reports-upgrade'),
                        onPressed: () => ensurePremium(context, ref),
                        child: Text(lang.tr('premium.cta')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SampleBody extends ConsumerWidget {
  const _SampleBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appLanguageProvider);
    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.tr('reports.summary'), style: titleStyle),
                const SizedBox(height: 16),
                ReportSummaryRow(
                  label: lang.tr('reports.totalEarnings'),
                  value: ReportsSampleData.earnings,
                  isPositive: true,
                ),
                ReportSummaryRow(
                  label: lang.tr('reports.commissions'),
                  value: ReportsSampleData.commissions,
                  isPositive: false,
                  isLightValue: true,
                ),
                ReportSummaryRow(
                  label: lang.tr('reports.otherExpenses'),
                  value: ReportsSampleData.otherExpenses,
                  isPositive: false,
                  isLightValue: true,
                ),
                ReportSummaryRow(
                  label: lang.tr('reports.totalExpenses'),
                  value: ReportsSampleData.totalExpenses,
                  isPositive: false,
                ),
                const Divider(),
                ReportSummaryRow(
                  label: lang.tr('reports.netProfit'),
                  value: ReportsSampleData.netProfit,
                  isPositive: true,
                  isTotal: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lang.tr('reports.metrics'), style: titleStyle),
                const SizedBox(height: 16),
                ReportMetricRow(
                  label: lang.tr('reports.ridesDone'),
                  value: ReportsSampleData.rides,
                ),
                ReportMetricRow(
                  label: lang.tr('reports.totalKm'),
                  value: ReportsSampleData.distance,
                ),
                ReportMetricRow(
                  label: lang.tr('reports.hoursWorked'),
                  value: ReportsSampleData.hours,
                ),
                ReportMetricRow(
                  label: lang.tr('reports.avgPerKm'),
                  value: ReportsSampleData.perKm,
                ),
                ReportMetricRow(
                  label: lang.tr('reports.avgPerHour'),
                  value: ReportsSampleData.perHour,
                ),
                ReportMetricRow(
                  label: lang.tr('reports.avgPerRide'),
                  value: ReportsSampleData.perRide,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
