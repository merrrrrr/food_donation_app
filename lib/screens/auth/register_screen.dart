import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/models/user_model.dart';
import 'package:food_donation_app/providers/auth_provider.dart';
import 'package:food_donation_app/widgets/custom_text_field.dart';
import 'package:food_donation_app/widgets/loading_overlay.dart';
import 'package:food_donation_app/widgets/primary_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  RegisterScreen
// ─────────────────────────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  UserRole _selectedRole = UserRole.donor;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text,
      role: _selectedRole,
    );

    if (!mounted) return;

    if (!success && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
    // Success: WrapperScreen reacts to AuthState.signedIn automatically.
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.primary,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: auth.isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Section header ────────────────────────────────────────
                  Text(
                    'Join FoodBridge',
                    style: textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Gap(4),
                  Text(
                    'Create your account to start donating or claiming food.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Gap(28),

                  // ── Role selector ─────────────────────────────────────────
                  Text(
                    'I am a...',
                    style: textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Gap(8),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(
                        value: UserRole.donor,
                        label: Text('Donor'),
                        icon: Icon(Icons.restaurant_rounded),
                      ),
                      ButtonSegment(
                        value: UserRole.ngo,
                        label: Text('NGO'),
                        icon: Icon(Icons.handshake_rounded),
                      ),
                    ],
                    selected: {_selectedRole},
                    onSelectionChanged: (Set<UserRole> newSelection) {
                      setState(() => _selectedRole = newSelection.first);
                    },
                  ),
                  const Gap(24),

                  // ── Display name ──────────────────────────────────────────
                  CustomTextField(
                    controller: _nameCtrl,
                    label: _selectedRole == UserRole.donor
                        ? 'Full Name'
                        : 'Organisation Name',
                    hint: _selectedRole == UserRole.donor
                        ? 'Ahmad bin Ali'
                        : 'Pertubuhan Kebajikan XYZ',
                    prefixIcon: Icons.person_outline,
                    onFieldSubmitted: (_) => _onRegister(),
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
                  const Gap(16),

                  // ── Email ─────────────────────────────────────────────────
                  CustomTextField(
                    controller: _emailCtrl,
                    label: 'Email',
                    hint: 'you@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    onFieldSubmitted: (_) => _onRegister(),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required.';
                      }
                      if (!v.contains('@')) return 'Enter a valid email.';
                      return null;
                    },
                  ),
                  const Gap(16),

                  // ── Password ──────────────────────────────────────────────
                  CustomTextField(
                    controller: _passwordCtrl,
                    label: 'Password',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    onFieldSubmitted: (_) => _onRegister(),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Password is required.';
                      }
                      if (v.length < 6) {
                        return 'Must be at least 6 characters.';
                      }
                      return null;
                    },
                  ),
                  const Gap(16),

                  // ── Confirm password ──────────────────────────────────────
                  CustomTextField(
                    controller: _confirmPasswordCtrl,
                    label: 'Confirm Password',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    onFieldSubmitted: (_) => _onRegister(),
                    validator: (v) {
                      if (v != _passwordCtrl.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const Gap(32),

                  // ── Register button ───────────────────────────────────────
                  PrimaryButton(
                    label: 'Create Account',
                    isLoading: auth.isLoading,
                    leadingIcon: Icons.check_circle_outline,
                    onPressed: _onRegister,
                  ),
                  const Gap(16),

                  // ── Login link ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
