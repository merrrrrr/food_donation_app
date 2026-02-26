import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';
import 'package:food_donation_app/widgets/loading_overlay.dart';
import 'package:food_donation_app/widgets/primary_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NgoResultScreen
//  After claiming, the NGO uploads a photo proving food was collected.
//  Receives a [DonationModel] (with status = claimed) via Navigator args.
// ─────────────────────────────────────────────────────────────────────────────
class NgoResultScreen extends StatefulWidget {
  const NgoResultScreen({super.key});

  @override
  State<NgoResultScreen> createState() => _NgoResultScreenState();
}

class _NgoResultScreenState extends State<NgoResultScreen> {
  XFile? _evidenceImage;
  bool _submitted = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await _showSourceDialog();
    if (source == null) return;

    final image = await picker.pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (image != null) setState(() => _evidenceImage = image);
  }

  Future<ImageSource?> _showSourceDialog() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmitEvidence(DonationModel donation) async {
    if (_evidenceImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take or select a photo as evidence first.'),
        ),
      );
      return;
    }

    final donationProv = context.read<DonationProvider>();

    final success = await donationProv.completeDonation(
      donationId: donation.id,
      evidenceImage: File(_evidenceImage!.path),
    );

    if (!mounted) return;

    if (success) {
      setState(() => _submitted = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            donationProv.errorMessage ?? 'Upload failed. Please retry.',
          ),
        ),
      );
    }
  }

  Future<void> _onCancelClaim(DonationModel donation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Claim?'),
        content: const Text(
          'Are you sure you want to release this donation? '
          'It will become available for other NGOs to claim.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep It'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Yes, Cancel Claim'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<DonationProvider>().cancelClaim(
      donation.id,
    );

    if (success && mounted) {
      Navigator.pop(context);
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<DonationProvider>().errorMessage ??
                'Cancellation failed.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialDonation =
        ModalRoute.of(context)!.settings.arguments as DonationModel;
    final donationProv = context.watch<DonationProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Find the latest version of this donation in the provider's list.
    // However, if the passed [initialDonation] is already in a terminal state
    // (completed/cancelled), we prioritize its status to avoid stale cache issues.
    var donation = donationProv.ngoDonations.firstWhere(
      (d) => d.id == initialDonation.id,
      orElse: () => initialDonation,
    );

    // Safety: If the deep-link/argument says it's completed but the cached list
    // is lagging behind, trust the argument. Terminal states don't go backwards.
    if (initialDonation.status == DonationStatus.completed ||
        initialDonation.status == DonationStatus.cancelled) {
      if (donation.status != initialDonation.status) {
        donation = initialDonation;
      }
    }

    // ── Completed / Evidence view ──────────────────────────────────────────
    if (donation.status == DonationStatus.completed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Completion Evidence')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.statusCompleted.withValues(alpha: 0.1),
                  borderRadius: AppTheme.radiusMd,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.statusCompleted,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Text(
                        'This donation was successfully completed.',
                        style: textTheme.titleSmall?.copyWith(
                          color: AppTheme.statusCompleted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),
              Text(
                'Evidence Photo',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(12),
              if (donation.evidencePhotoUrl != null)
                ClipRRect(
                  borderRadius: AppTheme.radiusMd,
                  child: CachedNetworkImage(
                    imageUrl: donation.evidencePhotoUrl!,
                    fit: BoxFit.fitWidth,
                    placeholder: (_, __) => Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: AppTheme.radiusMd,
                  ),
                  child: const Center(
                    child: Text('No evidence photo available.'),
                  ),
                ),
              const Gap(32),
              Text(
                'Donation Summary',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(label: 'Food', value: donation.foodName),
                      _SummaryRow(label: 'Quantity', value: donation.quantity),
                      _SummaryRow(
                        label: 'Completed at',
                        value: donation.updatedAt != null
                            ? DateFormat(
                                'dd MMM yyyy, hh:mm a',
                              ).format(donation.updatedAt!)
                            : '—',
                      ),
                      _SummaryRow(
                        label: 'Donor',
                        value: donation.donorName,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              const Gap(40),
            ],
          ),
        ),
      );
    }

    // ── Cancelled view ────────────────────────────────────────────────────
    if (donation.status == DonationStatus.cancelled) {
      return Scaffold(
        appBar: AppBar(title: const Text('Donation Cancelled')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cancel_outlined, size: 72, color: Colors.grey),
                const Gap(24),
                Text(
                  'This listing was cancelled by the donor.',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(color: Colors.grey),
                ),
                const Gap(32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Success view ──────────────────────────────────────────────────────
    if (_submitted) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 96,
                  color: AppTheme.statusCompleted,
                ),
                const Gap(24),
                Text(
                  'Handover Complete!',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Gap(8),
                Text(
                  'Thank you for collecting "${donation.foodName}". '
                  'The donor has been notified.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const Gap(40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Back to Dashboard'),
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Waiting for donor view ──────────────────────────────────────────────
    if (donation.status == DonationStatus.claimed) {
      final timeFmt = DateFormat('hh:mm a');
      final scheduledStr = donation.scheduledPickupTime != null
          ? timeFmt.format(donation.scheduledPickupTime!)
          : '—';

      return Scaffold(
        appBar: AppBar(title: const Text('Handover Process')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.hourglass_empty_rounded,
                size: 72,
                color: AppTheme.statusExpiringSoon,
              ),
              const Gap(24),
              Text(
                'Waiting for Donor',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(12),
              Text(
                'Please ask the donor to click "Confirm Handover" on their device to verify the collection of "${donation.foodName}".',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Gap(24),

              // ── Arrival Info ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: AppTheme.radiusMd,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Scheduled Arrival',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          Text(
                            scheduledStr,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),

              // ── Donation details ──────────────────────────────────────────
              Text(
                'Donation Summary',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(label: 'Food', value: donation.foodName),
                      _SummaryRow(label: 'Quantity', value: donation.quantity),
                      _SummaryRow(
                        label: 'Donor',
                        value:
                            '${donation.donorName}\n${donation.donorPhone ?? ''}',
                      ),
                      _SummaryRow(
                        label: 'Location',
                        value: donation.address ?? 'See map',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),

              const Gap(32),
              if (donation.canCancelClaim) ...[
                TextButton.icon(
                  onPressed: () => _onCancelClaim(donation),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Cancel My Claim'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                ),
                const Gap(8),
              ],
              const Gap(8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRouter.ngoFoodDetail, arguments: donation),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Full Listing Details'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Evidence upload view ──────────────────────────────────────────────
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Donation')),
      body: LoadingOverlay(
        isLoading: donationProv.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Verified banner ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.statusClaimed.withValues(alpha: 0.08),
                  borderRadius: AppTheme.radiusMd,
                  border: Border.all(
                    color: AppTheme.statusClaimed.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.statusCompleted,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Collection Verified!',
                            style: textTheme.titleSmall?.copyWith(
                              color: AppTheme.statusCompleted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'The donor has confirmed the handover.',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(24),

              // ── Instructions ──────────────────────────────────────────────
              Text(
                'Upload Collection Photo',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(8),
              Text(
                'Finally, please take a photo of the food you have collected. '
                'This serves as evidence that the handover was completed successfully.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
              const Gap(16),

              // ── Photo picker ──────────────────────────────────────────────
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: _evidenceImage == null ? 220 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: AppTheme.radiusMd,
                    border: Border.all(
                      color: _evidenceImage != null
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.5),
                      width: _evidenceImage != null ? 2 : 1,
                    ),
                  ),
                  child: _evidenceImage != null
                      ? ClipRRect(
                          borderRadius: AppTheme.radiusMd,
                          child: Image.file(
                            File(_evidenceImage!.path),
                            fit: BoxFit.fitWidth,
                            width: double.infinity,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 52,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            const Gap(12),
                            Text(
                              'Tap to take or select a photo',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const Gap(12),

              // Re-pick action
              if (_evidenceImage != null)
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Change Photo'),
                  onPressed: _pickImage,
                ),
              const Gap(24),

              // Upload progress
              if (donationProv.isLoading &&
                  donationProv.uploadProgress > 0) ...[
                LinearProgressIndicator(value: donationProv.uploadProgress),
                const Gap(8),
                Center(
                  child: Text(
                    'Uploading… '
                    '${(donationProv.uploadProgress * 100).toStringAsFixed(0)}%',
                    style: textTheme.bodySmall,
                  ),
                ),
                const Gap(16),
              ],

              PrimaryButton(
                label: 'Complete Donation',
                isLoading: donationProv.isLoading,
                leadingIcon: Icons.task_alt_rounded,
                onPressed: () => _onSubmitEvidence(donation),
              ),
              const Gap(12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRouter.ngoFoodDetail, arguments: donation),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View Full Listing Details'),
              ),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }
}
