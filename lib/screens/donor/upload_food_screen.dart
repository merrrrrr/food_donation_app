import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/theme/app_theme.dart';
import 'package:food_donation_app/widgets/custom_text_field.dart';
import 'package:food_donation_app/widgets/primary_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  UploadFoodScreen  (Step 1 of 2)
//  Collects: food name, food type, quantity, storage type, optional photo.
//  On "Next" it pushes Step 2, passing a [FoodDraft] argument so state is
//  shared across both screens without a global provider.
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight data carrier passed from Step 1 → Step 2.
class FoodDraft {
  final String foodName;
  final FoodType foodType;
  final String quantity;
  final StorageType storageType;
  final XFile? photo;

  const FoodDraft({
    required this.foodName,
    required this.foodType,
    required this.quantity,
    required this.storageType,
    this.photo,
  });
}

class UploadFoodScreen extends StatefulWidget {
  const UploadFoodScreen({super.key});

  @override
  State<UploadFoodScreen> createState() => _UploadFoodScreenState();
}

class _UploadFoodScreenState extends State<UploadFoodScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  final _foodNameCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  FoodType _foodType = FoodType.halal;
  StorageType _storageType = StorageType.roomTemperature;
  XFile? _pickedImage;

  @override
  void dispose() {
    _foodNameCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }

  // ── Image picker ───────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (image != null) setState(() => _pickedImage = image);
  }

  // ── Next ───────────────────────────────────────────────────────────────────
  void _onNext() {
    if (!_formKey.currentState!.validate()) return;

    final draft = FoodDraft(
      foodName: _foodNameCtrl.text.trim(),
      foodType: _foodType,
      quantity: _quantityCtrl.text.trim(),
      storageType: _storageType,
      photo: _pickedImage,
    );

    Navigator.of(
      context,
    ).pushNamed(AppRouter.donorUploadStep2, arguments: draft);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Details'),
        bottom: _StepIndicator(step: 1),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Food name ────────────────────────────────────────────────
              _SectionHeader(title: 'Food Details'),
              const Gap(12),

              CustomTextField(
                controller: _foodNameCtrl,
                label: 'Food Name',
                hint: 'e.g. Nasi Lemak, Biryani Rice',
                prefixIcon: Icons.fastfood_outlined,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Food name is required.'
                    : null,
              ),
              const Gap(14),

              // ── Food Type ────────────────────────────────────────────────
              DropdownButtonFormField<FoodType>(
                value: _foodType,
                decoration: const InputDecoration(
                  labelText: 'Food Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: FoodType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayLabel),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _foodType = v!),
              ),
              const Gap(14),

              // ── Quantity ─────────────────────────────────────────────────
              CustomTextField(
                controller: _quantityCtrl,
                label: 'Quantity',
                hint: 'e.g. 10 pax, 3 kg, 20 packets',
                prefixIcon: Icons.production_quantity_limits_outlined,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Quantity is required.'
                    : null,
              ),
              const Gap(14),

              // ── Storage Type ─────────────────────────────────────────────
              DropdownButtonFormField<StorageType>(
                value: _storageType,
                decoration: const InputDecoration(
                  labelText: 'Storage Type',
                  prefixIcon: Icon(Icons.kitchen_outlined),
                ),
                items: StorageType.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.displayLabel),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _storageType = v!),
              ),
              const Gap(28),

              // ── Food Photo ───────────────────────────────────────────────
              _SectionHeader(title: 'Food Photo (Optional)'),
              const Gap(12),

              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: AppTheme.radiusMd,
                    border: Border.all(
                      color: _pickedImage != null
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.5),
                      width: _pickedImage != null ? 2 : 1,
                    ),
                  ),
                  child: _pickedImage != null
                      ? ClipRRect(
                          borderRadius: AppTheme.radiusMd,
                          child: Image.file(
                            File(_pickedImage!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 42,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const Gap(8),
                            Text(
                              'Tap to add a photo',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              if (_pickedImage != null) ...[
                const Gap(8),
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Change Photo'),
                  onPressed: _pickImage,
                ),
              ],
              const Gap(32),

              PrimaryButton(
                label: 'Next: Schedule & Location',
                leadingIcon: Icons.arrow_forward_rounded,
                onPressed: _onNext,
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
//  Shared private widgets (also used in Step 2 via export or same file)
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }
}

/// Simple step indicator shown in the AppBar bottom.
class _StepIndicator extends StatelessWidget implements PreferredSizeWidget {
  final int step; // 1 or 2
  const _StepIndicator({required this.step});

  @override
  Size get preferredSize => const Size.fromHeight(4);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.onPrimary;
    return LinearProgressIndicator(
      value: step / 2,
      backgroundColor: primary.withValues(alpha: 0.25),
      color: primary,
      minHeight: 4,
    );
  }
}
