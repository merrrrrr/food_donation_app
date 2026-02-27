import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import 'package:food_donation_app/models/donation_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AiAutofillResult
//  Structured result returned by [AiAutofillService.suggestFromFoodName].
// ─────────────────────────────────────────────────────────────────────────────
class AiAutofillResult {
  /// One of [DietarySourceStatus] constants.
  final String sourceStatus;

  /// One of [DietaryBase] constants.
  final String dietaryBase;

  /// Subset of [DietaryContains] constants.
  final List<String> contains;

  /// Suggested [StorageType].
  final StorageType storageType;

  /// Suggested quantity unit, e.g. "pax", "kg", "packets".
  final String qtyUnit;

  const AiAutofillResult({
    required this.sourceStatus,
    required this.dietaryBase,
    required this.contains,
    required this.storageType,
    required this.qtyUnit,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  AiAutofillService
//  Sends a food name to Gemini via Firebase AI Logic and returns suggested
//  dietary tags, storage type, and quantity unit.
//  No API key needed — auth is handled by Firebase.
// ─────────────────────────────────────────────────────────────────────────────
class AiAutofillService {
  // Valid constant sets used in the prompt so Gemini never invents new values.
  static const _validSource = [
    'Halal Certified',
    'Pork-Free / Muslim-Friendly',
    'Non-Halal',
  ];
  static const _validBase = ['Non-Vegetarian', 'Vegetarian', 'Vegan'];
  static const _validContains = [
    'Contains Beef',
    'Contains Seafood',
    'Contains Nuts',
    'Contains Dairy / Egg',
  ];
  static const _validStorage = ['roomTemperature', 'refrigerated', 'frozen'];

  Future<AiAutofillResult> suggestFromFoodName(String foodName) async {
    final model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(
        temperature: 0.0, // deterministic classification
        maxOutputTokens: 1024,
        responseMimeType: 'application/json',
      ),
    );

    final prompt = '''
You are a food classification assistant for a Malaysian food donation platform.

Given the food name "$foodName", return a single compact JSON object with these fields:
- "sourceStatus": one of ${jsonEncode(_validSource)}
- "dietaryBase": one of ${jsonEncode(_validBase)}
- "contains": array, subset of ${jsonEncode(_validContains)}, only include if relevant, can be empty []
- "storageType": one of ${jsonEncode(_validStorage)}
- "qtyUnit": best unit string for this food (e.g. "pax", "kg", "packets", "boxes", "portions", "bottles")

Rules:
- Halal Certified if the food is typically made halal (e.g. chicken rice, nasi lemak, biryani)
- Non-Halal if it clearly contains pork (e.g. bak kut teh, char siu, wantan mee)
- Pork-Free / Muslim-Friendly if uncertain but typically pork-free
- Use "refrigerated" for cooked food, dairy, or food that spoils quickly
- Use "frozen" for ice cream or frozen meals only
- Use "roomTemperature" for dry goods, bread, packaged snacks, fruits
- Vegetarian / Vegan only if no meat or animal products
- Return ONLY the JSON object, no explanation.
''';

    debugPrint('[AiAutofill] Requesting suggestions for: "$foodName"');

    final response = await model.generateContent([Content.text(prompt)]);
    final text = (response.text ?? '').trim();

    debugPrint('[AiAutofill] Response: $text');

    final map = jsonDecode(text) as Map<String, dynamic>;

    // ── Validate & sanitise each field ────────────────────────────────────
    final sourceStatus = _validSource.contains(map['sourceStatus'])
        ? map['sourceStatus'] as String
        : DietarySourceStatus.porkFree;

    final dietaryBase = _validBase.contains(map['dietaryBase'])
        ? map['dietaryBase'] as String
        : DietaryBase.nonVeg;

    final rawContains = (map['contains'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where(_validContains.contains)
        .toList();

    final storageKey = map['storageType'] as String? ?? 'roomTemperature';
    final storageType = StorageType.values.firstWhere(
      (s) => s.name == storageKey,
      orElse: () => StorageType.roomTemperature,
    );

    final qtyUnit = (map['qtyUnit'] as String? ?? 'pax').trim();

    return AiAutofillResult(
      sourceStatus: sourceStatus,
      dietaryBase: dietaryBase,
      contains: rawContains,
      storageType: storageType,
      qtyUnit: qtyUnit,
    );
  }
}
