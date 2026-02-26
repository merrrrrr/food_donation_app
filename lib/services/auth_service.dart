import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_donation_app/models/user_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AuthService
//  A thin, stateless service that wraps Firebase Auth and the Firestore
//  `/users` collection.  Providers call into this class; it never holds state.
// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Convenience ref ───────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  // ── Auth state stream ─────────────────────────────────────────────────────
  /// Emits the raw Firebase [User] (or null) whenever auth state changes.
  /// The AuthProvider listens to this and fetches the full [UserModel].
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Current Firebase user ─────────────────────────────────────────────────
  User? get currentFirebaseUser => _auth.currentUser;

  // ── Register ──────────────────────────────────────────────────────────────
  /// Creates a Firebase Auth account and writes the initial [UserModel] doc.
  /// Returns the created [UserModel] on success, or throws a [AuthException].
  Future<UserModel> registerUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    String? phone,
    String? registrationNumber,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      final newUser = UserModel(
        uid: uid,
        displayName: displayName.trim(),
        email: email.trim(),
        role: role,
        phone: phone?.trim() ?? '',
        isVerified: role == UserRole.ngo ? false : true,
        registrationNumber: registrationNumber?.trim(),
      );

      // Write user profile; include createdAt server timestamp on first write
      await _usersCol.doc(uid).set(newUser.toDocument(includeCreatedAt: true));

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  // ── Sign In ───────────────────────────────────────────────────────────────
  /// Authenticates the user and returns the matching [UserModel] from Firestore.
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return fetchUserModel(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      throw _mapAuthException(e);
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async => _auth.signOut();

  // ── Fetch UserModel ───────────────────────────────────────────────────────
  /// Reads and deserialises the [UserModel] for a given [uid].
  /// Throws if the document doesn't exist (shouldn't happen in normal flow).
  Future<UserModel> fetchUserModel(String uid) async {
    final snap = await _usersCol.doc(uid).get();
    if (!snap.exists) {
      throw Exception('User profile not found for uid: $uid');
    }
    return UserModel.fromDocument(snap);
  }

  // ── Update profile ────────────────────────────────────────────────────────
  /// Partially updates a user's profile document and returns the new model.
  Future<UserModel> updateUserProfile({
    required String uid,
    String? displayName,
    String? phone,
    String? address,
    String? photoUrl,
  }) async {
    final Map<String, dynamic> data = {};
    if (displayName != null) data['displayName'] = displayName.trim();
    if (phone != null) data['phone'] = phone.trim();
    if (address != null) data['address'] = address.trim();
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    if (data.isEmpty) {
      // Nothing to update; just return current snapshot.
      return fetchUserModel(uid);
    }

    await _usersCol.doc(uid).update(data);
    return fetchUserModel(uid);
  }

  // ── Error mapping ─────────────────────────────────────────────────────────
  /// Converts Firebase error codes into human-readable messages.
  Exception _mapAuthException(FirebaseAuthException e) {
    final message = switch (e.code) {
      'email-already-in-use' => 'An account with this email already exists.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password must be at least 6 characters.',
      'user-not-found' => 'No account found for this email.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'too-many-requests' =>
        'Too many failed attempts. Please try again later.',
      'network-request-failed' =>
        'Network error. Please check your connection.',
      _ => e.message ?? 'An unexpected error occurred.',
    };
    return Exception(message);
  }
}
