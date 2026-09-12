//
//  KeyEvent.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa

var activeAppsList: [AppData] = []
var exclusionAppsList: [AppData] = []

var exclusionAppsDict: [String: String] = [:]

class KeyEvent: NSObject {
  var keyCode: CGKeyCode?
  var isExclusionApp = false
  let bundleId = Bundle.main.infoDictionary?["CFBundleIdentifier"] as! String
  var hasConvertedEventLog: KeyMapping?
  var eventTap: CFMachPort?

  override init() {
    super.init()
  }

  func start() {
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(KeyEvent.setActiveApp(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil)

    // Input Monitoring権限のチェック (macOS 10.15+)
    if #available(macOS 10.15, *) {
      if !CGPreflightListenEventAccess() {
        CGRequestListenEventAccess()
      }
    }

    // Accessibility権限のチェック
    let checkOptionPrompt = kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString
    let options: CFDictionary = [checkOptionPrompt: true] as NSDictionary

    if !AXIsProcessTrustedWithOptions(options) {
      // アクセシビリティに設定されていない場合、設定されるまでループで待つ
      Timer.scheduledTimer(
        timeInterval: 1.0,
        target: self,
        selector: #selector(KeyEvent.watchAXIsProcess(_:)),
        userInfo: nil,
        repeats: true)
    } else {
      self.watch()
    }
  }

