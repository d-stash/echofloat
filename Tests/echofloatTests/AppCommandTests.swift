import Testing
@testable import echofloat

@Test @MainActor func unregisterCommandRemovesRegisteredLoginItem() {
    let service = FakeCommandLoginItemService(status: .enabled)
    let manager = AutostartManager(service: service)

    let result = AppCommand.run(
        arguments: ["echofloat", "--unregister-login-item"],
        autostartManager: manager
    )

    #expect(result == 0)
    #expect(service.unregisterCalls == 1)
}

@Test @MainActor func unregisterCommandSucceedsWhenNotRegistered() {
    let service = FakeCommandLoginItemService(status: .notRegistered)

    let result = AppCommand.run(
        arguments: ["echofloat", "--unregister-login-item"],
        autostartManager: AutostartManager(service: service)
    )

    #expect(result == 0)
    #expect(service.unregisterCalls == 0)
}

private final class FakeCommandLoginItemService: LoginItemServicing {
    var status: LoginItemStatus
    private(set) var unregisterCalls = 0

    init(status: LoginItemStatus) {
        self.status = status
    }

    func register() throws {}

    func unregister() throws {
        unregisterCalls += 1
        status = .notRegistered
    }
}
