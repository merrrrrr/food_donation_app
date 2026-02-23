import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/services/donation_service.dart';
import 'package:food_donation_app/services/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DonationProvider
//  Central store for donation lists.  Screens read data from here and call
//  action methods (create, claim, complete) which delegate to the services.
// ─────────────────────────────────────────────────────────────────────────────
class DonationProvider extends ChangeNotifier {
  final DonationService _donationService;
  final StorageService _storageService;

  // ── Public state ──────────────────────────────────────────────────────────
  List<DonationModel> donations = [];
  bool isLoading = false;
  double uploadProgress = 0.0;
  String? errorMessage;

  // ── Active stream subscriptions ───────────────────────────────────────────
  StreamSubscription<List<DonationModel>>? _donationSub;

  // ── Constructor ───────────────────────────────────────────────────────────
  DonationProvider({
    DonationService? donationService,
    StorageService? storageService,
  })  : _donationService = donationService ?? DonationService(),
        _storageService = storageService ?? StorageService();

  // ── Stream loaders ────────────────────────────────────────────────────────

  /// Loads real-time donations for a specific donor (Donor's Status tab).
  void loadDonorDonations(String donorId) {
    _cancelExistingSubscription();
    _donationSub = _donationService
        .getDonorDonations(donorId)
        .listen(_onDonationsReceived, onError: _onStreamError);
  }

  /// Loads real-time available (pending) donations (NGO Discovery screen).
  void loadAvailableDonations() {
    _cancelExistingSubscription();
    _donationSub = _donationService
        .getAvailableDonations()
        .listen(_onDonationsReceived, onError: _onStreamError);
  }

  /// Loads real-time claimed/completed donations for an NGO (NGO Profile).
  void loadNgoDonations(String ngoId) {
    _cancelExistingSubscription();
    _donationSub = _donationService
        .getNgoDonations(ngoId)
        .listen(_onDonationsReceived, onError: _onStreamError);
  }

  // ── Create ────────────────────────────────────────────────────────────────
  /// Creates a new donation.  If [foodImage] is provided it is uploaded to
  /// Storage first and the download URL is stored on the model.
  Future<bool> createDonation(
    DonationModel donation, {
    File? foodImage,
  }) async {
    _setLoading(true);
    try {
      // We need the ID before uploading so Storage path is predictable.
      // Generate client-side first, then upload, then create the doc.
      String? photoUrl;
      if (foodImage != null) {
        // Generate a temporary ID for the Storage path
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        uploadProgress = 0.0;
        photoUrl = await _storageService.uploadFoodPhoto(
          foodImage,
          tempId,
          onProgress: (p) {
            uploadProgress = p;
            notifyListeners();
          },
        );
      }

      final donationWithPhoto = photoUrl != null
          ? donation.copyWith(photoUrl: photoUrl)
          : donation;

      await _donationService.createDonation(donationWithPhoto);
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ── Claim ─────────────────────────────────────────────────────────────────
  Future<bool> claimDonation({
    required String donationId,
    required String ngoId,
    required String ngoName,
  }) async {
    _setLoading(true);
    try {
      await _donationService.claimDonation(
        donationId: donationId,
        ngoId: ngoId,
        ngoName: ngoName,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ── Complete ──────────────────────────────────────────────────────────────
  Future<bool> completeDonation({
    required String donationId,
    required File evidenceImage,
  }) async {
    _setLoading(true);
    try {
      uploadProgress = 0.0;
      final evidenceUrl = await _storageService.uploadEvidencePhoto(
        evidenceImage,
        donationId,
        onProgress: (p) {
          uploadProgress = p;
          notifyListeners();
        },
      );

      await _donationService.completeDonation(
        donationId: donationId,
        evidencePhotoUrl: evidenceUrl,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      _setLoading(false);
      return false;
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────
  Future<bool> cancelDonation(String donationId) async {
    try {
      await _donationService.cancelDonation(donationId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void _onDonationsReceived(List<DonationModel> data) {
    donations = data;
    notifyListeners();
  }

  void _onStreamError(Object err) {
    errorMessage = err.toString();
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    if (value) errorMessage = null;
    notifyListeners();
  }

  void _cancelExistingSubscription() {
    _donationSub?.cancel();
    _donationSub = null;
    donations = [];
  }

  @override
  void dispose() {
    _donationSub?.cancel();
    super.dispose();
  }
}
