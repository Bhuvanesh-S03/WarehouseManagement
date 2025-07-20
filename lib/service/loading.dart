import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_manager/model/product_model.dart';
import 'package:warehouse_manager/screens/qr_code_screen.dart';
import 'package:warehouse_manager/widget/show_dialog.dart'
    show showProductDialog;

class LoadingPage extends StatefulWidget {
  final Map<String, Product> productMap;
  final Function(String, Product) onProductUpdated;

  const LoadingPage({
    Key? key,
    required this.productMap,
    required this.onProductUpdated,
  }) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  int? columns;
  int? racksPerColumn;
  int? shelvesPerRack;
  int? positionsPerShelf;

  @override
  void initState() {
    super.initState();
    _loadLayoutSettings();
  }

  Future<void> _loadLayoutSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final savedColumns = prefs.getInt('columns');
    final savedRacks = prefs.getInt('racks');
    final savedShelves = prefs.getInt('shelves');
    final savedPositions = prefs.getInt('positions');

    if (savedColumns != null &&
        savedRacks != null &&
        savedShelves != null &&
        savedPositions != null) {
      setState(() {
        columns = savedColumns;
        racksPerColumn = savedRacks;
        shelvesPerRack = savedShelves;
        positionsPerShelf = savedPositions;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _askForLayout());
    }
  }

  Future<void> _askForLayout() async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        final colController = TextEditingController();
        final rackController = TextEditingController();
        final shelfController = TextEditingController();
        final posController = TextEditingController();

        return AlertDialog(
          title: Text('Enter Layout Dimensions'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: colController,
                  decoration: InputDecoration(labelText: 'Columns'),
                ),
                TextField(
                  controller: rackController,
                  decoration: InputDecoration(labelText: 'Racks per Column'),
                ),
                TextField(
                  controller: shelfController,
                  decoration: InputDecoration(labelText: 'Shelves per Rack'),
                ),
                TextField(
                  controller: posController,
                  decoration: InputDecoration(labelText: 'Positions per Shelf'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, {
                  'columns': int.tryParse(colController.text) ?? 3,
                  'racks': int.tryParse(rackController.text) ?? 3,
                  'shelves': int.tryParse(shelfController.text) ?? 4,
                  'positions': int.tryParse(posController.text) ?? 4,
                });
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('columns', result['columns']!);
      await prefs.setInt('racks', result['racks']!);
      await prefs.setInt('shelves', result['shelves']!);
      await prefs.setInt('positions', result['positions']!);

      setState(() {
        columns = result['columns'];
        racksPerColumn = result['racks'];
        shelvesPerRack = result['shelves'];
        positionsPerShelf = result['positions'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (columns == null ||
        racksPerColumn == null ||
        shelvesPerRack == null ||
        positionsPerShelf == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Load Products')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Load Products')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: columns,
          itemBuilder: (context, colIndex) {
            return Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Column ${colIndex + 1}",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...List.generate(racksPerColumn!, (rackIndex) {
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: 6),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Rack ${rackIndex + 1}",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...List.generate(shelvesPerRack!, (shelfIndex) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 16.0,
                              ),
                              child: GridView.builder(
                                physics: NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: positionsPerShelf!,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: 1.2,
                                    ),
                                itemCount: positionsPerShelf!,
                                itemBuilder: (context, positionIndex) {
                                  final shelfKey =
                                      'C${colIndex + 1}-R${rackIndex + 1}-S${shelfIndex + 1}-P${positionIndex + 1}';
                                  final shelfProduct =
                                      widget.productMap[shelfKey];

                                  final bgColor =
                                      shelfProduct == null
                                          ? Colors.green
                                          : shelfProduct.colorCode ==
                                              Colors.yellow.value
                                          ? Colors.yellow
                                          : Colors.red;

                                  return GestureDetector(
                                    onTap: () async {
                                      if (shelfProduct == null) {
                                        final result = await showProductDialog(
                                          context,
                                          shelfKey,
                                          widget.productMap,
                                        );
                                        if (result != null) {
                                          widget.onProductUpdated(
                                            shelfKey,
                                            result,
                                          );
                                          setState(() {});

                                          // Navigate to QR generator screen
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => GenerateQRScreen(
                                                    product: result,
                                                  ),
                                            ),
                                          );
                                        }

                                      } else {
                                        showDialog(
                                          context: context,
                                          builder:
                                              (_) => AlertDialog(
                                                title: Text(shelfProduct.name),
                                                content: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Weight: ${shelfProduct.weight.toStringAsFixed(2)} kg",
                                                    ),
                                                    Text(
                                                      "Expiry: ${shelfProduct.expiryDate.toLocal().toString().split(' ')[0]}",
                                                    ),
                                                    Text("Location: $shelfKey"),
                                                  ],
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed:
                                                        () => Navigator.pop(
                                                          context,
                                                        ),
                                                    child: Text("Close"),
                                                  ),
                                                ],
                                              ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        border: Border.all(
                                          color: Colors.black26,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: EdgeInsets.all(4),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              shelfProduct?.name ?? 'Empty',
                                              style: TextStyle(fontSize: 10),
                                              textAlign: TextAlign.center,
                                            ),
                                            if (shelfProduct != null)
                                              Text(
                                                shelfProduct.expiryDate
                                                    .toLocal()
                                                    .toString()
                                                    .split(' ')[0],
                                                style: TextStyle(fontSize: 9),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
