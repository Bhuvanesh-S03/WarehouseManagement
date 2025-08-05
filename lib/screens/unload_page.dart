import 'package:flutter/material.dart';
import 'package:warehouse_manager/model/product_model.dart';
import 'package:warehouse_manager/service/appwrite.dart';
import 'package:appwrite/appwrite.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

class UnloadPage extends StatefulWidget {
  final AppwriteService appwriteService;
  final Function(String productId) onUnload;

  const UnloadPage({
    Key? key,
    required this.appwriteService,
    required this.onUnload,
  }) : super(key: key);

  @override
  State<UnloadPage> createState() => _UnloadPageState();
}

class _UnloadPageState extends State<UnloadPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  Product? _scannedProduct;
  bool _isScanning = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final status = await perm.Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _isScanning = true;
        _scannedProduct = null;
        _errorMessage = null;
      });
    } else {
      _showMessageDialog(
        'Permission Denied',
        'Camera permission is required to scan QR codes.',
        isError: true,
      );
    }
  }

  void _onQrCodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final String? qrCodeData = capture.barcodes.first.rawValue;
      if (qrCodeData != null && !_isLoading && _isScanning) {
        _scannerController.stop();
        setState(() {
          _isScanning = false;
        });

        // FIX: Parse the QR data to extract only the Product ID
        final RegExp idRegex = RegExp(r'Product ID: (.+)');
        final match = idRegex.firstMatch(qrCodeData);
        final String? productId = match?.group(1)?.trim();

        if (productId != null && productId.isNotEmpty) {
          _fetchProductDetails(productId);
        } else {
          _showMessageDialog(
            'Invalid QR Code',
            'The scanned QR code does not contain a valid Product ID.',
            isError: true,
          );
        }
      }
    }
  }

  Future<void> _fetchProductDetails(String productId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final document = await widget.appwriteService.db.getDocument(
        databaseId: AppwriteService.databaseId,
        collectionId: AppwriteService.productsCollectionId,
        documentId: productId,
      );
      setState(() {
        _scannedProduct = Product.fromDocument(document.data, document.$id);
      });
    } on AppwriteException catch (e) {
      setState(() {
        _errorMessage = 'Error fetching product: ${e.message}';
        _scannedProduct = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
        _scannedProduct = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unloadProduct() async {
    if (_scannedProduct == null) {
      _showMessageDialog('Error', 'No product to unload.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Unload'),
            content: Text(
              'Are you sure you want to unload "${_scannedProduct!.name}"? This will permanently remove it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Unload'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.appwriteService.deleteProduct(_scannedProduct!.id);
      widget.onUnload(_scannedProduct!.id);
      _showMessageDialog('Success', 'Product unloaded successfully.');
      setState(() {
        _scannedProduct = null;
      });
    } on AppwriteException catch (e) {
      _showMessageDialog(
        'Error',
        'Failed to unload product: ${e.message}',
        isError: true,
      );
    } catch (e) {
      _showMessageDialog(
        'Error',
        'An unexpected error occurred: $e',
        isError: true,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showMessageDialog(
    String title,
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isError ? Icons.error : Icons.check_circle,
                  color: isError ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unload Product'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isScanning && _scannedProduct == null)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startScan,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              if (_isScanning)
                Expanded(
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onQrCodeDetected,
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed:
                                () => setState(() => _isScanning = false),
                            child: const Text('Cancel Scan'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              if (_isLoading && !_isScanning) const CircularProgressIndicator(),
              if (!_isLoading && !_isScanning)
                _scannedProduct != null
                    ? _buildProductDetailsCard()
                    : _errorMessage != null
                    ? Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    )
                    : const Text('Scan a QR code to view product details.'),
              if (_scannedProduct != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: ElevatedButton.icon(
                    onPressed: _unloadProduct,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Unload Product'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductDetailsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _scannedProduct!.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildDetailRow('Product ID', _scannedProduct!.id),
            _buildDetailRow(
              'Weight',
              '${_scannedProduct!.weight?.toStringAsFixed(2) ?? 'N/A'} kg',
            ),
            _buildDetailRow(
              'Expiry Date',
              _scannedProduct!.expiryDate?.toLocal().toString().split(' ')[0] ??
                  'N/A',
            ),
            _buildDetailRow('Locations', _scannedProduct!.formattedLocations),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
