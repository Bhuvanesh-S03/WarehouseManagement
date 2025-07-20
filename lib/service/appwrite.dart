import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

/// Service class to handle all Appwrite operations
class AppwriteService {
  // ✅ Initialize Appwrite client
  final Client client = Client()
      .setEndpoint('https://cloud.appwrite.io/v1') // Appwrite Cloud endpoint
      .setProject('687bc7e3001a688c12aa'); // Your Appwrite Project ID

  late final Databases db;
  late final Storage storage;

  AppwriteService() {
    db = Databases(client);
    storage = Storage(client);
  }

  /// Save product details to Appwrite database
  Future<void> saveProduct(Map<String, dynamic> data, String docId) async {
    try {
      await db.createDocument(
        databaseId: 'default', // Or your actual DB ID
        collectionId: 'Products', // Your collection ID
        documentId: docId, // Unique document ID
        data: data, // Product details
      );
      print('✅ Product saved');
    } on AppwriteException catch (e) {
      print('❌ Error saving product: ${e.message}');
      rethrow;
    }
  }

  /// Upload a QR image file to Appwrite Storage and get its viewable URL
  Future<String> uploadQR(File file, String fileName) async {
    try {
      final result = await storage.createFile(
        bucketId: 'qrcodes', // Your bucket ID
        fileId: fileName, // Can also use ID.unique()
        file: InputFile.fromPath(path: file.path),
      );

      // Return a viewable URL for displaying the QR
      return 'https://cloud.appwrite.io/v1/storage/buckets/qrcodes/files/${result.$id}/view?project=687bc7e3001a688c12aa';
    } on AppwriteException catch (e) {
      print('❌ Error uploading QR: ${e.message}');
      rethrow;
    }
  }
}
