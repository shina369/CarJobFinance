import 'package:carjobfinance/core/constants/app_constants.dart';
import 'package:carjobfinance/presentation/widgets/expense_category_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each known category has its own icon', () {
    final icons =
        AppConstants.expenseCategories.map(expenseCategoryIcon).toSet();
    expect(icons.length, AppConstants.expenseCategories.length);
  });

  test('specific categories map to fitting icons', () {
    expect(expenseCategoryIcon('Combustível'), Icons.local_gas_station);
    expect(expenseCategoryIcon('Lavagem'), Icons.local_car_wash);
    expect(expenseCategoryIcon('Estacionamento'), Icons.local_parking);
    expect(expenseCategoryIcon('Alimentação'), Icons.restaurant);
  });

  test('unknown categories fall back to a generic receipt icon', () {
    expect(expenseCategoryIcon('Algo novo'), Icons.receipt_long);
  });
}
