import SwiftUI

@main
struct SwiftKeyRemapApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var store = SettingsStore.shared

  var body: some Scene {
    MenuBarExtra("SwiftKeyRemap", systemImage: "command", isInserted: Binding(
      get: { store.showMenuBarIcon },
      set: { if store.showMenuBarIcon != $0 { store.showMenuBarIcon = $0 } })) {
      Button("About SwiftKeyRemap") {
        appDelegate.showSettings()
        store.showAbout = true
      }
      Button("Settings…") { appDelegate.showSettings() }.keyboardShortcut(",")
      Divider()
      Button("Restart") { appDelegate.restart() }
      Button("Quit SwiftKeyRemap") { NSApp.terminate(nil) }.keyboardShortcut("q")
    }.menuBarExtraStyle(.menu)
  }
}
