//define food data structured and provides parsing from Firestore.
// ensure data send to firestore the correct datatype
import 'package:cloud_firestore/cloud_firestore.dart';

class FoodModel {
  final String id;
  final String foodName;
  final String description;
  final String pickupLocation;
  final String exactLocation;
  final DateTime pickupDate;
  final String pickupTimeRange;
  final Map<String, dynamic> expiryOption;
  final bool isHalal;
  final int quantity;
  final int redeemedCount;
  final bool isRedeemed;
  final DateTime? redeemedAt;
  final String imageUrl;
  final String postedBy;
  final DateTime postedAt;

  FoodModel({
    required this.id,
    required this.foodName,
    required this.description,
    required this.pickupLocation,
    this.exactLocation = '',
    required this.pickupDate,
    required this.pickupTimeRange,
    required this.expiryOption,
    required this.isHalal,
    required this.quantity,
    required this.redeemedCount,
    required this.isRedeemed,
    this.redeemedAt,
    required this.imageUrl,
    required this.postedBy,
    required this.postedAt,
  });

  // Defensive factory: converts Firestore types to Dart types safely
  factory FoodModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    DateTime parseTimestamp(dynamic v, {DateTime? fallback}) {
      if (v == null) return fallback ?? DateTime.now();
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? (fallback ?? DateTime.now());
      if (v is DateTime) return v;
      return fallback ?? DateTime.now();
    }

    int parseInt(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    bool parseBool(dynamic v, [bool fallback = false]) {
      if (v == null) return fallback;
      if (v is bool) return v;
      if (v is int) return v != 0;
      if (v is String) return v.toLowerCase() == 'true';
      return fallback;
    }

    String parseString(dynamic v, [String fallback = '']) {
      if (v == null) return fallback;
      return v.toString();
    }

    final expiry = (data['expiryOption'] is Map)
        ? Map<String, dynamic>.from(data['expiryOption'])
        : <String, dynamic>{'type': 'today', 'value': null};

    final redeemedAtRaw = data['redeemedAt'];

    return FoodModel(
      id: doc.id,
      foodName: parseString(data['foodName']),
      description: parseString(data['description']),
      pickupLocation: parseString(data['pickupLocation']),
      exactLocation: parseString(data['exactLocation']),
      pickupDate: parseTimestamp(data['pickupDate']),
      pickupTimeRange: parseString(data['pickupTimeRange']),
      expiryOption: expiry,
      isHalal: parseBool(data['isHalal'], true),
      quantity: parseInt(data['quantity'], 1),
      redeemedCount: parseInt(data['redeemedCount'], 0),
      isRedeemed: parseBool(data['isRedeemed'], false),
      redeemedAt: redeemedAtRaw != null ? parseTimestamp(redeemedAtRaw) : null,
      imageUrl: parseString(data['imageUrl']),
      postedBy: parseString(data['postedBy']),
      postedAt: parseTimestamp(data['postedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'foodName': foodName,
      'description': description,
      'pickupLocation': pickupLocation,
      'exactLocation': exactLocation,
      'pickupDate': Timestamp.fromDate(pickupDate),
      'pickupTimeRange': pickupTimeRange,
      'expiryOption': expiryOption,
      'isHalal': isHalal,
      'quantity': quantity,
      'redeemedCount': redeemedCount,
      'isRedeemed': isRedeemed,
      'redeemedAt': redeemedAt != null ? Timestamp.fromDate(redeemedAt!) : null,
      'imageUrl': imageUrl,
      'postedBy': postedBy,
      'postedAt': Timestamp.fromDate(postedAt),
    };
  }
}