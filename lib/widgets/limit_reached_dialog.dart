import 'package:flutter/material.dart';

class LimitReachedDialog extends StatelessWidget {
  const LimitReachedDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Expense Limit Reached'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You have reached the maximum limit of 150 expenses for free users.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            'To add a new expense, you can either:',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text('• Delete the oldest expense'),
          Text('• Upgrade to Premium for unlimited expenses'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0095FF),
          ),
          child: const Text('Delete Oldest & Continue'),
        ),
      ],
    );
  }
} 