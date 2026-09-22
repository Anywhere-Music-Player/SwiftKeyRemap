import AppKit
import SwiftUI

/// Small macOS lifecycle bridge. All app content and menus are SwiftUI.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  let keyEvent = KeyEvent()
  private(set) var settingsWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let store = SettingsStore.shared
    let isTesting = NSClassFromString("XCTestCase") != nil
    let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    guard !isTesting && !isPreview else { return }
    if store.updatesConfigured { store.updaterController.startUpdater() }
    keyEvent.start()
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    showSettings()
    return false
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

  func applicationDidResignActive(_ notification: Notification) { activeKeyTextField?.blur() }
  func windowWillClose(_ notification: Notification) { activeKeyTextField?.blur() }

  func showSettings() {
    if settingsWindow == nil {
      let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: .shared)))
      window.title = "SwiftKeyRemap Settings"
      window.styleMask = [.titled, .closable]
      window.collectionBehavior = [.fullScreenNone]
      window.setContentSize(NSSize(width: 640, height: 440))
      window.contentMinSize = NSSize(width: 640, height: 440)
      window.contentMaxSize = window.contentMinSize
      window.isReleasedWhenClosed = false
      window.delegate = self
      window.center()
      settingsWindow = window
    }
    SettingsStore.shared.refresh()
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  func restart() {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    task.arguments = ["-n", Bundle.main.bundlePath]
    do {
      try task.run()
      task.waitUntilExit()
      guard task.terminationStatus == 0 else {
        throw NSError(domain: "AppRestart", code: Int(task.terminationStatus), userInfo: [
          NSLocalizedDescriptionKey: "The app could not be restarted. Please reopen it from Applications."
        ])
      }
      NSApp.terminate(nil)
    } catch {
      SettingsStore.shared.errorMessage = error.localizedDescription
      showSettings()
    }
  }
}
