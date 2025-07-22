import 'dart:io';
import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../model/product_model.dart';

/// Service class to handle all Appwrite operations (SDK 17.0.2 compatible)
class AppwriteService {
  // Initialize Appwrite client
  final Client client = Client()
      .setEndpoint('https://nyc.cloud.appwrite.io/v1') // Appwrite Cloud endpoint
      .setProject('687bc7e3001a688c12aa'); // Your Appwrite Project ID

  late final Databases db;
  late final Storage storage;

  // Database and Collection IDs
  static const String databaseId = '687c42240030c078e176';
  static const String productsCollectionId = '687c423200186f51fe44';
  static const String qrBucketId = '687c472b0021c89655b8';
  static const String settingsCollectionId = 'settings';

  AppwriteService() {
    db = Databases(client);
    storage = Storage(client);
  }

  /// Save product details to Appwrite database with QR code
  Future<String> saveProductWithQR(Product product, File? qrFile) async {
    try {
      String? qrUrl;
      String? qrFileId;

      // Upload QR code first if provided
      if (qrFile != null) {
        final qrUploadResult = await uploadQRCode(
          qrFile,
          'QR_${product.name}_${DateTime.now().millisecondsSinceEpoch}.png',
        );
        qrUrl = qrUploadResult['url'];
        qrFileId = qrUploadResult['fileId'];
      }

      final data = {
        'name': product.name,
        'weight': product.weight,
        'entry_date': product.entryDate.toIso8601String(),
        'expiry_date': product.expiryDate.toIso8601String(),
        'locations': product.locations,
        'color_code': product.colorCode,
        'qr_url': qrUrl ?? '',
        'qr_file_id': qrFileId ?? '',
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
      print('❌ Error saving product: ${e.message} (Code: ${e.code})');
      rethrow;
    }
  }

  /// Save product details to Appwrite database
  Future<Product> saveProduct(Product product) async {
    try {
      final data = {
        'name': product.name,
        'weight': product.weight,
        'entry_date': product.entryDate.toIso8601String(),
        'expiry_date': product.expiryDate.toIso8601String(),
        'locations': product.locations,
        'color_code': product.colorCode,
      };

      final result = await db.createDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: ID.unique(),
        data: data,
      );

      // Return the complete product with the new ID
      return Product(
        id: result.$id,
        name: result.data['name'],
        weight: result.data['weight'].toDouble(),
        entryDate: DateTime.parse(result.data['entry_date']),
        expiryDate: DateTime.parse(result.data['expiry_date']),
        locations: List<String>.from(result.data['locations']),
        colorCode: result.data['color_code'],
        qrUrl: result.data['qr_url'] ?? '',
      );
    } on AppwriteException catch (e) {
      print('Error saving product: ${e.message}');
      rethrow;
    }
  }

