import 'package:flutter/material.dart';

// Screen imports — auth
import 'package:food_donation_app/screens/auth/wrapper_screen.dart';
import 'package:food_donation_app/screens/auth/login_screen.dart';
import 'package:food_donation_app/screens/auth/register_screen.dart';

// Screen imports — donor
import 'package:food_donation_app/screens/donor/donor_main_screen.dart';
import 'package:food_donation_app/screens/donor/donor_profile_screen.dart';
import 'package:food_donation_app/screens/donor/donor_result_screen.dart';
import 'package:food_donation_app/screens/donor/donor_status_screen.dart';
import 'package:food_donation_app/screens/donor/location_picker_screen.dart';
import 'package:food_donation_app/screens/donor/upload_food_screen.dart';
import 'package:food_donation_app/screens/donor/upload_food_step2_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Screen imports — NGO
import 'package:food_donation_app/screens/ngo/ngo_discovery_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_food_detail_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_main_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_profile_screen.dart';
import 'package:food_donation_app/screens/ngo/ngo_result_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppRouter
//  Centralises all named routes.  Add new routes here and nowhere else.
//
//  Usage in MaterialApp:
//    initialRoute: AppRouter.root,
//    onGenerateRoute: AppRouter.generateRoute,
// ─────────────────────────────────────────────────────────────────────────────
abstract final class AppRouter {
  // ── Route name constants ──────────────────────────────────────────────────
  static const String root = '/';
  static const String login = '/login';
  static const String register = '/register';

  // Donor routes
  static const String donorHome = '/donor/home';
  static const String donorUpload = '/donor/upload';
  static const String donorUploadStep2 = '/donor/upload/step2';
  static const String donorStatus = '/donor/status';
  static const String donorResult = '/donor/result';
  static const String donorProfile = '/donor/profile';
  static const String donorLocationPicker = '/donor/location-picker';

  // NGO routes
  static const String ngoHome = '/ngo/home';
  static const String ngoDiscovery = '/ngo/discovery';
  static const String ngoFoodDetail = '/ngo/food-detail';
  static const String ngoResult = '/ngo/result';
  static const String ngoProfile = '/ngo/profile';

  // ── Route generator ───────────────────────────────────────────────────────
  static Route<dynamic> generateRoute(RouteSettings settings) {
    return switch (settings.name) {
      root => _fade(const WrapperScreen(), settings),
      login => _slide(const LoginScreen(), settings),
      register => _slide(const RegisterScreen(), settings),

      // Donor
      donorHome => _fade(const DonorMainScreen(), settings),
      donorUpload => _slide(const UploadFoodScreen(), settings),
      donorUploadStep2 => _slide(const UploadFoodStep2Screen(), settings),
      donorStatus => _slide(const DonorStatusScreen(), settings),
      donorResult => _slide(const DonorResultScreen(), settings),
      donorProfile => _slide(const DonorProfileScreen(), settings),
      donorLocationPicker => _slide(
        LocationPickerScreen(initialLocation: settings.arguments as LatLng?),
        settings,
      ),

      // NGO
      ngoHome => _fade(const NgoMainScreen(), settings),
      ngoDiscovery => _slide(const NgoDiscoveryScreen(), settings),
      ngoFoodDetail => _slide(const NgoFoodDetailScreen(), settings),
      ngoResult => _slide(const NgoResultScreen(), settings),
      ngoProfile => _slide(const NgoProfileScreen(), settings),

      // Fallback for unknown routes
      _ => MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Not Found')),
          body: Center(child: Text('No route defined for "${settings.name}"')),
        ),
      ),
    };
  }

  // ── Transition helpers ────────────────────────────────────────────────────

  /// Smooth fade for "global" transitions (e.g., auth wrapper → home).
  static PageRouteBuilder<T> _fade<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Slide-from-right for sequential "forward" navigations.
  static PageRouteBuilder<T> _slide<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: Curves.easeOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 280),
    );
  }
}
