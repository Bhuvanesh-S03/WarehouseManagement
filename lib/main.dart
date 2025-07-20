import 'package:flutter/material.dart';

import 'package:warehouse_manager/model/product_model.dart';
import 'package:warehouse_manager/screens/home_screen.dart';
import 'package:warehouse_manager/screens/setting.dart';

import 'package:warehouse_manager/service/loading.dart';

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

  @override
  void initState() {
    super.initState();
    // Initialize Appwrite service

    _loadInitialProducts();
  }

  Future<void> _loadInitialProducts() async {
    try {
      // Example: Load products from Appwrite
      // final products = await _appwriteService.getProducts();
      // setState(() => _productMap.addAll(products));
    } catch (e) {
      debugPrint('Initial load error: $e');
    }
  }

  void _updateProduct(String key, Product product) {
    setState(() {
      _productMap[key] = product;
    });
  }

  @override
  Widget build(BuildContext context) {
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
    );
  }

  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return HomePage(
          productMap: _productMap,
          onProductUpdated: _updateProduct,
        );
      case 1:
        return LoadingPage(
          productMap: _productMap,
          onProductUpdated: _updateProduct,
        );
      case 2:
        return const Center(
          child: Text("Unload (Coming Soon)", style: TextStyle(fontSize: 18)),
        );
      case 3:
        return SettingsPage(
          initialRows: 3,
          initialColumns: 2,
          initialShelves: 4,
          onSettingsUpdated: (_) {},
        );
      default:
        return HomePage(
          productMap: _productMap,
          onProductUpdated: _updateProduct,
        );
    }
  }
}
