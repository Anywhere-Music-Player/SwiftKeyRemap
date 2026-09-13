//
//  KeyTextField.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Cocoa

var activeKeyTextField: KeyTextField?

class KeyTextField: NSComboBox {
  /// このフィールドが表すショートカット。編集終了時に表示と keyMappingList へ反映される
  var shortcut: KeyboardShortcut?
  var saveAddress: (row: Int, id: String)?
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

      if let saveAddress = saveAddress {
        ShortcutTextResolver.apply(
          shortcut, to: &keyMappingList, row: saveAddress.row, columnId: saveAddress.id)
        keyMappingListToShortcutList()
      }
    } else {
      self.stringValue = ""
    }

    saveKeyMappings()

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
    activeKeyTextField = nil
  }
}
