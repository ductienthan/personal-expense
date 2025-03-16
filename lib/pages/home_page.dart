import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'signin_page.dart';
import 'signup_page.dart';  // Add this import
import 'add_expense_page.dart';
import '../models/expense.dart';
import '../constants/expense_category.dart';
import '../services/firebase_service.dart';
import '../pages/report_page.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../widgets/expense_item.dart';

class HomePage extends StatefulWidget {
  final bool isAuthenticated;
  final String? userId;

  const HomePage({
    super.key,
    this.isAuthenticated = false,
    this.userId,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  late Stream<List<Expense>> _expensesStream;
  DateTimeRange? _selectedDateRange;
  int _currentPage = 0;
  static const int _itemsPerPage = 50;
  List<Expense> _allExpenses = [];
  String? _userEmail;
  Stream<List<Expense>>? _filteredExpensesStream;
  int _selectedIndex = 0;
  final Color _selectedItem = const Color(0xFF0095FF);  // Blue color
  final Color _unselectedItem = const Color(0xFF457AA1); // Gray color

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _expensesStream = _firebaseService.getExpenses(widget.userId!);
      _loadUserEmail();
    }
    // Set initial date range to current month
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  Future<void> _loadUserEmail() async {
    try {
      final userDoc = await _firebaseService.getUserDocument(widget.userId!);
      if (mounted) {
        setState(() {
          _userEmail = userDoc?['email'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error loading user email: $e');
    }
  }

  Future<void> _selectDateRange() async {
    try {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: _selectedDateRange ?? DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 30)),
          end: DateTime.now(),
        ),
      );

      if (picked != null && mounted) {
        setState(() {
          _selectedDateRange = picked;
          _filteredExpensesStream = _firebaseService.getExpensesByDateRange(
            widget.userId!,
            picked.start,
            picked.end,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting date range: $e')),
        );
      }
    }
  }

  final List<Color> _expenseColors = [
    const Color(0xFF4CAF50), // Green
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFFA726), // Orange
    const Color(0xFFE91E63), // Pink
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFFF5722), // Deep Orange
    const Color(0xFF3F51B5), // Indigo
  ];

  List<Expense> _getFilteredExpenses(List<Expense> expenses) {
    if (_selectedDateRange == null) return expenses;

    return expenses.where((expense) {
      return expense.date.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
             expense.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
    }).toList();
  }

  List<Expense> _getPaginatedExpenses(List<Expense> expenses) {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    
    if (startIndex >= expenses.length) return [];
    
    return expenses.sublist(
      startIndex,
      endIndex > expenses.length ? expenses.length : endIndex,
    );
  }

  void _addNewExpense(Expense expense) {
    setState(() {
      // This method is no longer used with Firebase
    });
  }

  // Add this method to handle expense deletion
  Future<void> _deleteExpense(String expenseId) async {
    try {
      await _firebaseService.deleteExpense(widget.userId!, expenseId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting expense: $e')),
      );
    }
  }

  // Add this method to handle expense editing
  Future<void> _editExpense(Expense expense) async {
    
    try {
      final editedExpense = await Navigator.push<Expense>(
        context,
        MaterialPageRoute(
          builder: (context) => AddExpensePage(
            userId: widget.userId!,
            expense: expense,
          ),
        ),
      );


      if (editedExpense != null && expense.id != null) {
        try {
          final updatedExpense = Expense(
            id: expense.id,
            title: editedExpense.title,
            amount: editedExpense.amount,
            date: editedExpense.date,
            description: editedExpense.description,
            category: editedExpense.category,
          );
          
          await _firebaseService.updateExpense(
            widget.userId!, 
            expense.id!, 
            updatedExpense
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense updated successfully')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating expense: $e')),
          );
        }
      } else {
        if (editedExpense == null) {
          debugPrint('Edit was cancelled');
        }
        if (expense.id == null) {
          debugPrint('Original expense has no ID');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error in edit flow: $e')),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  double _calculateTotalExpense(List<Expense> expenses) {
    return expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  double _calculateMonthlyExpense(List<Expense> expenses, DateTime date) {
    return expenses
      .where((e) => e.date.month == date.month && e.date.year == date.year)
      .fold(0, (sum, expense) => sum + expense.amount);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAuthenticated) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Personal Expense',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0C161D),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignInPage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0095FF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Don\'t have an account?',
                style: TextStyle(
                  color: Color(0xFF457AA1),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignUpPage(),
                    ),
                  );
                },
                child: const Text(
                  'Create an account',
                  style: TextStyle(
                    color: Color(0xFF0095FF),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<Expense>>(
        stream: _filteredExpensesStream ?? _firebaseService.getExpenses(widget.userId!),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Show loading indicator only on initial load
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data ?? [];
          _allExpenses = expenses;
          final totalExpense = expenses.fold(0.0, (sum, expense) => sum + expense.amount);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
              child: Column(
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.yellow[700]
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.person_fill,
                                  color: Colors.yellow[800],
                                )
                              ],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Welcome!",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.outline
                                    ),
                                  ),
                                  Text(
                                    _userEmail ?? "User",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.onBackground
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          await _authService.signOut();
                          if (mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const SignInPage()),
                            );
                          }
                        }, 
                        icon: const Icon(CupertinoIcons.settings)
                      )
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Updated Total Expense Card
                  Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.width / 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                        transform: const GradientRotation(pi / 4),
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 4,
                          color: Colors.grey.shade300,
                          offset: const Offset(5, 5)
                        )
                      ]
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Total Expense',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '\$${totalExpense.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 40,
                            color: Colors.white,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Updated Transactions header with date range
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onBackground,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      Row(
                        children: [
                          if (_selectedDateRange != null)
                            Text(
                              '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - '
                              '${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _selectDateRange,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedDateRange == null ? 'All Time' : 'Change',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.outline,
                                    fontWeight: FontWeight.w400
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Add a clear filter button if date range is selected
                  if (_selectedDateRange != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDateRange = null;
                            _filteredExpensesStream = null;
                          });
                        },
                        child: const Text('Clear Filter'),
                      ),
                    ),

                  const SizedBox(height: 20),
                  
                  // Your existing expense list
                  Expanded(
                    child: expenses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedDateRange != null
                                    ? 'No expenses found for selected dates'
                                    : 'No expenses found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          itemCount: expenses.length,
                          itemBuilder: (context, int i) {
                            final expense = expenses[i];
                            final color = _expenseColors[i % _expenseColors.length];
                            
                            return ExpenseItem(
                              expense: expense,
                              color: color,
                              onEdit: _editExpense,
                              onDelete: _deleteExpense,
                            );
                          },
                        ),
                  ),

                  // Bottom Navigation Bar
                  Container(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      child: BottomNavigationBar(
                        currentIndex: _selectedIndex,
                        onTap: (index) async {
                          setState(() {
                            _selectedIndex = index;
                          });
                          
                          // Handle navigation based on index
                          switch (index) {
                            case 0: // Home - do nothing as we're already on home
                              break;
                            case 1: // Add Expense
                              final newExpense = await Navigator.push<Expense>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddExpensePage(userId: widget.userId!),
                                ),
                              );
                              if (newExpense != null) {
                                _addNewExpense(newExpense);
                              }
                              // Reset index back to home after adding expense
                              setState(() {
                                _selectedIndex = 0;
                              });
                              break;
                            case 2: // Reports
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ReportPage(userId: widget.userId!),
                                ),
                              );
                              // Reset index back to home after viewing reports
                              setState(() {
                                _selectedIndex = 0;
                              });
                              break;
                          }
                        },
                        backgroundColor: Colors.white,
                        selectedItemColor: _selectedItem,
                        unselectedItemColor: _unselectedItem,
                        showSelectedLabels: false,
                        showUnselectedLabels: false,
                        elevation: 3,
                        items: [
                          const BottomNavigationBarItem(
                            icon: Icon(CupertinoIcons.house),
                            activeIcon: Icon(CupertinoIcons.house_fill),
                            label: 'Home',
                          ),
                          BottomNavigationBarItem(
                            icon: Container(
                              width: 60,
                              height: 60,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.secondary,
                                    Theme.of(context).colorScheme.tertiary,
                                  ],
                                  transform: const GradientRotation(pi / 4),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                CupertinoIcons.plus,
                                color: Colors.white,
                              ),
                            ),
                            activeIcon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0095FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                CupertinoIcons.plus,
                                color: Colors.white,
                              ),
                            ),
                            label: 'Add',
                          ),
                          const BottomNavigationBarItem(
                            icon: Icon(CupertinoIcons.graph_square),
                            activeIcon: Icon(CupertinoIcons.graph_square_fill),
                            label: 'Reports',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
