//
//  MediaKeyEventTests.swift
//  cmd-eikanaTests
//

import Foundation
import Testing

@testable import _英かな

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
}
