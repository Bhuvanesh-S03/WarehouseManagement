class Product {
  String id; // Unique per product
  String name;
  double weight;
  DateTime entryDate;
  DateTime expiryDate;
  List<String> locations;
  int colorCode;

  Product({
    required this.id,
    required this.name,
    required this.weight,
    required this.entryDate,
    required this.expiryDate,
    required this.locations,
    required this.colorCode,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'weight': weight,
    'entryDate': entryDate.toIso8601String(),
    'expiryDate': expiryDate.toIso8601String(),
    'locations': locations,
    'colorCode': colorCode,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'],
    name: json['name'],
    weight: (json['weight'] as num).toDouble(),
    entryDate: DateTime.parse(json['entryDate']),
    expiryDate: DateTime.parse(json['expiryDate']),
    locations: List<String>.from(json['locations']),
    colorCode: json['colorCode'],
  );
}
