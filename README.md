# 🍱 FoodBridge — AI-Powered Food Donation Platform

## 📑 Table of Contents

- [Project Overview](#-project-overview)
- [SDG Alignment](#-sdg-alignment)
- [Key Features](#-key-features)
- [Technology Stack](#-technology-stack)
- [Architecture Diagram](#-architecture-diagram)
- [Setup & Installation](#-setup--installation)
- [User Guide](#-user-guide)
- [AI Integration Deep Dive](#-ai-integration-deep-dive)
- [Implementation Details](#-implementation-details)
- [Challenges Faced & Solutions](#-challenges-faced--solutions)
- [Future Roadmap](#-future-roadmap)
- [Team Members](#-team-members)
- [License](#-license)

---

## 🌍 Project Overview

FoodBridge is a Flutter mobile application that bridges the gap between **food donors** (restaurants, caterers, individuals) and **NGOs / charity organisations** to reduce food waste and combat hunger. It uses **Gemini AI** via Firebase AI Logic to intelligently match available food donations with NGO needs, **Google Maps** for location-based discovery, and **Firebase** as the full backend infrastructure.

### Problem Statement

In Malaysia alone, approximately **17,000 tonnes of food** are wasted daily, while food banks and NGOs struggle to source enough provisions for vulnerable communities. The core issue is a **coordination gap** — donors have surplus food but no efficient way to connect with nearby NGOs that need it, and NGOs waste valuable time manually searching for available donations that match their dietary requirements and capacity.

### Solution Summary

**FoodBridge** solves this by creating a real-time, AI-enhanced food donation marketplace:

1. **Donors** upload surplus food with photos, dietary info, quantity, expiry dates, and pickup location.
2. **NGOs** discover donations via an interactive map or an **AI matching system** (Gemini 2.5 Flash) that ranks donations against the NGO's specific needs.
3. The platform manages the full **donation lifecycle** — from listing to claiming, handover verification, and evidence-based completion.
4. An **admin dashboard** handles NGO verification, ensuring only legitimate organisations can claim donations.

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
| **Flutter** | Cross-platform UI framework (Android & iOS from single codebase) |

### Other Tools & Libraries
| Tool | Usage |
|------|-------|
| **Provider** | State management with `ChangeNotifierProxyProvider` for reactive, session-aware architecture |
| **Cached Network Image** | Efficient image loading and caching for remote food and evidence photos |
| **Image Picker** | Camera and gallery access for food photo capture and handover evidence upload |

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

A pre-configured admin account is available:

| Field | Value |
|-------|-------|
| Email | `admin@gmail.com` |
| Password | `abcd1234` |

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
5. **Create an admin user manually** — register an account in the app, then open the Firestore console and set the `role` field of that user's document in `/users/{uid}` to `"admin"`.

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

## 📱 User Guide

### Getting Started

1. **Launch the app** — you'll see the login screen.
2. **Register an account** — choose your role:
   - **Donor**: Can immediately start uploading food donations
   - **NGO**: Requires admin approval before claiming donations
3. **Log in** — you'll be routed to your role-specific dashboard automatically.

---

### Donor Flow

1. **Upload a donation** — tap "Donate Food" and complete the two-step form:
   - Step 1: Add a photo, food name, dietary category (Halal/Vegetarian/Other), allergens, quantity, expiry date, storage type, and pickup window
   - Step 2: Pin the pickup location on the Google Maps picker
2. **Track status** — your donation appears on the dashboard with a live status badge (Pending → Claimed → Picked Up → Completed)
3. **Confirm handover** — when the NGO arrives, tap "Confirm Handover" to advance the status to Picked Up
4. **Complete** — once the NGO uploads evidence, the donation is marked Completed and moved to history
5. **Edit or cancel** — donations in Pending status can be edited or cancelled at any time

---

### NGO Flow

1. **Wait for approval** — after registration, your account is pending until an admin verifies your organisation
2. **Discover donations** — browse available donations via the map view (colour-coded markers: red = expiring ≤24h, green = safe) or the list view with search and filters
3. **AI Smart Match** *(optional)* — tap "AI Match" and enter your needs (food type, dietary preference, number of people, max distance); Gemini ranks the best available donations for you
4. **Claim a donation** — tap a donation and press "Claim"; select your scheduled pickup time
5. **Cancel if needed** — claims can be cancelled within 30 minutes of claiming
6. **Pick up & complete** — after the donor confirms handover, upload a photo as evidence to mark the donation Completed

---

### Admin Flow

1. **Log in** with the admin account — you are routed directly to the Admin Dashboard
2. **Review pending NGOs** — a live queue shows all NGO accounts awaiting verification
3. **Approve or reject** — tap an NGO to review their details, then approve to grant them claiming access or reject to decline

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
- **Per-user daily quota** — Hard cap of 10 AI calls/user/day enforced via `AiQuotaService` in Firestore; 45-second cooldown prevents burst requests within that budget
- **Retry & caching** — Up to 2 automatic retries with exact delay parsed from Gemini error strings; identical inputs return cached results instantly
- **Graceful degradation** — Malformed JSON is recovered via regex fallback; if Gemini is fully unavailable the app falls back to locally-scored results

> See [Challenge 1](#challenge-1-ai-api-rate-limits-on-free-tier) for full implementation details.

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

## 🔧 Implementation Details

### 1. Real-Time Data Architecture
All data in the app is **live by default**. `DonationProvider` holds two persistent Firestore `snapshots()` streams — one for the current donor's donations and one for all available donations (for NGO discovery). These streams are started when a user signs in and cancelled on sign-out, managed by `ChangeNotifierProxyProvider` reacting to `AuthProvider` state changes. This means every screen always reflects the latest Firestore state without manual refresh.

### 2. Role-Based Navigation
Route decisions are made in `WrapperScreen`, which listens to `AuthProvider`. On auth state change, it reads `currentUser.role` (stored in Firestore `/users/{uid}`) and pushes the appropriate named route — `/donor/home`, `/ngo/home`, or `/admin/home`. All named routes are centralised in `AppRouter` with typed constants, ensuring no magic strings scattered across the codebase.

### 3. Transaction-Safe Donation Claiming
Two NGOs claiming the same donation simultaneously is prevented with a **Firestore transaction** in `DonationService`. The transaction reads the donation document inside an atomic block and only writes the `claimed` status if the current value is still `pending`. If another NGO claimed it first, the transaction aborts and the second NGO receives a clear "already claimed" error — no double-claiming is possible.

### 4. Two-Step Donation Upload
The donor upload flow is split across two screens (`UploadFoodScreen` → `UploadFoodStep2Screen`) to keep each step focused. State is passed forward via a `FoodDraft` object (a plain Dart class) as a route argument — no global provider is used for transient form state. The final `DonationModel` is only written to Firestore after both steps are confirmed, preventing orphaned partial documents.

### 5. Image Upload Pipeline
Food photos and evidence photos are handled by `StorageService`, which uploads to Firebase Storage at structured paths (`/donations/{donationId}/food.jpg`, `/evidence/{donationId}.jpg`). The download URL is written to Firestore only after a successful upload, ensuring documents never reference a missing file. `cached_network_image` is used throughout for efficient loading and caching of remote images.

### 6. Firestore Security Rules
Security is enforced server-side in `firestore.rules`:
- Donors can only read/write their own donations
- NGOs can only claim `pending` donations and update status within valid transitions
- Admins have elevated read access for the NGO verification queue
- `/ai_quotas` documents are locked to the owning UID — users cannot spoof or reset each other's counters

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

## 🚀 Future Roadmap

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

---

## 👥 Team Members

| Name | Role |
|------|------|
| Mervin Ooi Zhian Yang | Full-Stack Developer & Project Lead |
| Lim Tze Jiun | Full-Stack Developer |
| Kum Yong Jun | Full-Stack Developer |
| Liew Jun Wei Ivan | Full-Stack Developer |
---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
