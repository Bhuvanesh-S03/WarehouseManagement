import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:warehouse_manager/model/product_model.dart';

Future<Product?> showProductDialog(
  BuildContext context,
  String locationKey,
  Map<String, Product> productMap, // ⬅️ shared product map
) async {
  final List<String> productItems =
      productMap.values.map((e) => e.name).toList().toSet().toList();

  String? selectedProduct;
  final weightController = TextEditingController();
  DateTime? selectedExpiryDate;
  final expiryDateController = TextEditingController();

  Future<void> _pickDate(BuildContext context) async {
    final year = await showDialog<int>(
      context: context,
      builder: (context) {
        int selectedYear = DateTime.now().year;
        return AlertDialog(
          title: Text("Select Year"),
          content: SizedBox(
            height: 200,
            width: 300,
            child: ListView.builder(
              itemCount: 20,
              itemBuilder: (context, index) {
                final year = DateTime.now().year + index;
                return ListTile(
                  title: Text(year.toString()),
                  onTap: () => Navigator.of(context).pop(year),
                );
              },
            ),
          ),
        );
      },
    );

    if (year == null) return;

    final month = await showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text("Select Month"),
          children: List.generate(12, (index) {
            return SimpleDialogOption(
              child: Text(DateFormat.MMMM().format(DateTime(year, index + 1))),
              onPressed: () => Navigator.of(context).pop(index + 1),
            );
          }),
        );
      },
    );

    if (month == null) return;

    final day = await showDatePicker(
      context: context,
      initialDate: DateTime(year, month),
      firstDate: DateTime(year, month),
      lastDate: DateTime(year, month + 1).subtract(Duration(days: 1)),
    );

    if (day != null) {
      selectedExpiryDate = day;
      expiryDateController.text = DateFormat('yyyy-MM-dd').format(day);
    }
  }

  return showDialog<Product>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Enter Product Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedProduct,
                decoration: InputDecoration(labelText: "Product Name"),
                items:
                    productItems.map((item) {
                      return DropdownMenuItem(value: item, child: Text(item));
                    }).toList(),
                onChanged: (value) => selectedProduct = value,
              ),
              TextField(
                controller: weightController,
                decoration: InputDecoration(labelText: "Weight (kg)"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: expiryDateController,
                readOnly: true,
                decoration: InputDecoration(labelText: "Expiry Date"),
                onTap: () => _pickDate(context),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Text("Location: "),
                  Text(
                    locationKey,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text("Cancel"),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: Text("Save"),
            onPressed: () {
              if (selectedProduct != null &&
                  weightController.text.isNotEmpty &&
                  selectedExpiryDate != null) {
                final double weight =
                    double.tryParse(weightController.text.trim()) ?? 0.0;
                final now = DateTime.now();
                final daysToExpiry = selectedExpiryDate!.difference(now).inDays;

                int colorCode;
                if (daysToExpiry < 30) {
                  colorCode = Colors.yellow.value;
                } else {
                  colorCode = Colors.red.value;
                }

              final product = Product(
                  id: "${DateTime.now().millisecondsSinceEpoch}-$locationKey",
                  name: selectedProduct!,
                  weight: weight,
                  entryDate: now,
                  expiryDate: selectedExpiryDate!,
                  locations: [locationKey],
                  colorCode: colorCode,
                );


                Navigator.of(context).pop(product);
              }
            },
          ),
        ],
      );
    },
  );
}
