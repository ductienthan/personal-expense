import 'package:flutter/material.dart';
import 'models/expense.dart';
import 'constants/expense_category.dart';
import 'services/firebase_service.dart';
import 'widgets/add_category_dialog.dart';
import 'widgets/limit_reached_dialog.dart';

class AddExpensePage extends StatefulWidget {
  final String userId;
  final Expense? expense;

  const AddExpensePage({
    super.key,
    required this.userId,
    this.expense,
  });

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  ExpenseCategory _selectedCategory = ExpenseCategory.other;
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  List<CustomCategory> _customCategories = [];
  bool _isLoadingCategories = true;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCustomCategories();
    if (widget.expense != null) {
      _titleController.text = widget.expense!.title;
      _amountController.text = widget.expense!.amount.toString();
      _descriptionController.text = widget.expense!.description ?? '';
      _dateController.text = widget.expense!.date.toString();
      _selectedCategory = widget.expense!.category;
    }
  }

  Future<void> _loadCustomCategories() async {
    try {
      final categories = await _firebaseService.getCustomCategories(widget.userId);
      setState(() {
        _customCategories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('Error loading custom categories: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF0C161D),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 48),
                      child: Text(
                        'Add Expense',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF0C161D),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.015,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form Fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Title Input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Title',
                          hintStyle: TextStyle(color: const Color(0xFF457AA1)),
                          filled: true,
                          fillColor: const Color(0xFFE6EEF4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    // Category Input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Category',
                                style: TextStyle(
                                  color: Color(0xFF0C161D),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Add Category'),
                                onPressed: () async {
                                  await showDialog(
                                    context: context,
                                    builder: (context) => AddCategoryDialog(
                                      onAdd: (icon, label) async {
                                        try {
                                          final newCategory = await _firebaseService.addCustomCategory(
                                            widget.userId,
                                            icon,
                                            label,
                                          );
                                          setState(() {
                                            _customCategories.add(newCategory);
                                          });
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error adding category: $e')),
                                          );
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isLoadingCategories)
                            const Center(child: CircularProgressIndicator())
                          else
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6EEF4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedCategory.name,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                ),
                                items: [
                                  ...ExpenseCategory.values.map((category) {
                                    return DropdownMenuItem(
                                      value: category.name,
                                      child: Row(
                                        children: [
                                          Text(category.icon),
                                          const SizedBox(width: 8),
                                          Text(
                                            category.label,
                                            style: const TextStyle(
                                              color: Color(0xFF0C161D),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  ...(_customCategories.map((category) {
                                    return DropdownMenuItem(
                                      value: 'custom_${category.id}',
                                      child: Row(
                                        children: [
                                          Text(category.icon),
                                          const SizedBox(width: 8),
                                          Text(
                                            category.label,
                                            style: const TextStyle(
                                              color: Color(0xFF0C161D),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })),
                                ],
                                onChanged: (String? value) {
                                  if (value != null) {
                                    setState(() {
                                      if (value.startsWith('custom_')) {
                                        final categoryId = value.substring(7);
                                        final customCategory = _customCategories.firstWhere(
                                          (cat) => cat.id == categoryId,
                                        );
                                        // Handle custom category selection
                                      } else {
                                        _selectedCategory = ExpenseCategory.values.firstWhere(
                                          (cat) => cat.name == value,
                                        );
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Amount Input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Amount',
                          hintStyle: TextStyle(color: const Color(0xFF457AA1)),
                          filled: true,
                          fillColor: const Color(0xFFE6EEF4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          suffixIcon: Icon(
                            Icons.attach_money,
                            color: const Color(0xFF457AA1),
                          ),
                        ),
                      ),
                    ),

                    // Description Input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Description',
                          hintStyle: TextStyle(color: const Color(0xFF457AA1)),
                          filled: true,
                          fillColor: const Color(0xFFE6EEF4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),

                    // Date Input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null) {
                            _dateController.text = 
                                "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Date',
                          hintStyle: TextStyle(color: const Color(0xFF457AA1)),
                          filled: true,
                          fillColor: const Color(0xFFE6EEF4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            color: const Color(0xFF457AA1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Save Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        await _saveExpense();
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0095FF),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.015,
                      ),
                    ),
            )
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (_titleController.text.isNotEmpty &&
        _amountController.text.isNotEmpty &&
        _dateController.text.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        final expense = Expense(
          id: widget.expense?.id,
          title: _titleController.text,
          amount: double.parse(_amountController.text),
          date: DateTime.parse(_dateController.text),
          description: _descriptionController.text,
          category: _selectedCategory,
        );

        if (widget.expense == null) {
          // Adding new expense
          final success = await _firebaseService.addExpense(
            expense,
            widget.userId,
          );

          if (!success && mounted) {
            // Show limit reached dialog
            final shouldDelete = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => const LimitReachedDialog(),
            );

            if (shouldDelete == true) {
              // Delete oldest and try again
              await _firebaseService.deleteOldestExpense(widget.userId);
              await _firebaseService.addExpense(expense, widget.userId);
            } else {
              setState(() => _isLoading = false);
              return;
            }
          }
        } else {
          // Updating existing expense
          await _firebaseService.updateExpense(
            widget.userId,
            widget.expense!.id!,
            expense,
          );
        }

        if (!mounted) return;
        Navigator.pop(context, expense);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving expense: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}