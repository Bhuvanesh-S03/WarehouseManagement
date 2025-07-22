import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:warehouse_manager/service/appwrite.dart';
import 'package:intl/intl.dart';

import '../model/product_model.dart';

class GenerateQRScreen extends StatefulWidget {
  final Product product;
  final AppwriteService appwriteService;

  const GenerateQRScreen({
    super.key,
    required this.product,
    required this.appwriteService,
  });

  @override
  State<GenerateQRScreen> createState() => _GenerateQRScreenState();
}

class _GenerateQRScreenState extends State<GenerateQRScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isUploading = false;
  String? _qrUrl;
  bool _isSaving = false;
  String? _savedProductId;

  @override
  Widget build(BuildContext context) {
    final qrData = _generateQRData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate QR Code'),
        backgroundColor: Colors.blue.shade50,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProductInfo(),
            const SizedBox(height: 24),
            _buildQRSection(qrData),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow(
              Icons.scale,
              'Weight',
              '${widget.product.weight.toStringAsFixed(2)} kg',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Entry Date',
              DateFormat('MMM dd, yyyy').format(widget.product.entryDate),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.event_available,
              'Expiry Date',
              DateFormat('MMM dd, yyyy').format(widget.product.expiryDate),
              color: _getExpiryColor(),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.location_on,
              'Locations',
              widget.product.locations.join(', '),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getExpiryColor() {
    final daysUntilExpiry =
        widget.product.expiryDate.difference(DateTime.now()).inDays;
    if (daysUntilExpiry <= 7) return Colors.red;
    if (daysUntilExpiry <= 30) return Colors.orange;
    return Colors.green;
  }

  Widget _buildQRSection(String qrData) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'QR Code',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 200,
                      gapless: true,
                      errorStateBuilder: (cxt, err) {
                        return Container(
                          child: Center(
                            child: Text(
                              "Something went wrong...",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'ID: ${widget.product.id}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Save Product Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveProduct,
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.save),
            label: Text(_isSaving ? 'Saving Product...' : 'Save Product'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Download QR Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _downloadQR,
            icon:
                _isUploading
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.download),
            label: Text(_isUploading ? 'Processing...' : 'Download QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Upload QR Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                (_isUploading || _savedProductId == null) ? null : _uploadQR,
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Upload to Cloud'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (_qrUrl != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QR code uploaded successfully!',
                    style: TextStyle(color: Colors.green.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _generateQRData() {
    // Generate comprehensive QR data with all product information
    return '''
Product ID: ${widget.product.id}
Name: ${widget.product.name}
Weight: ${widget.product.weight} kg
Entry: ${DateFormat('yyyy-MM-dd').format(widget.product.entryDate)}
Expiry: ${DateFormat('yyyy-MM-dd').format(widget.product.expiryDate)}
Locations: ${widget.product.locations.join(', ')}
Color: ${widget.product.colorCode}
'''.trim();
  }

  Future<void> _saveProduct() async {
    setState(() {
      _isSaving = true;
    });

    try {
      // Save product to database
      final productId = await widget.appwriteService.saveProduct(
        widget.product,
      );

      setState(() {
        _savedProductId = productId as String?;
      });

      // Update the product ID for future operations
      widget.product.id = productId as String;

      _showSuccessDialog('Product saved successfully!');
    } catch (e) {
      _showErrorDialog('Failed to save product: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _downloadQR() async {
    setState(() {
      _isUploading = true;
    });

    try {
      // Capture the QR code as image
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not find QR code to capture');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Get the downloads directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'QR_${widget.product.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');

      // Save the file
      await file.writeAsBytes(pngBytes);

      _showSuccessDialog('QR code saved to: ${file.path}');
    } catch (e) {
      _showErrorDialog('Failed to save QR code: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadQR() async {
    if (_savedProductId == null) {
      _showErrorDialog('Please save the product first');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // Capture the QR code as image
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not find QR code to capture');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'QR_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);

      // Upload to Appwrite storage
      final qrUrl = await widget.appwriteService.uploadQRCode(file, fileName);

      // Update product with QR URL
      await widget.appwriteService.updateProductQRUrl(_savedProductId!, qrUrl as String);

      setState(() {
        _qrUrl = qrUrl as String?;
      });

      // Clean up temporary file
      await file.delete();

      _showSuccessDialog('QR code uploaded to cloud successfully!');
    } catch (e) {
      _showErrorDialog('Failed to upload QR code: ${e.toString()}');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Success'),
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
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
}
