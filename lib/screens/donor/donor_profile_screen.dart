import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/services/seed_service.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DonorProfileScreen
//  Shows the signed-in donor's info and their full donation history.
// ─────────────────────────────────────────────────────────────────────────────
class DonorProfileScreen extends StatefulWidget {
  const DonorProfileScreen({super.key});

  @override
  State<DonorProfileScreen> createState() => _DonorProfileScreenState();
}

class _DonorProfileScreenState extends State<DonorProfileScreen> {
  Future<void> _openEditSheet(AuthProvider auth) async {
    final user = auth.currentUser;
    if (user == null) return;
    final nameCtrl = TextEditingController(text: user.displayName);
    final phoneCtrl = TextEditingController(text: user.phone);
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final viewInsets = MediaQuery.of(ctx).viewInsets;
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Edit Profile',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required.';
                    }
                    if (v.trim().length < 2) {
                      return 'Must be at least 2 characters.';
                    }
                    return null;
                  },
                ),
                const Gap(12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone number is required.';
                    }
                    if (v.trim().length < 8) {
                      return 'Enter a valid phone number.';
                    }
                    return null;
                  },
                ),
                const Gap(20),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final success = await auth.updateProfile(
                      displayName: nameCtrl.text,
                      phone: phoneCtrl.text,
                    );
                    if (!mounted) return;
                    if (!success && auth.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(auth.errorMessage!)),
                      );
                    } else {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _handleExit(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
          title: const Text('Log out?'),
          content: const Text(
            'You will be signed out and returned to the login page.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
              ),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true && mounted) {
      await context.read<AuthProvider>().signOut();
      if (mounted) {
        // Return to the root wrapper so it can decide which
        // screen to show based on auth state.
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRouter.root, (route) => false);
      }
    }

    // Prevent the default pop; navigation is handled manually.
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        context.read<DonationProvider>().loadDonorDonations(uid);
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

    return WillPopScope(
      onWillPop: () => _handleExit(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Profile'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
              onPressed: () => _openEditSheet(auth),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () => _handleExit(context),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar + name card ────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  borderRadius: AppTheme.radiusLg,
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withValues(alpha: 0.12),
                      colorScheme.secondary.withValues(alpha: 0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        (user?.displayName.isNotEmpty == true)
                            ? user!.displayName[0].toUpperCase()
                            : '?',
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Gap(14),
                    Text(
                      user?.displayName ?? '—',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),

                    const Gap(4),

                    const Gap(4),

                    Text(
                      user?.email ?? '—',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),

                    const Gap(4),

                    // Phone Number Display
                    Text(
                      user?.phone ?? '—',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),

                    const Gap(10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Donor',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Gap(24),

              // ── Stats ─────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: 'Total Donated',
                      value: donationProv.donorDonations.length.toString(),
                      icon: Icons.volunteer_activism_rounded,
                      color: colorScheme.primary,
                    ),
                  ),

                  Expanded(
                    child: _StatTile(
                      label: 'Completed',
                      value: donationProv.donorDonations
                          .where((d) => d.status == DonationStatus.completed)
                          .length
                          .toString(),
                      icon: Icons.check_circle_outline,
                      color: AppTheme.statusCompleted,
                    ),
                  ),
                ],
              ),
              const Gap(12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh Sample Donations'),
                onPressed: () async {
                  if (user == null) return;
                  try {
                    await SeedService.seedDonations(
                      donorId: user.uid,
                      donorName: user.displayName,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Succesfully seeded 15 donations!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Seeding failed: $e')),
                      );
                    }
                  }
                },
              ),
              const Gap(24),

              const Gap(16),

              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRouter.donorHistory),
                icon: const Icon(Icons.history),
                label: const Text('View Full Donation History'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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
//  _StatTile
// ─────────────────────────────────────────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
