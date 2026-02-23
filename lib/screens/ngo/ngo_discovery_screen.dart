import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NgoDiscoveryScreen
//  Toggle between List View and Map View of available food donations.
//  Map markers are colour-coded: red = expiring ≤ 24 h, green = safe.
// ─────────────────────────────────────────────────────────────────────────────
class NgoDiscoveryScreen extends StatefulWidget {
  const NgoDiscoveryScreen({super.key});

  @override
  State<NgoDiscoveryScreen> createState() => _NgoDiscoveryScreenState();
}

class _NgoDiscoveryScreenState extends State<NgoDiscoveryScreen> {
  bool _showMap = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DonationProvider>().loadAvailableDonations();
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Build markers from donation list ───────────────────────────────────────
  void _buildMarkers(List<DonationModel> donations) {
    _markers = donations.map((d) {
      final color = d.isExpiringSoon
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

      return Marker(
        markerId: MarkerId(d.id),
        position: LatLng(d.latitude, d.longitude),
        icon: color,
        infoWindow: InfoWindow(
          title: d.foodName,
          snippet:
              '${d.foodType.displayLabel} · ${d.quantity}\nExpires: ${DateFormat('dd MMM, hh:mm a').format(d.expiryDate)}',
          onTap: () => Navigator.of(context)
              .pushNamed(AppRouter.ngoFoodDetail, arguments: d),
        ),
      );
    }).toSet();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final donationProv = context.watch<DonationProvider>();
    final donations = donationProv.donations;

    // Rebuild markers whenever the list changes
    if (_showMap) _buildMarkers(donations);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Food'),
        actions: [
          // Map / List toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                selectedForegroundColor:
                    Theme.of(context).colorScheme.onPrimary,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.list_rounded, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.map_outlined, size: 18),
                ),
              ],
              selected: {_showMap},
              onSelectionChanged: (s) => setState(() => _showMap = s.first),
            ),
          ),
        ],
      ),
      body: donationProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _showMap
              ? _buildMapView(donations)
              : _buildListView(donations),
    );
  }

  // ── Map view ───────────────────────────────────────────────────────────────
  Widget _buildMapView(List<DonationModel> donations) {
    // Default camera: Malaysia centre
    const defaultPosition = LatLng(4.2105, 101.9758);

    // Centre on first listing if available
    final initialTarget = donations.isNotEmpty
        ? LatLng(donations.first.latitude, donations.first.longitude)
        : defaultPosition;

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (c) => _mapController = c,
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: donations.isNotEmpty ? 13.0 : 6.5,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
        ),
        // Legend overlay
        Positioned(
          top: 12,
          left: 12,
          child: _MapLegend(),
        ),
        if (donations.isEmpty)
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No available donations to show on map.'),
              ),
            ),
          ),
      ],
    );
  }

  // ── List view ──────────────────────────────────────────────────────────────
  Widget _buildListView(List<DonationModel> donations) {
    if (donations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: Colors.black26),
            Gap(12),
            Text(
              'No food available right now.\nCheck back soon!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: donations.length,
      itemBuilder: (_, i) => _DonationListCard(donation: donations[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _DonationListCard
// ─────────────────────────────────────────────────────────────────────────────
class _DonationListCard extends StatelessWidget {
  final DonationModel donation;
  const _DonationListCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final expiryColor = donation.isExpiringSoon
        ? AppTheme.statusExpiringSoon
        : AppTheme.statusCompleted;

    return Card(
      child: InkWell(
        borderRadius: AppTheme.radiusMd,
        onTap: () => Navigator.of(context)
            .pushNamed(AppRouter.ngoFoodDetail, arguments: donation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Food type icon pill ────────────────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fastfood_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const Gap(12),

              // ── Details ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donation.foodName,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Text(
                      '${donation.foodType.displayLabel} · ${donation.quantity}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const Gap(4),
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 13, color: expiryColor),
                        const Gap(4),
                        Text(
                          'Expires: ${DateFormat('dd MMM, hh:mm a').format(donation.expiryDate)}',
                          style: textTheme.labelSmall
                              ?.copyWith(color: expiryColor),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 13,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.5)),
                        const Gap(4),
                        Text(
                          donation.donorName,
                          style: textTheme.labelSmall?.copyWith(
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MapLegend
// ─────────────────────────────────────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendItem(color: Colors.red, label: 'Expiring ≤ 24h'),
            const Gap(4),
            _LegendItem(color: Colors.green, label: 'Safe'),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const Gap(6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
