import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:warehouse_manager/model/product_model.dart';
import 'package:warehouse_manager/service/Qr_genration.dart';
import 'package:warehouse_manager/service/appwrite.dart';
import 'package:warehouse_manager/widget/show_dialog.dart';

class LoadingPage extends StatefulWidget {
  final Map<String, Product> productMap;
  final Function(String, Product) onProductUpdated;
  final Map<String, int> warehouseSettings;
  final AppwriteService appwriteService;

  const LoadingPage({
    super.key,
    required this.productMap,
    required this.onProductUpdated,
    required this.warehouseSettings,
    required this.appwriteService,
  });

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
    if (widget.warehouseSettings.isNotEmpty) {
      setState(() {
        columns = widget.warehouseSettings['columns'];
        racksPerColumn = widget.warehouseSettings['racks_per_column'];
        shelvesPerRack = widget.warehouseSettings['shelves_per_rack'];
        positionsPerShelf = widget.warehouseSettings['positions_per_shelf'];
      });
      return;
    }

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
      final products = await widget.appwriteService.getAllProducts();
      Map<String, Product> locationProductMap = {};
      for (final product in products) {
        for (final location in product.locations!) {
          locationProductMap[location] = product;
        }
      }
      setState(() {
        _productMap = locationProductMap;
      });
      for (final entry in locationProductMap.entries) {
        widget.onProductUpdated(entry.key, entry.value);
      }
      print('✅ Loaded ${products.length} products from database');
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading products: $e';
      });
      print('❌ Error loading products: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Error Loading Products'),
                content: Text('Failed to load products from database: $e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadProductsFromDatabase();
                    },
                    child: const Text('Retry'),
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
      barrierDismissible: false,
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
          title: const Text('Configure Warehouse Layout'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter the dimensions for your warehouse layout:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: colController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Columns',
                    border: OutlineInputBorder(),
                    hintText: 'Number of columns',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: rackController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Racks per Column',
                    border: OutlineInputBorder(),
                    hintText: 'Number of racks in each column',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: shelfController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Shelves per Rack',
                    border: OutlineInputBorder(),
                    hintText: 'Number of shelves in each rack',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: posController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
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
              child: const Text('Use Defaults'),
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
              child: const Text('Apply'),
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
    if (product == null) {
      return Colors.grey.shade200; // Empty slots are grey
    }

    if (product.expiryDate != null) {
      final daysUntilExpiry =
          product.expiryDate!.difference(DateTime.now()).inDays;
      if (daysUntilExpiry < 0) {
        return Colors.red.shade200; // Expired items are red
      }
      if (daysUntilExpiry <= 90) {
        return Colors.yellow.shade200; // Soon expiring are yellow
      }
    }

    return Colors.green.shade200; // All other loaded items are green
  }

  Widget _buildPositionTile(String shelfKey, Product? shelfProduct) {
    final bgColor = _getProductStatusColor(shelfProduct);

    return GestureDetector(
      onTap: () async {
        if (shelfProduct == null) {
          final newProduct = await showProductDialog(
            context,
            shelfKey,
            _productMap,
          );
          if (newProduct != null) {
            try {
              final savedProduct = await widget.appwriteService.saveProduct(
                newProduct,
              );
              setState(() {
                _productMap[shelfKey] = savedProduct;
              });
              widget.onProductUpdated(shelfKey, savedProduct);
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => GenerateQRScreen(
                          product: savedProduct,
                          appwriteService: widget.appwriteService,
                        ),
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
                    const BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ]
                  : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shelfProduct?.name ?? 'Empty',
                style: TextStyle(
                  fontSize: 12,
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
                const SizedBox(height: 2),
                Text(
                  shelfProduct.expiryDate?.toLocal().toString().split(' ')[0] ??
                      'N/A',
                  style: const TextStyle(fontSize: 10, color: Colors.black87),
                ),
                Text(
                  '${shelfProduct.weight?.toStringAsFixed(1) ?? 'N/A'} kg',
                  style: const TextStyle(fontSize: 9, color: Colors.black54),
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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Weight',
                    '${product.weight?.toStringAsFixed(2) ?? 'N/A'} kg',
                  ),
                  _buildDetailRow(
                    'Entry Date',
                    product.entryDate?.toLocal().toString().split(' ')[0] ??
                        'N/A',
                  ),
                  _buildDetailRow(
                    'Expiry Date',
                    product.expiryDate?.toLocal().toString().split(' ')[0] ??
                        'N/A',
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
                            (context) => GenerateQRScreen(
                              product: product,
                              appwriteService: widget.appwriteService,
                            ),
                      ),
                    );
                  },
                  child: const Text('View QR'),
                ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text('Delete Product'),
                          content: Text(
                            'Are you sure you want to delete "${product.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('Delete'),
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
                          const SnackBar(
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
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
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
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Warehouse'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading warehouse data...'),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
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
        appBar: AppBar(title: const Text('Configuration Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Invalid warehouse configuration'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _askForLayout,
                child: const Text('Configure Layout'),
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
        title: const Text('Warehouse Layout'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadProductsFromDatabase();
            },
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _askForLayout,
            tooltip: 'Configure Layout',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(Colors.green.shade200, 'Good'),
                _buildLegendItem(Colors.yellow.shade200, 'Warning'),
                _buildLegendItem(Colors.orange.shade200, 'Critical'),
                _buildLegendItem(Colors.red.shade200, 'Expired'),
                _buildLegendItem(Colors.grey.shade200, 'Empty'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: columns,
                itemBuilder: (context, colIndex) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(8),
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
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(racksPerColumn!, (rackIndex) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(8),
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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                        const SizedBox(height: 4),
                                        GridView.builder(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'refresh_button',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadProductsFromDatabase();
            },
            tooltip: 'Refresh Data',
            mini: true,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 10),
        ],
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
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}
