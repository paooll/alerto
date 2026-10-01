# Alerto

Cross-platform (Flutter, Android + iOS) personal price-alert app for **Forex, Gold (XAU/USD) and CFD/index instruments**, backed by **Firebase**. Price monitoring and notifications only — no trading or order execution.

> **Build in progress** — this repo is being developed step by step. Current status: Steps 1–8 complete (scaffold, auth, market-data integration, alert creation/management, backend evaluator + FCM, alert history, Quicksand/glass UI with light+dark themes). Deployment tooling in `docs/DEPLOYMENT.md`. See `docs/MARKET_DATA.md` for the verified provider choice.

## Architecture

```
Flutter app ──► Callable Cloud Functions (getCatalog / getQuotes / getTimeSeries)
                      │
                      ▼
              MarketDataProvider interface  ◄── Twelve Data (default)
                      ▲                          (swap to OANDA later)
              Scheduled evaluator (1/min)
                      │  one provider fetch per DISTINCT symbol
                      ▼
              evaluate ALL users' alerts vs shared quotes
                      │
                      ├──► users/{uid}/alertHistory
                      └──► FCM push notifications (deduped)
```

- **API keys live only in Cloud Functions** (`TWELVEDATA_API_KEY` secret). The Flutter app never sees them.
- **One API request per distinct symbol per evaluation run** — 100 users with XAU/USD alerts cost 1 provider credit per run, not 100.
- **No market ticks in Firestore** — only short-lived `marketState` eval snapshots written by Admin SDK.

## Repository layout

```
lib/                    Flutter app (domain, data, services, providers, ui)
functions/              Firebase Cloud Functions (TypeScript): callables + evaluator
firebase/               Firestore rules & indexes
docs/MARKET_DATA.md     Provider verification & swap guide
.claude/skills/         Agent skills installed per user request
.agent/skills/
```

## Prerequisites

- Flutter SDK ≥ 3.4 (`flutter doctor`)
- Node.js 20 + Firebase CLI (`npm i -g firebase-tools`)
- A Firebase project (Blaze plan required for Cloud Functions + scheduled functions)
- A Twelve Data API key (free tier works)

## Setup

```bash
# 1. Flutter deps
flutter pub get

# 2. Wire the Firebase project (generates lib/firebase_options.dart,
#    android/google-services.json, ios/GoogleService-Info.plist)
flutterfire configure

# 3. Backend deps + API key
cd functions && npm install && cd ..
firebase functions:secrets:set TWELVEDATA_API_KEY

# 4. Deploy rules, indexes and functions
firebase deploy --only firestore:rules,firestore:indexes,functions
```

## Run

```bash
flutter run                # Android or iOS simulator
```

## Test

```bash
flutter test
cd functions && npm run build   # typecheck backend
```

## Deployment

Full deployment guide: **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** — covers
platform-folder bootstrap, Android/iOS release builds + signing, Firebase
deploy, and Firebase App Distribution (CLI + fastlane).

Quick reference:

```bash
sh ./scripts/bootstrap.sh                 # one-time: platforms + Firebase wiring
sh ./scripts/deploy-backend.sh            # functions, rules, indexes
sh ./scripts/distribute.sh android qa-testers "notes"   # App Distribution (APK)
sh ./scripts/distribute.sh ios-fastlane qa-testers "notes"  # App Distribution (IPA)
```

- **Firebase**: `firebase deploy` (functions, rules, indexes)
- **Android/iOS**: standard `flutter build apk --release` / `flutter build ipa`
- **Firebase App Distribution**: tester groups + `scripts/distribute.sh`

## Security

- Firestore rules: every user can only access `users/{uid}/**` (their own subtree). Server-only collections (`marketState`, `catalog` writes) are locked down.
- App Check (Play Integrity / App Attest) activated in `lib/main.dart`; enforce it in the Firebase console once your testers are enrolled.
- `firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist` are git-ignored; they are project config, and secrets stay in Functions secrets.
