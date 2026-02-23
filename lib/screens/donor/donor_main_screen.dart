import 'package:flutter/material.dart';
import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/screens/donor/donor_home_screen.dart';
import 'package:food_donation_app/screens/donor/donor_status_screen.dart';
import 'package:food_donation_app/screens/donor/donor_profile_screen.dart';

class DonorMainScreen extends StatefulWidget {
  const DonorMainScreen({super.key});

  @override
  State<DonorMainScreen> createState() => _DonorMainScreenState();
}

class _DonorMainScreenState extends State<DonorMainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    DonorHomeScreen(),
    DonorStatusScreen(),
    DonorProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
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
      floatingActionButton:
          _selectedIndex !=
              2 // Hide on Profile for cleaner look? No, maybe keep it everywhere.
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
