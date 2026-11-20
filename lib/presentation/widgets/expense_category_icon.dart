import 'package:flutter/material.dart';

/// Icon for an expense category (values from AppConstants.expenseCategories).
IconData expenseCategoryIcon(String category) => switch (category) {
      'Combustível' => Icons.local_gas_station,
      'Manutenção' => Icons.build,
      'Lavagem' => Icons.local_car_wash,
      'Estacionamento' => Icons.local_parking,
      'Pedágio' => Icons.toll,
      'Alimentação' => Icons.restaurant,
      'Seguro' => Icons.shield,
      'IPVA/Licenciamento' => Icons.assignment,
      'Acessórios' => Icons.shopping_bag,
      _ => Icons.receipt_long,
    };
