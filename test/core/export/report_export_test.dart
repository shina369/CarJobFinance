import 'dart:convert';

import 'package:carjobfinance/core/export/report_data.dart';
import 'package:carjobfinance/core/export/report_pdf.dart';
import 'package:carjobfinance/core/l10n/currencies.dart';
import 'package:carjobfinance/core/l10n/languages.dart';
import 'package:carjobfinance/domain/entities/expense.dart';
import 'package:carjobfinance/domain/entities/ride.dart';
import 'package:carjobfinance/presentation/controllers/data_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ptBr = languageForTag('pt_BR')!;
  final enUs = languageForTag('en_US')!;
  final hiIn = languageForTag('hi_IN')!;

  Ride ride({
    String id = 'r1',
    DateTime? date,
    String platform = 'Uber',
    double earnings = 100,
    double commission = 25,
    String? origin,
    String? destination,
  }) =>
      Ride(
        id: id,
        date: date ?? DateTime(2026, 3, 5, 14, 30),
        platform: platform,
        earnings: earnings,
        distanceKm: 12.5,
        durationMinutes: 30,
        rideType: 'Normal',
        commissionAmount: commission,
        origin: origin,
        destination: destination,
      );

  Expense expense({String? description, double amount = 40}) => Expense(
        id: 'e1',
        date: DateTime(2026, 3, 6, 9),
        category: 'Combustível',
        amount: amount,
        description: description,
      );

  group('ReportData', () {
    test('totals separate commissions from other expenses', () {
      final data = ReportData(
        periodLabel: 'Março',
        rides: [ride(), ride(id: 'r2', earnings: 50, commission: 5)],
        expenses: [expense()],
      );

      expect(data.totalEarnings, 150);
      expect(data.totalCommissions, 30);
      expect(data.otherExpenses, 40);
      expect(data.totalExpenses, 70);
      expect(data.netProfit, 80);
      expect(data.totalKm, 25);
      expect(data.totalMinutes, 60);
    });

    test('sorts rides by date', () {
      final data = ReportData(
        periodLabel: '',
        rides: [
          ride(id: 'late', date: DateTime(2026, 3, 9)),
          ride(id: 'early', date: DateTime(2026, 3, 1)),
        ],
        expenses: const [],
      );

      expect(data.rides.map((r) => r.id), ['early', 'late']);
    });
  });

  group('buildReportCsv', () {
    test('starts with a BOM and writes one row per record', () {
      final csv = buildReportCsv(
        ReportData(periodLabel: '', rides: [ride()], expenses: [expense()]),
        ptBr,
      );

      expect(csv.codeUnitAt(0), 0xFEFF);
      final lines = csv.substring(1).trimRight().split('\r\n');
      expect(lines, hasLength(3));
      expect(
        lines[0],
        'Tipo;Data;Plataforma/Categoria;Descrição;Ganhos;Comissão;Despesa;'
        'Distância (km);Duração (min)',
      );
      expect(lines[1], 'Corrida;2026-03-05 14:30;Uber;;100,00;25,00;;12,50;30');
      expect(lines[2], 'Despesa;2026-03-06 09:00;Combustível;;;;40,00;;');
    });

    test('uses the decimal mark of the language', () {
      final csv = buildReportCsv(
        ReportData(periodLabel: '', rides: [ride()], expenses: const []),
        enUs,
      );

      expect(csv, contains('Ride;2026-03-05 14:30;Uber;;100.00;25.00;'));
    });

    test('quotes fields containing the delimiter, quotes or line breaks', () {
      final csv = buildReportCsv(
        ReportData(
          periodLabel: '',
          rides: const [],
          expenses: [expense(description: 'Posto "Shell"; troca\nde óleo')],
        ),
        ptBr,
      );

      expect(csv, contains('"Posto ""Shell""; troca\nde óleo"'));
    });

    test('neutralises spreadsheet formulas typed by the user', () {
      final csv = buildReportCsv(
        ReportData(
          periodLabel: '',
          rides: [ride(platform: '@cmd')],
          expenses: [expense(description: '=SUM(A1:A9)')],
        ),
        ptBr,
      );

      expect(csv, contains(";'@cmd;"));
      expect(csv, contains(";'=SUM(A1:A9);"));
    });

    test('joins origin and destination in the description', () {
      final csv = buildReportCsv(
        ReportData(
          periodLabel: '',
          rides: [ride(origin: 'Centro', destination: 'Aeroporto')],
          expenses: const [],
        ),
        ptBr,
      );

      expect(csv, contains(';Centro → Aeroporto;'));
    });
  });

  group('buildReportPdf', () {
    final data = ReportData(
      periodLabel: 'Março',
      rides: [ride(origin: 'Centro')],
      expenses: [expense(description: 'Posto → “Shell”')],
    );

    test('produces a PDF document', () async {
      final bytes = await buildReportPdf(
        data,
        lang: ptBr,
        currency: currencyForCode('BRL')!,
        generatedAt: DateTime(2026, 3, 7),
      );

      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    });

    test('renders an empty period', () async {
      final bytes = await buildReportPdf(
        ReportData(periodLabel: '', rides: const [], expenses: const []),
        lang: enUs,
        currency: currencyForCode('USD')!,
      );

      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('falls back to English for scripts the PDF fonts cannot draw',
        () async {
      expect(pdfLanguageFor(hiIn).tag, 'en_US');
      expect(pdfLanguageFor(ptBr).tag, 'pt_BR');

      final bytes = await buildReportPdf(
        data,
        lang: hiIn,
        currency: currencyForCode('INR')!,
      );

      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });

  test('exportFileName carries a sortable timestamp', () {
    expect(
      exportFileName('report', 'csv', DateTime(2026, 3, 7, 9, 5)),
      'carjobfinance_report_20260307_0905.csv',
    );
  });
}
