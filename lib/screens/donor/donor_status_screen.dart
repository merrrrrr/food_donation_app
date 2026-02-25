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
//  DonorStatusScreen
//  Shows the donor's active (pending / claimed) donations in a filterable list.
// ─────────────────────────────────────────────────────────────────────────────
class DonorStatusScreen extends StatefulWidget {
  const DonorStatusScreen({super.key});

  @override
  State<DonorStatusScreen> createState() => _DonorStatusScreenState();
}

class _DonorStatusScreenState extends State<DonorStatusScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Load donations for this donor (may already be loaded from home screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<DonationProvider>().loadDonorDonations(uid);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final donationProv = context.watch<DonationProvider>();

    // Split into tabs
    final pending = donationProv.donations
        .where((d) => d.status == DonationStatus.pending)
        .toList();
    final claimed = donationProv.donations
        .where((d) => d.status == DonationStatus.claimed)
        .toList();
    final completed = donationProv.donations
        .where((d) => d.status == DonationStatus.completed)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Donations'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Claimed (${claimed.length})'),
            Tab(text: 'Done (${completed.length})'),
          ],
        ),
      ),
      body: donationProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _DonationList(donations: pending, showCancelButton: true),
                _DonationList(donations: claimed),
                _DonationList(donations: completed, showResultButton: true),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _DonationList
// ─────────────────────────────────────────────────────────────────────────────
class _DonationList extends StatelessWidget {
  final List<DonationModel> donations;
  final bool showCancelButton;
  final bool showResultButton;

  const _DonationList({
    required this.donations,
    this.showCancelButton = false,
    this.showResultButton = false,
  });

  @override
  Widget build(BuildContext context) {
    if (donations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: Colors.black26),
            Gap(12),
            Text(
              'No donations here yet.',
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final uid = context.read<AuthProvider>().currentUser?.uid;
        if (uid != null) {
          context.read<DonationProvider>().loadDonorDonations(uid);
          // Small delay to ensure the spinner is visible to the user
          await Future.delayed(const Duration(milliseconds: 600));
        }
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: donations.length,
        itemBuilder: (_, i) => _DonationCard(
          donation: donations[i],
          showCancelButton: showCancelButton,
          showResultButton: showResultButton,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _DonationCard
// ─────────────────────────────────────────────────────────────────────────────
class _DonationCard extends StatelessWidget {
  final DonationModel donation;
  final bool showCancelButton;
  final bool showResultButton;

  const _DonationCard({
    required this.donation,
    this.showCancelButton = false,
    this.showResultButton = false,
  });

  Color _statusColor() {
    return switch (donation.status) {
      DonationStatus.pending => AppTheme.statusPending,
      DonationStatus.claimed => AppTheme.statusClaimed,
      DonationStatus.completed => AppTheme.statusCompleted,
      DonationStatus.cancelled => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _statusColor();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    donation.foodName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(
                  label: donation.status.displayLabel,
                  color: statusColor,
                ),
              ],
            ),
            const Gap(8),

            // ── Details ───────────────────────────────────────────────────
            _InfoRow(
              icon: Icons.label_outline,
              label:
                  '${donation.sourceStatus} · ${donation.dietaryBase}'
                  '${donation.contains.isNotEmpty ? '\n${donation.contains.join(', ')}' : ''}',
            ),
            _InfoRow(
              icon: Icons.production_quantity_limits_outlined,
              label: donation.quantity,
            ),
            _InfoRow(
              icon: Icons.event_outlined,
              label:
                  'Expires: ${DateFormat('dd MMM yyyy, hh:mm a').format(donation.expiryDate)}',
              isWarning: donation.isExpiringSoon,
            ),
            if (donation.ngoName != null)
              _InfoRow(
                icon: Icons.handshake_rounded,
                label: 'Claimed by: ${donation.ngoName}',
              ),
            if (donation.address != null)
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: donation.address!,
              ),

            // ── Actions ────────────────────────────────────────────────────
            if (showCancelButton) ...[
              const Gap(12),
              OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel Listing'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error),
                ),
                onPressed: () => _confirmCancel(context),
              ),
            ],
            if (showResultButton) ...[
              const Gap(12),
              OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('View Result'),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRouter.donorResult, arguments: donation),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Donation?'),
        content: const Text(
          'This will remove the listing from the NGO discovery screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep It'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Donation'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<DonationProvider>().cancelDonation(donation.id);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isWarning;
  const _InfoRow({
    required this.icon,
    required this.label,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning
        ? AppTheme.statusExpiringSoon
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const Gap(6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
