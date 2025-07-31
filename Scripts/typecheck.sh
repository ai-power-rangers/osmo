#!/bin/bash

echo "🔍 Running Swift type check..."

# Type check all Swift files
find osmo -name "*.swift" -print0 | xargs -0 xcrun swiftc -typecheck \
  -sdk $(xcrun --show-sdk-path --sdk iphonesimulator) \
  -target arm64-apple-ios17.0-simulator \
  -I osmo \
  -module-name osmo \
  2>&1 | grep -E "error:|warning:" | head -20

if [ $? -eq 0 ]; then
  echo "✅ Type check passed!"
else
  echo "❌ Type check found issues"
fi