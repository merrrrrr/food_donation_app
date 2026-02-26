import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';
import 'package:food_donation_app/widgets/loading_overlay.dart';
import 'package:food_donation_app/widgets/primary_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NgoFoodDetailScreen
//  Full details of a donation listing with a mini map and a "Claim" CTA.
//  Receives a [DonationModel] via Navigator arguments.
// ─────────────────────────────────────────────────────────────────────────────
class NgoFoodDetailScreen extends StatelessWidget {
  const NgoFoodDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final donation =
        ModalRoute.of(context)!.settings.arguments as DonationModel;
    final donationProv = context.watch<DonationProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    final expiryColor = donation.isExpiringSoon
        ? AppTheme.statusExpiringSoon
        : AppTheme.statusCompleted;

    return Scaffold(
      appBar: AppBar(title: const Text('Donation Details')),
      body: LoadingOverlay(
        isLoading: donationProv.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Food photo ────────────────────────────────────────────────
              if (donation.photoUrl != null)
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 200),
                  child: SizedBox(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: AppTheme.radiusMd,
                      child: CachedNetworkImage(
                        imageUrl: donation.photoUrl!,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => Container(
                          constraints: const BoxConstraints(minHeight: 150),
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.3,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          constraints: const BoxConstraints(minHeight: 150),
                          color: colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined, size: 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.fastfood_rounded,
                      size: 60,
                      color: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              const Gap(20),

              // ── Title row ─────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      donation.foodName,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Gap(8),
                  if (donation.isExpiringSoon)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.statusExpiringSoon.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Expiring Soon',
                        style: textTheme.labelSmall?.copyWith(
                          color: AppTheme.statusExpiringSoon,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const Gap(16),

              // ── Details card ──────────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.label_outline,
                        label: 'Dietary Profile',
                        value:
                            '${donation.sourceStatus}\n${donation.dietaryBase}'
                            '${donation.contains.isNotEmpty ? '\n${donation.contains.join(', ')}' : ''}',
                      ),
                      _DetailRow(
                        icon: Icons.production_quantity_limits_outlined,
                        label: 'Quantity',
                        value: donation.quantity,
                      ),
                      _DetailRow(
                        icon: Icons.kitchen_outlined,
                        label: 'Storage',
                        value: donation.storageType.displayLabel,
                      ),
                      _DetailRow(
                        icon: Icons.event_outlined,
                        label: 'Expires',
                        value: fmt.format(donation.expiryDate),
                        valueColor: expiryColor,
                      ),
                      _DetailRow(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'Pickup From',
                        value: fmt.format(donation.pickupStart),
                      ),
                      _DetailRow(
                        icon: Icons.stop_circle_outlined,
                        label: 'Pickup Until',
                        value: fmt.format(donation.pickupEnd),
                      ),
                      _DetailRow(
                        icon: Icons.person_outline,
                        label: 'Donor',
                        value: donation.donorName,
                      ),
                      if (donation.donorPhone != null)
                        _DetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Contact',
                          value: donation.donorPhone!,
                          isLast: true,
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ),
              const Gap(20),

              // ── Mini map ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pickup Location',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (donation.address != null)
                    Expanded(
                      flex: 2,
                      child: Text(
                        donation.address!,
                        textAlign: TextAlign.right,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const Gap(8),
              ClipRRect(
                borderRadius: AppTheme.radiusMd,
                child: SizedBox(
                  height: 180,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(donation.latitude, donation.longitude),
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: LatLng(donation.latitude, donation.longitude),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                  ),
                ),
              ),
              const Gap(32),

              // ── Claim button ──────────────────────────────────────────────
              // ── CTA Buttons ──────────────────────────────────────────────
              if (donation.status == DonationStatus.pending)
                PrimaryButton(
                  label: 'Claim This Donation',
                  isLoading: donationProv.isLoading,
                  leadingIcon: Icons.volunteer_activism_rounded,
                  onPressed: () => _onClaim(context, donation),
                )
              else if (donation.status == DonationStatus.claimed ||
                  donation.status == DonationStatus.pickedUp)
                PrimaryButton(
                  label: 'Go to Handover Flow',
                  leadingIcon: Icons.local_shipping_outlined,
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed(AppRouter.ngoResult, arguments: donation),
                )
              else if (donation.status == DonationStatus.completed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.statusCompleted.withValues(alpha: 0.1),
                        borderRadius: AppTheme.radiusMd,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: AppTheme.statusCompleted,
                          ),
                          const Gap(10),
                          Text(
                            'Donation Completed',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.statusCompleted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Gap(12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AppRouter.ngoResult, arguments: donation),
                      icon: const Icon(Icons.image_search_rounded),
                      label: const Text('View Completion Evidence'),
                    ),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cancel_outlined, color: Colors.grey),
                      const Gap(10),
                      Text(
                        'Donation Cancelled',
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onClaim(BuildContext context, DonationModel donation) async {
    // Pickup time selection
    final now = DateTime.now();
    TimeOfDay? selectedTime;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Claim Donation?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You are about to claim "${donation.foodName}" from ${donation.donorName}.',
              ),
              const Gap(16),
              const Text(
                'What is your estimated pickup time?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Gap(8),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(
                  selectedTime == null
                      ? 'Select Time'
                      : 'Arrival Around: ${selectedTime!.format(ctx)}',
                ),
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(
                      now.add(const Duration(minutes: 30)),
                    ),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedTime = picked);
                  }
                },
              ),
              if (selectedTime != null) ...[
                const Gap(8),
                Text(
                  'Note: If you are late by more than 1 hour, your claim will be automatically reverted.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(ctx).colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedTime == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Claim'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedTime == null || !context.mounted) return;

    final scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    final auth = context.read<AuthProvider>();
    final donationProv = context.read<DonationProvider>();

    final success = await donationProv.claimDonation(
      donationId: donation.id,
      ngoId: auth.currentUser!.uid,
      ngoName: auth.currentUser!.displayName,
      ngoPhone: auth.currentUser!.phone,
      scheduledPickupTime: scheduledDate,
    );

    if (!context.mounted) return;

    if (success) {
      // Navigate to result/evidence screen, replacing detail from stack
      Navigator.of(context).pushReplacementNamed(
        AppRouter.ngoResult,
        arguments: donation.copyWith(
          ngoId: auth.currentUser!.uid,
          ngoName: auth.currentUser!.displayName,
          ngoPhone: auth.currentUser!.phone,
          status: DonationStatus.claimed,
          scheduledPickupTime: scheduledDate,
          claimedAt: DateTime.now(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            donationProv.errorMessage ?? 'Claim failed. Please try again.',
          ),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _DetailRow
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const Gap(12),
              SizedBox(
                width: 80,
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
