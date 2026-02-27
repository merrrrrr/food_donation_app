import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Maximum number of AI calls a single user can make per calendar day
/// (shared across AI Match and AI Autofill).
const int kAiDailyLimit = 10;

// ─────────────────────────────────────────────────────────────────────────────
//  AiQuotaService
//  Tracks per-user daily AI usage in Firestore under /ai_quotas/{uid}.
//  Document schema: { "date": "yyyy-MM-dd", "count": int }
//
//  Usage:
//    final quota = AiQuotaService();
//    if (!await quota.canUseAi(uid)) { /* show limit message */ return; }
//    // ... call Gemini ...
//    quota.incrementUsage(uid); // fire-and-forget after success
// ─────────────────────────────────────────────────────────────────────────────
class AiQuotaService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _docRef(String uid) =>
      _db.collection('ai_quotas').doc(uid);

  String get _today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// How many AI calls the user has made today.
  Future<int> getUsageToday(String uid) async {
    final snap = await _docRef(uid).get();
    if (!snap.exists) return 0;
    final data = snap.data()!;
    if (data['date'] != _today) return 0; // new day → treat as zero
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  /// Returns [true] if the user still has quota remaining for today.
  Future<bool> canUseAi(String uid) async {
    final used = await getUsageToday(uid);
    return used < kAiDailyLimit;
  }

  /// How many calls remain today.
  Future<int> remainingCalls(String uid) async {
    final used = await getUsageToday(uid);
    return (kAiDailyLimit - used).clamp(0, kAiDailyLimit);
  }

  /// Atomically increments the usage counter for today.
  /// Call this only after a successful AI response (fire-and-forget is fine).
  Future<void> incrementUsage(String uid) async {
    await _docRef(uid).set(
      {'date': _today, 'count': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }
}
