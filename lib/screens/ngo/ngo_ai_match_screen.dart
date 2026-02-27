import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/services/ai_quota_service.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Firebase AI Logic — no API key required. Auth is handled by Firebase.
//  Enable "Firebase AI Logic" in your Firebase console before using this.
//  https://firebase.google.com/docs/ai-logic/get-started
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
//  Dietary preference options shown in the form dropdown.
// ─────────────────────────────────────────────────────────────────────────────
const _kDietaryOptions = ['Any', 'Halal', 'Vegetarian / Vegan'];

// ─────────────────────────────────────────────────────────────────────────────
//  NgoAiMatchScreen
//  Lets the NGO describe their needs, then uses Gemini 2.0 Flash via
//  Firebase AI Logic to rank available (pending, non-expired) donations.
// ─────────────────────────────────────────────────────────────────────────────
class NgoAiMatchScreen extends StatefulWidget {
  const NgoAiMatchScreen({super.key});

  @override
  State<NgoAiMatchScreen> createState() => _NgoAiMatchScreenState();
}

class _NgoAiMatchScreenState extends State<NgoAiMatchScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ── Form controllers ──────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _foodTypeCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedDietary = 'Any';
  double _maxDistanceKm = 10;

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isAnalysing = false;
  String? _errorMessage;
  List<_MatchResult> _results = [];
  bool _hasSearched = false;

  // Retry state — shown in the loading banner
  int _retryAttempt = 0; // 0 = first attempt, 1/2 = retries
  int _retryCountdown = 0; // seconds remaining before next attempt
  Timer? _countdownTimer;

  // Cooldown to prevent rate limit spam
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  // Caching: prevent redundant calls if inputs haven't changed
  String? _lastSearchRequestHash;
  List<_MatchResult>? _cachedResults;

  // Current device location (used for distance calculation)
  Position? _devicePosition;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cooldownTimer?.cancel();
    _foodTypeCtrl.dispose();
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Location ──────────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (mounted) setState(() => _devicePosition = pos);
    } catch (_) {
      // Location optional — distance filter will be skipped
    }
  }

  // ── Haversine distance (km) ───────────────────────────────────────────────
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * pi / 180;

  // ── Build candidate list for Gemini ───────────────────────────────────────
  List<DonationModel> get _eligibleDonations {
    final all = context.read<DonationProvider>().availableDonations;
    final now = DateTime.now();

    return all.where((d) {
      // Must be pending and not expired
      if (d.status != DonationStatus.pending) return false;
      if (d.expiryDate.isBefore(now)) return false;

      // Distance filter (only when we have the device location)
      if (_devicePosition != null) {
        final dist = _distanceKm(
          _devicePosition!.latitude,
          _devicePosition!.longitude,
          d.latitude,
          d.longitude,
        );
        if (dist > _maxDistanceKm) return false;
      }

      return true;
    }).toList();
  }

  // ── Parse retry delay from Gemini quota error string ─────────────────────
  // The API returns e.g. "Please retry in 4.026734549s"
  Duration? _parseRetryDelay(String errorMsg) {
    final match = RegExp(
      r'Please retry in ([\d.]+)s',
      caseSensitive: false,
    ).firstMatch(errorMsg);
    if (match == null) return null;
    final secs = double.tryParse(match.group(1) ?? '');
    if (secs == null) return null;
    // Add 1 s buffer so we don't hit the edge of the window
    return Duration(milliseconds: ((secs + 1.5) * 1000).round());
  }

  // ── Countdown ticker ─────────────────────────────────────────────────────
  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _retryCountdown = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _retryCountdown--;
        if (_retryCountdown <= 0) t.cancel();
      });
    });
  }

  // ── Cooldown timer ───────────────────────────────────────────────────────
  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownRemaining = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) t.cancel();
      });
    });
  }

  // ── Parse the leading integer from a quantity string ──────────────────────
  // e.g. "30 box" → 30,  "15 cups" → 15,  "unknown" → null
  int? _parseQtyNumber(String quantity) {
    final match = RegExp(r'^\s*(\d+)').firstMatch(quantity);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  // ── Local fuzzy pre-ranking ──────────────────────────────────────────────
  // Assigns a rough score based on dietary, distance, keyword match,
  // and how well the donation quantity covers the number of people needed.
  int _localScore(
    DonationModel d,
    String query,
    String dietary, {
    int? peopleCount,
  }) {
    int score = 0;

    // 1. Dietary Match (Critical)
    if (dietary != 'Any') {
      if (dietary == 'Halal') {
        if (d.sourceStatus == DietarySourceStatus.halal) {
          score += 150;
        } else if (d.sourceStatus == DietarySourceStatus.porkFree) {
          score += 80;
        } else {
          score -= 300; // Severe penalty for non-halal when halal requested
        }
      } else if (dietary == 'Vegetarian / Vegan') {
        if (d.dietaryBase == DietaryBase.vegan ||
            d.dietaryBase == DietaryBase.vegetarian) {
          score += 150;
        } else {
          score -= 300; // Severe penalty
        }
      }
    }

    // 2. Keyword Match (Food Name)
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final name = d.foodName.toLowerCase();
      if (name.contains(q)) {
        score += 100;
      }
    }

    // 3. Quantity-fit vs people to feed
    if (peopleCount != null && peopleCount > 0) {
      final donationQty = _parseQtyNumber(d.quantity);
      if (donationQty != null) {
        final ratio = donationQty / peopleCount;
        if (ratio >= 1.0) {
          score += 120; // Covers everyone — best case
        } else if (ratio >= 0.75) {
          score += 70;  // Covers 75%+ — still useful
        } else if (ratio >= 0.5) {
          score += 30;  // Covers half — marginal
        } else {
          score -= 50;  // Too little to make a meaningful difference
        }
      }
    }

    // 4. Distance Bonus
    if (_devicePosition != null) {
      final dist = _distanceKm(
        _devicePosition!.latitude,
        _devicePosition!.longitude,
        d.latitude,
        d.longitude,
      );
      if (dist < 3) {
        score += 60;
      } else if (dist < 8) {
        score += 30;
      }
    }

    // 5. Freshness
    if (d.isExpiringSoon) score += 20;

    return score;
  }

  // ── Main analysis call (with retry) ──────────────────────────────────────
  Future<void> _analyse() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Check cooldown
    if (_cooldownRemaining > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please wait ${_cooldownRemaining}s before searching again.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 2. Check daily AI quota
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != null) {
      final allowed = await AiQuotaService().canUseAi(uid);
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Daily AI limit reached ($kAiDailyLimit calls/day). Try again tomorrow.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    final candidates = _eligibleDonations;
    if (candidates.isEmpty) {
      setState(() {
        _hasSearched = true;
        _results = [];
        _errorMessage = null;
      });
      return;
    }

    // 2. Local Pre-Ranking to pick the TOP 6 (reduced from 10 to save quota/speed)
    final query = _foodTypeCtrl.text.trim();
    final qty = _quantityCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    // Generate a simple hash of current inputs
    final currentHash =
        '$query|$_selectedDietary|$qty|$notes|${_maxDistanceKm.toInt()}';

    // CHECK CACHE: If inputs haven't changed and we have results, reuse them
    if (currentHash == _lastSearchRequestHash && _cachedResults != null) {
      setState(() {
        _results = _cachedResults!;
        _hasSearched = true;
        _isAnalysing = false;
        _errorMessage = 'Showing cached results (inputs haven\'t changed).';
      });
      return;
    }

    final parsedPeopleCount = int.tryParse(qty);

    final topCandidates = List<DonationModel>.from(candidates)
      ..sort((a, b) {
        final sa = _localScore(a, query, _selectedDietary, peopleCount: parsedPeopleCount);
        final sb = _localScore(b, query, _selectedDietary, peopleCount: parsedPeopleCount);
        return sb.compareTo(sa); // Highest local score first
      });

    final capped = topCandidates.take(6).toList();

    // 3. Minified JSON payload to save tokens
    final donationJson = capped.map((d) {
      final dist = _devicePosition != null
          ? _distanceKm(
              _devicePosition!.latitude,
              _devicePosition!.longitude,
              d.latitude,
              d.longitude,
            ).toStringAsFixed(1)
          : null;
      final numericQty = _parseQtyNumber(d.quantity);
      return {
        'i': d.id,                                           // i = id
        'f': d.foodName,                                     // f = food
        'q': d.quantity,                                     // q = qty string
        if (numericQty != null) 'n': numericQty,             // n = numeric qty
        'd': '${d.sourceStatus} / ${d.dietaryBase}',         // d = diet
        'e': DateFormat('MM-dd HH:mm').format(d.expiryDate), // e = expiry
        if (dist != null) 'k': dist,                         // k = km
      };
    }).toList();

    final needsFood = query.isEmpty ? 'any' : query;
    final needsQty = qty.isEmpty ? 'unspecified' : qty;
    final needsNotes = notes.isEmpty ? '' : ' Notes: $notes';

    // UI Feedback for fresh analysis
    setState(() {
      _isAnalysing = true;
      _errorMessage = null;
      _results = [];
      _retryAttempt = 0;
      _retryCountdown = 0;
    });
    _startCooldown(45); // Increased to 45s for Free Tier safety

    final prompt =
        '''
Role: Food Security & Nutrition Coordinator for NGO.
Goal: Match available donations to the NGO's specific needs.

NGO Profile:
- Feeding Need: $needsQty persons
- Dietary Requirement: $_selectedDietary
- Specific Food Requested: $needsFood
- Context: $needsNotes

Available Inventory (JSON):
${jsonEncode(donationJson)}

Tasks:
1. Filter out items that strictly violate the Dietary Requirement (e.g., non-halal food for Halal needs).
2. Rank items by how well they satisfy the Feeding Need. Use the numeric qty field "n" to judge sufficiency:
   - n >= people needed          → quantity label "Perfect Match" or "Generous", score boost +20
   - n >= 0.75 * people needed   → "Nearly Sufficient", no penalty
   - n >= 0.5  * people needed   → "Insufficient — covers ~half", score penalty -15
   - n <  0.5  * people needed   → "Too Little", score penalty -30
   - If "n" is absent, infer from the qty string.
3. Also consider food type relevance and dietary compatibility.
4. For "reason", state the quantity verdict and why it matches in ≤15 words.

Return ONLY a compact JSON array with NO whitespace or newlines between tokens.
Format: [{"i":"id","s":score_0_to_100,"r":"reason_max_15_words"}]
Sort by score descending. Only include scores >= 30.
''';

    debugPrint('--- AI MATCH REQUEST ---\n$prompt\n------------------------');

    // Firebase AI Logic — uses your Firebase project quota, no API key in app
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 4000,
        responseMimeType: 'application/json',
      ),
    );

    // ── Retry loop (max 2 attempts for quota safety) ────────────────────────
    const maxAttempts = 2;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        if (attempt > 0) setState(() => _retryAttempt = attempt);

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text ?? '';
        debugPrint(
          '--- AI MATCH RESPONSE ---\n$text\n-------------------------',
        );

        // Parse JSON response — with fallback for truncated output
        final parsed = _parseJsonSafe(text);

        final candidateMap = {for (final d in capped) d.id: d};
        final results = <_MatchResult>[];

        for (final item in parsed) {
          final map = item as Map<String, dynamic>;
          final id = map['i'] as String?;
          final score = (map['s'] as num?)?.toInt() ?? 0;
          final reason = map['r'] as String? ?? '';
          if (id != null && candidateMap.containsKey(id)) {
            final donation = candidateMap[id]!;
            final dist = _devicePosition != null
                ? _distanceKm(
                    _devicePosition!.latitude,
                    _devicePosition!.longitude,
                    donation.latitude,
                    donation.longitude,
                  )
                : null;
            results.add(
              _MatchResult(
                donation: donation,
                matchScore: score,
                reason: reason,
                distanceKm: dist,
              ),
            );
          }
        }

        // ✅ Success
        _countdownTimer?.cancel();
        if (uid != null) AiQuotaService().incrementUsage(uid);
        setState(() {
          _results = results;
          _cachedResults = results;
          _lastSearchRequestHash = currentHash;
          _hasSearched = true;
          _isAnalysing = false;
          _retryAttempt = 0;
          _retryCountdown = 0;
        });
        return; // done — exit the retry loop
      } catch (e) {
        final errStr = e.toString();
        // Extract strictly 429 or Resource Exhausted
        final isQuotaError =
            errStr.contains('RESOURCE_EXHAUSTED') || errStr.contains('429');

        final delay = _parseRetryDelay(errStr);

        // If it's not a quota/rate error, or last attempt — bail out with fallback results
        if (!isQuotaError || attempt == maxAttempts - 1) {
          _countdownTimer?.cancel();

          // ── Fallback ──────────────────────────────────────────────────────
          // If Gemini fails, we show the top local results instead of an error.
          final fallbackResults = capped
              .where((d) {
                final score = _localScore(d, query, _selectedDietary, peopleCount: parsedPeopleCount);
                return score >= 40; // Only decent local matches
              })
              .map((d) {
                final dist = _devicePosition != null
                    ? _distanceKm(
                        _devicePosition!.latitude,
                        _devicePosition!.longitude,
                        d.latitude,
                        d.longitude,
                      )
                    : null;
                return _MatchResult(
                  donation: d,
                  matchScore:
                      0, // 0 indicates it's a local fallback (can be shown as "Local Match")
                  reason: 'Selected by system filters (AI offline).',
                  distanceKm: dist,
                );
              })
              .toList();

          setState(() {
            if (fallbackResults.isNotEmpty) {
              _results = fallbackResults;
              _errorMessage =
                  'AI is currently busy. Showing local matches based on your filters.';
            } else {
              _errorMessage = _friendlyError(errStr);
            }
            _isAnalysing = false;
            _hasSearched = true;
            _retryAttempt = 0;
            _retryCountdown = 0;
          });
          debugPrint('AI Analysis failed. Error: $errStr');
          return;
        }

        // Wait the recommended delay before retrying
        final waitSecs = (delay?.inSeconds ?? (8 * (attempt + 1))).clamp(5, 45);
        _startCountdown(waitSecs);
        await Future.delayed(Duration(seconds: waitSecs));
      }
    }
  }

  // ── Safe JSON parser — recovers partial objects if response was truncated ──
  List<dynamic> _parseJsonSafe(String text) {
    // 1. Try standard parse first
    try {
      return jsonDecode(text) as List<dynamic>;
    } catch (_) {}

    // 2. Extract all complete JSON objects via regex as fallback
    final objects = <dynamic>[];
    final re = RegExp(r'\{[^{}]+\}');
    for (final match in re.allMatches(text)) {
      try {
        objects.add(jsonDecode(match.group(0)!));
      } catch (_) {
        // skip malformed fragment
      }
    }
    if (objects.isNotEmpty) return objects;

    // 3. Nothing salvageable — rethrow so the caller falls back to local results
    throw FormatException('AI returned unparseable response: $text');
  }

  // ── Friendly error messages ───────────────────────────────────────────────
  String _friendlyError(String raw) {
    if (raw.contains('RESOURCE_EXHAUSTED') || raw.contains('429')) {
      return 'Firebase AI quota reached. Try again in a moment.';
    }
    if (raw.contains('SAFETY')) {
      return 'Content Blocked: The AI refused to process this request due to safety filters.';
    }

    // Provide the raw error so we can see what's actually happening
    return 'Analysis interrupted. Please try again.\n\nError Details: $raw';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
            const Gap(8),
            const Text('AI Food Match'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header banner ───────────────────────────────────────────────
            _AiBanner(colorScheme: colorScheme, textTheme: textTheme),
            const Gap(24),

            // ── Needs form ──────────────────────────────────────────────────
            _NeedsForm(
              formKey: _formKey,
              foodTypeCtrl: _foodTypeCtrl,
              quantityCtrl: _quantityCtrl,
              notesCtrl: _notesCtrl,
              selectedDietary: _selectedDietary,
              onDietaryChanged: (v) =>
                  setState(() => _selectedDietary = v ?? 'Any'),
              maxDistanceKm: _maxDistanceKm,
              onDistanceChanged: (v) => setState(() => _maxDistanceKm = v),
              locationAvailable: _devicePosition != null,
            ),
            const Gap(20),

            // ── Analyse button ──────────────────────────────────────────────
            FilledButton.icon(
              icon: _isAnalysing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _isAnalysing
                    ? 'Analysing…'
                    : (_cooldownRemaining > 0
                          ? 'Wait ${_cooldownRemaining}s'
                          : 'Find Matches'),
              ),
              onPressed: (_isAnalysing || _cooldownRemaining > 0)
                  ? null
                  : _analyse,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: colorScheme.primary,
              ),
            ),

            const Gap(28),

            // ── Results ─────────────────────────────────────────────────────
            if (_isAnalysing) ...[
              _LoadingShimmer(
                colorScheme: colorScheme,
                retryAttempt: _retryAttempt,
                retryCountdown: _retryCountdown,
              ),
            ] else if (_errorMessage != null) ...[
              _ErrorCard(message: _errorMessage!),
            ] else if (_hasSearched && _results.isEmpty) ...[
              _EmptyResults(colorScheme: colorScheme, textTheme: textTheme),
            ] else if (_results.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'Matched Donations',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_results.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(12),
              ..._results.map(
                (r) => _MatchCard(
                  result: r,
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(AppRouter.ngoFoodDetail, arguments: r.donation),
                ),
              ),
            ],
            const Gap(24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data class
// ─────────────────────────────────────────────────────────────────────────────
class _MatchResult {
  final DonationModel donation;
  final int matchScore;
  final String reason;
  final double? distanceKm;

  const _MatchResult({
    required this.donation,
    required this.matchScore,
    required this.reason,
    this.distanceKm,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AiBanner extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  const _AiBanner({required this.colorScheme, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF7C5CBF), const Color(0xFF9D7FD4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.radiusLg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA07DD1).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalized Matching',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Gap(6),
                Text(
                  'Enter your dietary preferences and the number of people you need to feed. Gemini AI will calculate the best portion matches.',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),
          const Icon(
            Icons.auto_awesome_rounded,
            size: 52,
            color: Colors.white24,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _NeedsForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController foodTypeCtrl;
  final TextEditingController quantityCtrl;
  final TextEditingController notesCtrl;
  final String selectedDietary;
  final ValueChanged<String?> onDietaryChanged;
  final double maxDistanceKm;
  final ValueChanged<double> onDistanceChanged;
  final bool locationAvailable;

  const _NeedsForm({
    required this.formKey,
    required this.foodTypeCtrl,
    required this.quantityCtrl,
    required this.notesCtrl,
    required this.selectedDietary,
    required this.onDietaryChanged,
    required this.maxDistanceKm,
    required this.onDistanceChanged,
    required this.locationAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Describe Your Needs',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
              const Gap(16),

              // Food type
              TextFormField(
                controller: foodTypeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Food type / keywords (optional)',
                  hintText: 'e.g. rice, bread, curry…',
                  prefixIcon: Icon(Icons.restaurant_rounded),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const Gap(14),

              // Dietary preference
              DropdownButtonFormField<String>(
                value: selectedDietary,
                decoration: const InputDecoration(
                  labelText: 'Dietary preference',
                  prefixIcon: Icon(Icons.favorite_border_rounded),
                ),
                items: _kDietaryOptions
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: onDietaryChanged,
              ),
              const Gap(14),

              // Quantity
              TextFormField(
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of people to feed',
                  hintText: 'e.g. 50',
                  prefixIcon: Icon(Icons.people_outline_rounded),
                ),
              ),
              const Gap(18),

              // Distance slider
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 20),
                  const Gap(8),
                  Text('Max distance: ', style: textTheme.bodyMedium),
                  Text(
                    '${maxDistanceKm.toInt()} km',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  if (!locationAvailable) ...[
                    const Gap(6),
                    Tooltip(
                      message: 'Location unavailable — distance filter skipped',
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
              Slider(
                value: maxDistanceKm,
                min: 1,
                max: 50,
                divisions: 49,
                label: '${maxDistanceKm.toInt()} km',
                onChanged: onDistanceChanged,
              ),
              const Gap(4),

              // Extra notes
              TextFormField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Extra notes (optional)',
                  hintText:
                      'e.g. need storage containers, prefer pick up before 3 PM…',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final _MatchResult result;
  final VoidCallback onTap;

  const _MatchCard({required this.result, required this.onTap});

  Color _scoreColor(int score) {
    if (score >= 80) return AppTheme.statusCompleted;
    if (score >= 60) return AppTheme.statusClaimed;
    return AppTheme.statusPending;
  }

  @override
  Widget build(BuildContext context) {
    final d = result.donation;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final scoreColor = _scoreColor(result.matchScore);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shadowColor: Colors.black12,
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
      child: InkWell(
        borderRadius: AppTheme.radiusMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: food name + score badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      d.foodName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Gap(8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: scoreColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      '${result.matchScore}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(8),

              // AI reason
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: colorScheme.primary,
                    ),
                    const Gap(5),
                    Expanded(
                      child: Text(
                        result.reason,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary.withValues(alpha: 0.9),
                          fontStyle: FontStyle.italic,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(10),

              // Details row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: d.quantity,
                  ),
                  _InfoChip(
                    icon: Icons.restaurant_menu_rounded,
                    label: d.sourceStatus,
                  ),
                  if (result.distanceKm != null)
                    _InfoChip(
                      icon: Icons.location_on_outlined,
                      label: '${result.distanceKm!.toStringAsFixed(1)} km',
                    ),
                  _InfoChip(
                    icon: Icons.access_time_rounded,
                    label: 'Exp ${DateFormat('d MMM').format(d.expiryDate)}',
                    urgent: d.isExpiringSoon,
                  ),
                ],
              ),

              if (d.address != null) ...[
                const Gap(8),
                Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const Gap(4),
                    Expanded(
                      child: Text(
                        d.address!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const Gap(10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'by ${d.donorName}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'View details',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool urgent;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.urgent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = urgent
        ? AppTheme.statusExpiringSoon
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const Gap(3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: urgent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _LoadingShimmer extends StatelessWidget {
  final ColorScheme colorScheme;
  final int retryAttempt;
  final int retryCountdown;
  const _LoadingShimmer({
    required this.colorScheme,
    this.retryAttempt = 0,
    this.retryCountdown = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isRetrying = retryAttempt > 0;
    return Column(
      children: [
        const Gap(12),
        const CircularProgressIndicator(),
        const Gap(16),
        Text(
          isRetrying
              ? 'Rate limit hit — retrying…'
              : 'Gemini is analysing donations…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
        const Gap(6),
        if (isRetrying && retryCountdown > 0)
          Text(
            'Attempt ${retryAttempt + 1} / 3  ·  retrying in ${retryCountdown}s',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.primary.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          )
        else
          Text(
            isRetrying
                ? 'Attempting again now…'
                : 'This may take a few seconds.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _EmptyResults extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _EmptyResults({required this.colorScheme, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: colorScheme.onSurface.withValues(alpha: 0.25),
            ),
            const Gap(16),
            Text(
              'No matches found',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Gap(6),
            Text(
              'Try expanding your distance radius\nor adjusting your dietary preference.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusExpiringSoon.withValues(alpha: 0.08),
        borderRadius: AppTheme.radiusMd,
        border: Border.all(
          color: AppTheme.statusExpiringSoon.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.statusExpiringSoon,
            size: 20,
          ),
          const Gap(10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.statusExpiringSoon,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
