import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:warehouse_manager/service/appwrite.dart' show AppwriteService;

import '../model/product_model.dart';

class GenerateQRScreen extends StatefulWidget {
  final Product product;
  

  const GenerateQRScreen({super.key, required this.product});

  @override
  State<GenerateQRScreen> createState() => _GenerateQRScreenState();
}

class _GenerateQRScreenState extends State<GenerateQRScreen> {
  final GlobalKey globalKey = GlobalKey();
  bool isUploading = false;
  final AppwriteService _appwriteService = AppwriteService();


  
  Future<Uint8List?> _captureQR() async {
    try {
      RenderRepaintBoundary boundary =
          globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print("QR Capture Error: $e");
      return null;
    }
  }

  Future<void> _saveToAppwrite() async {
    setState(() => isUploading = true);

    final qrImage = await _captureQR();
    if (qrImage == null) return;

    final tempDir = await getTemporaryDirectory();
    final fileName = '${widget.product.id}.png';
    final file = await File('${tempDir.path}/$fileName').writeAsBytes(qrImage);

    try {
      final publicUrl = await _appwriteService.uploadQR(file, fileName);

      final data = {
        'id': widget.product.id,
        'name': widget.product.name,
        'weight': widget.product.weight,
        'entry_date': widget.product.entryDate.toIso8601String(),
        'expiry_date': widget.product.expiryDate.toIso8601String(),
        'locations': widget.product.locations,
        'color_code': widget.product.colorCode,
        'qr_url': publicUrl,
      };

      await _appwriteService.saveProduct(data, widget.product.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully to Appwrite')),
      );
      Navigator.pop(context);
    } catch (e) {
      print("Save to Appwrite Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData =
        'ID: ${widget.product.id}\nName: ${widget.product.name}\nExpiry: ${widget.product.expiryDate}\nLocation: ${widget.product.locations.join(',')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Generate QR')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            RepaintBoundary(
              key: globalKey,
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 250.0,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isUploading ? null : _saveToAppwrite,
              child:
                  isUploading
                      ? const CircularProgressIndicator()
                      : const Text("Save QR to Appwrite"),
            ),
          ],
        ),
      ),
    );
  }
}
