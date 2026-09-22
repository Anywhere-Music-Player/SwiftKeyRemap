//
//  MediaKeyEventTests.swift
//  SwiftKeyRemapTests
//

import Cocoa
import Foundation
import Testing

@testable import SwiftKeyRemap

struct MediaKeyEventTests {

  /// NX_SYSDEFINED イベントの data1 を組み立てる。上位 16 ビットがキー種別、次の 8 ビットが押下（0x0a）か解放（0x0b）か
  func data1(keyType: Int32, state: Int) -> Int {
    (Int(keyType) << 16) | (state << 8)
  }

  @Test func soundUpKeyDown() {
    let parsed = MediaKeyEvent.parse(data1: data1(keyType: NX_KEYTYPE_SOUND_UP, state: 0x0a))
    #expect(parsed.keyType == Int(NX_KEYTYPE_SOUND_UP))
    #expect(parsed.isKeyDown == true)
  }

  @Test func soundUpKeyUp() {
    let parsed = MediaKeyEvent.parse(data1: data1(keyType: NX_KEYTYPE_SOUND_UP, state: 0x0b))
    #expect(parsed.keyType == Int(NX_KEYTYPE_SOUND_UP))
    #expect(parsed.isKeyDown == false)
  }

  @Test func illuminationToggleKeyDown() {
    let parsed = MediaKeyEvent.parse(
      data1: data1(keyType: NX_KEYTYPE_ILLUMINATION_TOGGLE, state: 0x0a))
    #expect(parsed.keyType == Int(NX_KEYTYPE_ILLUMINATION_TOGGLE))
    #expect(parsed.isKeyDown == true)
  }

  /// 系統イベント（NX_SYSDEFINED）の生成。subtype 8 がメディアキー
  func systemDefinedEvent(subtype: Int16, data1: Int) -> CGEvent {
    NSEvent.otherEvent(
      with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
      context: nil, subtype: subtype, data1: data1, data2: -1)!.cgEvent!
  }

  @Test func mediaKeyEventIsBuiltFromSystemDefinedSubtypeEight() {
    let event = systemDefinedEvent(subtype: 8, data1: data1(keyType: NX_KEYTYPE_PLAY, state: 0x0a))
    let mediaKey = MediaKeyEvent(event)
    #expect(mediaKey?.keyCode == Int(NX_KEYTYPE_PLAY))
    #expect(mediaKey?.keyDown == true)
  }

  @Test func otherSystemDefinedSubtypeIsNotMediaKey() {
    let event = systemDefinedEvent(subtype: 7, data1: data1(keyType: NX_KEYTYPE_PLAY, state: 0x0a))
    #expect(MediaKeyEvent(event) == nil)
  }

  @Test func keyboardEventIsNotMediaKey() {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
    #expect(MediaKeyEvent(event) == nil)
  }
}
