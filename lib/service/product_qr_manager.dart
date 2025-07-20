// import 'dart:io';
// import 'dart:typed_data';
// import 'dart:ui';
// import 'package:appwrite/appwrite.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:url_launcher/url_launcher.dart';
// import 'package:intl/intl.dart';
// import 'package:warehouse_manager/model/product_model.dart';
// import 'package:warehouse_manager/service/appwrite_service.dart';

// class ProductQRManagerScreen extends StatefulWidget {
//   final Product product;

//   const ProductQRManagerScreen({super.key, required this.product});

//   @override
//   State<ProductQRManagerScreen> createState() => _ProductQRManagerScreenState();
// }

// class _ProductQRManagerScreenState extends State<ProductQRManagerScreen> {
//   final GlobalKey _qrKey = GlobalKey();
//   late final AppwriteService _appwriteService;
//   bool _isUploading = false;
//   String? _qrUrl;

//   @override
//   void initState() {
//     super.initState();
//     final client =
//         Client()
//           ..setEndpoint('https://nyc.cloud.appwrite.io/v1')
//           ..setProject('687bc7e3001a688c12aa')
//           ..setSelfSigned(status: true);
//     _appwriteService = AppwriteService(client);
//   }

//   Future<Uint8List> _captureQR() async {
//     try {
//       final boundary =
//           _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
//       final image = await boundary.toImage(pixelRatio: 3.0);
//       final byteData = await image.toByteData(format: ImageByteFormat.png);
//       return byteData!.buffer.asUint8List();
//     } catch (e) {
//       debugPrint("QR Capture Error: $e");
//       rethrow;
//     }
//   }

//   Future<void> _handleSave() async {
//     if (_isUploading) return;

//     setState(() => _isUploading = true);

//     try {
//       final qrBytes = await _captureQR();
//       final tempDir = await getTemporaryDirectory();
//       final file = File('${tempDir.path}/qr_${widget.product.id}.png');
//       await file.writeAsBytes(qrBytes);

//       _qrUrl = await _appwriteService.uploadQR(
//         file,
//         'qr_${widget.product.id}.png',
//       );

//       await _appwriteService.saveProduct(
//         widget.product.toMap()..['qr_url'] = _qrUrl,
//         widget.product.id,
//       );

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Product saved successfully!')),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
//     } finally {
//       if (mounted) setState(() => _isUploading = false);
//     }
//   }

//   Widget _buildQRSection() {
//     final qrData = '''
//       PRODUCT: ${widget.product.name}
//       ID: ${widget.product.id}
//       WEIGHT: ${widget.product.weight}kg
//       EXPIRY: ${DateFormat('yyyy-MM-dd').format(widget.product.expiryDate)}
//       LOCATIONS: ${widget.product.location.join(', ')}
//     ''';

//     return Column(
//       children: [
//         RepaintBoundary(
//           key: _qrKey,
//           child: Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               border: Border.all(color: Colors.grey.shade300),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: Column(
//               children: [
//                 QrImageView(
//                   data: qrData,
//                   version: QrVersions.auto,
//                   size: 200,
//                   gapless: true,
//                 ),
//                 const SizedBox(height: 12),
//                 Text(
//                   widget.product.name,
//                   style: Theme.of(context).textTheme.titleMedium,
//                 ),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(height: 20),
//         if (_qrUrl != null) ...[
//           Text(
//             'QR Already Uploaded',
//             style: TextStyle(color: Colors.green.shade700),
//           ),
//           const SizedBox(height: 8),
//           InkWell(
//             onTap: () async {
//               if (await canLaunchUrl(Uri.parse(_qrUrl!))) {
//                 await launchUrl(Uri.parse(_qrUrl!));
//               }
//             },
//             child: Text(
//               _qrUrl!,
//               style: const TextStyle(
//                 color: Colors.blue,
//                 decoration: TextDecoration.underline,
//               ),
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Product QR Manager'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.info_outline),
//             onPressed:
//                 () => showAboutDialog(
//                   context: context,
//                   applicationName: 'QR Warehouse Manager',
//                   applicationVersion: '1.0.0',
//                 ),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           children: [
//             _buildQRSection(),
//             const SizedBox(height: 20),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton(
//                 onPressed: _isUploading ? null : _handleSave,
//                 style: ElevatedButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                 ),
//                 child:
//                     _isUploading
//                         ? const CircularProgressIndicator()
//                         : const Text('Save to Appwrite'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
