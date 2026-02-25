import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Dietary tag constants
//  Use these string literals everywhere — never raw strings.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class DietarySourceStatus {
  static const String halal = 'Halal Certified';
  static const String porkFree = 'Pork-Free / Muslim-Friendly';
  static const String nonHalal = 'Non-Halal';

  static const List<String> all = [halal, porkFree, nonHalal];
}

abstract final class DietaryBase {
  static const String nonVeg = 'Non-Vegetarian';
  static const String vegetarian = 'Vegetarian';
  static const String vegan = 'Vegan';

  static const List<String> all = [nonVeg, vegetarian, vegan];
}

abstract final class DietaryContains {
  static const String beef = 'Contains Beef';
  static const String seafood = 'Contains Seafood';
  static const String nuts = 'Contains Nuts';
  static const String dairyEgg = 'Contains Dairy / Egg';

  static const List<String> all = [beef, seafood, nuts, dairyEgg];
}

// ─────────────────────────────────────────────────────────────────────────────
//  Enum: StorageType
// ─────────────────────────────────────────────────────────────────────────────
enum StorageType { roomTemperature, refrigerated, frozen }

extension StorageTypeExtension on StorageType {
  String toJson() => name;

  String get displayLabel {
    switch (this) {
      case StorageType.roomTemperature:
        return 'Room Temperature';
      case StorageType.refrigerated:
        return 'Refrigerated';
      case StorageType.frozen:
        return 'Frozen';
    }
  }

