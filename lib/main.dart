import 'package:flutter/material.dart';

import 'package:warehouse_manager/model/product_model.dart';
import 'package:warehouse_manager/screens/home_screen.dart';
import 'package:warehouse_manager/service/loading.dart';
import 'package:warehouse_manager/service/appwrite.dart';
import 'package:warehouse_manager/screens/unload_page.dart'; // NEW: Import the unload page

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warehouse Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const MainAppPage(),
    );
  }
}

class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  int _selectedIndex = 0;
  final Map<String, Product> _productMap = {};
  final AppwriteService _appwriteService = AppwriteService();
  bool _isLoading = true;
  Map<String, int> _warehouseSettings = {};

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _isLoading = true);

      final settings = await _appwriteService.getWarehouseSettings();
      if (settings != null) {
        setState(() => _warehouseSettings = settings);
      } else {
        setState(
          () =>
              _warehouseSettings = {
                'columns': 3,
                'racks_per_column': 3,
                'shelves_per_rack': 4,
                'positions_per_shelf': 4,
              },
        );
      }

      await _loadProductsFromDatabase();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(
        'Connection Error',
        'Failed to connect to database. Please check your internet connection and try again.\n\nError: ${e.toString()}',
      );
      debugPrint('App initialization error: $e');
    }
  }

  Future<void> _loadProductsFromDatabase() async {
    try {
      final products = await _appwriteService.getAllProducts();
      final Map<String, Product> productMap = {};

      for (final product in products) {
        for (final location in product.locations!) {
          productMap[location] = product;
        }
      }

      setState(() {
        _productMap.clear();
        _productMap.addAll(productMap);
      });
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  Future<void> _saveProductToDatabase(Product product) async {
    try {
      if (product.id.isEmpty) {
        await _appwriteService.saveProduct(product);
      } else {
        await _appwriteService.updateProduct(product);
      }
      await _loadProductsFromDatabase();
    } catch (e) {
      _showErrorDialog('Save Error', 'Failed to save product: $e');
    }
  }

  void _updateProduct(String key, Product product) async {
    setState(() {
      _productMap[key] = product;
    });
    await _saveProductToDatabase(product);
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateWarehouseSettings(Map<String, int> settings) async {
    try {
      await _appwriteService.saveWarehouseSettings(
        columns: settings['columns']!,
        racksPerColumn: settings['racks_per_column']!,
        shelvesPerRack: settings['shelves_per_rack']!,
        positionsPerShelf: settings['positions_per_shelf']!,
      );

      setState(() => _warehouseSettings = settings);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
    } catch (e) {
      _showErrorDialog('Settings Error', 'Failed to save settings: $e');
    }
  }

  Future<void> _refreshData() async {
    await _loadProductsFromDatabase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing Warehouse Manager...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: _buildCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Load"),
          BottomNavigationBarItem(
            icon: Icon(Icons.remove_circle),
            label: "Unload",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
      floatingActionButton:
          _selectedIndex == 0
              ? FloatingActionButton(
                onPressed: _refreshData,
                tooltip: 'Refresh Data',
                child: const Icon(Icons.refresh),
              )
              : null,
    );
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return HomePage(
          productMap: _productMap,
          onProductUpdated: _updateProduct,
          appwriteService: _appwriteService,
        );
      case 1:
        return LoadingPage(
          productMap: _productMap,
          onProductUpdated: _updateProduct,
          warehouseSettings: _warehouseSettings,
          appwriteService: _appwriteService,
        );
      case 2:
        return UnloadPage(
          appwriteService: _appwriteService,
          onUnload: (String productId) {
            _loadProductsFromDatabase(); // Refresh all data
          },
        );
      case 3:
        return const Center(child: Text("Settings Page Placeholder"));
      default:
        return HomePage(
          productMap: _productMap,
          onProductUpdated: _updateProduct,
          appwriteService: _appwriteService,
        );
    }
  }
}
