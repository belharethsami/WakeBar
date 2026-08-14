#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
configuration="${CONFIGURATION:-release}"
dist_dir="$project_dir/dist"
app_bundle="$dist_dir/WakeBar.app"
contents_dir="$app_bundle/Contents"
resources_dir="$contents_dir/Resources"
macos_dir="$contents_dir/MacOS"
arm_scratch="$project_dir/.build-arm64"
x86_scratch="$project_dir/.build-x86_64"

swift build \
    --package-path "$project_dir" \
    --scratch-path "$arm_scratch" \
    -c "$configuration" \
    --product WakeBar \
    --triple arm64-apple-macosx13.0
arm_bin_dir=$(swift build \
    --package-path "$project_dir" \
    --scratch-path "$arm_scratch" \
    -c "$configuration" \
    --product WakeBar \
    --triple arm64-apple-macosx13.0 \
    --show-bin-path)

swift build \
    --package-path "$project_dir" \
    --scratch-path "$x86_scratch" \
    -c "$configuration" \
    --product WakeBar \
    --triple x86_64-apple-macosx13.0
x86_bin_dir=$(swift build \
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
mkdir -p "$macos_dir" "$resources_dir"

lipo -create \
    "$arm_bin_dir/WakeBar" \
    "$x86_bin_dir/WakeBar" \
    -output "$macos_dir/WakeBar"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"

icon_work=$(mktemp -d /tmp/wakebar-icon.XXXXXX)
trap 'rm -rf "$icon_work"' EXIT

xcrun swift "$project_dir/scripts/generate-icon.swift" "$icon_work/icon_1024x1024.png"
mkdir -p "$icon_work/WakeBar.iconset"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$icon_work/icon_1024x1024.png" \
        --out "$icon_work/WakeBar.iconset/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$icon_work/icon_1024x1024.png" \
        --out "$icon_work/WakeBar.iconset/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$icon_work/WakeBar.iconset" -o "$resources_dir/WakeBar.icns"
codesign --force --deep --sign - "$app_bundle"

print "$app_bundle"
