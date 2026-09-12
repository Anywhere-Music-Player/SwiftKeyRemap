//
//  KeyTextField.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Carbon.HIToolbox
import Cocoa

var activeKeyTextField: KeyTextField?

/// JIS キーボードの英数キーとかなキーの keyCode
let eisuKeyCode = CGKeyCode(kVK_JIS_Eisu)
let kanaKeyCode = CGKeyCode(kVK_JIS_Kana)

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

    switch self.stringValue {
    case "英数":
      shortcut = KeyboardShortcut(keyCode: eisuKeyCode)
    case "かな":
      shortcut = KeyboardShortcut(keyCode: kanaKeyCode)
    case "⇧かな":
      shortcut = KeyboardShortcut(keyCode: kanaKeyCode, flags: CGEventFlags.maskShift)
    case "前の入力ソースを選択", "select the previous input source":
      if let hotKey = symbolicHotKeyShortcut(id: 60) {
        shortcut = hotKey
      }
    case "入力メニューの次のソースを選択", "select next source in input menu":
      if let hotKey = symbolicHotKeyShortcut(id: 61) {
        shortcut = hotKey
      }
    case "Disable":
      shortcut = KeyboardShortcut(keyCode: CGKeyCode(999))
    default:
      break
    }

    if let shortcut = shortcut {
      self.stringValue = shortcut.toString()

      if let saveAddress = saveAddress {
        if saveAddress.id == "input" {
          keyMappingList[saveAddress.row].input = shortcut
        } else {
          keyMappingList[saveAddress.row].output = shortcut
        }
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

  /// システム設定の「入力ソース」ショートカット（AppleSymbolicHotKeys の id 60 が前、61 が次）を読む。
  /// 設定が無いか形式が想定外なら nil
  private func symbolicHotKeyShortcut(id: Int) -> KeyboardShortcut? {
    guard
      let symbolicHotKeys = UserDefaults(suiteName: "com.apple.symbolichotkeys.plist")?.object(
        forKey: "AppleSymbolicHotKeys") as? NSDictionary,
      let parameters = symbolicHotKeys.value(forKeyPath: "\(id).value.parameters") as? [Int],
      parameters.count >= 3
    else {
      return nil
    }

    return KeyboardShortcut(
      keyCode: CGKeyCode(parameters[1]), flags: CGEventFlags(rawValue: UInt64(parameters[2])))
  }

  func blur() {
    self.window?.makeFirstResponder(nil)
    activeKeyTextField = nil
  }
}
