//
//  ShortcutTextResolver.swift
//  ⌘英かな
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// JIS キーボードの英数キーとかなキーの keyCode
let eisuKeyCode = CGKeyCode(kVK_JIS_Eisu)
let kanaKeyCode = CGKeyCode(kVK_JIS_Kana)

/// キー入力欄の文字列をショートカットに解決し、キーリマップ一覧へ反映する処理。
/// UI とシステム設定の読み取りには依存せず、読み取りは関数として受け取る
enum ShortcutTextResolver {
  /// システム設定「入力ソース」ショートカットの AppleSymbolicHotKeys 上の id
  static let previousInputSourceHotKeyId = 60
  static let nextInputSourceHotKeyId = 61

  /// 入力欄の文字列をショートカットに解決する。
  /// ドロップダウンの項目名に一致しない文字列や、システム設定が読めない場合は current をそのまま返す
  static func resolve(
    text: String, current: KeyboardShortcut?, symbolicHotKeyParameters: (Int) -> [Int]?
  ) -> KeyboardShortcut? {
    switch text {
    case "英数":
      return KeyboardShortcut(keyCode: eisuKeyCode)
    case "かな":
      return KeyboardShortcut(keyCode: kanaKeyCode)
    case "⇧かな":
      return KeyboardShortcut(keyCode: kanaKeyCode, flags: CGEventFlags.maskShift)
    case "前の入力ソースを選択", "select the previous input source":
      return hotKeyShortcut(id: previousInputSourceHotKeyId, symbolicHotKeyParameters) ?? current
    case "入力メニューの次のソースを選択", "select next source in input menu":
      return hotKeyShortcut(id: nextInputSourceHotKeyId, symbolicHotKeyParameters) ?? current
    case "Disable":
      return KeyboardShortcut(keyCode: disableKeyCode)
    default:
      return current
    }
  }

  /// システム設定でショートカットが未割り当てのとき、AppleSymbolicHotKeys の keyCode に入る値
  static let unassignedSymbolicHotKeyKeyCode: CGKeyCode = 65535

  /// AppleSymbolicHotKeys の parameters（[文字コード, keyCode, 修飾フラグ]）をショートカットにする。
  /// 要素が 3 つ未満、keyCode や修飾フラグが型の範囲に収まらない、または未割り当てなら nil
  static func shortcut(fromSymbolicHotKeyParameters parameters: [Int]) -> KeyboardShortcut? {
    guard parameters.count >= 3,
      let keyCode = CGKeyCode(exactly: parameters[1]),
      keyCode != unassignedSymbolicHotKeyKeyCode,
      let flags = UInt64(exactly: parameters[2])
    else {
      return nil
    }

    return KeyboardShortcut(keyCode: keyCode, flags: CGEventFlags(rawValue: flags))
  }

  /// 解決したショートカットを一覧の row 行に反映する。columnId が "input" なら入力側、それ以外は出力側
  static func apply(
    _ shortcut: KeyboardShortcut, to list: inout [KeyMapping], row: Int, columnId: String
  ) {
    if columnId == "input" {
      list[row].input = shortcut
    } else {
      list[row].output = shortcut
    }
  }

  private static func hotKeyShortcut(id: Int, _ symbolicHotKeyParameters: (Int) -> [Int]?)
    -> KeyboardShortcut?
  {
    guard let parameters = symbolicHotKeyParameters(id) else {
      return nil
    }
    return shortcut(fromSymbolicHotKeyParameters: parameters)
  }
}
