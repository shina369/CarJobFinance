// Entidades de domínio - Expense (Despesa)
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:carjobfinance/core/settings/locale_helper.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

@freezed
class Expense with _$Expense {
  const factory Expense({
    required String id,
    required DateTime date,
    required String category,
    required double amount,
    String? description,
    String? receiptImagePath,
    @Default(false) bool isRecurring,
    @Default(false) bool isSynced,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);

  const Expense._();

  // Helpers
  String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  String get formattedAmount => formatCurrency(amount, localeTag: 'pt_BR');
}
