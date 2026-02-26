import 'dart:math';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/services/donation_service.dart';

class SeedService {
  static final _donationService = DonationService();

  static const _klLocations = [
    {
      'lat': 3.1578,
      'lng': 101.7119,
      'addr': 'KLCC, Jalan Ampang, 50088 Kuala Lumpur',
    },
    {'lat': 3.1296, 'lng': 101.6723, 'addr': 'Bangsar, 59000 Kuala Lumpur'},
    {'lat': 3.1726, 'lng': 101.6649, 'addr': 'Mont Kiara, 50480 Kuala Lumpur'},
    {
      'lat': 3.1466,
      'lng': 101.7105,
      'addr': 'Bukit Bintang, 55100 Kuala Lumpur',
    },
    {
      'lat': 3.1695,
      'lng': 101.6975,
      'addr': 'Chow Kit, Jalan Raja Laut, 50350 Kuala Lumpur',
    },
    {'lat': 3.1073, 'lng': 101.6067, 'addr': 'Petaling Jaya, 47500 Selangor'},
    {
      'lat': 3.1548,
      'lng': 101.7596,
      'addr': 'Ampang Point, 68000 Ampang, Selangor',
    },
    {
      'lat': 3.1439,
      'lng': 101.6276,
      'addr': 'Damansara Heights, 50490 Kuala Lumpur',
    },
    {'lat': 3.2147, 'lng': 101.7436, 'addr': 'Wangsa Maju, 53300 Kuala Lumpur'},
    {'lat': 3.2117, 'lng': 101.6361, 'addr': 'Kepong Baru, 52100 Kuala Lumpur'},
    {'lat': 3.2041, 'lng': 101.7294, 'addr': 'Setapak, 53000 Kuala Lumpur'},
    {
      'lat': 3.0209,
      'lng': 101.6166,
      'addr': 'Puchong Jaya, 47100 Puchong, Selangor',
    },
    {
      'lat': 3.1190,
      'lng': 101.6882,
      'addr': 'Brickfields (Little India), 50470 Kuala Lumpur',
    },
    {'lat': 3.1285, 'lng': 101.7127, 'addr': 'Cheras, 56100 Kuala Lumpur'},
    {'lat': 3.1768, 'lng': 101.7127, 'addr': 'Titiwangsa, 53200 Kuala Lumpur'},
  ];

