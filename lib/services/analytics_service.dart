import 'package:firebase_analytics/firebase_analytics.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AnalyticsService
//  Thin singleton wrapper around FirebaseAnalytics that centralises every
//  custom event used to measure the three success metrics:
//
//  Metric 1 — Donation Completion Rate (%)
//    Events : donation_created  /  donation_completed
//    Formula: count(donation_completed) / count(donation_created)  × 100
//    Target : > 60 %
//
//  Metric 2 — Time-to-Claim (minutes)
//    Event  : donation_claimed   param: time_to_claim_minutes (double)
//    Formula: avg(time_to_claim_minutes) across all donation_claimed events
//    Target : < 60 minutes average
//
//  Metric 3 — AI Match Acceptance Rate (%)
//    Events : ai_match_donation_shown (one per result card displayed)
//             ai_match_donation_claimed (one per claim made from AI screen)
//    Formula: count(ai_match_donation_claimed) /
//             count(distinct donation_id in ai_match_donation_shown) × 100
//    Target : > 40 %
//
//  All events are visible in the Firebase Console under
//  Analytics → Events and Analytics → Custom definitions.
//  Use Google Analytics (linked automatically to Firebase) for dashboards,
//  funnels, and custom reports.
// ─────────────────────────────────────────────────────────────────────────────
class AnalyticsService {
  // ── Singleton ─────────────────────────────────────────────────────────────
  AnalyticsService._();
  static final AnalyticsService _instance = AnalyticsService._();
  factory AnalyticsService() => _instance;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ── Public getter for the observer (used in MaterialApp) ──────────────────
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ── Metric 1 helpers ──────────────────────────────────────────────────────

  /// Call immediately after a donation document is written to Firestore.
  /// Increments the denominator for Donation Completion Rate.
  Future<void> logDonationCreated(String donationId) async {
    await _analytics.logEvent(
      name: 'donation_created',
      parameters: {'donation_id': donationId},
    );
  }

  /// Call when a donation transitions to `completed` status.
  /// Increments the numerator for Donation Completion Rate.
  Future<void> logDonationCompleted(String donationId) async {
    await _analytics.logEvent(
      name: 'donation_completed',
      parameters: {'donation_id': donationId},
    );
  }

  // ── Metric 2 helper ───────────────────────────────────────────────────────

  /// Call when a donation transitions to `claimed` status.
  /// [createdAt] is the Firestore `createdAt` timestamp of the donation;
  /// used to compute how many minutes elapsed before the NGO claimed it.
  /// The computed value is surfaced as `time_to_claim_minutes` in GA so you
  /// can use the "average parameter value" feature in the Analytics Console.
  Future<void> logDonationClaimed({
    required String donationId,
    required DateTime? createdAt,
  }) async {
    final double? minutesDiff = createdAt != null
        ? DateTime.now().difference(createdAt).inSeconds / 60.0
        : null;

    await _analytics.logEvent(
      name: 'donation_claimed',
      parameters: {
        'donation_id': donationId,
        if (minutesDiff != null)
          'time_to_claim_minutes': double.parse(minutesDiff.toStringAsFixed(2)),
      },
    );
  }

  // ── Metric 3 helpers ──────────────────────────────────────────────────────

  /// Call once for **each** donation card displayed in the AI Match results.
  /// Logging per-donation (rather than a single batch event) allows GA to
  /// correctly compute the Acceptance Rate at the individual donation level.
  Future<void> logAiMatchDonationShown(String donationId) async {
    await _analytics.logEvent(
      name: 'ai_match_donation_shown',
      parameters: {'donation_id': donationId},
    );
  }

  /// Call when a donation that was surfaced by the AI Match screen is
  /// successfully claimed by an NGO.
  /// Increments the numerator for AI Match Acceptance Rate.
  Future<void> logAiMatchDonationClaimed(String donationId) async {
    await _analytics.logEvent(
      name: 'ai_match_donation_claimed',
      parameters: {'donation_id': donationId},
    );
  }

  // ── Screen tracking (automatic via FirebaseAnalyticsObserver) ─────────────
  // Named routes are tracked automatically once the observer is registered in
  // MaterialApp.  No manual calls are needed for screen_view events.
}
