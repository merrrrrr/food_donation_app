import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:food_donation_app/models/user_model.dart';
import 'package:food_donation_app/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AuthProvider
//  Exposes authentication state to the widget tree via Provider.
//
//  State machine:
//    authState == unknown  → app is still initialising (splash / loading)
//    authState == signedIn → currentUser is populated; role is determined
//    authState == signedOut→ show LoginScreen
// ─────────────────────────────────────────────────────────────────────────────
enum AuthState { unknown, signedIn, signedOut }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  // ── Public state ──────────────────────────────────────────────────────────
  UserModel? currentUser;
  // Start signed-out so the first visible screen is Login.
  AuthState authState = AuthState.signedOut;
  bool isLoading = false;
  String? errorMessage;

  // ── Internal ──────────────────────────────────────────────────────────────
  StreamSubscription<User?>? _authSub;

  // ── Constructor ───────────────────────────────────────────────────────────
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService() {
    _init();
  }

  // ── Initialise: listen to Firebase auth state ─────────────────────────────
  void _init() {
    _authSub = _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser == null) {
        currentUser = null;
        authState = AuthState.signedOut;
        notifyListeners();
      } else {
        try {
          // Re-fetch the full UserModel (role, displayName, etc.)
          currentUser = await _authService.fetchUserModel(firebaseUser.uid);
          authState = AuthState.signedIn;
        } catch (_) {
          // Profile missing — reset loading and sign out to recover gracefully
          isLoading = false;
          await _authService.signOut();
          authState = AuthState.signedOut;
        }
        isLoading = false;
        notifyListeners();
      }
    });
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phone,
  }) async {
    _setLoading(true);
    try {
      currentUser = await _authService.registerUser(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        phone: phone,
      );
      authState = AuthState.signedIn;
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ── Sign In ───────────────────────────────────────────────────────────────
  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    try {
      currentUser = await _authService.signIn(email: email, password: password);
      authState = AuthState.signedIn;
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    currentUser = null;
    authState = AuthState.signedOut;
    notifyListeners();
  }

  // ── Update profile ────────────────────────────────────────────────────────
  Future<bool> updateProfile({
    String? displayName,
    String? phone,
    String? address,
    String? photoUrl,
  }) async {
    if (currentUser == null) return false;

    _setLoading(true);
    try {
      currentUser = await _authService.updateUserProfile(
        uid: currentUser!.uid,
        displayName: displayName,
        phone: phone,
        address: address,
        photoUrl: photoUrl,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      _setLoading(false);
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    if (value) errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
