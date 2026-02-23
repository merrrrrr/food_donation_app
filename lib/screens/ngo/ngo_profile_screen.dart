import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NgoProfileScreen
//  Shows the NGO's profile info and their history of claimed / completed
//  donations.
// ─────────────────────────────────────────────────────────────────────────────
class NgoProfileScreen extends StatefulWidget {
  const NgoProfileScreen({super.key});

  @override
  State<NgoProfileScreen> createState() => _NgoProfileScreenState();
}

class _NgoProfileScreenState extends State<NgoProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<DonationProvider>().loadNgoDonations(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final donationProv = context.watch<DonationProvider>();
    final user = auth.currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final claimed = donationProv.donations
        .where((d) => d.status == DonationStatus.claimed)
        .length;
    final completed = donationProv.donations
        .where((d) => d.status == DonationStatus.completed)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Avatar card ───────────────────────────────────────────────
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor:
                          colorScheme.secondaryContainer,
                      child: Text(
                        (user?.displayName.isNotEmpty == true)
                            ? user!.displayName[0].toUpperCase()
                            : '?',
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Gap(12),
                    Text(
                      user?.displayName ?? '—',
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Gap(4),
                    Text(
                      user?.email ?? '—',
                      style: textTheme.bodyMedium?.copyWith(
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const Gap(4),
                    Chip(
                      label: const Text('NGO'),
                      backgroundColor: colorScheme.secondaryContainer
                          .withValues(alpha: 0.5),
                      labelStyle: textTheme.labelSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(24),

            // ── Stats row ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Active Claims',
                    value: claimed.toString(),
                    icon: Icons.local_shipping_outlined,
                    color: AppTheme.statusClaimed,
                  ),
                ),
                const Gap(10),
                Expanded(
                  child: _StatTile(
                    label: 'Completed',
                    value: completed.toString(),
                    icon: Icons.check_circle_outline,
                    color: AppTheme.statusCompleted,
                  ),
                ),
              ],
            ),
            const Gap(24),

            // ── History ────────────────────────────────────────────────────
            Text(
              'Claim History',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Gap(12),

            if (donationProv.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (donationProv.donations.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    "You haven't claimed any donations yet.\nBrowse available food to get started!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: donationProv.donations.length,
                itemBuilder: (_, i) {
                  final d = donationProv.donations[i];
                  return _HistoryTile(
                    donation: d,
                    onTap: d.status == DonationStatus.claimed
                        ? () => Navigator.of(context).pushNamed(
                              AppRouter.ngoResult,
                              arguments: d,
                            )
                        : null,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Private small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const Gap(10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final DonationModel donation;
  final VoidCallback? onTap;
  const _HistoryTile({required this.donation, this.onTap});

  Color _statusColor() => switch (donation.status) {
        DonationStatus.pending => AppTheme.statusPending,
        DonationStatus.claimed => AppTheme.statusClaimed,
        DonationStatus.completed => AppTheme.statusCompleted,
        DonationStatus.cancelled => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child:
            Icon(Icons.volunteer_activism_rounded, color: color, size: 20),
      ),
      title: Text(
        donation.foodName,
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'From: ${donation.donorName}',
            style: const TextStyle(fontSize: 11),
          ),
          Text(
            DateFormat('dd MMM yyyy')
                .format(donation.createdAt ?? donation.expiryDate),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
      trailing: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          donation.status.displayLabel,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ),
      onTap: onTap,
    );
  }
}
