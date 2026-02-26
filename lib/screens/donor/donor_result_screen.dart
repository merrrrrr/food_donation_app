import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DonorResultScreen
//  Confirmation screen showing the completed handover details and the
//  evidence photo uploaded by the NGO.
//  Receives a [DonationModel] via Navigator arguments.
// ─────────────────────────────────────────────────────────────────────────────
class DonorResultScreen extends StatelessWidget {
  const DonorResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Retrieve donation passed via Navigator arguments
    final donation =
        ModalRoute.of(context)!.settings.arguments as DonationModel;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Handover Confirmation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Success banner ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.statusCompleted.withValues(alpha: 0.1),
                borderRadius: AppTheme.radiusLg,
                border: Border.all(
                  color: AppTheme.statusCompleted.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppTheme.statusCompleted,
                  ),
                  const Gap(12),
                  Text(
                    'Food Successfully Delivered!',
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.statusCompleted,
                    ),
                  ),
                  const Gap(6),
                  Text(
                    '${donation.ngoName ?? 'An NGO'} has confirmed the pickup.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(24),

            // ── Donation summary card ─────────────────────────────────────
            Text(
              'Donation Summary',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _ResultRow(label: 'Food', value: donation.foodName),
                    _ResultRow(
                      label: 'Profile',
                      value:
                          '${donation.sourceStatus}\n${donation.dietaryBase}'
                          '${donation.contains.isNotEmpty ? '\n${donation.contains.join(', ')}' : ''}',
                    ),
                    _ResultRow(label: 'Quantity', value: donation.quantity),
                    _ResultRow(
                      label: 'Expiry',
                      value: fmt.format(donation.expiryDate),
                    ),
                    _ResultRow(
                      label: 'Storage',
                      value: donation.storageType.displayLabel,
                    ),
                    _ResultRow(
                      label: 'Claimed by',
                      value: donation.ngoName ?? '—',
                    ),
                    if (donation.ngoPhone != null)
                      _ResultRow(
                        label: 'NGO Contact',
                        value: donation.ngoPhone!,
                      ),
                  ],
                ),
              ),
            ),
            const Gap(24),

            // ── Evidence photo ────────────────────────────────────────────
            if (donation.evidencePhotoUrl != null) ...[
              Text(
                'Handover Evidence',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(12),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: 200),
                child: SizedBox(
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: AppTheme.radiusMd,
                    child: CachedNetworkImage(
                      imageUrl: donation.evidencePhotoUrl!,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox(
                        height: 200,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
              ),
              const Gap(24),
            ],

            // ── Done button ───────────────────────────────────────────────
            ElevatedButton.icon(
              icon: const Icon(Icons.home_outlined),
              label: const Text('Back to Home'),
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ResultRow
// ─────────────────────────────────────────────────────────────────────────────
class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
