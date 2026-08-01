# Stash

Swipe **three fingers down** on the trackpad and the window under your cursor drops into the
Dock. That's the whole app.

It lives in the menu bar, has no Dock icon, and works the same whether or not you use Stage
Manager — minimised windows land in the Dock either way.

## Install

Download the `.dmg` from the [latest release](../../releases/latest), open it, and drag
**Stash** onto **Applications**. That's it.

macOS will ask for **Accessibility** permission on first launch (System Settings › Privacy &
Security › Accessibility). Stash needs it twice over: to read trackpad gestures, and to act on
other apps' windows. Nothing works without it.

## Settings

Click the menu bar icon › *Réglages…*

- **Amplitude** — how far you have to swipe before the window drops. A live indicator shows the
  number of fingers detected and the progress of the current gesture, so you can calibrate it.
- **Background windows** — when off, only the active app's windows respond.
- **Launch at login**.
- **Updates** — Stash checks GitHub releases once a day and can install a new version itself.


## How it works

- A session-wide `CGEventTap` listens to gesture events and reads the raw `NSTouch` data, so
  Stash tracks the three fingers itself instead of relying on macOS's preset gestures.
- The Accessibility API finds the window: `AXUIElementCopyElementAtPosition` under the cursor,
  walk up to the `AXWindow`, then set `AXMinimized`.

Written in Swift and SwiftUI, no third-party dependencies. Source comments and the settings UI
are in French.

## Notes

- The build is **ad-hoc signed**. Each rebuild changes its signature, so macOS will ask you to
  re-approve it under Accessibility.
- The built-in updater downloads the release archive and removes its quarantine flag before
  swapping the bundle — otherwise Gatekeeper would refuse to launch an ad-hoc signed app that
  came from the internet. This is the same thing Sparkle and other updaters do. If you'd rather
  not, turn off automatic updates and install releases by hand.
