//
//  ShortcutsScreenTests.swift
//  cmd-eikanaTests
//

import Cocoa
import Testing

@testable import _英かな

/// キーリマップ一覧の画面の操作。グローバルの設定と保存先を退避して差し替えるので、
/// 同じグローバルを触る ShortcutsControllerTests と同じ suite（直列実行）に置く
extension GlobalStateTests.ShortcutsControllerTests {

  /// グローバルの設定と保存先を退避し、テスト用の一覧と記録用の保存先に差し替える
  @MainActor
  final class ScreenFixture {
    let controller = PreferenceScreens.shortcuts
    let defaults = RecordingDefaults(suiteName: nil)!
    private let originalList = keyMappingList
    private let originalShortcutList = shortcutList
    private let originalDefaults = settingsDefaults
    private let originalTextField = activeKeyTextField

    init(mappings: [KeyMapping]) {
      keyMappingList = mappings
      keyMappingListToShortcutList()
      settingsDefaults = defaults
      activeKeyTextField = nil
    }

    func restore() {
      keyMappingList = originalList
      shortcutList = originalShortcutList
      settingsDefaults = originalDefaults
      activeKeyTextField = originalTextField
    }

    var savedMappings: [[AnyHashable: Any]]? {
      defaults.lastValue(forKey: "mappings") as? [[AnyHashable: Any]]
    }

