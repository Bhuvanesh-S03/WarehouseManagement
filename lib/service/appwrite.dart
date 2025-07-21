import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../model/product_model.dart';

/// Enhanced service class to handle all Appwrite operations
class AppwriteService {
  // Initialize Appwrite client
  final Client client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1') // Appwrite Cloud endpoint
      .setProject('687bc7e3001a688c12aa'); // Your Appwrite Project ID

  late final Databases db;
  late final Storage storage;

  // Database and Collection IDs
  static const String databaseId = 'warehouse_db';
  static const String productsCollectionId = 'products';
  static const String settingsCollectionId = 'settings';
  static const String qrBucketId = 'qr_codes';

  AppwriteService() {
    db = Databases(client);
    storage = Storage(client);
  }

  /// Initialize the database and collections (call once during setup)
  Future<void> initializeDatabase() async {
    try {
      // Create database if it doesn't exist
      try {
        await db.get(databaseId: databaseId);
      } on AppwriteException catch (e) {
        if (e.code == 404) {
          await db.create(
            databaseId: databaseId,
            name: 'Warehouse Database',
          );
        }
      }

      // Create products collection
      try {
        await db.getCollection(
          databaseId: databaseId,
          collectionId: productsCollectionId,
        );
      } on AppwriteException catch (e) {
        if (e.code == 404) {
          await db.createCollection(
            databaseId: databaseId,
            collectionId: productsCollectionId,
            name: 'Products',
          );

          // Create attributes for the products collection
          await _createProductAttributes();
        }
      }

      // Create settings collection
      try {
        await db.getCollection(
          databaseId: databaseId,
          collectionId: settingsCollectionId,
        );
      } on AppwriteException catch (e) {
        if (e.code == 404) {
          await db.createCollection(
            databaseId: databaseId,
            collectionId: settingsCollectionId,
            name: 'Settings',
          );

          await _createSettingsAttributes();
        }
      }

      // Create storage bucket for QR codes
      try {
        await storage.getBucket(bucketId: qrBucketId);
      } on AppwriteException catch (e) {
        if (e.code == 404) {
          await storage.createBucket(
            bucketId: qrBucketId,
            name: 'QR Codes',
            permissions: [
              Permission.read(Role.any()),
              Permission.create(Role.any()),
              Permission.update(Role.any()),
              Permission.delete(Role.any()),
            ],
          );
        }
      }

      print('✅ Database initialized successfully');
    } on AppwriteException catch (e) {
      print('❌ Error initializing database: ${e.message}');
      rethrow;
    }
  }

  /// Create attributes for products collection
  Future<void> _createProductAttributes() async {
    final attributes = [
      {'key': 'name', 'type': 'string', 'size': 255, 'required': true},
      {'key': 'weight', 'type': 'double', 'required': true},
      {'key': 'entry_date', 'type': 'datetime', 'required': true},
      {'key': 'expiry_date', 'type': 'datetime', 'required': true},
      {'key': 'locations', 'type': 'array', 'required': true},
      {'key': 'color_code', 'type': 'integer', 'required': true},
      {'key': 'qr_url', 'type': 'string', 'size': 500, 'required': false},
    ];

    for (final attr in attributes) {
      try {
        switch (attr['type']) {
          case 'string':
            await db.createStringAttribute(
              databaseId: databaseId,
              collectionId: productsCollectionId,
              key: attr['key'] as String,
              size: attr['size'] as int,
              required: attr['required'] as bool,
            );
            break;
          case 'double':
            await db.createFloatAttribute(
              databaseId: databaseId,
              collectionId: productsCollectionId,
              key: attr['key'] as String,
              required: attr['required'] as bool,
            );
            break;
          case 'datetime':
            await db.createDatetimeAttribute(
              databaseId: databaseId,
              collectionId: productsCollectionId,
              key: attr['key'] as String,
              required: attr['required'] as bool,
            );
            break;
          case 'integer':
            await db.createIntegerAttribute(
              databaseId: databaseId,
              collectionId: productsCollectionId,
              key: attr['key'] as String,
              required: attr['required'] as bool,
            );
            break;
          case 'array':
            await db.createStringAttribute(
              databaseId: databaseId,
              collectionId: productsCollectionId,
              key: attr['key'] as String,
              size: 1000,
              required: attr['required'] as bool,
              isArray: true,
            );
            break;
        }
        
        // Add a small delay to avoid rate limiting
        await Future.delayed(Duration(milliseconds: 500));
      } on AppwriteException catch (e) {
        print('Warning: Could not create attribute ${attr['key']}: ${e.message}');
      }
    }
  }

