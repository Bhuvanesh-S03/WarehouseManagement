import 'dart:io';
import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import '../model/product_model.dart';
import 'package:uuid/uuid.dart';

class AppwriteService {
  final Client client = Client()
      .setEndpoint('https://nyc.cloud.appwrite.io/v1')
      .setProject('687bc7e3001a688c12aa');

  late final Databases db;
  late final Storage storage;

  static const String databaseId = '687c42240030c078e176';
  static const String productsCollectionId = '687c423200186f51fe44';
  static const String qrBucketId = '687c472b0021c89655b8';
  static const String settingsCollectionId = 'settings';

  AppwriteService() {
    db = Databases(client);
    storage = Storage(client);
  }

  Future<Product> saveProduct(Product product) async {
    try {
      final data = product.toDocument();
      final result = await db.createDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: ID.unique(),
        data: data,
      );

      print('✅ Product saved with ID: ${result.$id}');

      return product.copyWith(
        id: result.$id,
        locations: _parseLocations(result.data['locations']),
      );
    } on AppwriteException catch (e) {
      print('❌ Error saving product: ${e.message} (Code: ${e.code})');
      rethrow;
    }
  }

  // NEW: A method to update an existing product
  Future<void> updateProduct(Product product) async {
    try {
      final data = product.toDocument();
      await db.updateDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: product.id,
        data: data,
      );
      print('✅ Product updated with ID: ${product.id}');
    } on AppwriteException catch (e) {
      print('❌ Error updating product: ${e.message} (Code: ${e.code})');
      rethrow;
    }
  }

  Future<void> updateProductQRUrl(
    String documentId,
    String qrUrl,
    String qrFileId,
  ) async {
    try {
      final updateData = {'qr_url': qrUrl};

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

  Future<Map<String, Product>> getAllProductsAsMap() async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
      );

      Map<String, Product> productMap = {};

      for (final doc in response.documents) {
        try {
          final product = Product.fromDocument(doc.data, doc.$id);
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

  List<String> _parseLocations(dynamic locations) {
    if (locations == null) return [];
    if (locations is List) return locations.map((e) => e.toString()).toList();
    if (locations is String) return [locations];
    return [locations.toString()];
  }

  Future<List<Product>> getAllProducts() async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
      );

      return response.documents.map((doc) {
        try {
          return Product.fromDocument(doc.data, doc.$id);
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
          );
        }
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error fetching products: ${e.message}');
      return [];
    }
  }

  Future<List<Product>> getProductsByLocation(String location) async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        queries: [Query.search('locations', location)],
      );

      return response.documents.map((doc) {
        return Product.fromDocument(doc.data, doc.$id);
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error fetching products by location: ${e.message}');
      return [];
    }
  }

  Future<List<Product>> getExpiringProducts(int daysFromNow) async {
    try {
      final cutoffDate = DateTime.now().add(Duration(days: daysFromNow));

      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        queries: [Query.lessThan('expiry_date', cutoffDate.toIso8601String())],
      );

      return response.documents.map((doc) {
        return Product.fromDocument(doc.data, doc.$id);
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error fetching expiring products: ${e.message}');
      return [];
    }
  }

  Future<void> deleteProduct(String documentId) async {
    try {
      final product = await db.getDocument(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        documentId: documentId,
      );
      final qrFileId = product.data['qr_file_id'];
      if (qrFileId != null && qrFileId.isNotEmpty) {
        try {
          await storage.deleteFile(bucketId: qrBucketId, fileId: qrFileId);
          print('✅ QR file deleted');
        } catch (e) {
          print('⚠️ Could not delete QR file: $e');
        }
      }
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

  Future<Map<String, String>> uploadQRCode(File file, String fileName) async {
    try {
      final result = await storage.createFile(
        bucketId: qrBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path, filename: fileName),
      );

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
      await db.createDocument(
        databaseId: databaseId,
        collectionId: settingsCollectionId,
        documentId: 'warehouse_layout',
        data: data,
      );
      print('✅ Warehouse settings saved');
    } on AppwriteException catch (e) {
      if (e.code == 409) {
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

  Future<List<Product>> searchProducts(String query) async {
    try {
      final response = await db.listDocuments(
        databaseId: databaseId,
        collectionId: productsCollectionId,
        queries: [Query.search('name', query)],
      );

      return response.documents.map((doc) {
        return Product.fromDocument(doc.data, doc.$id);
      }).toList();
    } on AppwriteException catch (e) {
      print('❌ Error searching products: ${e.message}');
      return [];
    }
  }
}
