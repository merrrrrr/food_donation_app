import 'package:food_donation_app/models/donation_model.dart';

class DiscoveryFilter {
  final String? sourceStatus;
  final String? dietaryBase;
  final bool expiringSoon;

  const DiscoveryFilter({
    this.sourceStatus,
    this.dietaryBase,
    this.expiringSoon = false,
  });

  /// Factory for "Expiring Soon" filter
  factory DiscoveryFilter.expiringSoon() =>
      const DiscoveryFilter(expiringSoon: true);

  /// Factory for "Halal" filter
  factory DiscoveryFilter.halal() =>
      const DiscoveryFilter(sourceStatus: DietarySourceStatus.halal);

  /// Factory for "Vegetarian" filter
  factory DiscoveryFilter.vegetarian() =>
      const DiscoveryFilter(dietaryBase: DietaryBase.vegetarian);
}
