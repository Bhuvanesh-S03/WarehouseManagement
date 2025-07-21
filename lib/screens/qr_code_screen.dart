import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:appwrite/appwrite.dart';
import '../model/product_model.dart';

class GenerateQRScreen extends StatefulWidget {
  final Product product;
  const GenerateQRScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<GenerateQRScreen> createState() => _GenerateQRScreenState();
}

class _GenerateQRScreenState extends State<GenerateQRScreen> {
  bool _isSaving = false;
  String? _error;
  String? _successMessage;

  final Client _client = Client()
      .setEndpoint('https://nyc.cloud.appwrite.io/v1')
      .setProject('687bc7e3001a688c12aa');

  late final Storage _storage;

  @override
  void initState() {
    super.initState();
    _storage = Storage(_client);
  }

  Future<void> _saveQRToAppwrite() async {
    setState(() {
      _isSaving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // 1. Generate QR Code
      final qrImage = await QrPainter(
        data: jsonEncode(widget.product.toJson()),
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      ).toImageData(300);

      if (qrImage == null) throw Exception('Failed to generate QR image');

      // 2. Store in Appwrite
      await _storage.createFile(
        bucketId: '687c472b0021c89655b8',
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: qrImage.buffer.asUint8List(),
          filename: 'product_${widget.product.id}.png',
        ),
      );

      setState(() => _successMessage = 'QR stored successfully');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Store QR Code')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // QR Code Display
              QrImageView(
                data: jsonEncode(widget.product.toJson()),
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 30),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveQRToAppwrite,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
                child:
                    _isSaving
                        ? const CircularProgressIndicator()
                        : const Text('Store in Cloud'),
              ),
              const SizedBox(height: 20),

              // Status Messages
              if (_error != null)
                Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),

              if (_successMessage != null)
                Text(
                  _successMessage!,
                  style: const TextStyle(color: Colors.green),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
