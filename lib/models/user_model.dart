import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Enum: UserRole
//  Two roles exist in the system. The string values are stored in Firestore
//  so they must remain stable (avoid renaming without a migration).
// ─────────────────────────────────────────────────────────────────────────────
enum UserRole { donor, ngo }

extension UserRoleExtension on UserRole {
  /// Converts the enum to the lowercase string stored in Firestore.
  String toJson() => name; // 'donor' | 'ngo'

  /// Parses a Firestore string back to the enum; throws if unknown.
  static UserRole fromJson(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown UserRole: $value'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Model: UserModel
//
//  Firestore path: /users/{uid}
//
//  Fields
//  ──────
//  uid          – Firebase Auth UID (also the Firestore document ID)
//  displayName  – Full name or organisation name
//  email        – Auth email address (mirrored here for quick reads)
//  role         – 'donor' | 'ngo'
//  photoUrl     – Optional profile photo stored in Firebase Storage
//  phone        – Optional contact number
//  address      – Optional postal address (useful for NGOs)
//  createdAt    – Server timestamp set on first write; never overwritten
// ─────────────────────────────────────────────────────────────────────────────
class UserModel extends Equatable {
  final String uid;
  final String displayName;
  final String email;
  final UserRole role;
  final String? photoUrl;
  final String phone;
  final String? address;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.phone,
    this.photoUrl,
    this.address,
    this.createdAt,
  });

  // ── Factory: from a Firestore DocumentSnapshot ──────────────────────────
  factory UserModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      uid: doc.id,
      displayName: data['displayName'] as String,
      email: data['email'] as String,
      role: UserRoleExtension.fromJson(data['role'] as String),
      photoUrl: data['photoUrl'] as String?,
      phone: data['phone'] as String,
      address: data['address'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // ── To Firestore map ─────────────────────────────────────────────────────
  /// Converts this model to a map suitable for `set()` / `update()`.
  /// Pass [includeCreatedAt] = true only when creating the document for the
  /// first time; subsequent updates should omit it to preserve the original.
  Map<String, dynamic> toDocument({bool includeCreatedAt = false}) {
    return {
      'displayName': displayName,
      'email': email,
      'role': role.toJson(),
      'phone': phone,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (address != null) 'address': address,
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ─────────────────────────────────────────────────────────────
  UserModel copyWith({
    String? displayName,
    String? email,
    UserRole? role,
    String? photoUrl,
    String? phone,
    String? address,
  }) {
    return UserModel(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    displayName,
    email,
    role,
    photoUrl,
    phone,
    address,
    createdAt,
  ];
}