  static Future<void> seedDonations({
    required String donorId,
    required String donorName,
  }) async {
    final now = DateTime.now();
    final random = Random();

    final foodPool = [
      {
        'name': 'PK Froz Premium Frozen Salmon Fillet',
        'source': DietarySourceStatus.nonHalal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.seafood],
        'qty': '4 packs (approx 800g)',
        'storage': StorageType.frozen,
        'days': 60,
      },
      {
        'name': 'Ready & Refresh Bistro Caesar Salad Pack',
        'source': DietarySourceStatus.porkFree,
        'base': DietaryBase.vegetarian,
        'contains': [DietaryContains.dairyEgg],
        'qty': '6 packs',
        'storage': StorageType.refrigerated,
        'days': 2,
      },
      {
        'name': 'Nasi Lemak Bungkus (Daun Pisang)',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.seafood, DietaryContains.nuts],
        'qty': '30 pax',
        'storage': StorageType.roomTemperature,
        'days': 1,
      },
      {
        'name': 'Rich Chocolate Fudge Cake Slices',
        'source': DietarySourceStatus.porkFree,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.dairyEgg],
        'qty': '12 slices',
        'storage': StorageType.roomTemperature,
        'days': 3,
      },
      {
        'name': 'Bistro Garden Greek Salad Pack',
        'source': DietarySourceStatus.porkFree,
        'base': DietaryBase.vegetarian,
        'contains': [DietaryContains.dairyEgg, DietaryContains.nuts],
        'qty': '5 packs',
        'storage': StorageType.refrigerated,
        'days': 2,
      },
      {
        'name': 'Nasi Lemak with Rendang Ayam',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.nuts],
        'qty': '20 pax',
        'storage': StorageType.roomTemperature,
        'days': 1,
      },
      {
        'name': 'Dark Chocolate Truffle Birthday Cake',
        'source': DietarySourceStatus.porkFree,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.dairyEgg],
        'qty': '1 whole cake (8 portions)',
        'storage': StorageType.refrigerated,
        'days': 3,
      },
      {
        'name': 'Frozen Tiger Prawns (Shell On)',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.seafood],
        'qty': '3 bags (approx 1.2 kg)',
        'storage': StorageType.frozen,
        'days': 90,
      },
      {
        'name': 'Roti Canai with Dhal & Curry',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.vegetarian,
        'contains': [DietaryContains.dairyEgg],
        'qty': '40 pieces (with gravy)',
        'storage': StorageType.roomTemperature,
        'days': 1,
      },
      {
        'name': 'Mixed Spinach & Cranberry Salad Kit',
        'source': DietarySourceStatus.porkFree,
        'base': DietaryBase.vegan,
        'contains': [DietaryContains.nuts],
        'qty': '4 packs',
        'storage': StorageType.refrigerated,
        'days': 1,
      },
      {
        'name': 'Bistro Chicken Caesar Salad Tray',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.dairyEgg],
        'qty': '8 trays',
        'storage': StorageType.refrigerated,
        'days': 2,
      },
      {
        'name': 'Nasi Lemak Set with Sambal Prawn',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.seafood, DietaryContains.nuts],
        'qty': '25 pax',
        'storage': StorageType.roomTemperature,
        'days': 1,
      },
      {
        'name': 'Assorted Fruit Salad Cups',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.vegan,
        'contains': [],
        'qty': '15 cups',
        'storage': StorageType.refrigerated,
        'days': 1,
      },
      {
        'name': 'Banana & Blueberry Muffin Pack',
        'source': DietarySourceStatus.porkFree,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.dairyEgg, DietaryContains.nuts],
        'qty': '24 muffins (4 boxes)',
        'storage': StorageType.roomTemperature,
        'days': 3,
      },
      {
        'name': 'Frozen Atlantic Salmon Sashimi Grade',
        'source': DietarySourceStatus.nonHalal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.seafood],
        'qty': '2 packs (approx 500g)',
        'storage': StorageType.frozen,
        'days': 90,
      },

      // New items for "refresh" / variety
      {
        'name': 'Dim Sum Platter (Siew Mai & Har Gow)',
        'source': DietarySourceStatus.nonHalal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.seafood],
        'qty': '50 pieces',
        'storage': StorageType.refrigerated,
        'days': 1,
      },
      {
        'name': 'Vegetarian Fried Rice with Mixed Veggies',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.vegetarian,
        'contains': [],
        'qty': '15 boxes',
        'storage': StorageType.roomTemperature,
        'days': 1,
      },
      {
        'name': 'Grilled Chicken Chop with Black Pepper Sauce',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.nonVeg,
        'contains': [],
        'qty': '10 sets',
        'storage': StorageType.roomTemperature,
        'days': 1,
      },
      {
        'name': 'Cheese Margherita Pizza (Large)',
        'source': DietarySourceStatus.porkFree,
        'base': DietaryBase.vegetarian,
        'contains': [DietaryContains.dairyEgg],
        'qty': '4 pizzas',
        'storage': StorageType.roomTemperature,
        'days': 1,
      },
      {
        'name': 'Stir-fry Noodles (Mee Goreng Mamak)',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.seafood, DietaryContains.nuts],
        'qty': '20 pax',
        'storage': StorageType.roomTemperature,
        'days': 1,
      },
      {
        'name': 'Fresh Soy Milk (Less Sugar)',
        'source': DietarySourceStatus.halal,
        'base': DietaryBase.vegan,
        'contains': [],
        'qty': '12 bottles',
        'storage': StorageType.refrigerated,
        'days': 3,
      },
      {
        'name': 'Assorted Sandwich Box (Tuna, Egg, Cheese)',
        'source': DietarySourceStatus.porkFree,
        'base': DietaryBase.nonVeg,
        'contains': [DietaryContains.seafood, DietaryContains.dairyEgg],
        'qty': '30 halves',
        'storage': StorageType.refrigerated,
        'days': 1,
      },
    ];

    // Shuffle and pick 15
    foodPool.shuffle(random);
    final foods = foodPool.take(15).toList();

    for (int i = 0; i < foods.length; i++) {
      final food = foods[i];
      final loc = _klLocations[random.nextInt(_klLocations.length)];

      final donation = DonationModel(
        id: '', // Generated by service
        donorId: donorId,
        donorName: donorName,
        foodName: food['name'] as String,
        sourceStatus: food['source'] as String,
        dietaryBase: food['base'] as String,
        contains: List<String>.from(food['contains'] as List),
        quantity: food['qty'] as String,
        expiryDate: now.add(Duration(days: food['days'] as int)),
        pickupStart: now.add(const Duration(hours: 2)),
        pickupEnd: now.add(const Duration(hours: 10)),
        storageType: food['storage'] as StorageType,
        latitude: loc['lat'] as double,
        longitude: loc['lng'] as double,
        address: loc['addr'] as String,
        status: DonationStatus.pending,
      );

      await _donationService.createDonation(donation);
    }
  }
}
