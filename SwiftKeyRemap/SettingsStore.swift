import AppKit
import Combine
import ServiceManagement
import Sparkle

extension Notification.Name {
  static let keyRemapAppsChanged = Notification.Name("SwiftKeyRemap.appsChanged")
}

@MainActor
final class SettingsStore: ObservableObject {
  static let shared = SettingsStore()
  @Published private(set) var mappings: [KeyMapping]
  @Published private(set) var apps: [AppData] = []
  @Published private(set) var excludedIDs: Set<String> = []
  @Published private(set) var loginStatus: SMAppService.Status = .notRegistered
  @Published var errorMessage: String?
  @Published var showAbout = false
  @Published var showMenuBarIcon: Bool {
    didSet { defaults.set(showMenuBarIcon ? 1 : 0, forKey: "showIcon") }
  }
  @Published var automaticUpdates: Bool {
    didSet { updaterController.updater.automaticallyChecksForUpdates = automaticUpdates }
  }

  let updatesConfigured: Bool
  let updaterController = SPUStandardUpdaterController(
    startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
  private let defaults: UserDefaults
  private let loginItem: LaunchAtStartup
  private let publishToKeyboard: Bool
  private var excludedApps: [AppData]
  private var subscriptions = Set<AnyCancellable>()

  init(defaults: UserDefaults = .standard, loginItem: LaunchAtStartup = .shared,
       publishToKeyboard: Bool = true) {
    self.defaults = defaults
    self.loginItem = loginItem
    self.publishToKeyboard = publishToKeyboard
    mappings = StartupSettings.mappings(saved: defaults.object(forKey: "mappings")).list
    excludedApps = StartupSettings.exclusionApps(from: defaults.object(forKey: "exclusionApps"))
    showMenuBarIcon = (defaults.object(forKey: "showIcon") as? Int ?? 1) == 1
    updatesConfigured = Bundle.main.object(forInfoDictionaryKey: "SwiftKeyRemapUpdatesConfigured") as? Bool ?? false
    automaticUpdates = updatesConfigured && updaterController.updater.automaticallyChecksForUpdates
    if publishToKeyboard {
      keyMappingList = mappings
      keyMappingListToShortcutList()
      exclusionAppsList = excludedApps
      exclusionAppsDict = StartupSettings.exclusionAppsDict(excludedApps)
    }
    refresh()
    NotificationCenter.default.publisher(for: .keyRemapAppsChanged)
      .merge(with: NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification))
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in self?.refresh() }
      .store(in: &subscriptions)
  }

  var launchAtLogin: Bool { loginStatus == .enabled || loginStatus == .requiresApproval }

  func refresh() {
    loginStatus = loginItem.status
    excludedIDs = Set(excludedApps.map(\.id))
    var seen = Set<String>()
    apps = (excludedApps + (publishToKeyboard ? activeAppsList : []))
      .filter { seen.insert($0.id).inserted }
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do { try loginItem.setEnabled(enabled) }
    catch { errorMessage = error.localizedDescription }
    loginStatus = loginItem.status
  }

  func addMapping() {
    activeKeyTextField?.blur()
    mappings = KeyMappingListEditor.adding(to: mappings)
    saveMappings()
  }

  func setEnabled(_ enabled: Bool, for mapping: KeyMapping) {
    guard mappings.contains(where: { $0 === mapping }) else { return }
    guard mapping.enable != enabled else { return }
    objectWillChange.send()
    mapping.enable = enabled
    saveMappings()
  }

  func setShortcut(_ shortcut: KeyboardShortcut, for mapping: KeyMapping, input: Bool) {
    // A recorder may finish editing after its row was removed. Never modify another row.
    guard mappings.contains(where: { $0 === mapping }) else { return }
    let previous = input ? mapping.input : mapping.output
    guard previous.keyCode != shortcut.keyCode || previous.flags != shortcut.flags else { return }
    objectWillChange.send()
    if input { mapping.input = shortcut } else { mapping.output = shortcut }
    saveMappings()
  }

  func apply(_ operation: MappingMenuOperation, to mapping: KeyMapping) {
    activeKeyTextField?.blur()
    guard let index = mappings.firstIndex(where: { $0 === mapping }) else { return }
    mappings = KeyMappingListEditor.apply(operation, at: index, to: mappings)
    saveMappings()
  }

  private func saveMappings() {
    KeyMappingListEditor.save(mappings, to: defaults)
    if publishToKeyboard {
      keyMappingList = mappings
      keyMappingListToShortcutList()
    }
  }

  func setExcluded(_ excluded: Bool, app: AppData) {
    excludedApps.removeAll { $0.id == app.id }
    if excluded { excludedApps.append(app) }
    if publishToKeyboard {
      exclusionAppsList = excludedApps
      exclusionAppsDict = StartupSettings.exclusionAppsDict(excludedApps)
      activeAppsList.removeAll { $0.id == app.id }
      if !excluded { activeAppsList.insert(app, at: 0) }
    }
    defaults.set(ExclusionListEditor.serialized(excludedApps), forKey: "exclusionApps")
    refresh()
  }

  func checkForUpdates() {
    if updatesConfigured {
      updaterController.checkForUpdates(nil)
    } else {
      NSWorkspace.shared.open(URL(string: "https://github.com/Anywhere-Music-Player/SwiftKeyRemap/releases")!)
    }
  }

  static func preview() -> SettingsStore {
    let defaults = UserDefaults(suiteName: "SwiftKeyRemap.Preview")!
    defaults.removePersistentDomain(forName: "SwiftKeyRemap.Preview")
    return SettingsStore(defaults: defaults, loginItem: LaunchAtStartup(status: { .notRegistered }),
                         publishToKeyboard: false)
  }
}
