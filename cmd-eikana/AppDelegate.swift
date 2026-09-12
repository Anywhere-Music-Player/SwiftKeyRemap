//
//  AppDelegate.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa
import Sparkle

var statusItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
var loginItem = NSMenuItem()

@main
class AppDelegate: NSObject, NSApplicationDelegate {

  var windowController: NSWindowController?
  var preferenceWindowController: PreferenceWindowController!
  let keyEvent = KeyEvent()
  // Sparkle。開始は起動処理の中で行う（旧設定の引き継ぎを先に済ませるため）
  let updaterController = SPUStandardUpdaterController(
    startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Insert code here to initialize your application

    ////////////////////////////
    // 保存データの読み込み
    ////////////////////////////

    let userDefaults = UserDefaults.standard

    // 「ログイン後にこのアプリを起動」
    if userDefaults.object(forKey: "lunchAtStartup") == nil {
      setLaunchAtStartup(true)
      userDefaults.set(1, forKey: "lunchAtStartup")
    }

    // バージョンアップ時に自動起動設定を再登録（バンドルID変更対応）
    let lastVersion = userDefaults.string(forKey: "lastLaunchVersion")
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    if shouldReregisterLaunchAtStartup(
      lastVersion: lastVersion,
      currentVersion: currentVersion,
      launchAtStartupEnabled: userDefaults.integer(forKey: "lunchAtStartup") == 1
    ) {
      setLaunchAtStartup(true)
    }
    userDefaults.set(currentVersion, forKey: "lastLaunchVersion")

    // 旧設定「起動時にアップデートを確認」を Sparkle の自動確認設定へ引き継ぐ（キーを消すので 1 度だけ走る）
    if let legacyCheckUpdate = userDefaults.object(forKey: "checkUpdateAtlaunch") as? Int {
      updaterController.updater.automaticallyChecksForUpdates = (legacyCheckUpdate == 1)
      userDefaults.removeObject(forKey: "checkUpdateAtlaunch")
    }
    updaterController.startUpdater()

    // 除外アプリ設定
    if let exclusionAppsListData = userDefaults.object(forKey: "exclusionApps")
      as? [[AnyHashable: Any]]
    {
      for val in exclusionAppsListData {
        if let exclusionApps = AppData(dictionary: val) {
          exclusionAppsList.append(exclusionApps)
        }
      }

      for val in exclusionAppsList {
        exclusionAppsDict[val.id] = val.name
      }
    }

    // ショートカット設定
    if let keyMappingListData = userDefaults.object(forKey: "mappings") as? [[AnyHashable: Any]] {
      for val in keyMappingListData {
        if let mapping = KeyMapping(dictionary: val) {
          keyMappingList.append(mapping)
        }
      }

      keyMappingListToShortcutList()
    } else {
      if let oneShotModifiersData = userDefaults.object(forKey: "oneShotModifiers") as? [AnyObject]
      {
        // v2.0.xからの引き継ぎ
        for val in oneShotModifiersData {
          if let inputKeyCodeInt = val["input"] as? Int,
            let inputKeyCode = CGKeyCode(exactly: inputKeyCodeInt),
            let outputDic = val["output"] as? [AnyHashable: Any],
            let output = KeyboardShortcut(dictionary: outputDic)
          {
            keyMappingList.append(
              KeyMapping(
                input: KeyboardShortcut(keyCode: inputKeyCode),
                output: output))
          }
        }

        userDefaults.removeObject(forKey: "oneShotModifiers")
      } else {
        // 初期設定（左右のコマンドキー単体で英数/かな）
        keyMappingList = [
          KeyMapping(input: KeyboardShortcut(keyCode: 55), output: KeyboardShortcut(keyCode: 102)),
          KeyMapping(input: KeyboardShortcut(keyCode: 54), output: KeyboardShortcut(keyCode: 104)),
        ]
      }

      saveKeyMappings()
      keyMappingListToShortcutList()
    }

    ////////////////////////////
    // UIの初期化
    ////////////////////////////

    preferenceWindowController = PreferenceWindowController.getInstance()

    let menu = NSMenu()
    statusItem.button?.title = "⌘"
    statusItem.menu = menu
    // 「メニューバーにアイコンを表示」の保存値を起動時に反映する（設定画面と同じく、未設定なら表示）
    statusItem.isVisible = (userDefaults.object(forKey: "showIcon") as? Int ?? 1) == 1

    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

    menu.addItem(
      withTitle: "About ⌘英かな \(version)", action: #selector(AppDelegate.open(_:)), keyEquivalent: ""
    )
    menu.addItem(
      withTitle: "Preferences...", action: #selector(AppDelegate.openPreferencesSerector(_:)),
      keyEquivalent: "")
    menu.addItem(NSMenuItem.separator())
    menu.addItem(
      withTitle: "Restart", action: #selector(AppDelegate.restart(_:)), keyEquivalent: "")
    menu.addItem(withTitle: "Quit", action: #selector(AppDelegate.quit(_:)), keyEquivalent: "")

    keyEvent.start()
  }

  func applicationWillTerminate(_ aNotification: Notification) {
    // Insert code here to tear down your application
  }

  func applicationDidResignActive(_ notification: Notification) {
    activeKeyTextField?.blur()
  }
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool
  {
    preferenceWindowController.showAndActivate(self)
    return false
  }

  // 保存されたUserDefaultを全削除する。
  func resetUserDefault() {
    guard let appDomain = Bundle.main.bundleIdentifier else { return }
    UserDefaults.standard.removePersistentDomain(forName: appDomain)
  }

  @IBAction func open(_ sender: NSButton) {
    if let checkURL = URL(string: "https://eikana.dominion525.com/") {
      if NSWorkspace.shared.open(checkURL) {
        print("url successfully opened")
      }
    } else {
      print("invalid url")
    }
  }
  @IBAction func openPreferencesSerector(_ sender: NSButton) {
    preferenceWindowController.showAndActivate(self)
  }

  @IBAction func launch(_ sender: NSButton) {
    if sender.state.rawValue == 0 {
      sender.state = NSControl.StateValue(rawValue: 1)
    } else {
      sender.state = NSControl.StateValue(rawValue: 0)
    }
  }

  @IBAction func restart(_ sender: NSButton) {
    let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
    let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = [path]
    task.launch()
    NSApplication.shared.terminate(self)
  }

  @IBAction func quit(_ sender: NSButton) {
    NSApplication.shared.terminate(self)
  }
}
