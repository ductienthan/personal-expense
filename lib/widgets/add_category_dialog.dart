import 'package:flutter/material.dart';
import '../constants/expense_category.dart';

class AddCategoryDialog extends StatefulWidget {
  final Function(String icon, String label) onAdd;

  const AddCategoryDialog({
    super.key,
    required this.onAdd,
  });

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  final _labelController = TextEditingController();
  String _selectedEmoji = '📦';

  final List<String> _commonEmojis = [
    '🛒', '🎮', '🎵', '🎬', '👕', '💄', '🏠', '🚗',
    '✈️', '🍔', '☕', '🎁', '💼', '📱', '💻', '📚',
    '🏥', '🎨', '🎭', '🎪', '🎯', '🎲', '🎸', '📷',
  ];

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Add Custom Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C161D),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _labelController,
              decoration: InputDecoration(
                hintText: 'Category Name',
                filled: true,
                fillColor: const Color(0xFFE6EEF4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Icon',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0C161D),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFFE6EEF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _commonEmojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedEmoji = _commonEmojis[index];
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedEmoji == _commonEmojis[index]
                            ? const Color(0xFF0095FF)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _commonEmojis[index],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (_labelController.text.isNotEmpty) {
                      widget.onAdd(_selectedEmoji, _labelController.text);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 