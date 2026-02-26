import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DonorHistoryScreen
//  Shows the donor's past donations, filtered to only completed or cancelled.
// ─────────────────────────────────────────────────────────────────────────────
class DonorHistoryScreen extends StatelessWidget {
  const DonorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Donation History'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _HistoryTabContent(status: DonationStatus.completed),
            _HistoryTabContent(status: DonationStatus.cancelled),
          ],
        ),
      ),
    );
  }
}

class _HistoryTabContent extends StatelessWidget {
  final DonationStatus status;
  const _HistoryTabContent({required this.status});

  @override
  Widget build(BuildContext context) {
    final donationProv = context.watch<DonationProvider>();

    final historyDonations = donationProv.donorDonations
        .where((d) => d.status == status)
        .toList();

    if (donationProv.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (historyDonations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            "You have no ${status.displayLabel.toLowerCase()} donations.",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black45),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyDonations.length,
      itemBuilder: (_, i) {
        final d = historyDonations[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _HistoryTile(
            donation: d,
            onTap: d.status == DonationStatus.completed
                ? () => Navigator.of(
                    context,
                  ).pushNamed(AppRouter.donorResult, arguments: d)
                : null,
          ),
        );
      },
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
          child: Icon(Icons.history, color: color, size: 20),
        ),
        title: Text(
          donation.foodName,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          DateFormat(
            'dd MMM yyyy',
          ).format(donation.createdAt ?? donation.expiryDate),
          style: const TextStyle(fontSize: 12),
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
