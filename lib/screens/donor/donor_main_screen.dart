import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/screens/donor/donor_home_screen.dart';
import 'package:food_donation_app/screens/donor/donor_profile_screen.dart';
import 'package:food_donation_app/screens/donor/donor_status_screen.dart';

class DonorMainScreen extends StatefulWidget {
  const DonorMainScreen({super.key});

  @override
  State<DonorMainScreen> createState() => _DonorMainScreenState();
}

class _DonorMainScreenState extends State<DonorMainScreen> {
  final List<Widget> _screens = const [
    DonorHomeScreen(),
    DonorStatusScreen(),
    DonorProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final donationProv = context.watch<DonationProvider>();
    final selectedIndex = donationProv.donorSelectedIndex;

    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => donationProv.setDonorTab(index),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Donations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: selectedIndex != 2
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRouter.donorUpload),
              icon: const Icon(Icons.add),
              label: const Text('Upload Food'),
            )
          : null,
    );
  }
}
