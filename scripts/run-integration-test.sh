#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_bundle="$project_dir/dist/WakeBar.app"
executable="$app_bundle/Contents/MacOS/WakeBar"
log_file=$(mktemp /tmp/wakebar-integration.XXXXXX.log)
app_pid=""
caffeinate_pid=""

cleanup() {
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
    fi
    if [[ -n "$caffeinate_pid" ]] && kill -0 "$caffeinate_pid" 2>/dev/null; then
        kill "$caffeinate_pid" 2>/dev/null || true
    fi
    rm -f "$log_file"
}
trap cleanup EXIT

"$project_dir/scripts/build-app.sh" >/dev/null

"$executable" \
    --start-for 4 \
    --keep-display-awake \
    --quit-after-session \
    >"$log_file" 2>&1 &
app_pid=$!

for _ in {1..50}; do
    caffeinate_pid=$(pgrep -P "$app_pid" -x caffeinate 2>/dev/null || true)
    [[ -n "$caffeinate_pid" ]] && break
    sleep 0.1
done

if [[ -z "$caffeinate_pid" ]]; then
    print -u2 "WakeBar did not start caffeinate"
    sed -n '1,120p' "$log_file" >&2
    exit 1
fi

command_line=$(ps -p "$caffeinate_pid" -o command=)
[[ "$command_line" == *"-i"* ]]
[[ "$command_line" == *"-d"* ]]
[[ "$command_line" == *"-w $app_pid"* ]]

assertions=$(pmset -g assertions)
if ! print "$assertions" | rg -q "pid $caffeinate_pid\(caffeinate\).*PreventUserIdleSystemSleep"; then
    print -u2 "Expected system-sleep assertion was not present"
    print -u2 "$assertions"
    exit 1
fi

if ! print "$assertions" | rg -q "pid $caffeinate_pid\(caffeinate\).*PreventUserIdleDisplaySleep"; then
    print -u2 "Expected display-sleep assertion was not present"
    print -u2 "$assertions"
    exit 1
fi

for _ in {1..80}; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        break
    fi
    sleep 0.1
done

if kill -0 "$app_pid" 2>/dev/null; then
    print -u2 "WakeBar did not exit after the timed session"
    exit 1
fi

wait "$app_pid"
app_pid=""

if kill -0 "$caffeinate_pid" 2>/dev/null; then
    print -u2 "caffeinate was left running after WakeBar exited"
    exit 1
fi

print "Integration test passed: app launch, both power assertions, timer expiry, and cleanup."
caffeinate_pid=""
