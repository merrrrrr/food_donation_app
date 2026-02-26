import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:food_donation_app/models/user_model.dart';
import 'package:food_donation_app/services/admin_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AdminProvider
//  Manages the state of the admin dashboard, including listening to pending NGOs
//  and handling approval actions.
// ─────────────────────────────────────────────────────────────────────────────
class AdminProvider extends ChangeNotifier {
  final AdminService _adminService;
  StreamSubscription<List<UserModel>>? _pendingNGOsSub;

  List<UserModel> _pendingNGOs = [];
  List<UserModel> get pendingNGOs => _pendingNGOs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Track approval loading state per UID
  final Set<String> _approvingUids = {};

  AdminProvider({AdminService? adminService})
    : _adminService = adminService ?? AdminService();

  void startAdminSession() {
    if (_pendingNGOsSub == null) {
      _subscribeToPendingNGOs();
    }
  }

  void endAdminSession() {
    _unsubscribe();
  }

  void _subscribeToPendingNGOs() {
    _setLoading(true);
    _pendingNGOsSub?.cancel();
    _pendingNGOsSub = _adminService.streamPendingNGOs().listen(
      (ngos) {
        _pendingNGOs = ngos;
        _setLoading(false);
      },
      onError: (e) {
        _errorMessage = "Failed to load pending NGOs: $e";
        _setLoading(false);
      },
    );
  }

  void _unsubscribe() {
    _pendingNGOsSub?.cancel();
    _pendingNGOsSub = null;
    _pendingNGOs = [];
  }

  bool isApproving(String uid) => _approvingUids.contains(uid);

  Future<bool> approveNGO(String uid) async {
    _approvingUids.add(uid);
    notifyListeners();

    try {
      await _adminService.approveNGO(uid);
      _approvingUids.remove(uid);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to approve NGO: $e';
      _approvingUids.remove(uid);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setLoading(bool val) {
    if (_isLoading != val) {
      _isLoading = val;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