  @objc func watchAXIsProcess(_ timer: Timer) {
    // macOS 10.15+ではInput Monitoring権限も確認
    if #available(macOS 10.15, *) {
      if AXIsProcessTrusted() && CGPreflightListenEventAccess() {
        timer.invalidate()
        self.watch()
      }
    } else {
      if AXIsProcessTrusted() {
        timer.invalidate()
        self.watch()
      }
    }
  }

  @objc func setActiveApp(_ notification: NSNotification) {
    let app = notification.userInfo!["NSWorkspaceApplicationKey"] as! NSRunningApplication

    if let name = app.localizedName, let id = app.bundleIdentifier {
      isExclusionApp = exclusionAppsDict[id] != nil

      if id != bundleId && !isExclusionApp {
        activeAppsList = activeAppsList.filter { $0.id != id }
        activeAppsList.insert(AppData(name: name, id: id), at: 0)

        if activeAppsList.count > 10 {
          activeAppsList.removeLast()
        }
      }
    }
  }

  func watch() {
    // マウスのドラッグバグ回避のため、NSEventとCGEventを併用
    // CGEventのみでやる方法を捜索中
    let nsEventMaskList: NSEvent.EventTypeMask = [
      .leftMouseDown,
      .leftMouseUp,
      .rightMouseDown,
      .rightMouseUp,
      .otherMouseDown,
      .otherMouseUp,
      .scrollWheel,
    ]

    NSEvent.addGlobalMonitorForEvents(matching: nsEventMaskList) { _ in
      self.keyCode = nil
    }

    NSEvent.addLocalMonitorForEvents(matching: nsEventMaskList) { (event: NSEvent) -> NSEvent? in
      self.keyCode = nil
      return event
    }

    let eventMaskList = [
      CGEventType.keyDown.rawValue,
      CGEventType.keyUp.rawValue,
      CGEventType.flagsChanged.rawValue,
      UInt32(NX_SYSDEFINED),  // Media key Event
    ]
    var eventMask: UInt32 = 0

    for mask in eventMaskList {
      eventMask |= (1 << mask)
    }

    let observer = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: {
          (
            proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
            refcon: UnsafeMutableRawPointer?
          ) -> Unmanaged<CGEvent>? in
          if let observer = refcon {
            let mySelf = Unmanaged<KeyEvent>.fromOpaque(observer).takeUnretainedValue()
            return mySelf.eventCallback(proxy: proxy, type: type, event: event)
          }
          return Unmanaged.passUnretained(event)
        },
        userInfo: observer
      )
    else {
      print("failed to create event tap")
      exit(1)
    }

    self.eventTap = eventTap

    let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

    CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
  }

  func eventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<
    CGEvent
  >? {
    // タイムアウト等でシステムに無効化されたイベントタップを再有効化する
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap = self.eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return nil
    }

    if isExclusionApp {
      return Unmanaged.passUnretained(event)
    }

    if let mediaKeyEvent = MediaKeyEvent(event) {
      return mediaKeyEvent.keyDown ? mediaKeyDown(mediaKeyEvent) : mediaKeyUp(mediaKeyEvent)
    }

    switch type {
    case .flagsChanged:
      let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

      guard let modifierMask = modifierMasks[keyCode] else {
        return Unmanaged.passUnretained(event)
      }
      return event.flags.rawValue & modifierMask.rawValue != 0
        ? modifierKeyDown(event) : modifierKeyUp(event)

    case .keyDown:
      return keyDown(event)

    case .keyUp:
      return keyUp(event)

    default:
      self.keyCode = nil

      return Unmanaged.passUnretained(event)
    }
  }

  func keyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    #if DEBUG
      print(KeyboardShortcut(event).toString())
    #endif

    self.keyCode = nil

    if let keyTextField = activeKeyTextField {
      keyTextField.shortcut = KeyboardShortcut(event)
      keyTextField.stringValue = keyTextField.shortcut!.toString()

      return nil
    }

    return convertIfMapped(event)
  }

  func keyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    self.keyCode = nil

    return convertIfMapped(event)
  }

  /// 設定に一致すれば変換後のイベント（Disable なら nil）を、一致しなければ元のイベントをそのまま返す
  private func convertIfMapped(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    if hasConvertedEvent(event) {
      if let event = getConvertedEvent(event) {
        return Unmanaged.passUnretained(event)
      }
      return nil
    }

    return Unmanaged.passUnretained(event)
  }

  func modifierKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    #if DEBUG
      print(KeyboardShortcut(event).toString())
    #endif

    self.keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

    if let keyTextField = activeKeyTextField, keyTextField.isAllowModifierOnly {
      let shortcut = KeyboardShortcut(event)

      keyTextField.shortcut = shortcut
      keyTextField.stringValue = shortcut.toString()
    }

    return Unmanaged.passUnretained(event)
  }

  func modifierKeyUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    if activeKeyTextField != nil {
      self.keyCode = nil
    } else if self.keyCode == CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode)) {
      if let convertedEvent = getConvertedEvent(event) {
        KeyboardShortcut(convertedEvent).postEvent()
      }
    }

    self.keyCode = nil

    return Unmanaged.passUnretained(event)
  }

  func mediaKeyDown(_ mediaKeyEvent: MediaKeyEvent) -> Unmanaged<CGEvent>? {
    #if DEBUG
      print(
        KeyboardShortcut(keyCode: mappingKeyCode(of: mediaKeyEvent), flags: mediaKeyEvent.flags)
          .toString())
    #endif

    self.keyCode = nil

    if let keyTextField = activeKeyTextField {
      if keyTextField.isAllowModifierOnly {
        keyTextField.shortcut = KeyboardShortcut(
          keyCode: mappingKeyCode(of: mediaKeyEvent),
          flags: mediaKeyEvent.flags)
        keyTextField.stringValue = keyTextField.shortcut!.toString()
      }

      return nil
    }

    if hasConvertedEvent(mediaKeyEvent.event, keyCode: mappingKeyCode(of: mediaKeyEvent)) {
      if let event = getConvertedEvent(
        mediaKeyEvent.event, keyCode: mappingKeyCode(of: mediaKeyEvent))
      {
        event.post(tap: CGEventTapLocation.cghidEventTap)
      }
      return nil
    }

    return Unmanaged.passUnretained(mediaKeyEvent.event)
  }

  func mediaKeyUp(_ mediaKeyEvent: MediaKeyEvent) -> Unmanaged<CGEvent>? {
    return Unmanaged.passUnretained(mediaKeyEvent.event)
  }

  /// メディアキーを設定表で引くときの keyCode（NX_KEYTYPE_* にオフセットを足したもの）
  private func mappingKeyCode(of mediaKeyEvent: MediaKeyEvent) -> CGKeyCode {
    return CGKeyCode(mediaKeyCodeOffset + mediaKeyEvent.keyCode)
  }

  func hasConvertedEvent(_ event: CGEvent, keyCode: CGKeyCode? = nil) -> Bool {
    let shortcut =
      event.type.rawValue == UInt32(NX_SYSDEFINED)
      ? KeyboardShortcut(keyCode: 0, flags: MediaKeyEvent(event)!.flags) : KeyboardShortcut(event)

    if let mappingList = shortcutList[keyCode ?? shortcut.keyCode],
      let mapping = mappingList.first(where: { shortcut.isCover($0.input) })
    {
      hasConvertedEventLog = mapping
      return true
    }
    hasConvertedEventLog = nil
    return false
  }

  func getConvertedEvent(_ event: CGEvent, keyCode: CGKeyCode? = nil) -> CGEvent? {
    var event = event

    if event.type.rawValue == UInt32(NX_SYSDEFINED) {
      let flags = MediaKeyEvent(event)!.flags
      event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
      event.flags = flags
    }

    let shortcut = KeyboardShortcut(event)

    func getEvent(_ mappings: KeyMapping) -> CGEvent? {
      if mappings.output.keyCode == disableKeyCode {
        return nil
      }

      event.setIntegerValueField(.keyboardEventKeycode, value: Int64(mappings.output.keyCode))
      event.flags = CGEventFlags(
        rawValue: (event.flags.rawValue & ~mappings.input.flags.rawValue)
          | mappings.output.flags.rawValue
      )

      return event
    }

    if let mappingList = shortcutList[keyCode ?? shortcut.keyCode] {
      if let mappings = hasConvertedEventLog,
        shortcut.isCover(mappings.input)
      {
        return getEvent(mappings)
      }
      if let mappings = mappingList.first(where: { shortcut.isCover($0.input) }) {
        return getEvent(mappings)
      }
    }
    return nil
  }
}

/// 出力側にこの keyCode を設定した項目は、入力キーを無効化する（何も送らない）
let disableKeyCode: CGKeyCode = 999

/// メディアキーは NX_KEYTYPE_* にこの値を足した keyCode で設定表と keyCodeDictionary を引く
let mediaKeyCodeOffset = 1000

let modifierMasks: [CGKeyCode: CGEventFlags] = [
  54: CGEventFlags.maskCommand,
  55: CGEventFlags.maskCommand,
  56: CGEventFlags.maskShift,
  60: CGEventFlags.maskShift,
  59: CGEventFlags.maskControl,
  62: CGEventFlags.maskControl,
  58: CGEventFlags.maskAlternate,
  61: CGEventFlags.maskAlternate,
  63: CGEventFlags.maskSecondaryFn,
  57: CGEventFlags.maskAlphaShift,
]
