# Installing WakeBar

WakeBar supports macOS 13 Ventura and newer. Managed Macs may require your IT
administrator to approve or deploy the app. Do not disable Gatekeeper, System
Integrity Protection, or company management controls.

## Install from a DMG

1. Download the latest WakeBar DMG from
   [GitHub Releases](https://github.com/belharethsami/WakeBar/releases/latest).
2. Open the downloaded DMG.
3. Drag **WakeBar** onto the **Applications** shortcut in the DMG window.
4. Eject the WakeBar disk image.
5. Open **Applications** in Finder and launch **WakeBar**.
6. Look for the cup icon in the menu bar and choose a session duration.

If macOS or device management prevents the app from opening, stop there and ask
your IT administrator to inspect and approve the release. Public distribution
builds should be Developer ID signed and notarized.

## Build and install from source

Install Xcode or Apple's Command Line Tools, then run:

```sh
git clone https://github.com/belharethsami/WakeBar.git
cd WakeBar
make test
make app
open dist
```

Finder will open the `dist` folder. Drag `WakeBar.app` into Applications, then
launch it from there. The local build is ad-hoc signed for development; managed
Macs may still require IT approval.

To create the drag-to-Applications disk image locally, run `make dmg`. The
result is written to `dist/WakeBar-0.2.3.dmg`.

## Optional closed-lid support

Ordinary WakeBar sessions need no administrator access. If you specifically
need a session to continue after closing the laptop lid:

1. Open WakeBar from the menu bar.
2. Click **Install Closed-Lid Support…** and authenticate with an administrator
   account.
3. Enable **Keep running when the lid closes** before starting a session.

Closed-Lid Mode changes a system-wide sleep setting while active. WakeBar's
watchdog restores normal sleep if the app stops responding, and WakeBar stops
the mode at 5 percent battery while unplugged. Closed-Lid Mode works above
5 percent on battery, including with Low Power Mode enabled. Never put a
closed, awake Mac in a bag.

## Update or remove WakeBar

To update, quit WakeBar and replace the existing copy in Applications with the
new version.

Before deleting WakeBar, use **Remove Closed-Lid Support…** if it was installed,
turn off **Launch at Login**, and quit the app. Then move WakeBar from
Applications to the Trash.
