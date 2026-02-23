import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/screens/donor/upload_food_screen.dart'
    show FoodDraft;
import 'package:food_donation_app/theme/app_theme.dart';
import 'package:food_donation_app/widgets/custom_text_field.dart';
import 'package:food_donation_app/widgets/loading_overlay.dart';
import 'package:food_donation_app/widgets/primary_button.dart';
import 'package:food_donation_app/app_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
//  UploadFoodStep2Screen  (Step 2 of 2)
//  Receives a [FoodDraft] from Step 1 via Navigator arguments.
//  Collects: expiry date, pickup window (start → end), GPS location.
//  Submits the completed [DonationModel] to Firestore.
// ─────────────────────────────────────────────────────────────────────────────
class UploadFoodStep2Screen extends StatefulWidget {
  const UploadFoodStep2Screen({super.key});

  @override
  State<UploadFoodStep2Screen> createState() => _UploadFoodStep2ScreenState();
}

class _UploadFoodStep2ScreenState extends State<UploadFoodStep2Screen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _fmt = DateFormat('dd MMM yyyy, hh:mm a');

  // ── Controllers ───────────────────────────────────────────────────────────
  final _expiryCtrl = TextEditingController();
  final _pickupStartCtrl = TextEditingController();
  final _pickupEndCtrl = TextEditingController();

  // ── Date state ────────────────────────────────────────────────────────────
  DateTime? _expiryDate;
  DateTime? _pickupStart;
  DateTime? _pickupEnd;

  // ── Location state ────────────────────────────────────────────────────────
  double? _latitude;
  double? _longitude;
  String? _address;
  String _locationStatus = 'Tap to get current location';
  bool _fetchingLocation = false;

  @override
  void dispose() {
    _expiryCtrl.dispose();
    _pickupStartCtrl.dispose();
    _pickupEndCtrl.dispose();
    super.dispose();
  }

  // ── Date/time pickers ─────────────────────────────────────────────────────
  Future<DateTime?> _pickDateTime({
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? initial,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final dt = await _pickDateTime(
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initial: now.add(const Duration(days: 1)),
    );
    if (dt == null) return;
    setState(() {
      _expiryDate = dt;
      _expiryCtrl.text = _fmt.format(dt);
    });
  }

  Future<void> _pickPickupStart() async {
    final now = DateTime.now();
    final dt = await _pickDateTime(
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initial: now.add(const Duration(hours: 1)),
    );
    if (dt == null) return;
    setState(() {
      _pickupStart = dt;
      _pickupStartCtrl.text = _fmt.format(dt);
      // Reset end if it's now before start
      if (_pickupEnd != null && _pickupEnd!.isBefore(dt)) {
        _pickupEnd = null;
        _pickupEndCtrl.clear();
      }
    });
  }

  Future<void> _pickPickupEnd() async {
    if (_pickupStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pickup start time first.'),
        ),
      );
      return;
    }
    final dt = await _pickDateTime(
      firstDate: _pickupStart!.add(const Duration(minutes: 15)),
      lastDate: _pickupStart!.add(const Duration(days: 7)),
      initial: _pickupStart!.add(const Duration(hours: 2)),
    );
    if (dt == null) return;
    setState(() {
      _pickupEnd = dt;
      _pickupEndCtrl.text = _fmt.format(dt);
    });
  }

  // ── Location ─────────────────────────────────────────────────────────────
  Future<void> _getLocation() async {
    setState(() {
      _fetchingLocation = true;
      _locationStatus = 'Fetching location…';
    });

    try {
      // 1. Is the device location service on?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _locationStatus = 'Location services are disabled.');
          _showLocationServiceDialog();
        }
        return;
      }

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() => _locationStatus = 'Location permission denied.');
        }
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationStatus = 'Permission permanently denied.');
          _showOpenSettingsDialog();
        }
        return;
      }

      // 3. Get position — use bestForNavigation so Android keeps a lock longer
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 15),
        ),
      );

      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _locationStatus = 'Fetching address…';
        });
        await _reverseGeocode(pos.latitude, pos.longitude);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _locationStatus = 'Could not get location. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _pickFromMap() async {
    final result = await Navigator.of(context).pushNamed(
      AppRouter.donorLocationPicker,
      arguments: _latitude != null ? LatLng(_latitude!, _longitude!) : null,
    );

    if (result is LatLng && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        _locationStatus = 'Fetching address…';
      });
      await _reverseGeocode(result.latitude, result.longitude);
    }
  }

  // ── Google Maps Geocoding API ──────────────────────────────────────────────
  /// Calls the Google Maps Geocoding REST API to convert [lat]/[lon] to a
  /// human-readable [formatted_address].  Falls back to raw coordinates on error.
  static const _mapsApiKey = 'AIzaSyCA7zeQ1Sek99acjsNw9e20ljurKbjgNl8';

  Future<void> _reverseGeocode(double lat, double lon) async {
    final fallback = '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '$lat,$lon',
        'key': _mapsApiKey,
      });

      final response = await http.get(uri);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final status = body['status'] as String;

        if (status == 'OK') {
          final results = body['results'] as List<dynamic>;
          if (results.isNotEmpty) {
            final addr =
                (results.first as Map<String, dynamic>)['formatted_address']
                    as String;
            setState(() {
              _address = addr;
              _locationStatus = addr;
            });
            return;
          }
        }
      }
    } catch (_) {
      // Network or parsing error — fall through to fallback
    }

    if (mounted) {
      setState(() => _locationStatus = fallback);
    }
  }

  void _showLocationServiceDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Location Services Off'),
        content: const Text(
          'Please enable location services in your device settings and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showOpenSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'Location permission is permanently denied. Open app settings to allow it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _onSubmit(FoodDraft draft) async {
    if (!_formKey.currentState!.validate()) return;

    if (_expiryDate == null) {
      _snack('Please select an expiry date & time.');
      return;
    }
    if (_pickupStart == null || _pickupEnd == null) {
      _snack('Please select both pickup start and end times.');
      return;
    }
    if (_latitude == null || _longitude == null) {
      _snack('Please set the pickup location first.');
      return;
    }

    final auth = context.read<AuthProvider>();
    final donationProv = context.read<DonationProvider>();

    final donation = DonationModel(
      id: _uuid.v4(),
      donorId: auth.currentUser!.uid,
      donorName: auth.currentUser!.displayName,
      foodName: draft.foodName,
      foodType: draft.foodType,
      quantity: draft.quantity,
      storageType: draft.storageType,
      expiryDate: _expiryDate!,
      pickupStart: _pickupStart!,
      pickupEnd: _pickupEnd!,
      latitude: _latitude!,
      longitude: _longitude!,
      address: _address,
    );

    final success = await donationProv.createDonation(
      donation,
      foodImage: draft.photo != null ? File(draft.photo!.path) : null,
    );

    if (!mounted) return;

    if (success) {
      // Pop both Step 2 and Step 1, returning to the home screen
      Navigator.of(context).popUntil(
        (route) =>
            route.settings.name != null &&
            !route.settings.name!.startsWith('/donor/upload'),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation listed successfully! 🎉')),
      );
    } else {
      _snack(donationProv.errorMessage ?? 'Failed to upload donation.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final draft = ModalRoute.of(context)!.settings.arguments as FoodDraft;
    final donationProv = context.watch<DonationProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule & Location'),
        bottom: _StepIndicator(step: 2),
      ),
      body: LoadingOverlay(
        isLoading: donationProv.isLoading,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Schedule ───────────────────────────────────────────────
                _SectionHeader(title: 'Schedule'),
                const Gap(12),

                // Expiry
                CustomTextField(
                  controller: _expiryCtrl,
                  label: 'Expiry Date & Time',
                  prefixIcon: Icons.event_outlined,
                  hint: 'Tap to pick',
                  readOnly: true,
                  onTap: _pickExpiry,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Expiry date is required.'
                      : null,
                ),
                const Gap(14),

                // Pickup window header
                Text(
                  'Available Pickup Window',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(8),

                // Start
                CustomTextField(
                  controller: _pickupStartCtrl,
                  label: 'Pickup From',
                  prefixIcon: Icons.play_circle_outline_rounded,
                  hint: 'Earliest collection time',
                  readOnly: true,
                  onTap: _pickPickupStart,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Pickup start time is required.'
                      : null,
                ),
                const Gap(10),

                // End
                CustomTextField(
                  controller: _pickupEndCtrl,
                  label: 'Pickup Until',
                  prefixIcon: Icons.stop_circle_outlined,
                  hint: 'Latest collection time',
                  readOnly: true,
                  onTap: _pickPickupEnd,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Pickup end time is required.'
                      : null,
                ),
                const Gap(28),

                // ── Location ───────────────────────────────────────────────
                _SectionHeader(title: 'Pickup Location'),
                const Gap(8),
                Text(
                  'NGOs will use this address to navigate to you.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const Gap(12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: _fetchingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _latitude != null
                                    ? Icons.my_location_rounded
                                    : Icons.my_location_rounded,
                                color: _latitude != null
                                    ? colorScheme.primary
                                    : null,
                              ),
                        label: Text(
                          _fetchingLocation ? 'Fetching…' : 'Current',
                          style: TextStyle(
                            color: _latitude != null
                                ? colorScheme.primary
                                : null,
                          ),
                        ),
                        onPressed: _fetchingLocation ? null : _getLocation,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _latitude != null
                                ? colorScheme.primary
                                : colorScheme.outline,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Pick on Map'),
                        onPressed: _pickFromMap,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),

                const Gap(12),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),

                      const Gap(12),

                      Expanded(
                        child: Text(
                          _locationStatus,
                          style: textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _latitude != null
                                ? colorScheme.onSurface
                                : colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_latitude != null) ...[
                  const Gap(8),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: AppTheme.statusCompleted,
                      ),
                      const Gap(6),
                      Text(
                        'Location captured',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.statusCompleted,
                        ),
                      ),
                    ],
                  ),
                ],
                const Gap(32),

                // ── Upload progress ────────────────────────────────────────
                if (donationProv.isLoading &&
                    donationProv.uploadProgress > 0) ...[
                  LinearProgressIndicator(value: donationProv.uploadProgress),
                  const Gap(8),
                  Center(
                    child: Text(
                      'Uploading photo… '
                      '${(donationProv.uploadProgress * 100).toStringAsFixed(0)}%',
                      style: textTheme.bodySmall,
                    ),
                  ),
                  const Gap(16),
                ],

                PrimaryButton(
                  label: 'Submit Donation',
                  isLoading: donationProv.isLoading,
                  leadingIcon: Icons.volunteer_activism_rounded,
                  onPressed: () => _onSubmit(draft),
                ),
                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared widgets (imported via upload_food_screen.dart in Step 1)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget implements PreferredSizeWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Size get preferredSize => const Size.fromHeight(4);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onPrimary;
    return LinearProgressIndicator(
      value: step / 2,
      backgroundColor: primary.withValues(alpha: 0.25),
      color: primary,
      minHeight: 4,
    );
  }
}
