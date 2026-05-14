#!/bin/sh
set -e

# Xcode Cloud runs this after `git clone`. The repo intentionally ignores
# Grove.xcodeproj — XcodeGen regenerates it from project.yml on every build.

echo "==> Installing XcodeGen"
brew install xcodegen

echo "==> Generating Grove.xcodeproj from project.yml"
cd "$CI_PRIMARY_REPOSITORY_PATH"
xcodegen generate