  /// Create attributes for settings collection
  Future<void> _createSettingsAttributes() async {
    final attributes = [
      {'key': 'columns', 'type': 'integer', 'required': true},
      {'key': 'racks_per_column', 'type': 'integer', 'required': true},
      {'key': 'shelves_per_rack', 'type': 'integer', 'required': true},
      {'key': 'positions_per_shelf', 'type': 'integer', 'required': true},
    ];

    for (final attr in attributes) {
      try {
        await db.createIntegerAttribute(
          databaseId: databaseId,
          collectionId: settingsCollectionId,
          key: attr['key'] as String,
          required: attr['required'] as bool,
        );
        
        await Future.delayed(Duration(milliseconds: 500));
      } on AppwriteException catch (e) {
        print('Warning: Could not create setting attribute ${attr['key']}: ${e.message}');
      }
    }
  }

  /// Save product details to Appwrite database
  Future<String> saveProduct(Product product) async {
    try {
      final data = {
        'name': product.name,
        'weight': product.weight,
        'entry_date': product.entryDate.toIso8601String(),
        'expiry_date': product.expiryDate.toIso8601String(),
        'locations': product.locations,
        'color_code': product.colorCode,
        'qr_url': '', // Will be updated when QR is uploaded
      };

      final result = await db.createDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: ID.unique(),
        data: data,
      );

      print('✅ Product saved with ID: ${result.$id}');
      return result.$id;
    } on AppwriteException catch (e) {
      print('❌ Error saving product: ${e.message}');
      rethrow;
    }
  }

  /// Update product with QR URL
  Future<void> updateProductQRUrl(String documentId, String qrUrl) async {
    try {
      await db.updateDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: documentId,
        data: {'qr_url': qrUrl},
      );
      print('✅ Product QR URL updated');
    } on AppwriteException catch (e) {
      print('❌ Error updating product QR URL: ${e.message}');
      rethrow;
    }
  }

  /// Get all products from database
  Future<List<Product>> getAllProducts() async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
      );

      return response.documents.map((doc) {
        return Product(
          id: doc.$id,
          name: doc.data['name'],
          weight: (doc.data['weight'] as num).toDouble(),
          entryDate: DateTime.parse(doc.data['entry_date']),
          expiryDate: DateTime.parse(doc.data['expiry_date']),
          locations: List<String>.from(doc.data['locations']),
          colorCode: doc.data['color_code'],
        );
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error fetching products: ${e.message}');
      return [];
    }
  }

  /// Get products by location
  Future<List<Product>> getProductsByLocation(String location) async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        queries: [
          Query.search('locations', location),
        ],
      );

      return response.documents.map((doc) {
        return Product(
          id: doc.$id,
          name: doc.data['name'],
          weight: (doc.data['weight'] as num).toDouble(),
          entryDate: DateTime.parse(doc.data['entry_date']),
          expiryDate: DateTime.parse(doc.data['expiry_date']),
          locations: List<String>.from(doc.data['locations']),
          colorCode: doc.data['color_code'],
        );
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error fetching products by location: ${e.message}');
      return [];
    }
  }

  /// Get products expiring soon (within specified days)
  Future<List<Product>> getExpiringProducts(int daysFromNow) async {
    try {
      final cutoffDate = DateTime.now().add(Duration(days: daysFromNow));
      
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        queries: [
          Query.lessThan('expiry_date', cutoffDate.toIso8601String()),
        ],
      );

      return response.documents.map((doc) {
        return Product(
          id: doc.$id,
          name: doc.data['name'],
          weight: (doc.data['weight'] as num).toDouble(),
          entryDate: DateTime.parse(doc.data['entry_date']),
          expiryDate: DateTime.parse(doc.data['expiry_date']),
          locations: List<String>.from(doc.data['locations']),
          colorCode: doc.data['color_code'],
        );
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error fetching expiring products: ${e.message}');
      return [];
    }
  }

  /// Delete a product
  Future<void> deleteProduct(String documentId) async {
    try {
      await db.deleteDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: documentId,
      );
      print('✅ Product deleted');
    } on AppwriteException catch (e) {
      print('❌ Error deleting product: ${e.message}');
      rethrow;
    }
  }

  /// Upload QR code image and return its URL
  Future<String> uploadQRCode(File file, String fileName) async {
    try {
      final result = await storage.createFile(
        bucketId: qrBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path),
      );

      // Return a viewable URL
      final fileUrl = 'https://cloud.appwrite.io/v1/storage/buckets/$qrBucketId/files/${result.$id}/view?project=687bc7e3001a688c12aa';
      
      print('✅ QR code uploaded: $fileUrl');
      return fileUrl;
    } on AppwriteException catch (e) {
      print('❌ Error uploading QR code: ${e.message}');
      rethrow;
    }
  }

  /// Save warehouse layout settings
  Future<void> saveWarehouseSettings({
    required int columns,
    required int racksPerColumn,
    required int shelvesPerRack,
    required int positionsPerShelf,
  }) async {
    try {
      final data = {
        'columns': columns,
        'racks_per_column': racksPerColumn,
        'shelves_per_rack': shelvesPerRack,
        'positions_per_shelf': positionsPerShelf,
      };

      await db.createDocument(
        databaseId: databaseId,
        collectionId: settingsCollectionId,
        documentId: 'warehouse_layout',
        data: data,
      );

      print('✅ Warehouse settings saved');
    } on AppwriteException catch (e) {
      if (e.code == 409) {
        // Document exists, update it
        await db.updateDocument(
          databaseId: databaseId,
          collectionId: settingsCollectionId,
          documentId: 'warehouse_layout',
          data: data,
        );
        print('✅ Warehouse settings updated');
      } else {
        print('❌ Error saving warehouse settings: ${e.message}');
        rethrow;
      }
    }
  }

  /// Get warehouse layout settings
  Future<Map<String, int>?> getWarehouseSettings() async {
    try {
      final response = await db.getDocument(
        databaseId: databaseId,
        collectionId: settingsCollectionId,
        documentId: 'warehouse_layout',
      );

      return {
        'columns': response.data['columns'],
        'racks_per_column': response.data['racks_per_column'],
        'shelves_per_rack': response.data['shelves_per_rack'],
        'positions_per_shelf': response.data['positions_per_shelf'],
      };
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        print('No warehouse settings found');
        return null;
      }
      print('❌ Error fetching warehouse settings: ${e.message}');
      return null;
    }
  }

  /// Search products by name
  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        queries: [
          Query.search('name', query),
        ],
      );

      return response.documents.map((doc) {
        return Product(
          id: doc.$id,
          name: doc.data['name'],
          weight: (doc.data['weight'] as num).toDouble(),
          entryDate: DateTime.parse(doc.data['entry_date']),
          expiryDate: DateTime.parse(doc.data['expiry_date']),
          locations: List<String>.from(doc.data['locations']),
          colorCode: doc.data['color_code'],
        );
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error searching products: ${e.message}');
      return [];
    }
  }
}