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
  String? _qrUrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _qrUrl = widget.product.qrUrl;
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

  Future<File?> _captureQrImage() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not find QR code to capture');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to convert QR code to image');
      }
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final fileName =
          'QR_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      _showMessageDialog(
        'Error',
        'Failed to capture QR code: ${e.toString()}',
        isError: true,
      );
      return null;
    }
  }

  Future<void> _downloadQR() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final qrFile = await _captureQrImage();
      if (qrFile == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'QR_${widget.product.name.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final newFile = await qrFile.copy('${directory.path}/$fileName');
      await qrFile.delete(); // Clean up temp file

      _showMessageDialog('Success', 'QR code saved to: ${newFile.path}');
    } catch (e) {
      _showMessageDialog(
        'Error',
        'Failed to save QR code: ${e.toString()}',
        isError: true,
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _uploadQR() async {
    if (widget.product.id.isEmpty) {
      _showMessageDialog(
        'Error',
        'Product must have an ID to upload a QR code.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final qrFile = await _captureQrImage();
      if (qrFile == null) return;

      final uploadResult = await widget.appwriteService.uploadQRCode(
        qrFile,
        'QR_${widget.product.id}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      final qrUrl = uploadResult['url'];
      final qrFileId = uploadResult['fileId'];

      if (qrUrl == null || qrFileId == null) {
        throw Exception('Failed to get QR URL or file ID from upload result');
      }

      // FIX: The call below is now in sync with the corrected AppwriteService method.
      // It no longer passes 'qr_file_id' as a separate attribute.
      await widget.appwriteService.updateProductQRUrl(
        widget.product.id,
        qrUrl,
        qrFileId,
      );

      setState(() {
        _qrUrl = qrUrl;
        _isProcessing = false;
      });

      await qrFile.delete();

      _showMessageDialog('Success', 'QR code uploaded to cloud successfully!');
    } catch (e) {
      _showMessageDialog(
        'Error',
        'Failed to upload QR code: ${e.toString()}',
        isError: true,
      );
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _buildQRSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
            if (_qrUrl != null && _qrUrl!.isNotEmpty)
              _buildStatusMessage(
                'QR code uploaded successfully!',
                Colors.green,
              ),
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
                const Icon(Icons.inventory_2, color: Colors.blue, size: 28),
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
              '${widget.product.weight?.toStringAsFixed(2) ?? 'N/A'} kg',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Entry Date',
              DateFormat('MMM dd, yyyy').format(widget.product.entryDate!),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.event_available,
              'Expiry Date',
              DateFormat('MMM dd, yyyy').format(widget.product.expiryDate!),
              color: _getExpiryColor(),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.location_on,
              'Locations',
              widget.product.locations?.join(', ') ?? 'N/A',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.info,
              'Status',
              widget.product.unloaded ? 'Unloaded' : 'In Stock',
              color: widget.product.unloaded ? Colors.orange : Colors.green,
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
    final expiryStatus = widget.product.expiryStatus;
    switch (expiryStatus) {
      case ExpiryStatus.good:
        return Colors.green;
      case ExpiryStatus.warning:
        return Colors.orange;
      case ExpiryStatus.critical:
        return Colors.red;
      case ExpiryStatus.expired:
        return Colors.red;
    }
  }

  Widget _buildQRSection() {
    final qrData = widget.product.generateQRData();
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
                        return const Center(
                          child: Text(
                            "Something went wrong...",
                            textAlign: TextAlign.center,
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
    final isProductSaved = widget.product.id.isNotEmpty;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _downloadQR,
            icon:
                _isProcessing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.download),
            label: Text(_isProcessing ? 'Processing...' : 'Download QR Code'),
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isProcessing || !isProductSaved) ? null : _uploadQR,
            icon:
                (_isProcessing && isProductSaved)
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.cloud_upload),
            label: Text(
              _isProcessing ? 'Uploading to Cloud...' : 'Upload to Cloud',
            ),
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
      ],
    );
  }

  Widget _buildStatusMessage(String message, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(color: color))),
          ],
        ),
      ),
    );
  }
}
