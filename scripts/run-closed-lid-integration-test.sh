#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
app_bundle="$project_dir/dist/WakeBar.app"
executable="$app_bundle/Contents/MacOS/WakeBar"
support_dir="$HOME/Library/Application Support/WakeBar"
marker="$support_dir/closed-lid-owned"
heartbeat="$support_dir/closed-lid-heartbeat"
installed_guard="$support_dir/WakeBarGuard"
sudoers_file="/private/etc/sudoers.d/wakebar_closed_lid"
log_file=$(mktemp /tmp/wakebar-closed-lid.XXXXXX.log)
app_pid=""
caffeinate_pid=""

sleep_is_disabled() {
    /usr/sbin/ioreg -r -c IOPMrootDomain -d 1 | \
        /usr/bin/grep -q '"SleepDisabled" = Yes'
}

force_normal_sleep() {
    /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 >/dev/null 2>&1 || true
}

cleanup() {
    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
        kill "$app_pid" 2>/dev/null || true
    fi
    if [[ -n "$caffeinate_pid" ]] && kill -0 "$caffeinate_pid" 2>/dev/null; then
        kill "$caffeinate_pid" 2>/dev/null || true
    fi
    force_normal_sleep
    rm -f "$marker" "$heartbeat" "$log_file"
}
trap cleanup EXIT

if [[ ! -e "$sudoers_file" ]]; then
    print -u2 "Closed-Lid Support is not installed. Install it from WakeBar first."
    exit 2
fi

if sleep_is_disabled; then
    print -u2 "Refusing to test while SleepDisabled is already enabled by another owner."
    exit 2
fi

"$project_dir/scripts/build-app.sh" >/dev/null

"$executable" --start-for 6 --closed-lid --quit-after-session >"$log_file" 2>&1 &
app_pid=$!

for _ in {1..80}; do
    caffeinate_pid=$(pgrep -P "$app_pid" -x caffeinate 2>/dev/null || true)
    if sleep_is_disabled && [[ -n "$caffeinate_pid" ]]; then
        break
    fi
    sleep 0.1
done

if ! sleep_is_disabled; then
    print -u2 "WakeBar did not enable the kernel SleepDisabled state."
    sed -n '1,160p' "$log_file" >&2
    exit 1
fi
[[ -n "$caffeinate_pid" ]]
command_line=$(ps -p "$caffeinate_pid" -o command=)
[[ "$command_line" == *"-i"* ]]
if [[ "$command_line" == *"-d"* ]]; then
    print -u2 "Closed-lid session unexpectedly requested a display-sleep assertion."
    exit 1
fi
assertions=$(pmset -g assertions)
if print "$assertions" | rg -q "pid $caffeinate_pid\(caffeinate\).*PreventUserIdleDisplaySleep"; then
    print -u2 "Closed-lid session unexpectedly prevented display sleep."
    print -u2 "$assertions"
    exit 1
fi
[[ -f "$marker" ]]
[[ -f "$heartbeat" ]]
[[ -x "$installed_guard" ]]
/bin/launchctl print "gui/$(id -u)/app.wakebar.closed-lid-guard" >/dev/null

for _ in {1..100}; do
    if ! kill -0 "$app_pid" 2>/dev/null; then
        break
    fi
    sleep 0.1
done

if kill -0 "$app_pid" 2>/dev/null; then
    print -u2 "WakeBar did not exit after the closed-lid timed session."
    exit 1
fi
wait "$app_pid"
app_pid=""
caffeinate_pid=""

if sleep_is_disabled; then
    print -u2 "WakeBar left SleepDisabled enabled after normal session cleanup."
    exit 1
fi
[[ ! -e "$marker" ]]
[[ ! -e "$heartbeat" ]]

"$executable" --start-for 300 --closed-lid >"$log_file" 2>&1 &
app_pid=$!

for _ in {1..80}; do
    caffeinate_pid=$(pgrep -P "$app_pid" -x caffeinate 2>/dev/null || true)
    if sleep_is_disabled && [[ -n "$caffeinate_pid" ]]; then
        break
    fi
    sleep 0.1
done

if ! sleep_is_disabled; then
    print -u2 "WakeBar did not enable SleepDisabled for the crash-recovery test."
    exit 1
fi

kill -9 "$app_pid"
wait "$app_pid" 2>/dev/null || true
app_pid=""
caffeinate_pid=""

touch -t 200001010000 "$heartbeat"
"$installed_guard"

if sleep_is_disabled; then
    print -u2 "WakeBarGuard did not restore normal sleep after a simulated crash."
    exit 1
fi
[[ ! -e "$marker" ]]
[[ ! -e "$heartbeat" ]]

print "Closed-lid integration test passed: display sleep allowed, enable verification, timed cleanup, and watchdog crash recovery."
