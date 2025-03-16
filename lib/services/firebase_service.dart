import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense.dart';
import '../constants/expense_category.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const int maxFreeExpenses = 150;

  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Get user's expenses collection reference
  CollectionReference<Map<String, dynamic>> getUserExpensesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('expenses');
  }

  // Add expense
  Future<bool> addExpense(Expense expense, String userId) async {
    try {
      final isPremium = await isPremiumUser(userId);
      final expenseCount = await getExpenseCount(userId);

      if (!isPremium && expenseCount >= maxFreeExpenses) {
        return false; // Indicates limit reached
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .add({
        'title': expense.title,
        'amount': expense.amount,
        'date': Timestamp.fromDate(expense.date),
        'description': expense.description,
        'category': expense.category.name,
      });

      return true; // Successfully added
    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  // Get all expenses for a user
  Stream<List<Expense>> getExpenses(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs.map((doc) {
              return Expense.fromMap(doc.id, doc.data());
            }).toList();
          } catch (e) {
            throw Exception('Failed to parse expenses: $e');
          }
        });
  }

  // Get expenses by date range
  Stream<List<Expense>> getExpensesByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return getUserExpensesRef(userId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            isLessThanOrEqualTo: Timestamp.fromDate(
              DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)
            ))
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Expense(
          id: doc.id,
          title: data['title'],
          amount: (data['amount'] as num).toDouble(),
          date: data['date'].toDate(),
          description: data['description'],
          category: ExpenseCategory.values.firstWhere(
            (e) => e.name == data['category'],
          ),
        );
      }).toList();
    });
  }

  // Get expenses by category
  Stream<List<Expense>> getExpensesByCategory(
    String userId,
    ExpenseCategory category,
  ) {
    return getUserExpensesRef(userId)
        .where('category', isEqualTo: category.name)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return Expense(
          id: doc.id,
          title: data['title'],
          amount: (data['amount'] as num).toDouble(),
          date: data['date'].toDate(),
          description: data['description'],
          category: category,
        );
      }).toList();
    });
  }

  // Delete expense
  Future<void> deleteExpense(String userId, String expenseId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  // Update expense
  Future<void> updateExpense(String userId, String expenseId, Expense expense) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .doc(expenseId)
          .update({
        'title': expense.title,
        'amount': expense.amount,
        'date': Timestamp.fromDate(expense.date),
        'description': expense.description,
        'category': expense.category.name,
      });
    } catch (e) {
      debugPrint('Error updating expense: $e');
      rethrow;
    }
  }

  // Get total by category for date range
  Stream<Map<ExpenseCategory, double>> getTotalByCategory(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return getExpensesByDateRange(userId, startDate, endDate).map((expenses) {
      final totals = <ExpenseCategory, double>{};
      for (final expense in expenses) {
        totals[expense.category] =
            (totals[expense.category] ?? 0) + expense.amount;
      }
      return totals;
    });
  }

  Future<UserCredential> signUp(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Don't create the user document yet - wait for email verification
      return userCredential;
    } catch (e) {
      debugPrint('Error in signUp: $e');
      rethrow;
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified
      if (userCredential.user != null) {
        if (!userCredential.user!.emailVerified) {
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'email-not-verified',
            message: 'Please verify your email before signing in.',
          );
        }

        // Check if user document exists, if not create it
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error in signIn: $e');
      rethrow;
    }
  }

  // Add method to create user document
  Future<void> createUserDocument(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating user document: $e');
      rethrow;
    }
  }

  Future<List<Expense>> getExpensesForDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      
      // Convert DateTime to Timestamp for Firestore query
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59)
      );

      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp)
          .orderBy('date', descending: true)
          .get();

      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Expense.fromMap(doc.id, data);
      }).toList();
    } catch (e) {
      debugPrint('Error getting expenses for date range: $e');
      rethrow;
    }
  }

  // Add methods for custom categories
  Future<List<CustomCategory>> getCustomCategories(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_categories')
          .get();

      return querySnapshot.docs
          .map((doc) => CustomCategory.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting custom categories: $e');
      rethrow;
    }
  }

  Future<CustomCategory> addCustomCategory(
    String userId,
    String icon,
    String label,
  ) async {
    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_categories')
          .add({
        'icon': icon,
        'label': label,
        'userId': userId,
      });

      return CustomCategory(
        id: docRef.id,
        icon: icon,
        label: label,
        userId: userId,
      );
    } catch (e) {
      debugPrint('Error adding custom category: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomCategory(String userId, String categoryId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('custom_categories')
          .doc(categoryId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting custom category: $e');
      rethrow;
    }
  }

  // Add method to check premium status
  Future<bool> isPremiumUser(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data()?['isPremium'] ?? false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  // Fix the getExpenseCount method to handle nullable values
  Future<int> getExpenseCount(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .count()
          .get();
      
      return querySnapshot.count ?? 0; // Provide a default value if count is null
    } catch (e) {
      debugPrint('Error getting expense count: $e');
      return 0;
    }
  }

  // Add method to delete oldest expense
  Future<void> deleteOldestExpense(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('expenses')
          .orderBy('date')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('expenses')
            .doc(querySnapshot.docs.first.id)
            .delete();
      }
    } catch (e) {
      debugPrint('Error deleting oldest expense: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserDocument(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      return docSnapshot.data();
    } catch (e) {
      debugPrint('Error getting user document: $e');
      return null;
    }
  }
}