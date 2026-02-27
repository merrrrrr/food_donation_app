import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DonorHomeScreen (Dashboard)
//  Shows a warm welcome, a prominent "Upload Food" CTA, and a quick summary
//  row of the donor's donations by status.
// ─────────────────────────────────────────────────────────────────────────────
class DonorHomeScreen extends StatefulWidget {
  const DonorHomeScreen({super.key});

  @override
  State<DonorHomeScreen> createState() => _DonorHomeScreenState();
}

class _DonorHomeScreenState extends State<DonorHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Start listening to this donor's donations as soon as the screen mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<DonationProvider>().loadDonorDonations(uid);
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final donationProv = context.watch<DonationProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Derived counts from the live stream
    final pending = donationProv.donorDonations
        .where((d) => d.status == DonationStatus.pending)
        .length;
    final claimed = donationProv.donorDonations
        .where((d) => d.status == DonationStatus.claimed)
        .length;
    final completed = donationProv.donorDonations
        .where((d) => d.status == DonationStatus.completed)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('FoodBridge')),
      body: RefreshIndicator(
        onRefresh: () async {
          final uid = auth.currentUser?.uid;
          if (uid != null) {
            context.read<DonationProvider>().loadDonorDonations(uid);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Greeting ─────────────────────────────────────────────────
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.8,
                    ),
                    backgroundImage: auth.currentUser?.photoUrl != null
                        ? CachedNetworkImageProvider(
                            auth.currentUser!.photoUrl!,
                          )
                        : null,
                    child: auth.currentUser?.photoUrl == null
                        ? Text(
                            (auth.currentUser?.displayName.isNotEmpty == true)
                                ? auth.currentUser!.displayName[0].toUpperCase()
                                : '?',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      'Hello, ${auth.currentUser?.displayName.split(' ').first ?? 'there'}',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(4),
              Text(
                'Share your surplus food today.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Gap(28),

              // ── Upload CTA card ───────────────────────────────────────────
              _UploadCTACard(
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.donorUpload),
              ),
              const Gap(24),

              // ── Stats row ─────────────────────────────────────────────────
              Text(
                'Your Donations',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Pending',
                      count: pending,
                      color: AppTheme.statusPending,
                      icon: Icons.hourglass_empty_rounded,
                      onTap: () => donationProv.setDonorTab(1),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: _StatCard(
                      label: 'Claimed',
                      count: claimed,
                      color: AppTheme.statusClaimed,
                      icon: Icons.local_shipping_outlined,
                      onTap: () => donationProv.setDonorTab(1),
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: _StatCard(
                      label: 'Done',
                      count: completed,
                      color: AppTheme.statusCompleted,
                      icon: Icons.check_circle_outline,
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(AppRouter.donorHistory),
                    ),
                  ),
                ],
              ),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _UploadCTACard
// ─────────────────────────────────────────────────────────────────────────────
class _UploadCTACard extends StatelessWidget {
  final VoidCallback onTap;
  const _UploadCTACard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: colorScheme.primaryContainer,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
      child: InkWell(
        borderRadius: AppTheme.radiusLg,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Have surplus food?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      'List it in under 2 minutes and help an NGO near you.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    const Gap(14),
                    FilledButton.icon(
                      icon: const Icon(Icons.upload_rounded, size: 18),
                      label: const Text('Upload Food'),
                      onPressed: onTap,
                    ),
                  ],
                ),
              ),
              const Gap(12),
              Icon(
                Icons.restaurant_rounded,
                size: 64,
                color: colorScheme.primary.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _StatCard
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.radiusMd,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const Gap(6),
              Text(
                '$count',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
