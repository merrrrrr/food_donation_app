# FoodBridge — Testing Guide

A quick guide to run the app and access both the **Donor** and **NGO** screen flows.

---

## Prerequisites

1. **Firebase configured** ✅ — `firebase_options.dart` is now generated.
2. An Android emulator / physical device connected (or an iOS simulator).
3. Run once if you haven't already:
   ```bash
   flutter pub get
   ```

## Run the App

```bash
flutter run
```

---

## Screen Flows

### Donor Flow

```
Register (role = Donor)
  └── Donor Dashboard  (home screen)
        ├── [Upload Food] or FAB  →  Upload Food Form
        ├── [View Active Donations]  →  My Donations (Pending / Claimed / Done tabs)
        │     └── Tap a "Done" donation  →  Handover Result & evidence photo
        └── Profile icon (top-right)  →  Donor Profile
```

**How to test**
1. Open the app → tap **Register**.
2. Choose **Donor**, fill in details, tap **Register**.
3. You land on the **Donor Dashboard**.
4. Tap **Upload Food** (FAB or CTA) → fill the form → submit.
5. Your new listing appears in **My Donations → Pending** tab.

---

### NGO Flow

```
Register (role = NGO)
  └── NGO Dashboard  (home screen)
        ├── [Discover Food] FAB or CTA  →  Discovery screen
        │     ├── List view — tap a card  →  Food Detail
        │     └── Map view  — tap info window  →  Food Detail
        │           └── [Claim This Donation]  →  Evidence Upload
        │                 └── Upload photo  →  Handover Complete ✅
        └── Profile icon (top-right)  →  NGO Profile + claim history
```

**How to test**
1. Register a second account (different email) → choose **NGO**.
2. You land on the **NGO Dashboard** — stats show pending donations.
3. Tap **Discover Food** → toggle between **List** 🗒️ and **Map** 🗺️.
   - Red markers = expiring within 24 h, green = safe.
4. Tap any listing → **Food Detail** screen.
5. Tap **Claim This Donation** → confirm in the dialog.
6. You're taken to **Evidence Upload** — take or select a photo and tap **Confirm Handover**.
7. Success screen appears; the donation now shows as **Completed** in your NGO Profile.

---

## Firestore Indexes

The first time a query runs, Firestore may log an index-creation link to the console:

```
[FIRESTORE] The query requires an index. You can create it here: <link>
```

Open each link in your browser and click **Create index**. Queries that need indexes:
- `donations` filtered by `donorId`, ordered by `createdAt`
- `donations` filtered by `status = pending`, ordered by `expiryDate`
- `donations` filtered by `ngoId`, ordered by `updatedAt`

---

## Quick Reference — Route Names

| Constant | Route | Screen |
|----------|-------|--------|
| `AppRouter.donorHome` | `/donor/home` | Donor Dashboard |
| `AppRouter.donorUpload` | `/donor/upload` | Upload Food form |
| `AppRouter.donorStatus` | `/donor/status` | My Donations |
| `AppRouter.donorResult` | `/donor/result` | Handover result |
| `AppRouter.donorProfile` | `/donor/profile` | Donor Profile |
| `AppRouter.ngoHome` | `/ngo/home` | NGO Dashboard |
| `AppRouter.ngoDiscovery` | `/ngo/discovery` | Discover Food (List+Map) |
| `AppRouter.ngoFoodDetail` | `/ngo/food-detail` | Food Detail + Claim |
| `AppRouter.ngoResult` | `/ngo/result` | Evidence Upload |
| `AppRouter.ngoProfile` | `/ngo/profile` | NGO Profile |
