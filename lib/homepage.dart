import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'signin_page.dart';
import 'signup_page.dart';  // Add this import
import 'addExpensePage.dart';
import 'models/expense.dart';
import 'constants/expense_category.dart';
import 'services/firebase_service.dart';
import 'report_page.dart';
import 'services/auth_service.dart';
import 'package:intl/intl.dart';
import 'dart:math';

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
                          itemCount: expenses.length,
                          itemBuilder: (context, int i) {
                            final expense = expenses[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 4,
                                      color: Colors.grey.shade100,
                                      offset: const Offset(0, 2)
                                    )
                                  ]
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
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
                                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                                    shape: BoxShape.circle
                                                  ),
                                                ),
                                                Text(
                                                  expense.category.name[0],
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    expense.title,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Theme.of(context).colorScheme.onBackground,
                                                      fontWeight: FontWeight.w500
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                  Text(
                                                    expense.description ?? '',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Theme.of(context).colorScheme.outline,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            "\$${expense.amount.toStringAsFixed(2)}",
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Theme.of(context).colorScheme.onBackground,
                                              fontWeight: FontWeight.w600
                                            ),
                                          ),
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(expense.date),
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context).colorScheme.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _editExpense(expense);
                                          } else if (value == 'delete') {
                                            // Show delete confirmation dialog
                                            if (!mounted) return;
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('Delete Expense'),
                                                content: const Text('Are you sure you want to delete this expense?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _deleteExpense(expense.id!);
                                                    },
                                                    child: const Text(
                                                      'Delete',
                                                      style: TextStyle(color: Colors.red),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit),
                                                SizedBox(width: 8),
                                                Text('Edit'),
                                              ],
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text('Delete', style: TextStyle(color: Colors.red)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  ),

                  // Bottom Navigation Bar
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Color(0xFFE6EEF4)),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              NavBarItem(
                                icon: Icons.home_filled,
                                label: 'Home',
                                isSelected: true,
                              ),
                              NavBarItem(
                                icon: Icons.search,
                                label: 'Accounts',
                              ),
                              NavBarItem(
                                icon: Icons.add_circle_outline,
                                label: 'Add Expense',
                                onTap: () async {
                                  final newExpense = await Navigator.push<Expense>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddExpensePage(userId: widget.userId!),
                                    ),
                                  );
                                  if (newExpense != null) {
                                    _addNewExpense(newExpense);
                                  }
                                },
                              ),
                              NavBarItem(
                                icon: Icons.pie_chart_outline,
                                label: 'Reports',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReportPage(userId: widget.userId!),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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

// ExpenseItem Widget
class ExpenseItem extends StatelessWidget {
  final String title;
  final double amount;
  final ExpenseCategory category;
  final String expenseId;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const ExpenseItem({
    super.key,
    required this.title,
    required this.amount,
    required this.category,
    required this.expenseId,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            category.icon,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0C161D),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  category.label,
                  style: const TextStyle(
                    color: Color(0xFF457AA1),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Color(0xFF457AA1),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            color: const Color(0xFF457AA1),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 20),
            color: Colors.red,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Expense'),
                  content: const Text('Are you sure you want to delete this expense?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete();
                      },
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// NavBarItem Widget
class NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF0C161D) : const Color(0xFF457AA1);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.015,
            ),
          ),
        ],
      ),
    );
  }
}
