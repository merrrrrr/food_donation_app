# 🍱 FoodBridge — AI-Powered Food Donation Platform

> **Connecting surplus food with communities in need — powered by Google AI and Firebase.**

FoodBridge is a Flutter mobile application that bridges the gap between **food donors** (restaurants, caterers, individuals) and **NGOs / charity organisations** to reduce food waste and combat hunger. It uses **Gemini AI** via Firebase AI Logic to intelligently match available food donations with NGO needs, **Google Maps** for location-based discovery, and **Firebase** as the full backend infrastructure.

---

## 📑 Table of Contents

- [Project Overview](#-project-overview)
- [SDG Alignment](#-sdg-alignment)
- [Key Features](#-key-features)
- [Technology Stack](#-technology-stack)
- [Architecture Diagram](#-architecture-diagram)
- [Setup & Installation](#-setup--installation)
- [Usage Guide](#-usage-guide)
- [AI Integration Deep Dive](#-ai-integration-deep-dive)
- [Challenges Faced & Solutions](#-challenges-faced--solutions)
- [Future Roadmap / Scalability](#-future-roadmap--scalability)
- [Team Members](#-team-members)
- [Acknowledgments](#-acknowledgments)
- [License](#-license)

---

## 🌍 Project Overview

### Problem Statement

In Malaysia alone, approximately **17,000 tonnes of food** are wasted daily, while food banks and NGOs struggle to source enough provisions for vulnerable communities. The core issue is a **coordination gap** — donors have surplus food but no efficient way to connect with nearby NGOs that need it, and NGOs waste valuable time manually searching for available donations that match their dietary requirements and capacity.

### Solution Summary

**FoodBridge** solves this by creating a real-time, AI-enhanced food donation marketplace:

1. **Donors** upload surplus food listings with photos, dietary information, quantity, expiry dates, and pickup locations via Google Maps.
2. **NGOs** discover available donations through an interactive map with colour-coded urgency markers, advanced filtering, or an **AI-powered matching system** that uses **Google Gemini 2.5 Flash** to rank donations based on the NGO's specific needs (dietary requirements, number of people to feed, proximity, food type preferences).
3. The platform manages the entire **donation lifecycle** — from listing to claiming (with transaction-safe concurrency), handover verification, and evidence-based completion — ensuring accountability and transparency.
4. An **admin dashboard** manages NGO verification, ensuring only legitimate organisations can claim donations.

---

## 🎯 SDG Alignment

| SDG | Goal | How FoodBridge Contributes |
|-----|------|--------------------------|
| **SDG 2** | Zero Hunger | Directly channels surplus food to NGOs serving food-insecure communities, ensuring edible food reaches those who need it most instead of going to waste. |
| **SDG 12** | Responsible Consumption and Production | Reduces food waste at the source by creating an efficient redistribution channel. The AI matching system minimises mismatches (wrong dietary type, insufficient quantity), further reducing waste in the donation pipeline. |
| **SDG 11** | Sustainable Cities and Communities | Strengthens urban food security infrastructure in Malaysian cities by connecting local donors with nearby NGOs using location-based services and Google Maps integration. |

---

## ✨ Key Features

### Donor Features
- **Two-Step Food Upload** — Guided form with food photo capture, three-tier dietary categorisation (Halal/Vegetarian/Allergens), quantity, expiry date, pickup window, and storage type
- **Interactive Location Picker** — Google Maps widget with crosshair UI and reverse geocoding for precise pickup point selection
- **Real-Time Donation Tracking** — Live status updates across Pending → Claimed → Picked Up → Completed stages
- **Handover Verification** — Donor confirms food handover before NGO can mark completion
- **Edit & Cancel** — Modify or cancel donations while still in pending status
- **Donation History** — Complete record of all past donations with outcome details

### NGO Features
- **🤖 AI-Powered Smart Matching** — Gemini 2.5 Flash analyses NGO needs (food type, dietary preference, people to feed, max distance) against available donations and returns ranked recommendations with match scores and reasoning *(powered by Firebase AI Logic)*
- **Discovery Screen with Map & List Views** — Toggle between interactive Google Maps (colour-coded markers: 🔴 expiring ≤24h, 🟢 safe) and a searchable list view
- **Advanced Filtering** — Filter by dietary type, storage conditions, allergens, expiry date range, pickup time, and sort order
- **Quick Filters** — One-tap preset filters for "Expiring Soon", "Halal", and "Vegetarian"
- **Transaction-Safe Claiming** — Firestore transactions prevent two NGOs from claiming the same donation simultaneously
- **30-Minute Cancellation Window** — NGOs can cancel a claim within 30 minutes if plans change
- **Evidence-Based Completion** — Upload a handover evidence photo to complete the donation cycle
- **Claim History** — Full history of claimed and completed donations

### Admin Features
- **NGO Verification Dashboard** — Review and approve newly registered NGOs before they can claim donations
- **Real-Time Pending Queue** — Live stream of unverified NGO applications

### Platform-Wide
- **Role-Based Access Control** — Separate experiences for Donors, NGOs, and Admins with Firestore security rules enforcement
- **Real-Time Updates** — Firestore `snapshots()` streams keep all data live across all user sessions
- **Auto-Revert Late Claims** — If an NGO doesn't pick up within 1 hour of scheduled time, the donation automatically reverts to available
- **Malaysian Localisation** — Seed data features Malaysian foods (Nasi Lemak, Roti Canai, Dim Sum) and KL locations

---

## 🛠️ Technology Stack

### Google AI Technologies
| Technology | Usage |
|-----------|-------|
| **Gemini 2.5 Flash** (via Firebase AI Logic) | AI-powered food matching — analyses NGO requirements against available donations, ranks by suitability, provides reasoning. No API key management needed; authentication handled natively by Firebase. |

### Other Google Technologies
| Technology | Usage |
|-----------|-------|
| **Firebase Authentication** | Email/password registration and sign-in with role-based user management |
| **Cloud Firestore** | Real-time NoSQL database for `/users`, `/donations`, and `/ai_quotas` collections with security rules |
| **Firebase Storage** | Stores food photos, handover evidence photos, and profile photos with structured paths |
| **Firebase AI Logic** (`firebase_ai: ^2.0.0`) | SDK bridge to Gemini — handles auth, quotas, and streaming natively within the Firebase project |
| **Google Maps Flutter** | Interactive maps for location picking (donor), donation discovery (NGO), and detail views |
| **Google Maps Geocoding API** | Reverse geocoding to convert GPS coordinates to human-readable addresses |
| **Geolocator** | Device GPS location fetching for map defaults and distance calculations |
| **Google Fonts** | Inter typeface for consistent, modern typography |
| **Flutter** | Cross-platform UI framework (Android & iOS from single codebase) |
| **Material 3** | Google's latest design system with custom colour scheme |

### Other Tools & Libraries
| Tool | Usage |
|------|-------|
| **Provider** | State management with `ChangeNotifierProxyProvider` for reactive, session-aware architecture |
| **Equatable** | Value equality for model classes |
| **UUID** | RFC-4122 UUID generation for Firestore document IDs |
| **Cached Network Image** | Efficient image loading and caching |
| **Image Picker** | Camera and gallery access for food and evidence photos |
| **Dart `http`** | HTTP client for Google Maps Geocoding REST API calls |

---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter App (UI Layer)                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────┐  │
│  │  Donor   │  │   NGO    │  │  Admin   │  │  Auth Screens  │  │
│  │ Screens  │  │ Screens  │  │Dashboard │  │ Login/Register │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └───────┬────────┘  │
│       │              │             │                │            │
│  ┌────┴──────────────┴─────────────┴────────────────┴────────┐  │
│  │              Provider State Management Layer               │  │
│  │  ┌──────────────┐ ┌────────────────┐ ┌──────────────────┐ │  │
│  │  │ AuthProvider  │ │DonationProvider│ │  AdminProvider   │ │  │
│  │  │(auth state,   │ │(live streams,  │ │(NGO verification│ │  │
│  │  │ user model)   │ │ CRUD, uploads) │ │ queue)          │ │  │
│  │  └──────┬───────┘ └───────┬────────┘ └────────┬─────────┘ │  │
│  └─────────┼─────────────────┼───────────────────┼───────────┘  │
│            │                 │                   │               │
│  ┌─────────┴─────────────────┴───────────────────┴───────────┐  │
│  │                 Service Layer (Stateless)                   │  │
│  │  ┌───────────┐ ┌──────────────┐ ┌───────────┐ ┌─────────┐│  │
│  │  │AuthService│ │DonationService│ │AdminService│ │Storage ││  │
│  │  │           │ │              │ │           │ │Service  ││  │
│  │  └───────────┘ └──────────────┘ └───────────┘ └─────────┘│  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Google Cloud / Firebase                       │
│                                                                  │
│  ┌──────────────┐  ┌───────────────┐  ┌──────────────────────┐  │
│  │ Firebase Auth │  │Cloud Firestore│  │  Firebase Storage    │  │
│  │ (Email/Pass)  │  │  /users       │  │  /donations/photos   │  │
│  │               │  │  /donations   │  │  /users/profiles     │  │
│  │               │  │  /ai_quotas   │  │                      │  │
│  └──────────────┘  └───────────────┘  └──────────────────────┘  │
│                                                                  │
│  ┌──────────────────────┐  ┌──────────────────────────────────┐ │
│  │  Firebase AI Logic    │  │     Google Maps Platform         │ │
│  │  (Gemini 2.5 Flash)   │  │  Maps SDK + Geocoding API       │ │
│  │  - AI food matching   │  │  - Location picker              │ │
│  │  - Nutritional ranking│  │  - Discovery map view           │ │
│  │  - Smart reasoning    │  │  - Detail mini-maps             │ │
│  └──────────────────────┘  └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Component Roles

| Component | Role |
|-----------|------|
| **UI Layer** | Role-specific screens (Donor, NGO, Admin) with Material 3 theming |
| **Provider Layer** | Reactive state management — `AuthProvider` drives session lifecycle; `DonationProvider` manages live Firestore streams that start/stop on auth changes; `AdminProvider` streams unverified NGOs |
| **Service Layer** | Stateless wrappers around Firebase SDKs — clean separation allows easy testing and swapping. Includes `AiQuotaService` for per-user daily AI usage tracking. |
| **Firebase Auth** | Handles user authentication; UID used as document key in Firestore |
| **Cloud Firestore** | Primary database with real-time listeners, security rules enforcing role-based access and valid status transitions |
| **Firebase Storage** | Stores binary assets (food photos, evidence photos, profile photos) with structured paths |
| **Firebase AI Logic** | Bridges to Gemini 2.5 Flash for the AI matching feature — no API key required, uses Firebase project credentials |
| **Google Maps Platform** | Provides interactive maps, markers, and geocoding throughout the app |

---

## ⚙️ Setup & Installation

### Prerequisites

- **Flutter SDK** ≥ 3.8.1 ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart SDK** ≥ 3.8.1 (bundled with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Android Emulator** (API 21+) or a physical Android device
- **Firebase CLI** ([Install Firebase CLI](https://firebase.google.com/docs/cli))
- **FlutterFire CLI** (`dart pub global activate flutterfire_cli`)
- **Git** for cloning the repository

### Step 1: Clone the Repository

```bash
git clone https://github.com/merrrrrr/food_donation_app.git
cd food_donation_app
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Firebase Configuration

This project uses Firebase. You have two options:

#### Option A: Use the Existing Firebase Project (Team Members)
The `firebase_options.dart` and `google-services.json` files are already configured for the `food-donation-app-beb27` project. No additional setup needed.

#### Option B: Set Up Your Own Firebase Project
1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable the following services:
   - **Authentication** → Email/Password sign-in method
   - **Cloud Firestore** → Create database in production mode
   - **Firebase Storage** → Set up default bucket
   - **Firebase AI Logic** → Enable Gemini API access
3. Configure FlutterFire:
   ```bash
   flutterfire configure
   ```
4. Deploy security rules:
   ```bash
   firebase deploy --only firestore:rules,storage
   ```

### Step 4: Google Maps API Key

A Google Maps API key is required for the map features. To use your own:

1. Enable **Maps SDK for Android** and **Geocoding API** in [Google Cloud Console](https://console.cloud.google.com/apis)
2. Create an API key and restrict it to these APIs
3. Replace the API key in:
   - `android/app/src/main/AndroidManifest.xml` → `com.google.android.geo.API_KEY`
   - `lib/screens/donor/upload_food_step2_screen.dart` → `_mapsApiKey`

### Step 5: Run the App

```bash
flutter run
```

### Environment Variables / API Keys

| Key | Where to Set | Purpose |
|-----|-------------|---------|
| Google Maps API Key | `AndroidManifest.xml` + `upload_food_step2_screen.dart` | Maps SDK & Geocoding API |
| Firebase Config | `firebase_options.dart` (auto-generated by `flutterfire configure`) | Firebase project binding |
| Gemini (Firebase AI Logic) | No API key needed — uses Firebase project credentials | AI food matching |

> **Note:** The Firebase AI Logic SDK (`firebase_ai`) does **not** require a separate API key. Gemini access is authenticated through the Firebase project itself.

---

## 📱 Usage Guide

### Getting Started

1. **Launch the app** — you'll see the login screen.
2. **Register an account** — choose your role:
   - **Donor**: Can immediately start uploading food donations
   - **NGO**: Requires admin approval before claiming donations
3. **Log in** — you'll be routed to your role-specific dashboard automatically.

### Donor Flow

```
Register (role = Donor)
  └── Donor Dashboard
        ├── [Upload Food] → Step 1: Food details + photo
        │                 → Step 2: Location, pickup window, expiry
        ├── [My Donations] → Track status (Pending / Claimed / Picked Up / Completed)
        │     ├── Edit or Cancel (while pending)
        │     └── Verify Handover (when NGO arrives)
        ├── [History] → View completed/cancelled donations
        └── [Profile] → Update name, phone, photo
```

### NGO Flow

```
Register (role = NGO, requires admin verification)
  └── NGO Dashboard
        ├── [Discover Food] → List View (searchable, filterable)
        │                   → Map View (colour-coded markers)
        │                   → Tap any listing → Food Detail → Claim
        ├── [AI Smart Match] → Enter needs → Get AI-ranked recommendations
        ├── [My Claims] → Track claimed donations → Upload evidence
        ├── [History] → Past completed donations
        └── [Profile] → Organisation details
```

### Admin Flow

```
Login (role = Admin)
  └── Admin Dashboard
        └── Pending NGO Verifications → Approve / Review
```

### Donation Lifecycle

```
  DONOR uploads food          NGO discovers & claims         Handover & completion
  ┌─────────────┐           ┌──────────────────┐          ┌──────────────────┐
  │   PENDING    │──claim──→│     CLAIMED       │──verify─→│   PICKED UP      │
  │              │           │ (+ scheduled time)│          │(donor confirms)  │
  └──────┬──────┘           └────────┬─────────┘          └────────┬─────────┘
         │                           │                              │
    cancel│                     cancel│(30 min)               evidence│photo
         ▼                           ▼                              ▼
  ┌─────────────┐           ┌──────────────────┐          ┌──────────────────┐
  │  CANCELLED   │           │  PENDING (revert) │          │   COMPLETED ✅    │
  └─────────────┘           └──────────────────┘          └──────────────────┘
```

---

## 🤖 AI Integration Deep Dive

### Technology Choice: Gemini 2.5 Flash via Firebase AI Logic

We chose **Firebase AI Logic** (`firebase_ai: ^2.0.0`) to access **Gemini 2.5 Flash** because:
- **No API key management** — Authentication is handled natively through the Firebase project, eliminating key rotation and security concerns
- **Low latency** — Gemini 2.5 Flash is optimised for speed, critical for a real-time matching experience
- **Structured JSON output** — The `responseMimeType: 'application/json'` parameter ensures reliable, parseable responses
- **Generous free tier** — Suitable for hackathon and MVP scale

### How AI Matching Works

The AI Smart Match feature (`NgoAiMatchScreen`) implements a **two-layer ranking system**:

#### Layer 1: Local Pre-Ranking (Client-Side)
Before calling Gemini, the app performs intelligent pre-filtering:
1. **Filters** donations to only `pending`, non-expired listings
2. **Calculates distance** from NGO's GPS position to each donation using the **Haversine formula**
3. **Eliminates** donations outside the NGO's max distance preference
4. **Scores** each donation across multiple factors:
   - Dietary compatibility (Halal match, Vegetarian/Vegan match)
   - Keyword relevance (food type search terms)
   - Quantity-fitness ratio (donation quantity vs. people to feed)
   - Distance proximity (closer = higher score)
   - Freshness (further from expiry = higher score)
5. **Selects Top 6** candidates to send to Gemini (minimises token usage)

#### Layer 2: Gemini AI Ranking (Server-Side)
The top 6 candidates are sent to Gemini with a carefully engineered prompt:

**System Prompt:** The model acts as a *"Food Security & Nutrition Coordinator"* for a Malaysian food bank network.

**Input:** Minified JSON of candidate donations + NGO requirements (dietary preference, people to feed, food type keywords, extra notes).

**Gemini's Tasks:**
1. **Hard filter** — Eliminate any donation violating dietary constraints (e.g., non-Halal if Halal required)
2. **Rank by feeding sufficiency** — Categorise quantity match as "Perfect Match", "Nearly Sufficient", "Insufficient", or "Too Little"
3. **Consider food type relevance** — Boost items matching the NGO's keyword preferences
4. **Score 0–100** and provide a **15-word reasoning** for each recommendation

**Output Format:**
```json
[{"i": "donation_id", "s": 85, "r": "Halal rice, feeds 30, 2km away, expires in 3 days"}]
```

#### Resilience & Error Handling
- **Retry logic** — Up to 2 automatic retries with exponential backoff for rate limit errors (HTTP 429 / `RESOURCE_EXHAUSTED`)
- **Dynamic retry delay** — Parses Gemini error messages for exact retry timing (e.g., `"Please retry in 4.026734549s"`)
- **Response caching** — Skips redundant API calls if search inputs haven't changed
- **Safe JSON parsing** — Falls back to regex-based object extraction if Gemini returns truncated JSON
- **Graceful degradation** — If Gemini is entirely unavailable, displays locally-scored results with an "AI offline" notice
- **Cooldown timer** — 45-second minimum between searches to respect Free Tier quotas
- **Countdown UI** — Visual countdown timers for both retry waits and cooldown periods
- **Per-user daily quota** — `AiQuotaService` tracks each user's AI calls in Firestore (`/ai_quotas/{uid}`). The limit is **10 AI calls per user per day** (shared across AI Match and AI Autofill). The counter resets automatically at midnight and is enforced server-side, not just in-app.

### AI Configuration
```dart
final model = FirebaseAI.googleAI().generativeModel(
  model: 'gemini-2.5-flash',
  generationConfig: GenerationConfig(
    temperature: 0.1,          // Low temperature for consistent, factual ranking
    maxOutputTokens: 4000,     // Sufficient for top-6 results
    responseMimeType: 'application/json',  // Structured output
  ),
);
```

---

## 🧩 Challenges Faced & Solutions

### Challenge 1: AI API Rate Limits on Free Tier
**Problem:** During development and testing, Gemini's free tier quota was quickly exhausted, resulting in `RESOURCE_EXHAUSTED` errors that broke the AI matching flow.

**Solution:** Implemented a multi-layered resilience strategy:
- **Per-user daily quota** — `AiQuotaService` writes to Firestore (`/ai_quotas/{uid}`) and enforces a hard cap of 10 AI calls per user per calendar day, shared across both AI Match and AI Autofill. This is the primary guardrail against token abuse.
- **45-second cooldown** between AI searches to spread out requests within the daily budget
- **Response caching** — if the same search parameters are submitted, the cached result is returned instantly without an API call
- **Automatic retry** with exponential backoff (parses exact retry delay from Gemini error strings)
- **Local fallback** — if AI is completely unavailable, the app gracefully degrades to showing locally-scored results, ensuring the feature never fully breaks

### Challenge 2: Race Conditions in Donation Claiming
**Problem:** Two NGOs could potentially claim the same donation simultaneously, leading to conflicts and a poor user experience.

**Solution:** Used **Firestore transactions** for the claiming operation. The transaction reads the donation's current status and only proceeds if it's still `pending`, atomically updating it to `claimed`. This guarantees exactly one NGO can claim a donation, with others receiving a clear "already claimed" message.

### Challenge 3: Parsing Unreliable AI JSON Responses
**Problem:** Gemini occasionally returned malformed or truncated JSON (especially under rate limiting or when responses were cut at token limits), causing `json.decode()` to throw exceptions.

**Solution:** Built a **safe JSON parser** with multi-level fallback:
1. First attempts standard `json.decode()`
2. If that fails, uses regex to extract individual JSON objects from the partial response
3. Validates each extracted object has the required fields before including it in results
4. If all parsing fails, falls back to local scoring results

### Challenge 4: Composite Firestore Index Requirements
**Problem:** Queries with multiple `where` clauses and `orderBy` required composite indexes, which added deployment friction and slowed development iteration.

**Solution:** Designed queries to use single-field filters and performed **client-side sorting**. This eliminated the need for composite indexes entirely (the `firestore.indexes.json` file is empty), simplifying deployment while maintaining query functionality.

### Challenge 5: Accurate Distance Calculation Without Google Distance Matrix API
**Problem:** Needed to calculate distances between NGO location and all available donations for filtering and scoring, but the Distance Matrix API would be expensive at scale.

**Solution:** Implemented the **Haversine formula** directly in Dart for straight-line distance calculation. While not as precise as road-distance, it's computationally free, instantaneous, and sufficiently accurate for ranking and filtering within city distances.

---

## 🚀 Future Roadmap / Scalability

### Short-Term Enhancements
- **Push Notifications** — Firebase Cloud Messaging to alert NGOs of new nearby donations and donors of claim activity
- **Multi-Language Support** — Malay (BM) and Chinese (中文) localisation for broader Malaysian adoption
- **Donation Analytics Dashboard** — Visualise food saved, meals distributed, and carbon offset metrics
- **QR Code Handover** — Generate unique QR codes for streamlined pickup verification

### Medium-Term Features
- **Route Optimisation** — Google Directions API integration for NGOs collecting multiple donations in one trip
- **Recurring Donations** — Allow donors to schedule regular surplus food slots (e.g., daily lunch leftovers)
- **Food Safety Compliance** — Integration with Malaysian Food Safety guidelines and automated expiry warnings
- **Photo-Based Food Recognition** — Use Gemini's vision capabilities to auto-fill food details from photos

### Scalability Strategy
| Current | Scaled |
|---------|--------|
| Firebase free tier | Firebase Blaze plan with auto-scaling |
| Client-side sorting | Server-side Firestore composite indexes for performance |
| Single-region Firestore | Multi-region Firestore for lower latency |
| Firebase AI Logic (free tier) | Vertex AI with dedicated throughput for production workloads |
| Local Haversine distance | Google Distance Matrix API for accurate road distances |
| Flutter mobile app | Flutter Web deployment for broader access |

---

## 👥 Team Members

| Name | Role |
|------|------|
| Mervin Ooi Zhian Yang | Full-Stack Developer & Project Lead |
| Lim Tze Jiun | Full-Stack Developer |
| Kum Yong Jun | Full-Stack Developer |
| Liew Jun Wei Ivan | Full-Stack Developer |
---

## 🙏 Acknowledgments

- **Google Developer Student Clubs (GDSC)** — For organising KitaHack 2026 and providing the platform to build impactful solutions
- **Firebase Documentation** — Comprehensive guides for Auth, Firestore, Storage, and AI Logic integration
- **Google AI Studio** — For prototyping and testing Gemini prompts before integrating into the app
- **Flutter Community** — Open-source packages (Provider, Geolocator, Google Maps Flutter) that accelerated development

---

## 📄 License

This project is developed for **KitaHack 2026** by Google Developer Student Clubs.

MIT License — see [LICENSE](LICENSE) for details.
