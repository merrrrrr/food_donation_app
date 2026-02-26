import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ⚠️  Replace this with your actual Gemini API key from
//      https://aistudio.google.com/apikeys
//      For production use --dart-define or a remote config service.
// ─────────────────────────────────────────────────────────────────────────────
const _kGeminiApiKey = 'AIzaSyDlFVrFmoZrEmghReVGXKro76ipBtDpTKA';

// ─────────────────────────────────────────────────────────────────────────────
//  Dietary preference options shown in the form dropdown.
// ─────────────────────────────────────────────────────────────────────────────
const _kDietaryOptions = ['Any', 'Halal', 'Vegetarian / Vegan'];

// ─────────────────────────────────────────────────────────────────────────────
//  NgoAiMatchScreen
//  Lets the NGO describe their needs, then uses Gemini 2.0 Flash to rank
//  the available (pending, non-expired) donations by suitability.
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

  // ── Local fuzzy pre-ranking ──────────────────────────────────────────────
  // Assigns a rough score based on dietary, distance, and keyword match.
  // Helps us pick the best 10 to send to Gemini.
  int _localScore(DonationModel d, String query, String dietary) {
    int score = 0;

    // 1. Dietary Match (Critical)
    if (dietary != 'Any') {
      if (dietary == 'Halal') {
        if (d.sourceStatus == DietarySourceStatus.halal) {
          score += 100;
        } else if (d.sourceStatus == DietarySourceStatus.porkFree) {
          score += 50;
        } else {
          score -= 200; // Major penalty
        }
      } else if (dietary == 'Vegetarian / Vegan') {
        if (d.dietaryBase == DietaryBase.vegan) {
          score += 100;
        } else if (d.dietaryBase == DietaryBase.vegetarian) {
          score += 80;
        } else {
          score -= 200;
        }
      }
    }

    // 2. Keyword Match (Food Name)
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      final name = d.foodName.toLowerCase();
      if (name.contains(q)) {
        score += 80;
      } else {
        // Simple token match
        final tokens = q.split(RegExp(r'\s+'));
        for (final t in tokens) {
          if (t.length > 2 && name.contains(t)) score += 30;
        }
      }
    }

    // 3. Distance Bonus
    if (_devicePosition != null) {
      final dist = _distanceKm(
        _devicePosition!.latitude,
        _devicePosition!.longitude,
        d.latitude,
        d.longitude,
      );
      // High bonus for very close items
      if (dist < 2) {
        score += 50;
      } else if (dist < 5) {
        score += 30;
      } else if (dist < 10) {
        score += 15;
      }
    }

    // 4. Freshness
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

    final candidates = _eligibleDonations;
    if (candidates.isEmpty) {
      setState(() {
        _hasSearched = true;
        _results = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isAnalysing = true;
      _errorMessage = null;
      _results = [];
      _retryAttempt = 0;
      _retryCountdown = 0;
    });
    _startCooldown(5); // 5 second gap

    // 2. Local Pre-Ranking to pick the TOP 10
    final query = _foodTypeCtrl.text.trim();
    final topCandidates = List<DonationModel>.from(candidates)
      ..sort((a, b) {
        final sa = _localScore(a, query, _selectedDietary);
        final sb = _localScore(b, query, _selectedDietary);
        return sb.compareTo(sa); // Highest local score first
      });

    final capped = topCandidates.take(10).toList();

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
      return {
        'i': d.id, // i = id
        'f': d.foodName, // f = food
        'q': d.quantity, // q = qty
        'd': '${d.sourceStatus} / ${d.dietaryBase}', // d = diet
        'e': DateFormat('MM-dd HH:mm').format(d.expiryDate), // e = expiry
        if (dist != null) 'k': dist, // k = km
      };
    }).toList();

    final needsFood = query.isEmpty ? 'any' : query;
    final needsQty = _quantityCtrl.text.trim().isEmpty
        ? 'unspecified'
        : _quantityCtrl.text.trim();
    final needsNotes = _notesCtrl.text.trim().isEmpty
        ? ''
        : ' Notes: ${_notesCtrl.text.trim()}';

    final prompt =
        '''
Role: Food donation matcher for NGO.
NGO Needs: food=$needsFood, diet=$_selectedDietary, qty=$needsQty.$needsNotes
Available (JSON): ${jsonEncode(donationJson)}

Task: Rank these 10 items. Return ONLY JSON array.
Format: [{"i":"id","s":0-100,"r":"reason ≤15 words"}]
Details: s=matchScore, r=reason. Sort by s desc. Only s>=40.
''';

    debugPrint('--- AI MATCH REQUEST ---\n$prompt\n------------------------');

    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _kGeminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 512,
        responseMimeType: 'application/json',
      ),
    );

    // ── Retry loop (max 3 attempts) ─────────────────────────────────────────
    const maxAttempts = 3;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        if (attempt > 0) setState(() => _retryAttempt = attempt);

        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text ?? '';
        debugPrint(
          '--- AI MATCH RESPONSE ---\n$text\n-------------------------',
        );

        // Parse JSON response
        final parsed = jsonDecode(text) as List<dynamic>;

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
        setState(() {
          _results = results;
          _hasSearched = true;
          _isAnalysing = false;
          _retryAttempt = 0;
          _retryCountdown = 0;
        });
        return; // done — exit the retry loop
      } catch (e) {
        final errStr = e.toString();
        final delay = _parseRetryDelay(errStr);
        final isQuotaError =
            errStr.contains('quota') ||
            errStr.contains('RESOURCE_EXHAUSTED') ||
            errStr.contains('rate') ||
            errStr.contains('429');

        // If it's not a quota/rate error, or last attempt — bail out with fallback results
        if (!isQuotaError || attempt == maxAttempts - 1) {
          _countdownTimer?.cancel();

          // ── Fallback ──────────────────────────────────────────────────────
          // If Gemini fails, we show the top local results instead of an error.
          final fallbackResults = capped
              .where((d) {
                final score = _localScore(d, query, _selectedDietary);
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
        final waitSecs = (delay?.inSeconds ?? (5 * (attempt + 1))).clamp(3, 30);
        _startCountdown(waitSecs);
        await Future.delayed(Duration(seconds: waitSecs));
      }
    }
  }

  // ── Friendly error messages ───────────────────────────────────────────────
  String _friendlyError(String raw) {
    if (raw.contains('quota') ||
        raw.contains('RESOURCE_EXHAUSTED') ||
        raw.contains('429')) {
      return 'Rate limit reached after 3 retries. '
          'Please wait a minute and try again.';
    }
    if (raw.contains('API_KEY') ||
        raw.contains('invalid') ||
        raw.contains('401')) {
      return 'Invalid API key. Please check the key in ngo_ai_match_screen.dart.';
    }
    return 'Analysis failed. Please try again.\n\nDetails: $raw';
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
                  'AI-Powered Matching',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Gap(6),
                Text(
                  'Describe your needs and Gemini AI will find the best nearby donations for your NGO.',
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
                initialValue: selectedDietary,
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
                decoration: const InputDecoration(
                  labelText: 'Quantity needed (optional)',
                  hintText: 'e.g. 50 pax, 10 kg',
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