  static StorageType fromJson(String value) {
    return StorageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown StorageType: $value'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Enum: DonationStatus
//  Represents the lifecycle of a single donation listing.
//
//  pending   → The donor has uploaded the food; no NGO has claimed it yet.
//  claimed   → An NGO has claimed the food and is on the way.
//  completed → The NGO has collected the food and uploaded evidence.
//  cancelled → The donor cancelled the listing before it was claimed.
// ─────────────────────────────────────────────────────────────────────────────
enum DonationStatus { pending, claimed, completed, cancelled }

extension DonationStatusExtension on DonationStatus {
  String toJson() => name;

  String get displayLabel {
    switch (this) {
      case DonationStatus.pending:
        return 'Pending';
      case DonationStatus.claimed:
        return 'Claimed';
      case DonationStatus.completed:
        return 'Completed';
      case DonationStatus.cancelled:
        return 'Cancelled';
    }
  }

  static DonationStatus fromJson(String value) {
    return DonationStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown DonationStatus: $value'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Model: DonationModel
//
//  Firestore path: /donations/{donationId}
//
//  Fields
//  ──────
//  id              – UUID generated client-side (also the document ID)
//  donorId         – UID of the donor who created this listing
//  donorName       – Denormalised display name (avoids extra reads on the map)
//  foodName        – e.g. "Nasi Lemak", "Biryani Rice"
//  dietaryTags     – Multi-select tags, e.g. ['Halal', 'No Pork']
//  quantity        – Human-readable quantity, e.g. "10 pax", "3 kg"
//  expiryDate      – Date/time after which the food should not be consumed
//  pickupTime      – Preferred pickup window set by the donor
//  storageType     – How the food must be stored
//  photoUrl        – Firebase Storage download URL of the food photo
//  latitude        – Geo-coordinates of the pickup location (for map pins)
//  longitude       – Geo-coordinates of the pickup location (for map pins)
//  status          – Current lifecycle status (pending → claimed → completed)
//  ngoId           – UID of the claiming NGO (null until claimed)
//  ngoName         – Denormalised NGO name (null until claimed)
//  evidencePhotoUrl– Photo proof uploaded by NGO on completion (null until completed)
//  createdAt       – Server timestamp set on creation
//  updatedAt       – Server timestamp refreshed on every write
// ─────────────────────────────────────────────────────────────────────────────
class DonationModel extends Equatable {
  final String id;
  final String donorId;
  final String donorName;

  // ── Food details (from Upload form) ──────────────────────────────────────
  final String foodName;
  final String sourceStatus;
  final String dietaryBase;
  final List<String> contains;
  final String quantity;
  final DateTime expiryDate;

  /// Earliest time the NGO can collect the food.
  final DateTime pickupStart;

  /// Latest time the NGO can collect the food.
  final DateTime pickupEnd;
  final StorageType storageType;
  final String? photoUrl;

  // ── Location (captured at upload time via device GPS) ────────────────────
  final double latitude;
  final double longitude;
  final String? address;

  // ── Status & NGO fields ──────────────────────────────────────────────────
  final DonationStatus status;
  final String? ngoId;
  final String? ngoName;
  final String? evidencePhotoUrl;

  // ── Timestamps ───────────────────────────────────────────────────────────
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DonationModel({
    required this.id,
    required this.donorId,
    required this.donorName,
    required this.foodName,
    required this.sourceStatus,
    required this.dietaryBase,
    required this.contains,
    required this.quantity,
    required this.expiryDate,
    required this.pickupStart,
    required this.pickupEnd,
    required this.storageType,
    required this.latitude,
    required this.longitude,
    this.address,
    this.photoUrl,
    this.status = DonationStatus.pending,
    this.ngoId,
    this.ngoName,
    this.evidencePhotoUrl,
    this.createdAt,
    this.updatedAt,
  });

  // ── Factory: from a Firestore DocumentSnapshot ──────────────────────────
  factory DonationModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    return DonationModel(
      id: doc.id,
      donorId: data['donorId'] as String,
      donorName: data['donorName'] as String,
      foodName: data['foodName'] as String,
      sourceStatus:
          data['sourceStatus'] as String? ?? DietarySourceStatus.porkFree,
      dietaryBase: data['dietaryBase'] as String? ?? DietaryBase.nonVeg,
      contains: List<String>.from((data['contains'] as List<dynamic>? ?? [])),
      quantity: data['quantity'] as String,
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      pickupStart: (data['pickupStart'] as Timestamp).toDate(),
      pickupEnd: (data['pickupEnd'] as Timestamp).toDate(),
      storageType: StorageTypeExtension.fromJson(data['storageType'] as String),
      photoUrl: data['photoUrl'] as String?,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      address: data['address'] as String?,
      status: DonationStatusExtension.fromJson(data['status'] as String),
      ngoId: data['ngoId'] as String?,
      ngoName: data['ngoName'] as String?,
      evidencePhotoUrl: data['evidencePhotoUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── To Firestore map ─────────────────────────────────────────────────────
  Map<String, dynamic> toDocument() {
    return {
      'donorId': donorId,
      'donorName': donorName,
      'foodName': foodName,
      'sourceStatus': sourceStatus,
      'dietaryBase': dietaryBase,
      'contains': contains,
      'quantity': quantity,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'pickupStart': Timestamp.fromDate(pickupStart),
      'pickupEnd': Timestamp.fromDate(pickupEnd),
      'storageType': storageType.toJson(),
      if (photoUrl != null) 'photoUrl': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      'status': status.toJson(),
      if (ngoId != null) 'ngoId': ngoId,
      if (ngoName != null) 'ngoName': ngoName,
      if (evidencePhotoUrl != null) 'evidencePhotoUrl': evidencePhotoUrl,
      // Always emit updatedAt; only add createdAt when first creating
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convenience map for the initial Firestore `set()` call.
  /// Includes `createdAt` in addition to all other fields.
  Map<String, dynamic> toNewDocument() {
    return {...toDocument(), 'createdAt': FieldValue.serverTimestamp()};
  }

  // ── copyWith ─────────────────────────────────────────────────────────────
  DonationModel copyWith({
    String? foodName,
    String? sourceStatus,
    String? dietaryBase,
    List<String>? contains,
    String? quantity,
    DateTime? expiryDate,
    DateTime? pickupStart,
    DateTime? pickupEnd,
    StorageType? storageType,
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? address,
    DonationStatus? status,
    String? ngoId,
    String? ngoName,
    String? evidencePhotoUrl,
  }) {
    return DonationModel(
      id: id,
      donorId: donorId,
      donorName: donorName,
      foodName: foodName ?? this.foodName,
      sourceStatus: sourceStatus ?? this.sourceStatus,
      dietaryBase: dietaryBase ?? this.dietaryBase,
      contains: contains ?? this.contains,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate ?? this.expiryDate,
      pickupStart: pickupStart ?? this.pickupStart,
      pickupEnd: pickupEnd ?? this.pickupEnd,
      storageType: storageType ?? this.storageType,
      photoUrl: photoUrl ?? this.photoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      status: status ?? this.status,
      ngoId: ngoId ?? this.ngoId,
      ngoName: ngoName ?? this.ngoName,
      evidencePhotoUrl: evidencePhotoUrl ?? this.evidencePhotoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // ── Computed helpers ─────────────────────────────────────────────────────

  /// True if the expiry date is within 24 hours from now.
  /// Used by the map to decide pin colour (red = expiring soon).
  bool get isExpiringSoon {
    final hoursLeft = expiryDate.difference(DateTime.now()).inHours;
    return hoursLeft <= 24 && hoursLeft >= 0;
  }

  /// True if the expiry date has already passed.
  bool get isExpired => DateTime.now().isAfter(expiryDate);

  @override
  List<Object?> get props => [
    id,
    donorId,
    foodName,
    sourceStatus,
    dietaryBase,
    contains,
    quantity,
    expiryDate,
    pickupStart,
    pickupEnd,
    storageType,
    photoUrl,
    latitude,
    longitude,
    address,
    status,
    ngoId,
    evidencePhotoUrl,
  ];
}
