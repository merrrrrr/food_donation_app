import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/providers/admin_provider.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AdminDashboardScreen
//  Displays a list of unverified NGOs for the admin to review and approve.
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminProv = context.watch<AdminProvider>();
    final pendingNGOs = adminProv.pendingNGOs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRouter.root, (route) => false);
              }
            },
          ),
        ],
      ),
      body: adminProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingNGOs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppTheme.statusCompleted,
                  ),
                  Gap(16),
                  Text(
                    'All caught up!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Gap(8),
                  Text('There are no NGOs pending verification.'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                // Assuming you might add a manual reload method to provider,
                // but since we are streaming real-time, this might be a no-op
                // or force restart the stream. For now, just a small delay.
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: pendingNGOs.length,
                separatorBuilder: (_, __) => const Gap(12),
                itemBuilder: (context, index) {
                  final ngo = pendingNGOs[index];
                  final isApproving = adminProv.isApproving(ngo.uid);

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.orange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.orange.withOpacity(0.2),
                                child: const Icon(
                                  Icons.business,
                                  color: Colors.orange,
                                ),
                              ),
                              const Gap(12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ngo.displayName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      ngo.email,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Gap(16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Registration No:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  ngo.registrationNumber ?? 'Not Provided',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (ngo.phone.isNotEmpty) ...[
                            const Gap(8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const Gap(8),
                                Text(
                                  ngo.phone,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                          const Gap(16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isApproving
                                  ? null
                                  : () async {
                                      final success = await adminProv
                                          .approveNGO(ngo.uid);
                                      if (success && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${ngo.displayName} has been approved.',
                                            ),
                                            backgroundColor:
                                                AppTheme.statusCompleted,
                                          ),
                                        );
                                      } else if (!success && context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              adminProv.errorMessage ??
                                                  'Failed to approve.',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.statusCompleted,
                              ),
                              icon: isApproving
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline),
                              label: Text(
                                isApproving ? 'Approving...' : 'Approve NGO',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
