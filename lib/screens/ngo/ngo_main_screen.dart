import 'package:flutter/material.dart';
import 'package:food_donation_app/screens/ngo/ngo_home_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_discovery_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/app_router.dart';
import 'package:gap/gap.dart';

class NgoMainScreen extends StatefulWidget {
  const NgoMainScreen({super.key});

  @override
  State<NgoMainScreen> createState() => _NgoMainScreenState();
}

class _NgoMainScreenState extends State<NgoMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    NgoHomeScreen(),
    NgoDiscoveryScreen(),
    NgoProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    if (user != null && !user.isVerified) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account Pending Review'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRouter.root,
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.hourglass_empty_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
                const Gap(24),
                Text(
                  'Verification Pending',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const Gap(16),
                Text(
                  'Your registration number (${user.registrationNumber ?? "N/A"}) is currently under review by our administrators.\n\n'
                  'We will verify your NGO registration and grant you access shortly.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.black54,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
