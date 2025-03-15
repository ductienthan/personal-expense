import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import '../models/expense.dart';
import '../constants/expense_category.dart';
import '../pages/home_page.dart';
import '../pages/signin_page.dart';
import '../pages/signup_page.dart';
import '../pages/add_expense_page.dart';

class ReportPage extends StatefulWidget {
  final String userId;

  const ReportPage({
    super.key,
    required this.userId,
  });

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final FirebaseService _firebaseService = FirebaseService();
  DateTimeRange? _customDateRange;
  String _selectedRange = 'Current Month';
  Map<ExpenseCategory, double> _categoryTotals = {};
  double _totalExpenses = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    DateTime endDate = DateTime.now();
    DateTime startDate;

    // Calculate start date based on selected range
    switch (_selectedRange) {
      case 'Current Month':
        // First day of current month
        startDate = DateTime(endDate.year, endDate.month, 1);
        break;
      case 'Last Month':
        // First day of last month
        startDate = DateTime(endDate.year, endDate.month - 1, 1);
        endDate = DateTime(endDate.year, endDate.month, 0); // Last day of last month
        break;
      case '3 Months':
        startDate = DateTime(endDate.year, endDate.month - 3, endDate.day);
        break;
      case '6 Months':
        startDate = DateTime(endDate.year, endDate.month - 6, endDate.day);
        break;
      case 'Custom Range':
        if (_customDateRange != null) {
          startDate = _customDateRange!.start;
          endDate = _customDateRange!.end;
        } else {
          startDate = DateTime(endDate.year, endDate.month, 1);
        }
        break;
      default:
        startDate = DateTime(endDate.year, endDate.month, 1);
    }

    try {
      final expenses = await _firebaseService.getExpensesForDateRange(
        widget.userId,
        startDate,
        endDate,
      );

      _categoryTotals.clear();
      _totalExpenses = 0;

      // Calculate totals for each category
      for (var expense in expenses) {
        _categoryTotals[expense.category] =
            (_categoryTotals[expense.category] ?? 0) + expense.amount;
        _totalExpenses += expense.amount;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading expenses: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customDateRange,
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

    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedRange = 'Custom Range';
      });
      _loadExpenses();
    }
  }

  List<PieChartSectionData> _getSections() {
    final List<PieChartSectionData> sections = [];
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.yellow,
      Colors.teal,
      Colors.pink,
    ];

    int colorIndex = 0;
    _categoryTotals.forEach((category, amount) {
      final percentage = (amount / _totalExpenses) * 100;
      if (percentage > 0) {
        sections.add(
          PieChartSectionData(
            color: colors[colorIndex % colors.length],
            value: amount,
            title: '${percentage.toStringAsFixed(1)}%',
            radius: 100,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        colorIndex++;
      }
    });

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Expense Report',
          style: TextStyle(
            color: Color(0xFF0C161D),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0C161D)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Time range selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Time Range',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0C161D),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'Current Month',
                    'Last Month',
                    '3 Months',
                    '6 Months',
                    'Custom Range',
                  ].map((range) {
                    return ChoiceChip(
                      label: Text(range),
                      selected: _selectedRange == range,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedRange = range);
                          if (range == 'Custom Range') {
                            _selectCustomDateRange();
                          } else {
                            _loadExpenses();
                          }
                        }
                      },
                      selectedColor: const Color(0xFF0095FF),
                      labelStyle: TextStyle(
                        color: _selectedRange == range
                            ? Colors.white
                            : const Color(0xFF457AA1),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Pie Chart
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _categoryTotals.isEmpty
                    ? const Center(
                        child: Text('No expenses found for this period'),
                      )
                    : Column(
                        children: [
                          SizedBox(
                            height: 300,
                            child: PieChart(
                              PieChartData(
                                sections: _getSections(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                startDegreeOffset: -90,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Legend
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: _categoryTotals.entries.map((entry) {
                                  final percentage =
                                      (entry.value / _totalExpenses) * 100;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: Row(
                                      children: [
                                        Text(
                                          entry.key.icon,
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            entry.key.label,
                                            style: const TextStyle(
                                              color: Color(0xFF0C161D),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '\$${entry.value.toStringAsFixed(2)} (${percentage.toStringAsFixed(1)}%)',
                                          style: const TextStyle(
                                            color: Color(0xFF457AA1),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
} 