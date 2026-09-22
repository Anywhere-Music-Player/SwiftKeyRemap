# SwiftKeyRemap

[GitHub repository](https://github.com/Anywhere-Music-Player/SwiftKeyRemap)

A lightweight menu bar app for remapping keys and keyboard shortcuts on macOS.
Assign different actions to the left and right Command keys, replace shortcuts,
disable individual keys, and turn remapping off in selected apps.

SwiftKeyRemap is based on [cmd-eikana](https://github.com/iMasanari/cmd-eikana)
(originally named ⌘英かな), with Apple Silicon support from
[dominion525's fork](https://github.com/dominion525/cmd-eikana).

## Requirements

- Apple Silicon Mac
- macOS 14 or later with the current Xcode 27 recommended deployment target
- Xcode 27 for local development

The project uses `$(RECOMMENDED_MACOSX_DEPLOYMENT_TARGET)` for the app and tests.
Xcode 27 currently resolves this to macOS 14.0; a future Xcode version may change it.

## Getting started

1. Build the app and move **SwiftKeyRemap.app** to **Applications**.
2. Open the app and allow **Accessibility** and **Input Monitoring** in
   **System Settings → Privacy & Security** when prompted.
3. Click the **⌘** menu bar icon and choose **Settings…**.

The default mappings retain the original app's behavior: tapping left Command
sends **Eisu** (the Japanese keyboard's alphanumeric key), and tapping right Command
sends **Kana** (the Japanese input key). These are key events, not arbitrary
English/Japanese input-source selectors. Change the mappings to suit your keyboard.

## Settings

- **Key Mappings:** Click **+** to add a mapping. Click an Input or Output field and
  press a shortcut, or select a preset from its menu. Uncheck a row to pause it.
  Use the **Actions** menu to reorder or remove mappings. **Disable** blocks an
  input key. Input-source presets use the shortcuts configured in macOS.
- **Excluded Apps:** Check apps where remapping should be disabled. The list
  includes recently active apps; switch to an app to make it appear.
- **General:** Show or hide the menu bar icon, manage launch at login, and check
  GitHub releases. Reopen the app from Applications if its menu bar icon is hidden.

The interface is built with SwiftUI, including the menu bar menu and settings.
Settings use a compact 640 × 440 window with a fixed size. Key mappings and app lists scroll
when they contain more rows than the window can display.

## Launch at login

SwiftKeyRemap registers the main app using `SMAppService.mainApp`. No separate startup
helper is bundled. Enable **Launch at login** in General settings when you want
it. The checkbox reflects the current system status rather than a saved preference.
If macOS requires approval, enable SwiftKeyRemap under
**System Settings → General → Login Items**. There is no legacy migration code.

The existing bundle identifier (`io.github.dominion525.cmd-eikana`) is retained so
saved mappings and excluded apps remain available after renaming the app. Quit the
previous app before running SwiftKeyRemap; do not run both copies simultaneously.

The source lives in `SwiftKeyRemap/`; the test target and folder are `SwiftKeyRemapTests`.
A small AppKit bridge records hardware shortcuts and manages the menu bar app's
window lifecycle. There are no storyboards or AppKit table controllers.

## Building

```sh
xcodebuild -project SwiftKeyRemap.xcodeproj -scheme SwiftKeyRemap \
  -configuration Release -arch arm64 build
```

To build and sign a copy in `build/SwiftKeyRemap.app`, run `./build.sh`.
The script uses `CODESIGN_IDENTITY`, an available Developer ID Application
certificate, or an ad hoc signature. A different signature can require granting
Accessibility and Input Monitoring permissions again.

Run the test suite with:

```sh
xcodebuild test -project SwiftKeyRemap.xcodeproj -scheme SwiftKeyRemap \
  -destination 'platform=macOS'
```

## Updates

In-app installation is disabled for this fork until it has its own signed Sparkle
feed. **View Releases…** opens this repository's GitHub releases. This prevents an
upstream update from replacing SwiftKeyRemap with the original app. To enable automatic
updates, configure your own `SUFeedURL` and `SUPublicEDKey`, then set
`SwiftKeyRemapUpdatesConfigured` to `YES` and update the release publishing workflow.
The inherited upstream feed is not started by this build.

## Removing the app

Turn off **Launch at login**, quit SwiftKeyRemap, and move the app to the Trash.
Preferences remain at
`~/Library/Preferences/io.github.dominion525.cmd-eikana.plist`.

## License and credits

MIT License. Copyright © 2016 iMasanari.
Original author: [iMasanari](https://github.com/iMasanari).
Apple Silicon fork: [dominion525](https://github.com/dominion525).
