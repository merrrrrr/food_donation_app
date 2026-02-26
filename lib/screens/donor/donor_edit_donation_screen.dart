import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';
import 'package:food_donation_app/widgets/custom_text_field.dart';
import 'package:food_donation_app/widgets/dietary_selection_widget.dart';
import 'package:food_donation_app/widgets/primary_button.dart';
import 'package:food_donation_app/widgets/loading_overlay.dart';

class DonorEditDonationScreen extends StatefulWidget {
  final DonationModel donation;

  const DonorEditDonationScreen({super.key, required this.donation});

  @override
  State<DonorEditDonationScreen> createState() =>
      _DonorEditDonationScreenState();
}

class _DonorEditDonationScreenState extends State<DonorEditDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fmt = DateFormat('dd MMM yyyy, hh:mm a');

  // ── Controllers ───────────────────────────────────────────────────────────
  late TextEditingController _foodNameCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _expiryCtrl;
  late TextEditingController _pickupStartCtrl;
  late TextEditingController _pickupEndCtrl;
  late TextEditingController _addressCtrl;

  // ── State ──────────────────────────────────────────────────────────────────
  late String _sourceStatus;
  late String _dietaryBase;
  late List<String> _contains;
  late StorageType _storageType;
  late DateTime _expiryDate;
  late DateTime _pickupStart;
  late DateTime _pickupEnd;
  double? _latitude;
  double? _longitude;
  XFile? _newImage;

  @override
  void initState() {
    super.initState();
    final d = widget.donation;
    _foodNameCtrl = TextEditingController(text: d.foodName);
    _quantityCtrl = TextEditingController(text: d.quantity);
    _expiryCtrl = TextEditingController(text: _fmt.format(d.expiryDate));
    _pickupStartCtrl = TextEditingController(text: _fmt.format(d.pickupStart));
    _pickupEndCtrl = TextEditingController(text: _fmt.format(d.pickupEnd));
    _addressCtrl = TextEditingController(text: d.address);

    _sourceStatus = d.sourceStatus;
    _dietaryBase = d.dietaryBase;
    _contains = List.from(d.contains);
    _storageType = d.storageType;
    _expiryDate = d.expiryDate;
    _pickupStart = d.pickupStart;
    _pickupEnd = d.pickupEnd;
    _latitude = d.latitude;
    _longitude = d.longitude;
  }

  @override
  void dispose() {
    _foodNameCtrl.dispose();
    _quantityCtrl.dispose();
    _expiryCtrl.dispose();
    _pickupStartCtrl.dispose();
    _pickupEndCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Pickers ───────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (image != null) setState(() => _newImage = image);
  }

  Future<DateTime?> _pickDateTime({
    required DateTime firstDate,
    required DateTime lastDate,
    DateTime? initial,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.now(),
    );
    if (time == null || !mounted) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final donationProv = context.read<DonationProvider>();
    final updated = widget.donation.copyWith(
      foodName: _foodNameCtrl.text.trim(),
      quantity: _quantityCtrl.text.trim(),
      sourceStatus: _sourceStatus,
      dietaryBase: _dietaryBase,
      contains: _contains,
      storageType: _storageType,
      expiryDate: _expiryDate,
      pickupStart: _pickupStart,
      pickupEnd: _pickupEnd,
      address: _addressCtrl.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
    );

    final success = await donationProv.updateDonation(
      updated,
      newImage: _newImage != null ? File(_newImage!.path) : null,
    );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation updated successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(donationProv.errorMessage ?? 'Update failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final donationProv = context.watch<DonationProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Donation')),
      body: LoadingOverlay(
        isLoading: donationProv.isLoading,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(title: 'Food Details'),
                const Gap(12),
                CustomTextField(
                  controller: _foodNameCtrl,
                  label: 'Food Name',
                  prefixIcon: Icons.fastfood_outlined,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const Gap(12),
                CustomTextField(
                  controller: _quantityCtrl,
                  label: 'Quantity (e.g. 10 pax)',
                  prefixIcon: Icons.production_quantity_limits_outlined,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const Gap(16),
                ThreeTierDietaryWidget(
                  initialSourceStatus: _sourceStatus,
                  initialDietaryBase: _dietaryBase,
                  initialContains: _contains,
                  onSelectionChanged: (s, b, c) {
                    setState(() {
                      _sourceStatus = s!;
                      _dietaryBase = b!;
                      _contains = c;
                    });
                  },
                ),
                const Gap(16),
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
                const Gap(24),

                _SectionHeader(title: 'Schedule & Location'),
                const Gap(12),
                CustomTextField(
                  controller: _expiryCtrl,
                  label: 'Expiry',
                  prefixIcon: Icons.event_outlined,
                  readOnly: true,
                  onTap: () async {
                    final dt = await _pickDateTime(
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initial: _expiryDate,
                    );
                    if (dt != null) {
                      setState(() {
                        _expiryDate = dt;
                        _expiryCtrl.text = _fmt.format(dt);
                      });
                    }
                  },
                ),
                const Gap(12),
                CustomTextField(
                  controller: _addressCtrl,
                  label: 'Pickup Address',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const Gap(24),

                _SectionHeader(title: 'Photo'),
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
                        color: colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: _newImage != null
                        ? ClipRRect(
                            borderRadius: AppTheme.radiusMd,
                            child: Image.file(
                              File(_newImage!.path),
                              fit: BoxFit.cover,
                            ),
                          )
                        : (widget.donation.photoUrl != null
                              ? ClipRRect(
                                  borderRadius: AppTheme.radiusMd,
                                  child: Image.network(
                                    widget.donation.photoUrl!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 40,
                                  color: colorScheme.primary,
                                )),
                  ),
                ),
                const Gap(32),

                PrimaryButton(
                  label: 'Save Changes',
                  isLoading: donationProv.isLoading,
                  onPressed: _onSave,
                ),
                const Gap(24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
      ),
    );
  }
}
