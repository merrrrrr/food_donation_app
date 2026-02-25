import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:food_donation_app/models/donation_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ThreeTierDietaryWidget
//
//  A 3-tier categorized system for dietary information.
//  Tier 1: Source Status (Single Choice)
//  Tier 2: Dietary Base (Single Choice)
//  Tier 3: Contains (Multi-select)
//
//  Logic rule: If Tier 2 is "Vegetarian" or "Vegan", Tier 3 options
//  "Contains Beef" and "Contains Seafood" are disabled.
// ─────────────────────────────────────────────────────────────────────────────
class ThreeTierDietaryWidget extends StatefulWidget {
  final String? initialSourceStatus;
  final String? initialDietaryBase;
  final List<String> initialContains;

  /// Called every time any of the 3 tiers change.
  final void Function(
    String? sourceStatus,
    String? dietaryBase,
    List<String> contains,
  )
  onSelectionChanged;

  const ThreeTierDietaryWidget({
    super.key,
    this.initialSourceStatus,
    this.initialDietaryBase,
    this.initialContains = const [],
    required this.onSelectionChanged,
  });

  @override
  State<ThreeTierDietaryWidget> createState() => _ThreeTierDietaryWidgetState();
}

class _ThreeTierDietaryWidgetState extends State<ThreeTierDietaryWidget> {
  String? _sourceStatus;
  String? _dietaryBase;
  late Set<String> _contains;

  @override
  void initState() {
    super.initState();
    _sourceStatus = widget.initialSourceStatus;
    _dietaryBase = widget.initialDietaryBase;
    _contains = Set<String>.from(widget.initialContains);
  }

  void _notify() {
    final orderedContains = DietaryContains.all
        .where(_contains.contains)
        .toList();
    widget.onSelectionChanged(_sourceStatus, _dietaryBase, orderedContains);
  }

  void _onSourceStatusChanged(String status) {
    setState(() => _sourceStatus = status);
    _notify();
  }

  void _onDietaryBaseChanged(String base) {
    setState(() {
      _dietaryBase = base;
      // Apply logic rule: Veg/Vegan disables Beef/Seafood
      if (base == DietaryBase.vegetarian || base == DietaryBase.vegan) {
        _contains.remove(DietaryContains.beef);
        _contains.remove(DietaryContains.seafood);
      }
    });
    _notify();
  }

  void _toggleContains(String item) {
    setState(() {
      if (_contains.contains(item)) {
        _contains.remove(item);
      } else {
        _contains.add(item);
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tier 1: Source Status ──────────────────────────────────────────
        Text(
          '1. Source Status',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Gap(6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: DietarySourceStatus.all.map((status) {
            final isSelected = _sourceStatus == status;
            return ChoiceChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (_) => _onSourceStatusChanged(status),
              selectedColor: colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const Gap(16),

        // ── Tier 2: Dietary Base ───────────────────────────────────────────
        Text(
          '2. Dietary Base',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Gap(6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: DietaryBase.all.map((base) {
            final isSelected = _dietaryBase == base;
            return ChoiceChip(
              label: Text(base),
              selected: isSelected,
              onSelected: (_) => _onDietaryBaseChanged(base),
              selectedColor: colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
        const Gap(16),

        // ── Tier 3: Contains (Allergens/Ingredients) ───────────────────────
        Text(
          '3. Contains (Optional)',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Gap(6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: DietaryContains.all.map((item) {
            final isSelected = _contains.contains(item);

            // Compute disabled state
            bool isDisabled = false;
            if ((_dietaryBase == DietaryBase.vegetarian ||
                    _dietaryBase == DietaryBase.vegan) &&
                (item == DietaryContains.beef ||
                    item == DietaryContains.seafood)) {
              isDisabled = true;
            }

            return FilterChip(
              label: Text(item),
              selected: isSelected,
              onSelected: isDisabled ? null : (_) => _toggleContains(item),
              showCheckmark: true,
              selectedColor: colorScheme.tertiaryContainer,
              checkmarkColor: colorScheme.onTertiaryContainer,
              labelStyle: TextStyle(
                color: isDisabled
                    ? colorScheme.onSurface.withValues(alpha: 0.38)
                    : isSelected
                    ? colorScheme.onTertiaryContainer
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
