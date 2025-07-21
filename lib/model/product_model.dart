class Product {
  String id; // Unique per product
  String name;
  double weight;
  DateTime entryDate;
  DateTime expiryDate;
  List<String> locations;
  int colorCode;
  String? qrUrl; // Optional QR URL

  Product({
    required this.id,
    required this.name,
    required this.weight,
    required this.entryDate,
    required this.expiryDate,
    required this.locations,
    required this.colorCode,
    this.qrUrl,
  });

  /// Convert Product to JSON for database storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'weight': weight,
    'entryDate': entryDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'locations': locations,
    'colorCode': colorCode,
    'qrUrl': qrUrl,
  };

  /// Create Product from JSON data
  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
    entryDate:
        json['entryDate'] != null
            ? DateTime.parse(json['entryDate'])
            : DateTime.now(),
    expiryDate:
        json['expiryDate'] != null
            ? DateTime.parse(json['expiryDate'])
            : DateTime.now().add(Duration(days: 30)),
    locations:
        json['locations'] != null ? List<String>.from(json['locations']) : [],
    colorCode: json['colorCode'] ?? 0,
    qrUrl: json['qrUrl'],
  );

  /// Create Product from Appwrite document
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
                : DateTime.now().add(Duration(days: 30)),
        locations:
            doc['locations'] != null ? List<String>.from(doc['locations']) : [],
        colorCode: doc['color_code'] ?? 0,
        qrUrl: doc['qr_url'],
      );

  /// Convert Product to Appwrite document format
  Map<String, dynamic> toDocument() => {
    'name': name,
    'weight': weight,
    'entry_date': entryDate.toIso8601String(),
    'expiry_date': expiryDate.toIso8601String(),
    'locations': locations,
    'color_code': colorCode,
    'qr_url': qrUrl ?? '',
  };

  /// Check if product is expiring within given days
  bool isExpiringWithin(int days) {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= days && daysUntilExpiry >= 0;
  }

  /// Check if product is expired
  bool get isExpired {
    return DateTime.now().isAfter(expiryDate);
  }

  /// Get expiry status
  ExpiryStatus get expiryStatus {
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;

    if (daysUntilExpiry < 0) return ExpiryStatus.expired;
    if (daysUntilExpiry <= 7) return ExpiryStatus.critical;
    if (daysUntilExpiry <= 30) return ExpiryStatus.warning;
    return ExpiryStatus.good;
  }

  /// Get formatted weight string
  String get formattedWeight => '${weight.toStringAsFixed(2)} kg';

  /// Get formatted location string
  String get formattedLocations => locations.join(', ');

  /// Copy product with updated fields
  Product copyWith({
    String? id,
    String? name,
    double? weight,
    DateTime? entryDate,
    DateTime? expiryDate,
    List<String>? locations,
    int? colorCode,
    String? qrUrl,
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
    );
  }

  /// Generate QR data string
  String generateQRData() {
    return '''Product ID: $id
Name: $name
Weight: $formattedWeight
Entry: ${entryDate.toIso8601String().split('T')[0]}
Expiry: ${expiryDate.toIso8601String().split('T')[0]}
Locations: $formattedLocations
Color: $colorCode''';
  }

  @override
  String toString() {
    return 'Product(id: $id, name: $name, weight: $weight, locations: $locations)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
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

  /// Note: Import Flutter material for Color usage
  /// Example: import 'package:flutter/material.dart';
  int get colorValue {
    switch (this) {
      case ExpiryStatus.good:
        return 0xFF4CAF50; // Colors.green
      case ExpiryStatus.warning:
        return 0xFFFF9800; // Colors.orange
      case ExpiryStatus.critical:
        return 0xFFF44336; // Colors.red
      case ExpiryStatus.expired:
        return 0xFFD32F2F; // Colors.red.shade800
    }
  }
}

/// Product validation utility
class ProductValidator {
  static String? validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Product name is required';
    }
    if (name.trim().length < 2) {
      return 'Product name must be at least 2 characters';
    }
    return null;
  }

  static String? validateWeight(String? weight) {
    if (weight == null || weight.trim().isEmpty) {
      return 'Weight is required';
    }

    final parsedWeight = double.tryParse(weight);
    if (parsedWeight == null) {
      return 'Please enter a valid weight';
    }

    if (parsedWeight <= 0) {
      return 'Weight must be greater than 0';
    }

    if (parsedWeight > 10000) {
      return 'Weight seems too large';
    }

    return null;
  }

  static String? validateExpiryDate(DateTime? expiryDate, DateTime? entryDate) {
    if (expiryDate == null) {
      return 'Expiry date is required';
    }

    if (entryDate != null && expiryDate.isBefore(entryDate)) {
      return 'Expiry date cannot be before entry date';
    }

    return null;
  }

  static String? validateLocations(List<String>? locations) {
    if (locations == null || locations.isEmpty) {
      return 'At least one location is required';
    }

    for (String location in locations) {
      if (location.trim().isEmpty) {
        return 'Location cannot be empty';
      }
    }

    return null;
  }

  static Map<String, String> validateProduct(Product product) {
    Map<String, String> errors = {};

    final nameError = validateName(product.name);
    if (nameError != null) errors['name'] = nameError;

    final weightError = validateWeight(product.weight.toString());
    if (weightError != null) errors['weight'] = weightError;

    final expiryError = validateExpiryDate(
      product.expiryDate,
      product.entryDate,
    );
    if (expiryError != null) errors['expiryDate'] = expiryError;

    final locationsError = validateLocations(product.locations);
    if (locationsError != null) errors['locations'] = locationsError;

    return errors;
  }
}
