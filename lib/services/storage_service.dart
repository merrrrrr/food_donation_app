import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  StorageService
//  Wraps Firebase Storage uploads.  All files are stored under structured
//  paths so Storage security rules can scope access by path prefix.
//
//  Storage layout:
//    donations/{donationId}/food_photo.jpg       ← donor's food image
//    donations/{donationId}/evidence_photo.jpg   ← NGO's handover evidence
//    users/{uid}/profile_photo.jpg               ← future: profile avatars
// ─────────────────────────────────────────────────────────────────────────────
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ── Food photo ────────────────────────────────────────────────────────────
  /// Uploads the donor's food photo and returns the public download URL.
  /// [onProgress] receives a 0.0–1.0 fraction for upload progress UI.
  Future<String> uploadFoodPhoto(
    File imageFile,
    String donationId, {
    void Function(double progress)? onProgress,
  }) async {
    return _uploadFile(
      file: imageFile,
      storagePath: 'donations/$donationId/food_photo.jpg',
      onProgress: onProgress,
    );
  }

  // ── Evidence photo ────────────────────────────────────────────────────────
  /// Uploads the NGO's evidence photo on handover completion.
  Future<String> uploadEvidencePhoto(
    File imageFile,
    String donationId, {
    void Function(double progress)? onProgress,
  }) async {
    return _uploadFile(
      file: imageFile,
      storagePath: 'donations/$donationId/evidence_photo.jpg',
      onProgress: onProgress,
    );
  }

  // ── Profile photo (future use) ────────────────────────────────────────────
  Future<String> uploadProfilePhoto(File imageFile, String uid) async {
    return _uploadFile(
      file: imageFile,
      storagePath: 'users/$uid/profile_photo.jpg',
    );
  }

  // ── Private upload helper ─────────────────────────────────────────────────
  Future<String> _uploadFile({
    required File file,
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref(storagePath);
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    // Wire up progress callback if provided
    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snap) {
        if (snap.totalBytes > 0) {
          onProgress(snap.bytesTransferred / snap.totalBytes);
        }
      });
    }

    await uploadTask;
    return ref.getDownloadURL();
  }
}
