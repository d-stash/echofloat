import Foundation
import Testing
@testable import echofloat

private enum FakeError: Error {
    case register
    case unregister
}

private final class FakeLoginItemService: LoginItemServicing {
    var status: LoginItemStatus = .notRegistered
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0

    func register() throws {
        registerCalls += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCalls += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

private func makeLegacyLaunchAgentsDirectory() throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let directory = packageRoot
        .appendingPathComponent(".test-artifacts", isDirectory: true)
        .appendingPathComponent("AutostartManagerTests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

@Test func reflectsServiceStatus() {
    let service = FakeLoginItemService()
    service.status = .requiresApproval

    let manager = AutostartManager(service: service)

    #expect(manager.status == .requiresApproval)
    #expect(manager.isEnabled == false)
}

@Test func enablingRegistersMainApp() throws {
    let service = FakeLoginItemService()
    let manager = AutostartManager(service: service)

    try manager.setEnabled(true)

    #expect(service.registerCalls == 1)
    #expect(manager.isEnabled)
}

@Test func disablingUnregistersMainApp() throws {
    let service = FakeLoginItemService()
    service.status = .enabled

    let manager = AutostartManager(service: service)

    try manager.setEnabled(false)

    #expect(service.unregisterCalls == 1)
    #expect(manager.isEnabled == false)
}

@Test func registrationErrorsPropagate() {
    let service = FakeLoginItemService()
    service.registerError = FakeError.register

    let manager = AutostartManager(service: service)

    #expect(throws: FakeError.self) {
        try manager.setEnabled(true)
    }
}

@Test func unregisterErrorsPropagate() {
    let service = FakeLoginItemService()
    service.status = .enabled
    service.unregisterError = FakeError.unregister

    let manager = AutostartManager(service: service)

    #expect(throws: FakeError.self) {
        try manager.unregisterIfRegistered()
    }
}

@Test func unregisteringAnUnregisteredAppIsANoOp() throws {
    let service = FakeLoginItemService()
    let manager = AutostartManager(service: service)

    try manager.unregisterIfRegistered()

    #expect(service.unregisterCalls == 0)
}

@Test func removesLegacyLaunchAgent() throws {
    let directory = try makeLegacyLaunchAgentsDirectory()
    defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

    let plist = directory.appendingPathComponent("com.echofloat.autostart.plist")
    try "legacy".write(to: plist, atomically: true, encoding: .utf8)

    let manager = AutostartManager(
        service: FakeLoginItemService(),
        legacyLaunchAgentsDirectory: directory
    )

    try manager.removeLegacyLaunchAgent()

    #expect(FileManager.default.fileExists(atPath: plist.path) == false)
}
