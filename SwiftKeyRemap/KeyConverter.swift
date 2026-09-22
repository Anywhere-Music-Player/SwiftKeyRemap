//
//  KeyConverter.swift
//  SwiftKeyRemap
//
//  MIT License
//  Copyright (c) 2016 iMasanari
//

import CoreGraphics
import Foundation

/// 1 つのキー入力に対して行う変換
enum KeyConversion: Equatable {
  /// 設定に一致しない。イベントをそのまま通す
  case passThrough
  /// 出力が Disable。イベントを捨てる
  case disable
  /// 別のキーに変換する
  case convert(keyCode: CGKeyCode, flags: CGEventFlags)
}

/// キー入力を設定表と照らして変換先を決める。CGEvent や UI には依存しない
enum KeyConverter {
  /// table[lookupKeyCode] の中で、shortcut の修飾キーが input を満たす最初の項目を返す
  static func findMapping(
    for shortcut: KeyboardShortcut, lookupKeyCode: CGKeyCode, in table: [CGKeyCode: [KeyMapping]]
  ) -> KeyMapping? {
    return table[lookupKeyCode]?.first { shortcut.isCover($0.input) }
  }

  /// 変換後の修飾フラグ。入力側の修飾を外し、出力側の修飾を付ける。それ以外のビットは元のまま
  static func convertedFlags(eventFlags: CGEventFlags, mapping: KeyMapping) -> CGEventFlags {
    return CGEventFlags(
      rawValue: (eventFlags.rawValue & ~mapping.input.flags.rawValue)
        | mapping.output.flags.rawValue)
  }

  /// shortcut（押されたキーと修飾フラグ）を lookupKeyCode で設定表から引き、変換先を決める
  static func resolve(
    shortcut: KeyboardShortcut, lookupKeyCode: CGKeyCode, in table: [CGKeyCode: [KeyMapping]]
  ) -> KeyConversion {
    guard let mapping = findMapping(for: shortcut, lookupKeyCode: lookupKeyCode, in: table) else {
      return .passThrough
    }

    if mapping.output.keyCode == disableKeyCode {
      return .disable
    }

    return .convert(
      keyCode: mapping.output.keyCode,
      flags: convertedFlags(eventFlags: shortcut.flags, mapping: mapping))
  }

  /// メディアキーの種類（NX_KEYTYPE_*）を設定表で引くときの keyCode。オフセットを足した値が
  /// keyCode の型に収まらなければ nil
  static func mediaKeyMappingKeyCode(keyType: Int) -> CGKeyCode? {
    return CGKeyCode(exactly: mediaKeyCodeOffset + keyType)
  }

  /// flagsChanged イベントの keyCode と flags から、修飾キーの押下（true）か解放（false）かを決める。
  /// 修飾キーとして扱わないキーコードなら nil
  static func modifierKeyState(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool? {
    guard let modifierMask = modifierMasks[keyCode] else {
      return nil
    }

    return flags.rawValue & modifierMask.rawValue != 0
  }
}

/// 修飾キーが単体で押されて離されたことを追跡する。
/// 押している間に他のキー操作やマウス操作があれば、単体押しとは見なさない
struct ModifierTapTracker {
  private(set) var pressedKeyCode: CGKeyCode?

  /// 修飾キーが押された
  mutating func modifierDown(_ keyCode: CGKeyCode) {
    pressedKeyCode = keyCode
  }

  /// 修飾キー以外の操作があった。単体押しの追跡を取り消す
  mutating func cancel() {
    pressedKeyCode = nil
  }

  /// 修飾キーが離された。押されたまま追跡していたキーと同じなら true。呼び出し後は必ず追跡を解除する
  mutating func modifierUp(_ keyCode: CGKeyCode) -> Bool {
    let isTap = pressedKeyCode == keyCode
    pressedKeyCode = nil
    return isTap
  }
}
