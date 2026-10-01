#!/usr/bin/env sh
# Build a release and distribute it to Firebase App Distribution.
#
# Usage:
#   sh ./scripts/distribute.sh android "qa-testers" "New alert engine + UI"
#   sh ./scripts/distribute.sh ios "qa-testers" "New alert engine + UI"
#
# Prerequisites (one-time):
#   - Firebase project created; App Distribution enabled in the console
#   - Tester groups created (e.g. "qa-testers") in App Distribution
#   - Android: google-services.json in android/app/
#   - iOS: GoogleService-Info.plist in ios/Runner/, signed with a team
set -e

PLATFORM="$1"
GROUP="${2:-qa-testers}"
NOTES="${3:-Latest build}"

[ -d "$PLATFORM" ] || { echo "Run scripts/bootstrap.sh first (android/ios folders missing)"; exit 1; }
command -v firebase >/dev/null || { echo "Install Firebase CLI: npm i -g firebase-tools"; exit 1; }

case "$PLATFORM" in
  android)
    echo "==> Building release APK"
    flutter build apk --release
    echo "==> Distributing to group: $GROUP"
    firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
      --app "$ANDROID_APP_ID" --groups "$GROUP" --release-notes "$NOTES"
    echo "✅ Android build distributed."
    ;;
  ios)
    echo "==> Building iOS (IPA, no codesign — use fastlane or Xcode for signed builds)"
    flutter build ipa --release --no-codesign
    echo "==> Exporting unsigned IPA is not uploadable; use one of:"
    echo "   1) fastlane: sh ./scripts/distribute.sh ios-fastlane \"$GROUP\""
    echo "   2) Xcode: Product > Archive > Distribute via App Distribution"
    ;;
  ios-fastlane)
    echo "==> Building and uploading via fastlane"
    command -v fastlane >/dev/null || { echo "Install fastlane: brew install fastlane"; exit 1; }
    cd ios && fastlane distribute notes:"$NOTES" group:"$GROUP" && cd ..
    echo "✅ iOS build distributed."
    ;;
  *)
    echo "Usage: sh ./scripts/distribute.sh android|ios|ios-fastlane [group] [notes]"
    exit 1
    ;;
esac
