//
//  KeyTextField.swift
//  SwiftKeyRemap
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa

var activeKeyTextField: KeyTextField?

class KeyTextField: NSComboBox, NSComboBoxDelegate {
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    delegate = self
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    delegate = self
  }

  var isUpdatingFromModel = false

  func comboBoxSelectionDidChange(_ notification: Notification) {
    guard !isUpdatingFromModel else { return }
    if let text = objectValueOfSelectedItem as? String {
      stringValue = text
      commitEditedText()
    }
  }

  /// このフィールドが表すショートカット。編集終了時に表示と keyMappingList へ反映される
  var shortcut: KeyboardShortcut?
  var onCommit: ((KeyboardShortcut) -> Void)?
  var isAllowModifierOnly = true

  override func becomeFirstResponder() -> Bool {
    let became = super.becomeFirstResponder()
    if became {
      activeKeyTextField = self
    }
    return became
  }

  override func textDidEndEditing(_ obj: Notification) {
    super.textDidEndEditing(obj)
    commitEditedText()
  }

  /// 入力された文字列を解決して表示と keyMappingList に反映し、保存する
  func commitEditedText() {
    shortcut = ShortcutTextResolver.resolve(
      text: self.stringValue, current: shortcut,
      symbolicHotKeyParameters: symbolicHotKeyParameters(id:))

    if let shortcut = shortcut {
      self.stringValue = shortcut.toString()

      onCommit?(shortcut)
    } else {
      self.stringValue = ""
    }


    if activeKeyTextField == self {
      activeKeyTextField = nil
    }
  }

  /// システム設定の AppleSymbolicHotKeys から、id のショートカットの parameters を読む。
  /// 設定が無いか形式が想定外なら nil
  private func symbolicHotKeyParameters(id: Int) -> [Int]? {
    guard
      let symbolicHotKeys = UserDefaults(suiteName: "com.apple.symbolichotkeys.plist")?.object(
        forKey: "AppleSymbolicHotKeys") as? NSDictionary
    else {
      return nil
    }

    return symbolicHotKeys.value(forKeyPath: "\(id).value.parameters") as? [Int]
  }

  func blur() {
    self.window?.makeFirstResponder(nil)
    if activeKeyTextField === self { commitEditedText() }
    activeKeyTextField = nil
  }
}
