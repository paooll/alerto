#!/usr/bin/env sh
# Alerto one-time bootstrap: generates the android/ and ios/ platform folders
# (not committed — `flutter create` must run on a machine with Flutter installed)
# and wires up Firebase configuration.
#
# Usage: sh ./scripts/bootstrap.sh
set -e

FLAVOR="${1:-default}"

echo "==> Checking Flutter"
command -v flutter >/dev/null || { echo "Flutter SDK not found. Install: https://docs.flutter.dev/get-started/install"; exit 1; }
flutter doctor

echo "==> Generating platform folders"
flutter create --platforms=android,ios --org com.alerto --project-name alerto .

echo "==> Fetching dependencies"
flutter pub get

echo "==> Configuring Firebase (interactive: select your project + platforms)"
command -v flutterfire >/dev/null || dart pub global activate flutterfire_cli
flutterfire configure \
  --project="${FIREBASE_PROJECT_ID:?Set FIREBASE_PROJECT_ID}" \
  --platforms=android,ios,web \
  --ios-bundle-id com.alerto.alerto \
  --android-package-name com.alerto.alerto

echo "==> Android: notification channel + permissions"
# Main application tweaks (FCM default channel, icon label) are documented in
# README.md. google-services.json is dropped by flutterfire configure.

echo "==> Backend"
(cd functions && npm install)
firebase functions:secrets:set TWELVEDATA_API_KEY

echo "==> Deploying rules, indexes, functions"
firebase deploy --only firestore:rules,firestore:indexes,functions

echo "✅ Bootstrap complete. Run: flutter run"
