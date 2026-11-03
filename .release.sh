# shellcheck shell=bash
# Release hooks for `ggrel` (see `ggrel --help`).
#
# ggrel sources this file from the repository root, in its own shell, before
# parsing arguments (even for --help). Keep it free of side effects and avoid
# defining variables other than the supported hooks below.
#
# ggrel substitutes the literal text `${version}` in TEST_CMD, BUILD_CMD and
# RELEASE_ASSETS with the target version, so those stay single-quoted.

# Single source of truth for the app name is scripts/config.sh.
APP_NAME="$(bash -c 'source ./scripts/config.sh && printf "%s" "$APP_NAME"')"

TEST_CMD='./scripts/test.sh'

# Runs after ggrel has written and committed VERSION. build_dmg.sh rebuilds the
# app (incrementing BUILD_NUMBER), so verify the bundle reports the target
# version and commit BUILD_NUMBER so the tag matches what was shipped.
BUILD_CMD='set -euo pipefail
./scripts/build_dmg.sh
app_name="$(bash -c "source ./scripts/config.sh && printf %s \"\$APP_NAME\"")"
built="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "build/${app_name}.app/Contents/Info.plist")"
[[ "$built" == "${version}" ]] || { echo "Built app reports version $built, expected ${version}." >&2; exit 1; }
git add -- BUILD_NUMBER
git diff --cached --quiet -- BUILD_NUMBER || git commit -m "chore(release): build $(cat BUILD_NUMBER) for v${version}"'

RELEASE_ASSETS=("build/${APP_NAME}-"'${version}.dmg')
