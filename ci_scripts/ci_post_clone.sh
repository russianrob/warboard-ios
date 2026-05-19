#!/bin/sh
# Xcode Cloud hook — runs after the repo is cloned but BEFORE the
# build phase. Our repo only ships project.yml (the xcodegen spec) so
# we need to generate Warboard.xcodeproj here, otherwise Xcode Cloud
# fails immediately with "no Xcode project found".
#
# Apple's runners pre-install Homebrew; xcodegen install is fast (~5s).

set -e

echo "=== ci_post_clone: installing xcodegen ==="
if ! command -v xcodegen >/dev/null 2>&1; then
    brew install xcodegen
fi
xcodegen --version

echo "=== ci_post_clone: generating Warboard.xcodeproj ==="
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate --spec project.yml

# Xcode Cloud runs with "automatic dependency resolution disabled" and
# expects a Package.resolved to already exist in the workspace. Since
# we don't commit generated files (Warboard.xcodeproj isn't in the
# repo), there's nothing to find. Pre-resolve here so Package.resolved
# gets written before the archive action runs.
echo "=== ci_post_clone: resolving Swift Package dependencies ==="
xcodebuild -resolvePackageDependencies \
    -project Warboard.xcodeproj \
    -scheme Warboard

echo "=== ci_post_clone: done ==="
ls -la Warboard.xcodeproj 2>/dev/null || echo "warning: project not generated"
ls -la Warboard.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved 2>/dev/null \
    && echo "Package.resolved ready" \
    || echo "warning: Package.resolved missing"
