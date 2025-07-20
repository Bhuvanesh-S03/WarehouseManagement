import 'package:flutter/material.dart';
import 'package:warehouse_manager/model/product_model.dart';

class HomePage extends StatefulWidget {
  final Map<String, Product> productMap;
  final Function(String, Product)? onProductUpdated;

  const HomePage({Key? key, required this.productMap, this.onProductUpdated})
    : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _addItemDialog() {
    String itemName = '';

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text("Add New Product"),
            content: TextField(
              decoration: InputDecoration(labelText: "Item Name"),
              onChanged: (value) => itemName = value.trim(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (itemName.isNotEmpty) {
                    final key = itemName.toLowerCase();
                    if (!widget.productMap.containsKey(key)) {
                      final product = Product(
                        id:
                            'manual-$key-${DateTime.now().millisecondsSinceEpoch}',
                        name: itemName,
                        weight: 0.0,
                        entryDate: DateTime.now(),
                        expiryDate: DateTime.now().add(Duration(days: 180)),
                        locations: [],
                        colorCode: Colors.green.value,
                      );
                      widget.onProductUpdated?.call(key, product);
                      setState(() {});
                    }
                    Navigator.pop(context);
                  }
                },
                child: Text("Add"),
              ),
            ],
          ),
    );
  }

  Color _getColorFromExpiry(DateTime expiryDate) {
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 30) return Colors.yellow;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, Product> summarizedProducts = {};

    widget.productMap.forEach((key, product) {
      final productName = product.name.toLowerCase();
      if (summarizedProducts.containsKey(productName)) {
        summarizedProducts[productName]!.weight += product.weight;
        summarizedProducts[productName]!.locations.addAll(
          product.locations.where(
            (loc) => !summarizedProducts[productName]!.locations.contains(loc),
          ),
        );
      } else {
        summarizedProducts[productName] = Product(
          id: 'summary-${product.name.toLowerCase()}',
          name: product.name,
          weight: product.weight,
          entryDate: product.entryDate,
          expiryDate: product.expiryDate,
          locations: List.from(product.locations),
          colorCode: product.colorCode,
        );
      }
    });

    final items = summarizedProducts.values.toList();
    items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    return Scaffold(
      appBar: AppBar(title: Text("Warehouse Summary")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItemDialog,
        child: Icon(Icons.add),
      ),
      body:
          items.isEmpty
              ? Center(child: Text("No items yet. Tap + to add."))
              : Padding(
                padding: const EdgeInsets.all(12),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    Map<String, List<String>> columnRowMap = {};

                    for (String loc in item.locations) {
                      final parts = loc.split('-');
                      if (parts.length >= 3) {
                        String colRow = '${parts[0]}-${parts[1]}';
                        columnRowMap.putIfAbsent(colRow, () => []).add(loc);
                      }
                    }

                    final cardColor = _getColorFromExpiry(item.expiryDate);

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    List<String> sortedLocations = List.from(
                                      item.locations,
                                    );
                                    sortedLocations.sort((a, b) {
                                      final aProduct = widget.productMap.values
                                          .firstWhere(
                                            (p) => p.locations.contains(a),
                                          );
                                      final bProduct = widget.productMap.values
                                          .firstWhere(
                                            (p) => p.locations.contains(b),
                                          );
                                      return aProduct.expiryDate.compareTo(
                                        bProduct.expiryDate,
                                      );
                                    });

                                    showDialog(
                                      context: context,
                                      builder:
                                          (_) => AlertDialog(
                                            title: Text(
                                              "Locations for ${item.name}",
                                            ),
                                            content: SingleChildScrollView(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children:
                                                    sortedLocations.map((loc) {
                                                      final prod = widget
                                                          .productMap
                                                          .values
                                                          .firstWhere(
                                                            (p) => p.locations
                                                                .contains(loc),
                                                          );
                                                      final expiry =
                                                          prod.expiryDate
                                                              .toLocal()
                                                              .toString()
                                                              .split(' ')[0];
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 4,
                                                            ),
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(loc),
                                                            ),
                                                            Text(
                                                              "Exp: $expiry",
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors
                                                                        .grey[600],
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }).toList(),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(context),
                                                child: Text("Close"),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                  child: Text("Show Locations"),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Total Weight: ${item.weight.toStringAsFixed(2)} kg",
                            ),
                            Text("Total Shelves: ${item.locations.length}"),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
