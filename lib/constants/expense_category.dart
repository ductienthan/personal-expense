import 'package:flutter/material.dart';

enum ExpenseCategory {
  food('🍔', 'Food'),
  transportation('🚗', 'Transportation'),
  entertainment('🎮', 'Entertainment'),
  shopping('🛍️', 'Shopping'),
  utilities('💡', 'Utilities'),
  health('🏥', 'Health'),
  education('📚', 'Education'),
  other('📦', 'Other');

  final String icon;
  final String label;

  const ExpenseCategory(this.icon, this.label);

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (category) => category.name == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

class CustomCategory {
  final String id;
  final String icon;
  final String label;
  final String userId;

  CustomCategory({
    required this.id,
    required this.icon,
    required this.label,
    required this.userId,
  });

  factory CustomCategory.fromMap(String id, Map<String, dynamic> map) {
    return CustomCategory(
      id: id,
      icon: map['icon'] ?? '📦',
      label: map['label'] ?? 'Custom',
      userId: map['userId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'icon': icon,
      'label': label,
      'userId': userId,
    };
  }
}