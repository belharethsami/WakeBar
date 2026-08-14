# WakeBar

[![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://github.com/belharethsami/WakeBar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build](https://github.com/belharethsami/WakeBar/actions/workflows/ci.yml/badge.svg)](https://github.com/belharethsami/WakeBar/actions/workflows/ci.yml)

WakeBar is a small, native, open-source macOS menu-bar app that keeps your Mac
awake by wrapping Apple's built-in `/usr/bin/caffeinate` command.

It is intentionally modest: no account, no network connection, no analytics,
and no third-party dependencies. Ordinary sessions need no elevated access;
Closed-Lid Mode is optional and separately authorized.

## Features

- One-click sessions for 15 or 30 minutes; 1, 2, 3, 4, 6, or 10 hours; or indefinitely
- Keep awake until a chosen time (today, or tomorrow if that time has passed)
- Optional display-sleep prevention
- Optional closed-lid sessions, including on battery without an external display
- Live remaining-time display
- Launch at Login using Apple's `SMAppService`
- Automatic assertion cleanup when the app quits or a session ends
- Scriptable launch flags for automation and integration testing

WakeBar targets macOS 13 Ventura and newer. Standard sessions prevent idle
sleep. Closed-Lid Mode additionally applies macOS's system-wide sleep override
for the duration of a session.

## Closed-Lid Mode

Closed-Lid Mode is deliberately separate from ordinary keep-awake sessions.
Click **Install Closed-Lid Support…** once and authenticate with an administrator
account. WakeBar installs a narrowly scoped sudoers rule allowing the current
account to run only these two commands without another prompt:

```text
/usr/bin/pmset -a disablesleep 1
/usr/bin/pmset -a disablesleep 0
```

WakeBar verifies the kernel's `SleepDisabled` state after every change. While
active, a user-level watchdog checks a 15-second heartbeat and restores normal
sleep if WakeBar stops responding for 90 seconds. Normal sleep is also restored
when the session ends, WakeBar quits, Low Power Mode is enabled, or battery
charge reaches 20 percent while unplugged.

This mode is system-wide and requires administrator approval to install. A
managed Mac may require IT to approve or deploy the rule. Never put a closed,
awake Mac in a bag; sustained workloads need adequate ventilation.

## Install

See [INSTALL.md](INSTALL.md) for step-by-step instructions using either the
latest DMG or a local source build. In short: open the DMG, drag WakeBar into
Applications, then launch it from Applications.

Release builds must be signed and notarized before general distribution. Until
the first notarized release is available, build WakeBar from source or ask your
IT administrator to inspect, approve, and deploy it.

## Build

The only requirement is Apple's Swift toolchain, available through Xcode or the
Command Line Tools. The test harness deliberately uses no test-framework package,
so it also runs on minimal Command Line Tools installations.

```sh
make test
make app
```

The app bundle is written to `dist/WakeBar.app`. The packaging script builds a
Universal 2 binary for Apple silicon and Intel Macs. To create a drag-to-Applications
disk image:

```sh
make dmg
```

To exercise the complete process lifecycle against macOS power assertions:

```sh
make integration-test
```

After installing Closed-Lid Support, exercise the real `SleepDisabled`
lifecycle, timed cleanup, and simulated-crash watchdog recovery with:

```sh
make closed-lid-integration-test
```

An offscreen UI snapshot can be rendered without Screen Recording permission:

```sh
make preview
```

## Command-line launch

The packaged executable accepts a few optional flags:

```sh
WakeBar --start
WakeBar --start-for 3600
WakeBar --start-for 300 --keep-display-awake
WakeBar --start-for 300 --closed-lid
WakeBar --start-for 5 --quit-after-session
```

`--quit-after-session` is useful for automation and the integration test.

## Distribution and managed Macs

The local build script applies an ad-hoc signature so the bundle is internally
consistent. A public release should instead be signed with an Apple Developer ID
certificate and notarized. Managed Macs may require IT to sign, notarize, approve,
or deploy the app. Do not disable Gatekeeper, SIP, or device-management controls.

## How it works

WakeBar launches the fixed executable `/usr/bin/caffeinate` directly—never through
a shell—with idle-sleep (`-i`) and optional display-sleep (`-d`) assertions. Each
child process watches WakeBar's process ID (`-w`), so macOS releases the assertion
if WakeBar exits unexpectedly. Timed sessions also provide caffeinate with a
defensive timeout and terminate the process when the UI timer expires.

Closed-Lid Mode runs `/usr/bin/pmset` through non-interactive `sudo` with fixed
arguments. User-configurable text is never evaluated as a command. The one-time
installer encodes and validates the exact rule with `visudo` before atomically
placing it in `/private/etc/sudoers.d/wakebar_closed_lid`.

WakeBar is not affiliated with Amphetamine or its developer.

## License

MIT
