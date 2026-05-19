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

echo "=== ci_post_clone: done ==="
ls -la Warboard.xcodeproj 2>/dev/null || echo "warning: project not generated"
