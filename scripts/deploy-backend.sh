#!/usr/bin/env sh
# Deploy the Alerto backend: functions, Firestore rules & indexes.
# Usage: sh ./scripts/deploy-backend.sh
set -e

command -v firebase >/dev/null || { echo "Install Firebase CLI: npm i -g firebase-tools"; exit 1; }

echo "==> Building functions"
(cd functions && npm install && npm run build)

echo "==> Deploying"
firebase deploy --only firestore:rules,firestore:indexes,functions

echo "✅ Backend deployed."
