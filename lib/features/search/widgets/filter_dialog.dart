import 'package:flutter/material.dart';

class FilterDialog extends StatefulWidget {
  const FilterDialog({
    super.key,
    required this.initialCategory,
    required this.initialPriceRange,
    required this.initialRooms,
  });

  final String? initialCategory;
  final RangeValues initialPriceRange;
  final int initialRooms;

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late String? _selectedCategory;
  late RangeValues _currentPriceRange;
  late TextEditingController _roomsController;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    _currentPriceRange = widget.initialPriceRange;
    _roomsController = TextEditingController(
      text: widget.initialRooms.toString(),
    );
  }

  @override
  void dispose() {
    _roomsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تصفية النتائج'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'التصنيف'),
              value: _selectedCategory,
              items: const [
                DropdownMenuItem(value: null, child: Text('الكل')),
                DropdownMenuItem(value: 'بيع', child: Text('بيع')),
                DropdownMenuItem(value: 'إيجار', child: Text('إيجار')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Text('نطاق السعر', style: Theme.of(context).textTheme.titleMedium),
            RangeSlider(
              values: _currentPriceRange,
              min: 0,
              max: 5000000, // Max price, can be dynamic later
              divisions: 100,
              labels: RangeLabels(
                _currentPriceRange.start.round().toString(),
                _currentPriceRange.end.round().toString(),
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _currentPriceRange = values;
                });
              },
            ),
            TextFormField(
              controller: _roomsController,
              decoration: const InputDecoration(labelText: 'أقل عدد غرف'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final rooms = int.tryParse(_roomsController.text) ?? 0;
            Navigator.of(context).pop({
              'category': _selectedCategory,
              'priceRange': _currentPriceRange,
              'rooms': rooms,
            });
          },
          child: const Text('تطبيق'),
        ),
      ],
    );
  }
}
