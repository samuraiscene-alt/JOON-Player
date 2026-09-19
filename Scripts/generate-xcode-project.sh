#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "❌ Xcode project generation must run on macOS."
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "❌ XcodeGen is not installed."
  echo "   Install it first with:"
  echo "   brew install xcodegen"
  exit 1
fi

if [[ ! -f "project.yml" ]]; then
  echo "❌ project.yml is missing."
  exit 1
fi

echo "Generating JOONPlayer.xcodeproj from project.yml..."
xcodegen generate --spec project.yml

if [[ ! -d "JOONPlayer.xcodeproj" ]]; then
  echo "❌ JOONPlayer.xcodeproj was not generated."
  exit 1
fi

echo "✅ JOONPlayer.xcodeproj generated."
echo
echo "Next:"
echo "1. Run: pod install"
echo "2. Open: JOONPlayer.xcworkspace"
echo "3. Run: ./Scripts/check-xcode-readiness.sh --build"
