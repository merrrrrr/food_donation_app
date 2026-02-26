import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NgoHistoryScreen
//  Shows the NGO's past donations in a single list.
// ─────────────────────────────────────────────────────────────────────────────
class NgoHistoryScreen extends StatelessWidget {
  const NgoHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final donationProv = context.watch<DonationProvider>();

    // Filter to only show completed and cancelled donations in the history list
    final historyDonations = donationProv.ngoDonations
        .where(
          (d) =>
              d.status == DonationStatus.completed ||
              d.status == DonationStatus.cancelled,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Claim History')),
      body: donationProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : historyDonations.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  "You have no completed or cancelled claims.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black45),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: historyDonations.length,
              itemBuilder: (_, i) {
                final d = historyDonations[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _HistoryTile(
                    donation: d,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRouter.ngoFoodDetail, arguments: d),
                  ),
                );
              },
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _HistoryTile
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryTile extends StatelessWidget {
  final DonationModel donation;
  final VoidCallback? onTap;
  const _HistoryTile({required this.donation, this.onTap});

  Color _statusColor() => switch (donation.status) {
    DonationStatus.pending => AppTheme.statusPending,
    DonationStatus.claimed => AppTheme.statusClaimed,
    DonationStatus.pickedUp => AppTheme.statusClaimed,
    DonationStatus.completed => AppTheme.statusCompleted,
    DonationStatus.cancelled => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(Icons.volunteer_activism_rounded, color: color, size: 20),
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
              DateFormat(
                'dd MMM yyyy',
              ).format(donation.createdAt ?? donation.expiryDate),
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            donation.status.displayLabel,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
