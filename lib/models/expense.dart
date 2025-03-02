import '../constants/expense_category.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  final String? id;
  final String title;
  final double amount;
  final DateTime date;
  final String? description;
  final ExpenseCategory category;

  Expense({
    this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.description,
    required this.category,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    try {
      final timestamp = map['date'];
      final DateTime date;
      
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        debugPrint('Invalid date format: $timestamp');
        date = DateTime.now(); // Fallback to current date
      }

      return Expense(
        id: id,
        title: map['title'] ?? '',
        amount: (map['amount'] ?? 0.0).toDouble(),
        date: date,
        description: map['description'],
        category: ExpenseCategory.values.firstWhere(
          (e) => e.name == map['category'],
          orElse: () => ExpenseCategory.other,
        ),
      );
    } catch (e) {
      debugPrint('Error creating Expense from map: $e');
      debugPrint('Map data: $map');
      rethrow;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'description': description,
      'category': category.name,
    };
  }

  @override
  String toString() {
    return 'Expense(id: $id, title: $title, amount: $amount, date: $date, description: $description, category: $category)';
  }
} 