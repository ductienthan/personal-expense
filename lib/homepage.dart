import 'package:flutter/material.dart';
import 'signin_page.dart';
import 'signup_page.dart';  // Add this import
import 'addExpensePage.dart';
import 'models/expense.dart';
import 'constants/expense_category.dart';
import 'services/firebase_service.dart';
import 'report_page.dart';

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
  late Stream<List<Expense>> _expensesStream;
  DateTimeRange? _selectedDateRange;
  int _currentPage = 0;
  static const int _itemsPerPage = 50;
  List<Expense> _allExpenses = [];

  @override
  void initState() {
    super.initState();
    if (widget.userId != null) {
      _expensesStream = _firebaseService.getExpenses(widget.userId!);
    }
    // Set initial date range to current month
    _selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0095FF),
              onPrimary: Colors.white,
              surface: Color(0xFFF8FAFC),
              onSurface: Color(0xFF0C161D),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        _currentPage = 0; // Reset to first page when date range changes
      });
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header with Date Range Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDateRange,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Expenses',
                            style: TextStyle(
                              color: Color(0xFF0C161D),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.015,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down),
                            onPressed: _selectDateRange,
                            color: const Color(0xFF0C161D),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Date Range Display
            if (_selectedDateRange != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '${_selectedDateRange!.start.toString().split(' ')[0]} - ${_selectedDateRange!.end.toString().split(' ')[0]}',
                  style: const TextStyle(
                    color: Color(0xFF457AA1),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            // Expense List with Pagination
            Expanded(
              child: StreamBuilder<List<Expense>>(
                stream: _expensesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allExpenses = snapshot.data ?? [];
                  final filteredExpenses = _getFilteredExpenses(allExpenses);
                  final paginatedExpenses = _getPaginatedExpenses(filteredExpenses);

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: paginatedExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = paginatedExpenses[index];
                            return ExpenseItem(
                              title: expense.title,
                              amount: expense.amount,
                              category: expense.category,
                              expenseId: expense.id!,
                              onDelete: () => _deleteExpense(expense.id!),
                              onEdit: () => _editExpense(expense),
                            );
                          },
                        ),
                      ),
                      
                      // Pagination Controls
                      if (filteredExpenses.length > _itemsPerPage)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 0
                                    ? () => setState(() => _currentPage--)
                                    : null,
                              ),
                              Text(
                                'Page ${_currentPage + 1} of ${(filteredExpenses.length / _itemsPerPage).ceil()}',
                                style: const TextStyle(
                                  color: Color(0xFF457AA1),
                                  fontSize: 14,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: (_currentPage + 1) * _itemsPerPage < filteredExpenses.length
                                    ? () => setState(() => _currentPage++)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                    ],
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
