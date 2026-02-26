import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/models/user_model.dart';
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
  /// Donations for the currently signed-in **donor** (Donor Status screen).
  List<DonationModel> donorDonations = [];

  /// Donations visible to the signed-in **NGO** (Discovery + NGO Home screen).
  List<DonationModel> availableDonations = [];

  /// Donations attributed to the signed-in **NGO** (NGO Profile screen).
  List<DonationModel> ngoDonations = [];

  bool isLoading = false;
  double uploadProgress = 0.0;
  String? errorMessage;

  // ── Active stream subscriptions + session tracking ────────────────────────
  StreamSubscription<List<DonationModel>>? _donorSub;
  StreamSubscription<List<DonationModel>>? _availableSub;
  StreamSubscription<List<DonationModel>>? _ngoSub;

  /// UID of the user whose streams are currently active. Guards against
  /// redundant restarts when AuthProvider calls notifyListeners() for reasons
  /// unrelated to sign-in (e.g. loading flag, profile update).
  String? _activeSessionUid;

  // ── Constructor ───────────────────────────────────────────────────────────
  DonationProvider({
    DonationService? donationService,
    StorageService? storageService,
  }) : _donationService = donationService ?? DonationService(),
       _storageService = storageService ?? StorageService();

  // ── Session lifecycle ────────────────────────────────────────────────────
  /// Called once when the user signs in. Starts the appropriate Firestore
  /// streams for the user's role. Screens do NOT need to call load* methods;
  /// they simply read from [donorDonations], [availableDonations], or
  /// [ngoDonations] via context.watch<DonationProvider>().
  void startSessionFor(UserModel user) {
    // Guard: only restart if a different user (or first login).
    if (_activeSessionUid == user.uid) return;
    _activeSessionUid = user.uid;
    endSession(clearUid: false); // cancel stale streams but keep new uid
    if (user.role == UserRole.donor) {
      _donorSub = _donationService.getDonorDonations(user.uid).listen((data) {
        donorDonations = data;
        notifyListeners();
      }, onError: _onStreamError);
    } else if (user.role == UserRole.ngo) {
      _availableSub = _donationService.getAvailableDonations().listen((data) {
        availableDonations = data;
        notifyListeners();
      }, onError: _onStreamError);
      _ngoSub = _donationService.getNgoDonations(user.uid).listen((data) {
        ngoDonations = data;
        notifyListeners();
      }, onError: _onStreamError);
    }
  }

  /// Cancels all subscriptions and clears cached data. Called on sign-out.
  void endSession({bool clearUid = true}) {
    if (clearUid) _activeSessionUid = null;
    _donorSub?.cancel();
    _availableSub?.cancel();
    _ngoSub?.cancel();
    _donorSub = null;
    _availableSub = null;
    _ngoSub = null;
    donorDonations = [];
    availableDonations = [];
    ngoDonations = [];
    notifyListeners();
  }

  // ── Manual refresh (pull-to-refresh support) ──────────────────────────────
  /// Restarts only the donor stream (used by pull-to-refresh on status screen).
  void loadDonorDonations(String donorId) {
    _donorSub?.cancel();
    _donorSub = _donationService.getDonorDonations(donorId).listen((data) {
      donorDonations = data;
      notifyListeners();
    }, onError: _onStreamError);
  }

  /// Restarts only the available stream (used by pull-to-refresh on discovery).
  void loadAvailableDonations() {
    _availableSub?.cancel();
    _availableSub = _donationService.getAvailableDonations().listen((data) {
      availableDonations = data;
      notifyListeners();
    }, onError: _onStreamError);
  }

  /// Restarts only the NGO claimed stream.
  void loadNgoDonations(String ngoId) {
    _ngoSub?.cancel();
    _ngoSub = _donationService.getNgoDonations(ngoId).listen((data) {
      ngoDonations = data;
      notifyListeners();
    }, onError: _onStreamError);
  }

  // ── Create ────────────────────────────────────────────────────────────────
  /// Creates a new donation.  If [foodImage] is provided it is uploaded to
  /// Storage first and the download URL is stored on the model.
  Future<bool> createDonation(DonationModel donation, {File? foodImage}) async {
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
    required String ngoPhone,
  }) async {
    _setLoading(true);
    try {
      await _donationService.claimDonation(
        donationId: donationId,
        ngoId: ngoId,
        ngoName: ngoName,
        ngoPhone: ngoPhone,
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

  void _onStreamError(Object err) {
    errorMessage = err.toString();
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    if (value) errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _donorSub?.cancel();
    _availableSub?.cancel();
    _ngoSub?.cancel();
    super.dispose();
  }
}