    func column(_ identifier: String) -> NSTableColumn {
      controller.tableView.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier(identifier))!
    }
  }

  func menu(selecting operation: MappingMenuOperation, row: Int) -> MappingMenu {
    let menu = MappingMenu(frame: .zero, pullsDown: true)
    menu.addItems(withTitles: ["…", "top", "up", "down", "bottom", "remove"])
    for (index, item) in menu.itemArray.enumerated() {
      item.tag = index
    }
    menu.select(menu.item(at: operation.rawValue))
    menu.row = row
    return menu
  }

  // MARK: - 行の追加・削除・並べ替え・有効切り替え

  @MainActor @Test func addRowAppendsDefaultMappingAndSaves() {
    let fixture = ScreenFixture(mappings: [createMapping(inputKeyCode: 55, outputKeyCode: 102)])
    defer { fixture.restore() }

    fixture.controller.addRow(NSButton())

    #expect(keyMappingList.count == 2)
    #expect(keyMappingList[1].input.keyCode == 0)
    #expect(fixture.savedMappings?.count == 2)
  }

  @MainActor @Test func toggleEnableFlipsTheRowAndRebuildsShortcutList() {
    let fixture = ScreenFixture(mappings: [createMapping(inputKeyCode: 55, outputKeyCode: 102)])
    defer { fixture.restore() }
    let button = NSButton()
    button.tag = 0

    fixture.controller.toggleEnable(button)

    #expect(keyMappingList[0].enable == false)
    #expect(shortcutList[55] == nil)
    #expect((fixture.savedMappings?[0]["enable"] as? Bool) == false)
  }

  @MainActor @Test func removeMenuDeletesTheRow() {
    let fixture = ScreenFixture(mappings: [
      createMapping(inputKeyCode: 55, outputKeyCode: 102),
      createMapping(inputKeyCode: 54, outputKeyCode: 104),
    ])
    defer { fixture.restore() }

    fixture.controller.remove(menu(selecting: .remove, row: 0))

    #expect(keyMappingList.map { $0.input.keyCode } == [54])
    #expect(fixture.savedMappings?.count == 1)
  }

  @MainActor @Test func moveToBottomMenuReordersRows() {
    let fixture = ScreenFixture(mappings: [
      createMapping(inputKeyCode: 55, outputKeyCode: 102),
      createMapping(inputKeyCode: 54, outputKeyCode: 104),
    ])
    defer { fixture.restore() }

    fixture.controller.remove(menu(selecting: .moveToBottom, row: 0))

    #expect(keyMappingList.map { $0.input.keyCode } == [54, 55])
  }

  @MainActor @Test func menuWithUnknownTagChangesNothing() {
    let fixture = ScreenFixture(mappings: [createMapping(inputKeyCode: 55, outputKeyCode: 102)])
    defer { fixture.restore() }
    let menu = MappingMenu(frame: .zero, pullsDown: true)
    menu.addItems(withTitles: ["…"])
    menu.row = 0

    fixture.controller.remove(menu)

    #expect(keyMappingList.map { $0.input.keyCode } == [55])
  }

  @MainActor @Test func removeMenuBlursTheActiveTextField() {
    let fixture = ScreenFixture(mappings: [createMapping(inputKeyCode: 55, outputKeyCode: 102)])
    defer { fixture.restore() }
    let field = KeyTextField(frame: .zero)
    activeKeyTextField = field

    fixture.controller.remove(menu(selecting: .remove, row: 0))

    #expect(activeKeyTextField == nil)
  }

  // MARK: - セルの生成

  @MainActor @Test func inputAndOutputCellsShowTheMapping() {
    let fixture = ScreenFixture(mappings: [createMapping(inputKeyCode: 55, outputKeyCode: 102)])
    defer { fixture.restore() }
    let controller = fixture.controller

    let inputCell =
      controller.tableView(controller.tableView, viewFor: fixture.column("input"), row: 0)
      as? NSTableCellView
    let outputCell =
      controller.tableView(controller.tableView, viewFor: fixture.column("output"), row: 0)
      as? NSTableCellView
    let inputField = inputCell?.subviews.first as? KeyTextField
    let outputField = outputCell?.subviews.first as? KeyTextField

    #expect(inputField?.stringValue == "Command_L")
    #expect(inputField?.isAllowModifierOnly == true)
    #expect(inputField?.saveAddress?.row == 0)
    #expect(inputField?.saveAddress?.id == "input")
    #expect(outputField?.stringValue == "英数")
    #expect(outputField?.isAllowModifierOnly == false)
    #expect(outputField?.saveAddress?.id == "output")
  }

  @MainActor @Test func enableCellReflectsTheRowAndTargetsToggle() {
    let fixture = ScreenFixture(mappings: [
      createMapping(inputKeyCode: 55, outputKeyCode: 102, enable: false)
    ])
    defer { fixture.restore() }
    let controller = fixture.controller

    let cell =
      controller.tableView(controller.tableView, viewFor: fixture.column("enable"), row: 0)
      as? NSTableCellView
    let button = cell?.subviews.first as? NSButton

    #expect(button?.state == .off)
    #expect(button?.tag == 0)
    #expect(button?.action == #selector(ShortcutsController.toggleEnable(_:)))
  }

  @MainActor @Test func menuCellCarriesTheRow() {
    let fixture = ScreenFixture(mappings: [
      createMapping(inputKeyCode: 55, outputKeyCode: 102),
      createMapping(inputKeyCode: 54, outputKeyCode: 104),
    ])
    defer { fixture.restore() }
    let controller = fixture.controller

    let cell =
      controller.tableView(controller.tableView, viewFor: fixture.column("mapping-menu"), row: 1)
      as? NSTableCellView
    let menu = cell?.subviews.first as? MappingMenu

    #expect(menu?.row == 1)
    #expect(menu?.action == #selector(ShortcutsController.remove(_:)))
  }

  @MainActor @Test func numberOfRowsFollowsTheList() {
    let fixture = ScreenFixture(mappings: [
      createMapping(inputKeyCode: 55, outputKeyCode: 102),
      createMapping(inputKeyCode: 54, outputKeyCode: 104),
    ])
    defer { fixture.restore() }
    #expect(fixture.controller.numberOfRows(in: fixture.controller.tableView) == 2)
  }

  // MARK: - 入力欄の編集終了

  @MainActor @Test func endingEditWithKnownTextAppliesToTheRow() {
    let fixture = ScreenFixture(mappings: [createMapping(inputKeyCode: 55, outputKeyCode: 0)])
    defer { fixture.restore() }
    let field = KeyTextField(frame: .zero)
    field.saveAddress = (row: 0, id: "output")
    field.isAllowModifierOnly = false
    field.stringValue = "英数"
    activeKeyTextField = field

    field.commitEditedText()

    #expect(keyMappingList[0].output.keyCode == 102)
    #expect(shortcutList[55]?.first?.output.keyCode == 102)
    #expect(field.stringValue == "英数")
    #expect(activeKeyTextField == nil)
    #expect(fixture.savedMappings?.count == 1)
  }

  @MainActor @Test func endingEditWithUnknownTextKeepsTheCurrentShortcut() {
    let fixture = ScreenFixture(mappings: [createMapping(inputKeyCode: 55, outputKeyCode: 102)])
    defer { fixture.restore() }
    let field = KeyTextField(frame: .zero)
    field.saveAddress = (row: 0, id: "output")
    field.shortcut = keyMappingList[0].output
    field.stringValue = "foo"

    field.commitEditedText()

    #expect(keyMappingList[0].output.keyCode == 102)
    #expect(field.stringValue == "英数")
  }

  @MainActor @Test func endingEditWithUnknownTextAndNoShortcutClearsTheField() {
    let fixture = ScreenFixture(mappings: [createMapping(inputKeyCode: 55, outputKeyCode: 102)])
    defer { fixture.restore() }
    let field = KeyTextField(frame: .zero)
    field.stringValue = "foo"

    field.commitEditedText()

    #expect(field.stringValue == "")
    #expect(keyMappingList[0].output.keyCode == 102)
  }

  @MainActor @Test func blurClearsTheActiveTextField() {
    let fixture = ScreenFixture(mappings: [])
    defer { fixture.restore() }
    let field = KeyTextField(frame: .zero)
    activeKeyTextField = field

    field.blur()

    #expect(activeKeyTextField == nil)
  }
}
