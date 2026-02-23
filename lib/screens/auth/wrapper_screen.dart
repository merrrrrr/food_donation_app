import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/models/user_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/screens/auth/login_screen.dart';
import 'package:food_donation_app/screens/donor/donor_main_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_main_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  WrapperScreen
//  The root route ('/').  Watches AuthProvider and renders the correct
//  screen based on auth state and user role.  No child screen needs its
//  own auth guard — this widget is the single gatekeeper.
// ─────────────────────────────────────────────────────────────────────────────
class WrapperScreen extends StatelessWidget {
  const WrapperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return switch (authProvider.authState) {
      // Still determining auth state on cold-start
      AuthState.unknown => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),

      // Not signed in — show login
      AuthState.signedOut => const LoginScreen(),

      // Signed in — route to the correct role dashboard
      AuthState.signedIn =>
        authProvider.currentUser?.role == UserRole.donor
            ? const DonorMainScreen()
            : const NgoMainScreen(),
    };
  }
}
