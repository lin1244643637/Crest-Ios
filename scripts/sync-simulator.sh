#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${TMPDIR%/}/CrestSignedDerivedData}"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
CONFIGURATION="${CONFIGURATION:-Debug}"
EXPECTED_APPLICATION_IDENTIFIER="RZA2NW5788.com.blackwave.crest"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphonesimulator/Crest.app"
ENTITLEMENTS_PATH="$DERIVED_DATA_PATH/Build/Intermediates.noindex/Crest.build/${CONFIGURATION}-iphonesimulator/Crest.build/Crest.app-Simulated.xcent"

xcodebuild \
  -project "$PROJECT_ROOT/Crest.xcodeproj" \
  -scheme Crest \
  -configuration "$CONFIGURATION" \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGNING_REQUIRED=YES \
  build

application_identifier="$(/usr/libexec/PlistBuddy -c 'Print :application-identifier' "$ENTITLEMENTS_PATH" 2>/dev/null || true)"
if [[ "$application_identifier" != "$EXPECTED_APPLICATION_IDENTIFIER" ]]; then
  print -u2 "拒绝安装：application-identifier 无效（${application_identifier:-缺失}）"
  exit 1
fi

xcrun simctl install booted "$APP_PATH"
xcrun simctl launch --terminate-running-process booted com.blackwave.crest

print "模拟器同步完成：$application_identifier"
