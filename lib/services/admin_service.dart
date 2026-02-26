import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_donation_app/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AdminService
//  Service layer for Admin-specific operations in Firestore.
// ─────────────────────────────────────────────────────────────────────────────
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Convenience ref ───────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  // ── Streams ────────────────────────────────────────────────────────────────
  /// Stream of all users with role 'ngo' and isVerified == false
  Stream<List<UserModel>> streamPendingNGOs() {
    return _usersCol
        .where('role', isEqualTo: UserRole.ngo.toJson())
        .where('isVerified', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromDocument(doc)).toList(),
        );
  }

  // ── Approve NGO ────────────────────────────────────────────────────────────
  /// Approves an NGO by setting isVerified to true.
  Future<void> approveNGO(String uid) async {
    await _usersCol.doc(uid).update({'isVerified': true});
  }
}
