import 'package:flutter/material.dart';
import 'package:food_donation_app/screens/ngo/ngo_home_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_discovery_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_profile_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_ai_match_screen.dart';

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
    NgoAiMatchScreen(),
    NgoProfileScreen(),
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
            icon: Icon(Icons.auto_awesome_outlined),
            activeIcon: Icon(Icons.auto_awesome),
            label: 'AI Match',
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
