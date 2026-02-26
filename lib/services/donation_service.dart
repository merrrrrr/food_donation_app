import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DonationService
//  Stateless Firestore gateway for the `/donations` collection.
//  All heavy lifting (error handling, state) lives in DonationProvider.
// ─────────────────────────────────────────────────────────────────────────────
class DonationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // ── Convenience ref ───────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _donationsCol =>
      _db.collection('donations');

  // ── Create ────────────────────────────────────────────────────────────────
  /// Persists a new donation. Generates a UUID for the document ID so the
  /// caller can reference the ID optimistically (e.g., for Storage paths)
  /// before the write completes.
  Future<String> createDonation(DonationModel donation) async {
    final id = _uuid.v4();
    final docRef = _donationsCol.doc(id);

    // toNewDocument() adds createdAt server timestamp
    await docRef.set({...donation.toNewDocument()});
    return id;
  }

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Real-time stream of a specific donor's donations, ordered newest first.
  Stream<List<DonationModel>> getDonorDonations(String donorId) {
    return _donationsCol
        .where('donorId', isEqualTo: donorId)
        // Avoid Firestore composite index requirement by sorting client-side.
        .snapshots()
        .map((snap) {
      final list = _mapSnapshot(snap);
      list.sort((a, b) {
        final aCreated =
            a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bCreated =
            b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bCreated.compareTo(aCreated); // newest first
      });
      return list;
    });
  }

  /// Real-time stream of all `pending` donations — used by the NGO discovery
  /// screen.  Ordered by expiry date ascending so soonest-to-expire appear
  /// first (consistent with the map pin colour coding).
  Stream<List<DonationModel>> getAvailableDonations() {
    return _donationsCol
        .where('status', isEqualTo: DonationStatus.pending.toJson())
        // Avoid Firestore composite index requirement by sorting client-side.
        .snapshots()
        .map((snap) {
      final list = _mapSnapshot(snap);
      list.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      return list;
    });
  }

  /// Real-time stream of a specific NGO's claimed/completed donations.
  Stream<List<DonationModel>> getNgoDonations(String ngoId) {
    return _donationsCol
        .where('ngoId', isEqualTo: ngoId)
        // Avoid Firestore composite index requirement by sorting client-side.
        .snapshots()
        .map((snap) {
      final list = _mapSnapshot(snap);
      list.sort((a, b) {
        final aUpdated =
            a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bUpdated =
            b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bUpdated.compareTo(aUpdated); // newest first
      });
      return list;
    });
  }

  // ── Fetch single ──────────────────────────────────────────────────────────
  Future<DonationModel> getDonation(String donationId) async {
    final snap = await _donationsCol.doc(donationId).get();
    if (!snap.exists) throw Exception('Donation not found: $donationId');
    return DonationModel.fromDocument(snap);
  }

  // ── Claim ─────────────────────────────────────────────────────────────────
  /// Transitions a donation from `pending` → `claimed`.
  /// Uses a transaction to guard against race conditions (two NGOs claiming
  /// simultaneously).
  Future<void> claimDonation({
    required String donationId,
    required String ngoId,
    required String ngoName,
    required String ngoPhone,
  }) async {
    await _db.runTransaction((tx) async {
      final ref = _donationsCol.doc(donationId);
      final snap = await tx.get(ref);

      if (!snap.exists) throw Exception('Donation not found.');

      final currentStatus = snap.data()!['status'] as String;
      if (currentStatus != DonationStatus.pending.toJson()) {
        throw Exception('This donation has already been claimed.');
      }

      tx.update(ref, {
        'status': DonationStatus.claimed.toJson(),
        'ngoId': ngoId,
        'ngoName': ngoName,
        'ngoPhone': ngoPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Complete ──────────────────────────────────────────────────────────────
  /// Transitions a donation from `claimed` → `completed` and attaches the
  /// evidence photo URL uploaded by the NGO.
  Future<void> completeDonation({
    required String donationId,
    required String evidencePhotoUrl,
  }) async {
    await _donationsCol.doc(donationId).update({
      'status': DonationStatus.completed.toJson(),
      'evidencePhotoUrl': evidencePhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  /// Allows a donor to cancel a listing while it is still `pending`.
  Future<void> cancelDonation(String donationId) async {
    await _donationsCol.doc(donationId).update({
      'status': DonationStatus.cancelled.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  List<DonationModel> _mapSnapshot(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map(DonationModel.fromDocument).toList();
}
