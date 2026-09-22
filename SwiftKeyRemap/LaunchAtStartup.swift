// MIT License
// Copyright (c) 2016 iMasanari

import ServiceManagement

/// The system is the source of truth for launch at login.
final class LaunchAtStartup {
  static let shared = LaunchAtStartup()

  private let readStatus: () -> SMAppService.Status
  private let register: () throws -> Void
  private let unregister: () throws -> Void

  init(
    status: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
    register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
    unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }
  ) {
    self.readStatus = status
    self.register = register
    self.unregister = unregister
  }

  var status: SMAppService.Status { readStatus() }

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      if status != .enabled && status != .requiresApproval { try register() }
    } else if status != .notRegistered {
      try unregister()
    }
  }
}
