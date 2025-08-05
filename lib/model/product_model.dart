import 'package:flutter/material.dart';

class Product {
  String id;
  String name;
  double weight;
  DateTime entryDate;
  DateTime expiryDate;
  List<String> locations;
  int colorCode;
  String? qrUrl;
  bool unloaded;

  Product({
    required this.id,
    required this.name,
    required this.weight,
    required this.entryDate,
    required this.expiryDate,
    required this.locations,
    required this.colorCode,
    this.qrUrl,
    this.unloaded = false,
  });

  Map<String, dynamic> toDocument() => {
    'name': name,
    'weight': weight,
    'entry_date': entryDate.toIso8601String(),
    'expiry_date': expiryDate.toIso8601String(),
    'locations': locations,
    'color_code': colorCode,
    'qr_url': qrUrl ?? '',
    'unloaded': unloaded,
  };

  factory Product.fromDocument(Map<String, dynamic> doc, String documentId) =>
      Product(
        id: documentId,
        name: doc['name'] ?? '',
        weight: (doc['weight'] as num?)?.toDouble() ?? 0.0,
        entryDate:
            doc['entry_date'] != null
                ? DateTime.parse(doc['entry_date'])
                : DateTime.now(),
        expiryDate:
            doc['expiry_date'] != null
                ? DateTime.parse(doc['expiry_date'])
                : DateTime.now().add(const Duration(days: 30)),
        locations: _parseLocations(doc['locations']),
        colorCode: doc['color_code'] ?? 0,
        qrUrl: doc['qr_url'],
        unloaded: doc['unloaded'] ?? false,
      );

  static List<String> _parseLocations(dynamic locations) {
    if (locations == null) return [];
    if (locations is List) return locations.map((e) => e.toString()).toList();
    if (locations is String) return [locations];
    return [locations.toString()];
  }

  ExpiryStatus get expiryStatus {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    if (daysUntilExpiry < 0) return ExpiryStatus.expired;
    if (daysUntilExpiry <= 7) return ExpiryStatus.critical;
    if (daysUntilExpiry <= 30) return ExpiryStatus.warning;
    return ExpiryStatus.good;
  }

  String get formattedLocations => locations.join(', ');

  String generateQRData() {
    return '''Product ID: $id
Name: $name
Weight: ${weight.toStringAsFixed(2)} kg
Entry: ${entryDate.toIso8601String().split('T')[0]}
Expiry: ${expiryDate.toIso8601String().split('T')[0]}
Locations: $formattedLocations
Color: $colorCode
Unloaded: $unloaded''';
  }

  Product copyWith({
    String? id,
    String? name,
    double? weight,
    DateTime? entryDate,
    DateTime? expiryDate,
    List<String>? locations,
    int? colorCode,
    String? qrUrl,
    bool? unloaded,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      entryDate: entryDate ?? this.entryDate,
      expiryDate: expiryDate ?? this.expiryDate,
      locations: locations ?? this.locations,
      colorCode: colorCode ?? this.colorCode,
      qrUrl: qrUrl ?? this.qrUrl,
      unloaded: unloaded ?? this.unloaded,
    );
  }
}

enum ExpiryStatus { good, warning, critical, expired }

extension ExpiryStatusExtension on ExpiryStatus {
  String get displayName {
    switch (this) {
      case ExpiryStatus.good:
        return 'Good';
      case ExpiryStatus.warning:
        return 'Warning';
      case ExpiryStatus.critical:
        return 'Critical';
      case ExpiryStatus.expired:
        return 'Expired';
    }
  }

  int get colorCodeValue {
    switch (this) {
      case ExpiryStatus.good:
        return 0;
      case ExpiryStatus.warning:
        return 1;
      case ExpiryStatus.critical:
        return 2;
      case ExpiryStatus.expired:
        return 3;
    }
  }
}

class ProductValidator {
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Product name is required';
    }
    return null;
  }

  static String? validateWeight(String? weight) {
    if (weight == null || weight.trim().isEmpty) {
      return 'Weight is required';
    }
    final parsedWeight = double.tryParse(weight);
    if (parsedWeight == null || parsedWeight <= 0) {
      return 'Please enter a valid weight > 0';
    }
    if (parsedWeight > 10000) {
      return 'Weight must be 10000kg or less';
    }
    return null;
  }

  static String? validateExpiryDate(DateTime? expiryDate) {
    if (expiryDate == null) {
      return 'Expiry date is required';
    }
    return null;
  }
}
