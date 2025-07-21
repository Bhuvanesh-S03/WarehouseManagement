// screens/qr_code_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:warehouse_manager/model/product_model.dart';
import 'package:warehouse_manager/service/appwrite.dart';


class GenerateQRScreen extends StatelessWidget {
  final Product product;

  const GenerateQRScreen({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product QR Code')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: product.toJson().toString(),
              version: QrVersions.auto,
              size: 200,
            ),
            const SizedBox(height: 20),
            Text(product.name, style: Theme.of(context).textTheme.titleLarge),
            Text('Location: ${product.location}'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await AppwriteService.saveQrToDevice(
                    product.id,
                    product.toJson().toString(),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('QR saved to gallery')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error saving QR: $e')),
                  );
                }
              },
              child: const Text('Save QR Code'),
            ),
          ],
        ),
      ),
    );
  }
}
