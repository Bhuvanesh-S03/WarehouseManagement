import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_manager/model/product_model.dart';
import 'package:warehouse_manager/screens/qr_code_screen.dart';
import 'package:warehouse_manager/service/appwrite.dart';
import 'package:warehouse_manager/widget/show_dialog.dart'
    show showProductDialog;

class LoadingPage extends StatefulWidget {
  final Map<String, Product> productMap;
  final Function(String, Product) onProductUpdated;
  final Map<String, int> warehouseSettings;
  final AppwriteService appwriteService;

  const LoadingPage({
    Key? key,
    required this.productMap,
    required this.onProductUpdated,
    required this.warehouseSettings,
    required this.appwriteService,
  }) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  int? columns;
  int? racksPerColumn;
  int? shelvesPerRack;
  int? positionsPerShelf;
  Map<String, Product> _productMap = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _productMap = Map.from(widget.productMap);
    _initializeLayout();
  }

  Future<void> _initializeLayout() async {
    await _loadLayoutSettings();
    await _loadProductsFromDatabase();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadLayoutSettings() async {
    // First try to get from warehouse settings passed from parent
    if (widget.warehouseSettings.isNotEmpty) {
      setState(() {
        columns = widget.warehouseSettings['columns'] ?? 3;
        racksPerColumn = widget.warehouseSettings['racks_per_column'] ?? 3;
        shelvesPerRack = widget.warehouseSettings['shelves_per_rack'] ?? 4;
        positionsPerShelf =
            widget.warehouseSettings['positions_per_shelf'] ?? 4;
      });
      return;
    }

    // Fallback to SharedPreferences
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
      // Set default values if nothing is found
      setState(() {
        columns = 3;
        racksPerColumn = 3;
        shelvesPerRack = 4;
        positionsPerShelf = 4;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _askForLayout());
    }
  }

  Future<void> _loadProductsFromDatabase() async {
    try {
      setState(() {
        _errorMessage = '';
      });

      // Get products from Appwrite database
      final products = await widget.appwriteService.getAllProducts();

      // Convert to location-based map
      Map<String, Product> locationProductMap = {};

      for (final product in products) {
        // Only include products that are not unloaded (if the field exists)
        // Note: Adjust this based on your actual database structure
        for (final location in product.locations) {
          locationProductMap[location] = product;
        }
      }

      setState(() {
        _productMap = locationProductMap;
      });

      // Update parent widget's product map
      for (final entry in locationProductMap.entries) {
        widget.onProductUpdated(entry.key, entry.value);
      }

      print('✅ Loaded ${products.length} products from database');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading products: $e';
      });
      print('❌ Error loading products: $e');

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Error Loading Products'),
                content: Text('Failed to load products from database: $e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('OK'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadProductsFromDatabase(); // Retry
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
        );
      }
    }
  }

  Future<void> _askForLayout() async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      barrierDismissible: false, // Prevent dismissing without input
      builder: (context) {
        final colController = TextEditingController(text: columns.toString());
        final rackController = TextEditingController(
          text: racksPerColumn.toString(),
        );
        final shelfController = TextEditingController(
          text: shelvesPerRack.toString(),
        );
        final posController = TextEditingController(
          text: positionsPerShelf.toString(),
        );

        return AlertDialog(
          title: Text('Configure Warehouse Layout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter the dimensions for your warehouse layout:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: colController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Columns',
                    border: OutlineInputBorder(),
                    hintText: 'Number of columns',
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: rackController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Racks per Column',
                    border: OutlineInputBorder(),
                    hintText: 'Number of racks in each column',
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: shelfController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Shelves per Rack',
                    border: OutlineInputBorder(),
                    hintText: 'Number of shelves in each rack',
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: posController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Positions per Shelf',
                    border: OutlineInputBorder(),
                    hintText: 'Number of positions on each shelf',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  () => Navigator.pop(context, {
                    'columns': columns!,
                    'racks': racksPerColumn!,
                    'shelves': shelvesPerRack!,
                    'positions': positionsPerShelf!,
                  }),
              child: Text('Use Defaults'),
            ),
            ElevatedButton(
              onPressed: () {
                final cols = int.tryParse(colController.text) ?? columns!;
                final racks =
                    int.tryParse(rackController.text) ?? racksPerColumn!;
                final shelves =
                    int.tryParse(shelfController.text) ?? shelvesPerRack!;
                final positions =
                    int.tryParse(posController.text) ?? positionsPerShelf!;

                Navigator.pop(context, {
                  'columns': cols,
                  'racks': racks,
                  'shelves': shelves,
                  'positions': positions,
                });
              },
              child: Text('Apply'),
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

      // Also save to Appwrite database
      try {
        await widget.appwriteService.saveWarehouseSettings(
          columns: result['columns']!,
          racksPerColumn: result['racks']!,
          shelvesPerRack: result['shelves']!,
          positionsPerShelf: result['positions']!,
        );
      } catch (e) {
        print('Warning: Could not save settings to database: $e');
      }

      setState(() {
        columns = result['columns'];
        racksPerColumn = result['racks'];
        shelvesPerRack = result['shelves'];
        positionsPerShelf = result['positions'];
      });
    }
  }

  Color _getProductStatusColor(Product? product) {
    if (product == null) return Colors.green.shade100;

    final status = product.expiryStatus;
    switch (status) {
      case ExpiryStatus.good:
        return Colors.green.shade200;
      case ExpiryStatus.warning:
        return Colors.yellow.shade200;
      case ExpiryStatus.critical:
        return Colors.orange.shade200;
      case ExpiryStatus.expired:
        return Colors.red.shade200;
    }
  }

  Widget _buildPositionTile(String shelfKey, Product? shelfProduct) {
    final bgColor = _getProductStatusColor(shelfProduct);

    return GestureDetector(
      onTap: () async {
        if (shelfProduct == null) {
          // Add new product
          final result = await showProductDialog(
            context,
            shelfKey,
            _productMap,
          );
          if (result != null) {
            // Save to database
            try {
              await widget.appwriteService.saveProduct(result);

              // Update local state
              setState(() {
                _productMap[shelfKey] = result;
              });

              widget.onProductUpdated(shelfKey, result);

              // Navigate to QR generator screen
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GenerateQRScreen(product: result),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving product: $e')),
                );
              }
            }
          }
        } else {
          // Show existing product details
          _showProductDetails(shelfProduct, shelfKey);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.black26, width: 1),
          borderRadius: BorderRadius.circular(6),
          boxShadow:
              shelfProduct != null
                  ? [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ]
                  : null,
        ),
        padding: EdgeInsets.all(4),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shelfProduct?.name ?? 'Empty',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      shelfProduct != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (shelfProduct != null) ...[
                SizedBox(height: 2),
                Text(
                  shelfProduct.expiryDate.toLocal().toString().split(' ')[0],
                  style: TextStyle(fontSize: 8, color: Colors.black87),
                ),
                Text(
                  '${shelfProduct.weight.toStringAsFixed(1)} kg',
                  style: TextStyle(fontSize: 7, color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDetails(Product product, String location) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              product.name,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Weight',
                    '${product.weight.toStringAsFixed(2)} kg',
                  ),
                  _buildDetailRow(
                    'Entry Date',
                    product.entryDate.toLocal().toString().split(' ')[0],
                  ),
                  _buildDetailRow(
                    'Expiry Date',
                    product.expiryDate.toLocal().toString().split(' ')[0],
                  ),
                  _buildDetailRow('Location', location),
                  _buildDetailRow('Status', product.expiryStatus.displayName),
                  _buildDetailRow('All Locations', product.formattedLocations),
                  if (product.qrUrl != null && product.qrUrl!.isNotEmpty)
                    _buildDetailRow('QR Code', 'Available'),
                ],
              ),
            ),
            actions: [
              if (product.qrUrl != null && product.qrUrl!.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => GenerateQRScreen(product: product),
                      ),
                    );
                  },
                  child: Text('View QR'),
                ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: Text('Delete Product'),
                          content: Text(
                            'Are you sure you want to delete "${product.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                  );

                  if (confirm == true) {
                    try {
                      await widget.appwriteService.deleteProduct(product.id);
                      setState(() {
                        _productMap.removeWhere(
                          (key, value) => value.id == product.id,
                        );
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Product deleted successfully'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error deleting product: $e')),
                        );
                      }
                    }
                  }
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading Warehouse'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading warehouse data...'),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (columns == null ||
        racksPerColumn == null ||
        shelvesPerRack == null ||
        positionsPerShelf == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Configuration Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Invalid warehouse configuration'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _askForLayout,
                child: Text('Configure Layout'),
              ),
            ],
          ),
        ),
      );
    }

    final totalProducts = _productMap.length;
    final totalPositions =
        columns! * racksPerColumn! * shelvesPerRack! * positionsPerShelf!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Warehouse Layout'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadProductsFromDatabase();
            },
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _askForLayout,
            tooltip: 'Configure Layout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Bar
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('Products: $totalProducts'),
                Text('Capacity: $totalPositions'),
                Text('Free: ${totalPositions - totalProducts}'),
                Text(
                  'Usage: ${((totalProducts / totalPositions) * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
          // Legend
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Colors.green.shade200, 'Good'),
                _buildLegendItem(Colors.yellow.shade200, 'Warning'),
                _buildLegendItem(Colors.orange.shade200, 'Critical'),
                _buildLegendItem(Colors.red.shade200, 'Expired'),
                _buildLegendItem(Colors.green.shade100, 'Empty'),
              ],
            ),
          ),
          Divider(height: 1),
          // Warehouse Layout
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: columns,
                itemBuilder: (context, colIndex) {
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Column ${colIndex + 1}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Shelf ${shelfIndex + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        GridView.builder(
                                          physics:
                                              NeverScrollableScrollPhysics(),
                                          shrinkWrap: true,
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount:
                                                    positionsPerShelf!,
                                                crossAxisSpacing: 4,
                                                mainAxisSpacing: 4,
                                                childAspectRatio: 1.0,
                                              ),
                                          itemCount: positionsPerShelf!,
                                          itemBuilder: (
                                            context,
                                            positionIndex,
                                          ) {
                                            final shelfKey =
                                                'C${colIndex + 1}-R${rackIndex + 1}-S${shelfIndex + 1}-P${positionIndex + 1}';
                                            final shelfProduct =
                                                _productMap[shelfKey];

                                            return _buildPositionTile(
                                              shelfKey,
                                              shelfProduct,
                                            );
                                          },
                                        ),
                                      ],
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isLoading = true;
          });
          _loadProductsFromDatabase();
        },
        child: Icon(Icons.refresh),
        tooltip: 'Refresh Data',
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10)),
      ],
    );
  }
}
