# WakeBar

[![macOS](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)](https://github.com/belharethsami/WakeBar/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build](https://github.com/belharethsami/WakeBar/actions/workflows/ci.yml/badge.svg)](https://github.com/belharethsami/WakeBar/actions/workflows/ci.yml)

WakeBar is a small, native, open-source macOS menu-bar app that keeps your Mac
awake by wrapping Apple's built-in `/usr/bin/caffeinate` command.

It is intentionally modest: no account, no network connection, no analytics,
no privileged helper, and no third-party dependencies.

## Features

- One-click sessions for 15 minutes, 30 minutes, 1 hour, 2 hours, or indefinitely
- Keep awake until a chosen time (today, or tomorrow if that time has passed)
- Optional display-sleep prevention
- Live remaining-time display
- Launch at Login using Apple's `SMAppService`
- Automatic assertion cleanup when the app quits or a session ends
- Scriptable launch flags for automation and integration testing

WakeBar targets macOS 13 Ventura and newer. It prevents idle sleep; it does not
override a MacBook's lid-closed sleep behavior.

## Install

Download the latest DMG from [GitHub Releases](https://github.com/belharethsami/WakeBar/releases/latest),
open it, and drag WakeBar into Applications.

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

WakeBar is not affiliated with Amphetamine or its developer.

## License

MIT
