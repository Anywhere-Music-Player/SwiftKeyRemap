import Foundation
import ServiceManagement
import Testing
@testable import SwiftKeyRemap

struct LaunchAtStartupTests {
  @Test func enablingRegistersAndDisablingUnregisters() throws {
    var state: SMAppService.Status = .notRegistered
    var registrations = 0
    var removals = 0
    let service = LaunchAtStartup(
      status: { state },
      register: { registrations += 1; state = .enabled },
      unregister: { removals += 1; state = .notRegistered })
    try service.setEnabled(true)
    #expect(service.status == .enabled)
    try service.setEnabled(true)
    #expect(registrations == 1)
    try service.setEnabled(false)
    #expect(service.status == .notRegistered)
    try service.setEnabled(false)
    #expect(removals == 1)
  }

  @Test func pendingApprovalIsNotRegisteredAgainAndCanBeCancelled() throws {
    var state: SMAppService.Status = .requiresApproval
    var registrations = 0
    let service = LaunchAtStartup(
      status: { state }, register: { registrations += 1 },
      unregister: { state = .notRegistered })
    try service.setEnabled(true)
    #expect(registrations == 0)
    #expect(service.status == .requiresApproval)
    try service.setEnabled(false)
    #expect(service.status == .notRegistered)
  }

  @Test func registrationAndRemovalErrorsPropagateWithoutClaimingSuccess() {
    let error = NSError(domain: "Test", code: 1)
    let disabled = LaunchAtStartup(status: { .notRegistered }, register: { throw error })
    #expect(throws: (any Error).self) { try disabled.setEnabled(true) }
    #expect(disabled.status == .notRegistered)
    let enabled = LaunchAtStartup(status: { .enabled }, unregister: { throw error })
    #expect(throws: (any Error).self) { try enabled.setEnabled(false) }
    #expect(enabled.status == .enabled)
  }
}
