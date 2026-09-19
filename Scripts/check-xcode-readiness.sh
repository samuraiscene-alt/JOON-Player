#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

EXPECTED_SWIFT_COUNT=23
MANIFEST="Docs/Xcode-Source-Manifest.txt"
PODFILE="Podfile"
PROJECT="JOONPlayer.xcodeproj"
WORKSPACE="JOONPlayer.xcworkspace"
SCHEME="JOONPlayer"

FAILURES=0
WARNINGS=0

pass() { printf "✅ %s\n" "$1"; }
warn() { printf "⚠️  %s\n" "$1"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf "❌ %s\n" "$1"; FAILURES=$((FAILURES + 1)); }
section() { printf "\n— %s —\n" "$1"; }

section "Environment"

if [[ "$(uname -s)" == "Darwin" ]]; then
  pass "macOS detected"
else
  fail "This script must be run on macOS for Xcode checks."
fi

if command -v xcode-select >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
  pass "Xcode command line tools path: $(xcode-select -p)"
else
  fail "Xcode command line tools are not selected."
fi

if command -v xcodebuild >/dev/null 2>&1; then
  XCODE_VERSION="$(xcodebuild -version 2>/dev/null | tr '\n' ' ')"
  pass "xcodebuild available: ${XCODE_VERSION}"
else
  fail "xcodebuild is not available."
fi

if command -v pod >/dev/null 2>&1; then
  pass "CocoaPods available: $(pod --version)"
else
  warn "CocoaPods is not installed yet. VLCKit cannot be installed until 'pod' is available."
fi

section "Repository structure"

if [[ -f "$MANIFEST" ]]; then
  pass "Source manifest found"
else
  fail "Missing $MANIFEST"
fi

ACTUAL_SWIFT_COUNT="$(find JOONPlayer -type f -name '*.swift' | wc -l | tr -d ' ')"

if [[ "$ACTUAL_SWIFT_COUNT" == "$EXPECTED_SWIFT_COUNT" ]]; then
  pass "Swift source count is ${EXPECTED_SWIFT_COUNT}"
else
  fail "Swift source count is ${ACTUAL_SWIFT_COUNT}; expected ${EXPECTED_SWIFT_COUNT}. Update the manifest before building."
fi

if [[ -f "$MANIFEST" ]]; then
  MISSING=0
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    [[ "$path" == \#* ]] && continue
    if [[ ! -f "$path" ]]; then
      printf "   missing: %s\n" "$path"
      MISSING=$((MISSING + 1))
    fi
  done < "$MANIFEST"
  if [[ "$MISSING" -eq 0 ]]; then
    pass "Every manifest source file exists"
  else
    fail "${MISSING} source file(s) from the manifest are missing"
  fi
fi

if [[ -f "$PODFILE" ]]; then
  pass "Podfile found"
  if grep -q "target 'JOONPlayer' do" "$PODFILE"; then
    pass "Podfile target is JOONPlayer"
  else
    fail "Podfile target does not match JOONPlayer"
  fi
  if grep -q "pod 'VLCKit', '4.0.0a24'" "$PODFILE"; then
    pass "VLCKit pin is 4.0.0a24"
  else
    fail "Expected VLCKit 4.0.0a24 pin was not found"
  fi
else
  fail "Podfile is missing"
fi

section "Xcode project state"

if [[ -d "$PROJECT" ]]; then
  pass "$PROJECT exists"
else
  warn "$PROJECT does not exist yet. Create the Xcode iOS App project using Docs/Xcode-Project-Setup.md."
fi

if [[ -d "$WORKSPACE" ]]; then
  pass "$WORKSPACE exists"
else
  if [[ -d "$PROJECT" ]]; then
    warn "$WORKSPACE does not exist yet. Run 'pod install' after the project is created."
  else
    warn "Workspace check skipped until the Xcode project exists."
  fi
fi

section "Optional build"

if [[ "${1:-}" == "--build" ]]; then
  if [[ ! -d "$WORKSPACE" ]]; then
    fail "Cannot build: $WORKSPACE is missing."
  elif ! command -v xcodebuild >/dev/null 2>&1; then
    fail "Cannot build: xcodebuild is unavailable."
  else
    printf "Running first simulator compile...\n"
    if xcodebuild \
      -workspace "$WORKSPACE" \
      -scheme "$SCHEME" \
      -configuration Debug \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      CODE_SIGNING_ALLOWED=NO \
      build; then
      pass "Simulator compile completed"
    else
      fail "Simulator compile failed. Keep the first compiler errors and fix them in order."
    fi
  fi
else
  printf "Run './Scripts/check-xcode-readiness.sh --build' after the workspace exists to attempt the first simulator compile.\n"
fi

section "Result"

if [[ "$FAILURES" -gt 0 ]]; then
  printf "❌ Readiness check finished with %s failure(s) and %s warning(s).\n" "$FAILURES" "$WARNINGS"
  exit 1
fi

if [[ "$WARNINGS" -gt 0 ]]; then
  printf "⚠️  Base repository checks passed with %s warning(s).\n" "$WARNINGS"
  exit 0
fi

printf "✅ JOON Player is ready for the next Xcode step.\n"