  /// Update product with QR URL and file ID
  Future<void> updateProductQRUrl(
    String documentId,
    String qrUrl, {
    String? qrFileId,
  }) async {
    try {
      final updateData = {'qr_url': qrUrl};
      if (qrFileId != null) {
        updateData['qr_file_id'] = qrFileId;
      }

      await db.updateDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: documentId,
        data: updateData,
      );
      print('✅ Product QR URL updated');
    } on AppwriteException catch (e) {
      print('❌ Error updating product QR URL: ${e.message}');
      rethrow;
    }
  }

  /// Get all products from database and return as a map with location keys
  Future<Map<String, Product>> getAllProductsAsMap() async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
      );

      Map<String, Product> productMap = {};

      for (final doc in response.documents) {
        try {
          final product = Product(
            id: doc.$id,
            name: doc.data['name'] ?? '',
            weight: (doc.data['weight'] as num?)?.toDouble() ?? 0.0,
            entryDate:
                doc.data['entry_date'] != null
                    ? DateTime.parse(doc.data['entry_date'])
                    : DateTime.now(),
            expiryDate:
                doc.data['expiry_date'] != null
                    ? DateTime.parse(doc.data['expiry_date'])
                    : DateTime.now(),
            locations: _parseLocations(doc.data['locations']),
            colorCode: doc.data['color_code'] ?? 0,
            qrUrl: doc.data['qr_url'] ?? '',
          );

          // Map product to all its locations
          for (final location in product.locations) {
            productMap[location] = product;
          }
        } catch (e) {
          print('Error parsing product ${doc.$id}: $e');
          continue;
        }
      }

      print('✅ Loaded ${productMap.length} product locations');
      return productMap;
    } on AppwriteException catch (e) {
      print('❌ Error fetching products: ${e.message}');
      return {};
    }
  }

  /// Helper method to parse locations from database
  List<String> _parseLocations(dynamic locations) {
    if (locations == null) return [];

    if (locations is List) {
      return locations.map((e) => e.toString()).toList();
    }

    if (locations is String) {
      return locations.split(',').map((e) => e.trim()).toList();
    }

    return [locations.toString()];
  }

  /// Get all products from database
  Future<List<Product>> getAllProducts() async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
      );

      return response.documents.map((doc) {
        try {
          return Product(
            id: doc.$id,
            name: doc.data['name'] ?? '',
            weight: (doc.data['weight'] as num?)?.toDouble() ?? 0.0,
            entryDate:
                doc.data['entry_date'] != null
                    ? DateTime.parse(doc.data['entry_date'])
                    : DateTime.now(),
            expiryDate:
                doc.data['expiry_date'] != null
                    ? DateTime.parse(doc.data['expiry_date'])
                    : DateTime.now(),
            locations: _parseLocations(doc.data['locations']),
            colorCode: doc.data['color_code'] ?? 0,
            qrUrl: doc.data['qr_url'] ?? '',
          );
        } catch (e) {
          print('Error parsing product ${doc.$id}: $e');
          return Product(
            id: doc.$id,
            name: 'Error Product',
            weight: 0.0,
            entryDate: DateTime.now(),
            expiryDate: DateTime.now(),
            locations: [],
            colorCode: 0,
            qrUrl: '',
          );
        }
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
        queries: [Query.search('locations', location)],
      );

      return response.documents.map((doc) {
        return Product(
          id: doc.$id,
          name: doc.data['name'] ?? '',
          weight: (doc.data['weight'] as num?)?.toDouble() ?? 0.0,
          entryDate:
              doc.data['entry_date'] != null
                  ? DateTime.parse(doc.data['entry_date'])
                  : DateTime.now(),
          expiryDate:
              doc.data['expiry_date'] != null
                  ? DateTime.parse(doc.data['expiry_date'])
                  : DateTime.now(),
          locations: _parseLocations(doc.data['locations']),
          colorCode: doc.data['color_code'] ?? 0,
          qrUrl: doc.data['qr_url'] ?? '',
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
        queries: [Query.lessThan('expiry_date', cutoffDate.toIso8601String())],
      );

      return response.documents.map((doc) {
        return Product(
          id: doc.$id,
          name: doc.data['name'] ?? '',
          weight: (doc.data['weight'] as num?)?.toDouble() ?? 0.0,
          entryDate:
              doc.data['entry_date'] != null
                  ? DateTime.parse(doc.data['entry_date'])
                  : DateTime.now(),
          expiryDate:
              doc.data['expiry_date'] != null
                  ? DateTime.parse(doc.data['expiry_date'])
                  : DateTime.now(),
          locations: _parseLocations(doc.data['locations']),
          colorCode: doc.data['color_code'] ?? 0,
          qrUrl: doc.data['qr_url'] ?? '',
        );
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error fetching expiring products: ${e.message}');
      return [];
    }
  }

  /// Delete a product and its QR code
  Future<void> deleteProduct(String documentId) async {
    try {
      // First get the product to find QR file ID
      final product = await db.getDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: documentId,
      );

      // Delete QR file if it exists
      final qrFileId = product.data['qr_file_id'];
      if (qrFileId != null && qrFileId.isNotEmpty) {
        try {
          await storage.deleteFile(bucketId: qrBucketId, fileId: qrFileId);
          print('✅ QR file deleted');
        } catch (e) {
          print('⚠️ Could not delete QR file: $e');
        }
      }

      // Delete the product document
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

  /// Upload QR code image and return its URL and file ID
  Future<Map<String, String>> uploadQRCode(File file, String fileName) async {
    try {
      final result = await storage.createFile(
        bucketId: qrBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path, filename: fileName),
      );

      // Return a viewable URL
      final fileUrl = storage.getFileView(
        bucketId: qrBucketId,
        fileId: result.$id,
      );

      print('✅ QR code uploaded: $fileUrl');
      return {'url': fileUrl.toString(), 'fileId': result.$id};
    } on AppwriteException catch (e) {
      print('❌ Error uploading QR code: ${e.message}');
      rethrow;
    }
  }

  /// Download QR code file
  Future<Uint8List?> downloadQRCode(String fileId) async {
    try {
      final result = await storage.getFileDownload(
        bucketId: qrBucketId,
        fileId: fileId,
      );
      print('✅ QR code downloaded');
      return result;
    } on AppwriteException catch (e) {
      print('❌ Error downloading QR code: ${e.message}');
      return null;
    }
  }

  /// Save warehouse layout settings
  /// Save warehouse layout settings
  Future<void> saveWarehouseSettings({
    required int columns,
    required int racksPerColumn,
    required int shelvesPerRack,
    required int positionsPerShelf,
  }) async {
    final data = {
      'columns': columns,
      'racks_per_column': racksPerColumn,
      'shelves_per_rack': shelvesPerRack,
      'positions_per_shelf': positionsPerShelf,
    };

    try {
      // First try to create the document
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
        try {
          await db.updateDocument(
            databaseId: databaseId,
            collectionId: settingsCollectionId,
            documentId: 'warehouse_layout',
            data: data,
          );
          print('✅ Warehouse settings updated');
        } on AppwriteException catch (updateError) {
          print('❌ Error updating warehouse settings: ${updateError.message}');
          rethrow;
        }
      } else {
        print('❌ Error saving warehouse settings: ${e.message}');
        rethrow;
      }
    } catch (e) {
      print('❌ Unexpected error in saveWarehouseSettings: $e');
      rethrow;
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
        'columns': response.data['columns'] ?? 3,
        'racks_per_column': response.data['racks_per_column'] ?? 3,
        'shelves_per_rack': response.data['shelves_per_rack'] ?? 4,
        'positions_per_shelf': response.data['positions_per_shelf'] ?? 4,
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
        queries: [Query.search('name', query)],
      );

      return response.documents.map((doc) {
        return Product(
          id: doc.$id,
          name: doc.data['name'] ?? '',
          weight: (doc.data['weight'] as num?)?.toDouble() ?? 0.0,
          entryDate:
              doc.data['entry_date'] != null
                  ? DateTime.parse(doc.data['entry_date'])
                  : DateTime.now(),
          expiryDate:
              doc.data['expiry_date'] != null
                  ? DateTime.parse(doc.data['expiry_date'])
                  : DateTime.now(),
          locations: _parseLocations(doc.data['locations']),
          colorCode: doc.data['color_code'] ?? 0,
          qrUrl: doc.data['qr_url'] ?? '',
        );
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error searching products: ${e.message}');
      return [];
    }
  }
}
