import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/services/donation_service.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NgoHomeScreen (Dashboard)
//  Shows quick stats on available food and shortcuts to key NGO actions.
// ─────────────────────────────────────────────────────────────────────────────
class NgoHomeScreen extends StatefulWidget {
  const NgoHomeScreen({super.key});

  @override
  State<NgoHomeScreen> createState() => _NgoHomeScreenState();
}

class _NgoHomeScreenState extends State<NgoHomeScreen> {
  List<DonationModel> _myClaims = [];
  StreamSubscription<List<DonationModel>>? _claimsSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load all pending donations for the statistics cards
      context.read<DonationProvider>().loadAvailableDonations();
      // Separately stream this NGO's active claims
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        _claimsSub = DonationService().getNgoDonations(uid).listen((list) {
          if (mounted) {
            setState(() {
              _myClaims = list
                  .where((d) => d.status == DonationStatus.claimed)
                  .toList();
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _claimsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final donationProv = context.watch<DonationProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final available = donationProv.donations;
    final expiringSoon = available.where((d) => d.isExpiringSoon).length;
    final halalCount = available
        .where((d) => d.foodType == FoodType.halal)
        .length;
    final vegCount = available
        .where((d) => d.foodType == FoodType.vegetarian)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('FoodBridge')),
      body: RefreshIndicator(
        onRefresh: () async =>
            context.read<DonationProvider>().loadAvailableDonations(),
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
                    child: Text(
                      (auth.currentUser?.displayName.isNotEmpty == true)
                          ? auth.currentUser!.displayName[0].toUpperCase()
                          : '?',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
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
                'Find available food donations near you.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Gap(28),

              // ── Hero discovery CTA ────────────────────────────────────────
              _DiscoveryCTACard(
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.ngoDiscovery),
              ),
              const Gap(24),

              // ── Quick stats ───────────────────────────────────────────────
              Text(
                'Available Right Now',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Listed',
                      count: available.length,
                      icon: Icons.list_alt_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: _StatCard(
                      label: 'Expiring Soon',
                      count: expiringSoon,
                      icon: Icons.timer_outlined,
                      color: AppTheme.statusExpiringSoon,
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Halal',
                      count: halalCount,
                      icon: Icons.restaurant_rounded,
                      color: AppTheme.statusCompleted,
                    ),
                  ),
                  const Gap(10),
                  Expanded(
                    child: _StatCard(
                      label: 'Vegetarian',
                      count: vegCount,
                      icon: Icons.eco_rounded,
                      color: const Color(0xFF558B2F),
                    ),
                  ),
                ],
              ),
              const Gap(24),

              // ── Urgency preview ───────────────────────────────────────────
              if (expiringSoon > 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.statusExpiringSoon.withValues(alpha: 0.08),
                    borderRadius: AppTheme.radiusMd,
                    border: Border.all(
                      color: AppTheme.statusExpiringSoon.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.statusExpiringSoon,
                      ),
                      const Gap(12),
                      Expanded(
                        child: Text(
                          '$expiringSoon donation${expiringSoon > 1 ? 's' : ''} '
                          'expiring within 24 hours. Claim now!',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppTheme.statusExpiringSoon,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // ── Active claims section ──────────────────────────────────────
              if (_myClaims.isNotEmpty) ...[
                const Gap(24),
                Row(
                  children: [
                    Text(
                      'My Active Claims',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.statusClaimed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_myClaims.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.statusClaimed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(8),
                ..._myClaims.map(
                  (d) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.statusClaimed.withValues(
                          alpha: 0.15,
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: AppTheme.statusClaimed,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        d.foodName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        d.address ?? '${d.quantity} · ${d.donorName}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed(AppRouter.ngoResult, arguments: d),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private widgets
// ─────────────────────────────────────────────────────────────────────────────
class _DiscoveryCTACard extends StatelessWidget {
  final VoidCallback onTap;
  const _DiscoveryCTACard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                      'Find Food Near You',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const Gap(6),
                    Text(
                      'Browse available listings on the map or list view and claim today.',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                    const Gap(14),
                    FilledButton.icon(
                      icon: const Icon(Icons.explore_rounded, size: 18),
                      label: const Text('Discover Donations'),
                      onPressed: onTap,
                    ),
                  ],
                ),
              ),
              const Gap(12),
              Icon(
                Icons.handshake_rounded,
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

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const Gap(10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
          ],
        ),
      ),
    );
  }
}
