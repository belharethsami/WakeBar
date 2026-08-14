#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${CONFIGURATION:-release}"
dist_dir="$project_dir/dist"
app_bundle="$dist_dir/WakeBar.app"
contents_dir="$app_bundle/Contents"
resources_dir="$contents_dir/Resources"
helpers_dir="$contents_dir/Helpers"
macos_dir="$contents_dir/MacOS"
arm_scratch="$project_dir/.build-arm64"
x86_scratch="$project_dir/.build-x86_64"
swiftpm_flags=()

if [[ "${WAKEBAR_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
    swiftpm_flags+=(--disable-sandbox)
fi

swift build \
    "${swiftpm_flags[@]}" \
    --package-path "$project_dir" \
    --scratch-path "$arm_scratch" \
    -c "$configuration" \
    --product WakeBar \
    --triple arm64-apple-macosx13.0
swift build \
    "${swiftpm_flags[@]}" \
    --package-path "$project_dir" \
    --scratch-path "$arm_scratch" \
    -c "$configuration" \
    --product WakeBarGuard \
    --triple arm64-apple-macosx13.0
arm_bin_dir=$(swift build \
    "${swiftpm_flags[@]}" \
    --package-path "$project_dir" \
    --scratch-path "$arm_scratch" \
    -c "$configuration" \
    --product WakeBar \
    --triple arm64-apple-macosx13.0 \
    --show-bin-path)

swift build \
    "${swiftpm_flags[@]}" \
    --package-path "$project_dir" \
    --scratch-path "$x86_scratch" \
    -c "$configuration" \
    --product WakeBar \
    --triple x86_64-apple-macosx13.0
swift build \
    "${swiftpm_flags[@]}" \
    --package-path "$project_dir" \
    --scratch-path "$x86_scratch" \
    -c "$configuration" \
    --product WakeBarGuard \
    --triple x86_64-apple-macosx13.0
x86_bin_dir=$(swift build \
    "${swiftpm_flags[@]}" \
    --package-path "$project_dir" \
    --scratch-path "$x86_scratch" \
    -c "$configuration" \
    --product WakeBar \
    --triple x86_64-apple-macosx13.0 \
    --show-bin-path)

if [[ "$app_bundle" != "$project_dir/dist/WakeBar.app" ]]; then
    print -u2 "Refusing to replace an unexpected app path: $app_bundle"
    exit 1
fi

rm -rf "$app_bundle"
mkdir -p "$macos_dir" "$resources_dir" "$helpers_dir"

lipo -create \
    "$arm_bin_dir/WakeBar" \
    "$x86_bin_dir/WakeBar" \
    -output "$macos_dir/WakeBar"
lipo -create \
    "$arm_bin_dir/WakeBarGuard" \
    "$x86_bin_dir/WakeBarGuard" \
    -output "$helpers_dir/WakeBarGuard"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Resources/WakeBar.icns" "$resources_dir/WakeBar.icns"
codesign --force --sign - "$helpers_dir/WakeBarGuard"
codesign --force --deep --sign - "$app_bundle"

print "$app_bundle"
