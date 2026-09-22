import SwiftUI
import ServiceManagement

struct SettingsView: View {
  @ObservedObject var store: SettingsStore
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      mappings.tabItem { Label("Key Mappings", systemImage: "keyboard") }.tag(0)
      excludedApps.tabItem { Label("Excluded Apps", systemImage: "app.badge.checkmark") }.tag(1)
      general.tabItem { Label("General", systemImage: "gearshape") }.tag(2)
    }
    .padding(20)
    .frame(width: 640, height: 440)
    .onChange(of: selectedTab) { _, _ in activeKeyTextField?.blur() }
    .onDisappear { activeKeyTextField?.blur() }
    .alert("Unable to Update Settings", isPresented: Binding(
      get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
        Button("OK", role: .cancel) { store.errorMessage = nil }
      } message: { Text(store.errorMessage ?? "") }
    .sheet(isPresented: $store.showAbout) {
      VStack(spacing: 12) {
        Image(systemName: "command").font(.system(size: 44)).padding(.bottom, 4)
        Text("SwiftKeyRemap").font(.title.bold())
        Text("Key remapping for macOS.").foregroundStyle(.secondary)
        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
          .font(.caption).foregroundStyle(.secondary)
        Text("Based on cmd-eikana by iMasanari and dominion525.")
          .font(.caption).foregroundStyle(.secondary)
        Button("Done") { store.showAbout = false }.keyboardShortcut(.defaultAction)
      }.padding(32).frame(width: 360)
    }
  }

  private var mappings: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Click a shortcut to record it, or choose a preset from its menu.")
        .font(.callout).foregroundStyle(.secondary)
      HStack {
        Text("On").frame(width: 30)
        Text("Input").frame(maxWidth: .infinity, alignment: .leading)
        Text("Output").frame(maxWidth: .infinity, alignment: .leading)
        Color.clear.frame(width: 28, height: 1)
      }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 12)
      List {
        ForEach(store.mappings, id: \.self) { mapping in
          HStack(spacing: 12) {
            Toggle("Enable mapping", isOn: Binding(
              get: { mapping.enable }, set: { store.setEnabled($0, for: mapping) }))
              .labelsHidden().toggleStyle(.checkbox).frame(width: 30)
            ShortcutRecorder(shortcut: mapping.input, allowsModifierOnly: true) {
              store.setShortcut($0, for: mapping, input: true)
            }.frame(maxWidth: .infinity).accessibilityLabel("Input shortcut")
            ShortcutRecorder(shortcut: mapping.output, allowsModifierOnly: false) {
              store.setShortcut($0, for: mapping, input: false)
            }.frame(maxWidth: .infinity).accessibilityLabel("Output shortcut")
            Menu {
              Button("Move to Top") { store.apply(.moveToTop, to: mapping) }
              Button("Move Up") { store.apply(.moveUp, to: mapping) }
              Button("Move Down") { store.apply(.moveDown, to: mapping) }
              Button("Move to Bottom") { store.apply(.moveToBottom, to: mapping) }
              Divider()
              Button("Remove", role: .destructive) { store.apply(.remove, to: mapping) }
            } label: { Image(systemName: "ellipsis") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
            .accessibilityLabel("Mapping actions")
          }.padding(.vertical, 4)
        }
      }
      .listStyle(.inset(alternatesRowBackgrounds: true))
      .overlay { if store.mappings.isEmpty { Text("No mappings yet").foregroundStyle(.secondary) } }
      Button { store.addMapping() } label: { Label("Add Mapping", systemImage: "plus") }
    }.padding(.top, 16)
  }

  private var excludedApps: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Key remapping is disabled in checked apps.")
        .font(.callout).foregroundStyle(.secondary)
      List(store.apps, id: \.id) { app in
        Toggle(isOn: Binding(get: { store.excludedIDs.contains(app.id) },
                             set: { store.setExcluded($0, app: app) })) {
          VStack(alignment: .leading, spacing: 3) {
            Text(app.name)
            Text(app.id).font(.caption).foregroundStyle(.secondary)
          }
        }.toggleStyle(.checkbox).padding(.vertical, 3)
      }.listStyle(.inset(alternatesRowBackgrounds: true))
      .overlay {
        if store.apps.isEmpty { Text("Switch to an app to add it to this list.").foregroundStyle(.secondary) }
      }
      Text("Recently used apps appear here automatically.").font(.caption).foregroundStyle(.secondary)
    }.padding(.top, 16)
  }

  private var general: some View {
    Form {
      Section {
        Toggle("Show menu bar icon", isOn: $store.showMenuBarIcon)
        Toggle("Launch at login", isOn: Binding(get: { store.launchAtLogin }, set: store.setLaunchAtLogin))
        if store.loginStatus == .requiresApproval {
          LabeledContent("Approval required") {
            Button("Open System Settings") { SMAppService.openSystemSettingsLoginItems() }
          }
        }
      }
      Section("Updates") {
        if store.updatesConfigured {
          Toggle("Automatically check for updates", isOn: $store.automaticUpdates)
        }
        Button(store.updatesConfigured ? "Check for Updates…" : "View Releases…") { store.checkForUpdates() }
      }
    }.formStyle(.grouped).padding(.top, 8)
  }
}

/// AppKit is used only for recording hardware shortcuts; the surrounding UI is SwiftUI.
struct ShortcutRecorder: NSViewRepresentable {
  let shortcut: KeyboardShortcut
  let allowsModifierOnly: Bool
  let onCommit: (KeyboardShortcut) -> Void

  func makeNSView(context: Context) -> KeyTextField {
    let field = KeyTextField(frame: .zero)
    field.isAllowModifierOnly = allowsModifierOnly
    field.completes = false
    field.addItems(withObjectValues: allowsModifierOnly
      ? ["Command_L", "Command_R", "Eisu", "Kana", "Shift + Kana"]
      : ["Eisu", "Kana", "Shift + Kana", "Previous Input Source", "Next Input Source", "Disable"])
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return field
  }

  func updateNSView(_ field: KeyTextField, context: Context) {
    field.onCommit = onCommit
    field.isUpdatingFromModel = true
    defer { field.isUpdatingFromModel = false }
    if activeKeyTextField !== field {
      field.shortcut = shortcut
      field.stringValue = shortcut.toString()
    }
  }

  static func dismantleNSView(_ field: KeyTextField, coordinator: ()) {
    if activeKeyTextField === field { field.blur() }
    field.onCommit = nil
  }
}

#Preview("Settings") { SettingsView(store: SettingsStore.preview()) }
