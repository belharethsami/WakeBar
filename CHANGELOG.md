# Changelog

All notable changes to WakeBar will be documented here.

## 0.2.0 — 2026-08-13

- Added an explicitly opt-in Closed-Lid Mode backed by `pmset disablesleep`.
- Added one-time, narrowly scoped administrator authorization.
- Added kernel-state verification after enable and disable operations.
- Added a user-level heartbeat watchdog for crash recovery.
- Added automatic shutdown at 20 percent battery and in Low Power Mode.
- Added closed-lid status, warnings, installation, and removal controls.

## 0.1.0 — 2026-08-13

- Added timed sessions for 15 minutes, 30 minutes, 1 hour, and 2 hours.
- Added indefinite and until-a-selected-time sessions.
- Added optional display-sleep prevention.
- Added live remaining-time status and session controls.
- Added Launch at Login support using `SMAppService`.
- Added Universal 2 app and DMG build scripts.
- Added unit-style logic checks and a live macOS power-assertion integration test.
