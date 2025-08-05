import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_manager/model/product_model.dart';

Future<Product?> showProductDialog(
  BuildContext context,
  String locationKey,
  Map<String, Product> productMap,
) async {
  final nameController = TextEditingController();
  final weightController = TextEditingController();
  DateTime? selectedExpiryDate;
  final expiryDateController = TextEditingController();

  final formKey = GlobalKey<FormState>();

  return showDialog<Product>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Enter Product Details"),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: "Product Name",
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (value) => ProductValidator.validateName(value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: weightController,
                      decoration: const InputDecoration(
                        labelText: "Weight (kg)",
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) => ProductValidator.validateWeight(value),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: expiryDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "Expiry Date",
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      validator:
                          (value) => ProductValidator.validateExpiryDate(
                            selectedExpiryDate,
                          ),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 2),
                          ),
                        );
                        if (date != null) {
                          setState(() {
                            selectedExpiryDate = date;
                            expiryDateController.text = DateFormat(
                              'yyyy-MM-dd',
                            ).format(date);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text("Location: "),
                        Text(
                          locationKey,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: const Text("Save"),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final name =
                        nameController.text.trim().isEmpty
                            ? 'Unknown Product'
                            : nameController.text.trim();
                    final weight =
                        double.tryParse(weightController.text.trim()) ?? 0.0;
                    final locations = [locationKey];

                    final newProduct = Product(
                      id: const Uuid().v4(),
                      name: name,
                      weight: weight,
                      entryDate: DateTime.now(),
                      expiryDate: selectedExpiryDate!,
                      locations: locations,
                      colorCode:
                          Product(
                            id: '',
                            name: name,
                            weight: weight,
                            entryDate: DateTime.now(),
                            expiryDate: selectedExpiryDate!,
                            locations: locations,
                            colorCode: 0,
                          ).expiryStatus.colorCodeValue,
                    );
                    Navigator.of(context).pop(newProduct);
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}
