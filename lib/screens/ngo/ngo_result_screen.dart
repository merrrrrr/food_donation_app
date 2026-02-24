import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
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

  @override
  Widget build(BuildContext context) {
    final donation =
        ModalRoute.of(context)!.settings.arguments as DonationModel;
    final donationProv = context.watch<DonationProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRouter.ngoHome, (_) => false),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Evidence upload view ──────────────────────────────────────────────
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Evidence')),
      body: LoadingOverlay(
        isLoading: donationProv.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Claimed banner ────────────────────────────────────────────
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
                      Icons.local_shipping_outlined,
                      color: AppTheme.statusClaimed,
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Donation Claimed!',
                            style: textTheme.titleSmall?.copyWith(
                              color: AppTheme.statusClaimed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            donation.foodName,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppTheme.statusClaimed.withValues(
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
                'Upload Evidence Photo',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(8),
              Text(
                'Take a photo of the collected food to confirm the handover. '
                'This photo will be shared with the donor.',
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
                label: 'Confirm Handover',
                isLoading: donationProv.isLoading,
                leadingIcon: Icons.check_rounded,
                onPressed: () => _onSubmitEvidence(donation),
              ),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}
