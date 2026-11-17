# Changelog

All notable changes to WakeBar will be documented here.

## 0.2.3 — 2026-11-16

- Allow closed-lid sessions above 5 percent battery, including in Low Power Mode.
- Keep automatic session shutdown at or below 5 percent while unplugged.
- Share the battery cutoff between session startup and monitoring, with boundary coverage.
- Honor `--quit-after-session` when caffeinate's timeout finishes before the app timer.

## 0.2.2 — 2026-08-17

- Added clamshell-state monitoring during closed-lid sessions.
- Explicitly turns the display off when the lid closes unless display-sleep
  prevention is enabled.
- Added a **Turn Display Off Now** control during display-allowed sessions.
- Added repeat-close transition and fixed-command coverage.

## 0.2.1 — 2026-08-17

- Added a 12-hour one-click session preset.
- Fixed active display-sleep changes so the previous `caffeinate -d` assertion
  is fully released without cycling Closed-Lid Mode.
- Clarified when the display follows the normal macOS sleep timer.
- Added closed-lid integration coverage that rejects display-sleep assertions.

## 0.2.0 — 2026-08-13

- Added an explicitly opt-in Closed-Lid Mode backed by `pmset disablesleep`.
- Added one-time, narrowly scoped administrator authorization.
- Added kernel-state verification after enable and disable operations.
- Added a user-level heartbeat watchdog for crash recovery.
- Added automatic shutdown at 20 percent battery and in Low Power Mode.
- Added closed-lid status, warnings, installation, and removal controls.
- Added 3-, 4-, 6-, and 10-hour one-click session presets.
- Added detailed release, source-build, update, and removal instructions.

## 0.1.0 — 2026-08-13

- Added timed sessions for 15 minutes, 30 minutes, 1 hour, and 2 hours.
- Added indefinite and until-a-selected-time sessions.
- Added optional display-sleep prevention.
- Added live remaining-time status and session controls.
- Added Launch at Login support using `SMAppService`.
- Added Universal 2 app and DMG build scripts.
- Added unit-style logic checks and a live macOS power-assertion integration test.
