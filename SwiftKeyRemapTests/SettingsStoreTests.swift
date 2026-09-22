import Cocoa
import SwiftUI
import ServiceManagement
import Testing
@testable import SwiftKeyRemap

extension GlobalStateTests {
  @Suite @MainActor struct SettingsStoreTests {
    @MainActor final class Fixture {
      let suite = "SwiftKeyRemap.Tests.\(UUID().uuidString)"
      let defaults: UserDefaults
      let oldMappings = keyMappingList
      let oldTable = shortcutList
      let oldExcluded = exclusionAppsList
      let oldDict = exclusionAppsDict
      let oldRecent = activeAppsList
      init() { defaults = UserDefaults(suiteName: suite)!; activeAppsList = [] }
      func restore() {
        defaults.removePersistentDomain(forName: suite)
        keyMappingList = oldMappings; shortcutList = oldTable
        exclusionAppsList = oldExcluded; exclusionAppsDict = oldDict; activeAppsList = oldRecent
      }
      func store(login: LaunchAtStartup = LaunchAtStartup(status: { .notRegistered })) -> SettingsStore {
        SettingsStore(defaults: defaults, loginItem: login)
      }
    }

    @Test func editsPersistAndImmediatelyUpdateEventTable() {
      let f = Fixture(); defer { f.restore() }
      let store = f.store()
      let row = store.mappings[0]
      store.setShortcut(KeyboardShortcut(keyCode: 115), for: row, input: true)
      store.setShortcut(KeyboardShortcut(keyCode: 123, flags: .maskCommand), for: row, input: false)
      #expect(shortcutList[115]?.first === row)
      #expect(shortcutList[55] == nil)
      let restored = StartupSettings.mappings(saved: f.defaults.object(forKey: "mappings"))
      #expect(restored.list[0].input.keyCode == 115)
      #expect(restored.list[0].output.flags == .maskCommand)
      store.setEnabled(false, for: row)
      #expect(shortcutList[115] == nil)
    }

    @Test func reorderPreservesIdentityAndStaleRecorderCannotEditAnotherRow() {
      let f = Fixture(); defer { f.restore() }
      let store = f.store()
      let first = store.mappings[0]
      let second = store.mappings[1]
      store.apply(.moveToBottom, to: first)
      store.setShortcut(KeyboardShortcut(keyCode: 4), for: first, input: true)
      #expect(store.mappings[1] === first)
      #expect(second.input.keyCode == 54)
      store.apply(.remove, to: first)
      store.setShortcut(KeyboardShortcut(keyCode: 8), for: first, input: true)
      #expect(store.mappings.count == 1)
      #expect(store.mappings[0] === second)
      #expect(shortcutList[8] == nil)
      store.addMapping()
      #expect(store.mappings.count == 2)
    }

    @Test func exclusionsPersistAndReturnToRecentWhenUnchecked() {
      let f = Fixture(); defer { f.restore() }
      let app = AppData(name: "Editor", id: "test.editor")
      activeAppsList = [app]
      let store = f.store()
      store.setExcluded(true, app: app)
      #expect(exclusionAppsDict[app.id] == app.name)
      #expect(activeAppsList.isEmpty)
      #expect(store.excludedIDs == [app.id])
      #expect(StartupSettings.exclusionApps(from: f.defaults.object(forKey: "exclusionApps")).count == 1)
      store.setExcluded(false, app: app)
      #expect(exclusionAppsDict.isEmpty)
      #expect(store.apps.first?.id == app.id)
      #expect(activeAppsList.first?.id == app.id)
    }

    @Test func failedLoginRegistrationKeepsActualSystemStateAndReportsError() {
      let f = Fixture(); defer { f.restore() }
      let store = f.store(login: LaunchAtStartup(status: { .notRegistered }, register: {
        throw NSError(domain: "Test", code: 1)
      }))
      store.setLaunchAtLogin(true)
      #expect(!store.launchAtLogin)
      #expect(store.errorMessage != nil)
    }

    @Test func refreshReflectsSystemApprovalAndMenuVisibilityPersists() {
      let f = Fixture(); defer { f.restore() }
      var state: SMAppService.Status = .enabled
      let store = f.store(login: LaunchAtStartup(status: { state }))
      #expect(store.launchAtLogin)
      state = .requiresApproval; store.refresh()
      #expect(store.loginStatus == .requiresApproval)
      state = .notRegistered; store.refresh()
      #expect(!store.launchAtLogin)
      store.showMenuBarIcon = false
      #expect(f.defaults.integer(forKey: "showIcon") == 0)
    }

    @Test func hostedSettingsHaveFixedContentSize() {
      let f = Fixture(); defer { f.restore() }
      let host = NSHostingController(rootView: SettingsView(store: f.store()))
      host.view.layoutSubtreeIfNeeded()
      #expect(host.view.fittingSize == NSSize(width: 640, height: 440))
    }

    @Test func recorderCommitsPresetThroughBinding() {
      let field = KeyTextField(frame: .zero)
      var recorded: SwiftKeyRemap.KeyboardShortcut?
      field.onCommit = { recorded = $0 }
      field.stringValue = "Eisu"
      field.commitEditedText()
      #expect(recorded?.keyCode == 102)
      #expect(field.stringValue == "Eisu")
    }
  }
}
