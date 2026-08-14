#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
output_path="${1:-$project_dir/dist/WakeBar-menu-preview.png}"
renderer=$(mktemp /tmp/wakebar-renderer.XXXXXX)
rm -f "$renderer"
trap 'rm -f "$renderer"' EXIT

xcrun swiftc \
    -parse-as-library \
    "$project_dir/Sources/WakeBarCore/CaffeinateCommand.swift" \
    "$project_dir/Sources/WakeBarCore/SessionSchedule.swift" \
    "$project_dir/Sources/WakeBarCore/StartupOptions.swift" \
    "$project_dir/Sources/WakeBar/SessionController.swift" \
    "$project_dir/Sources/WakeBar/LaunchAtLoginController.swift" \
    "$project_dir/Sources/WakeBar/WakeBarMenu.swift" \
    "$project_dir/scripts/render-menu.swift" \
    -o "$renderer"

mkdir -p "${output_path:h}"
"$renderer" "$output_path"
print "$output_path"
