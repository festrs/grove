import SwiftUI

// MARK: - Router

private struct RouterKey: EnvironmentKey {
    static let defaultValue = Router()
}

extension EnvironmentValues {
    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}

// MARK: - Backend Service

private struct BackendServiceKey: EnvironmentKey {
    static let defaultValue: any BackendServiceProtocol = MockBackendService()
}

extension EnvironmentValues {
    var backendService: any BackendServiceProtocol {
        get { self[BackendServiceKey.self] }
        set { self[BackendServiceKey.self] = newValue }
    }
}

// MARK: - Sync Service

private struct SyncServiceKey: EnvironmentKey {
    static let defaultValue = SyncService()
}

extension EnvironmentValues {
    var syncService: SyncService {
        get { self[SyncServiceKey.self] }
        set { self[SyncServiceKey.self] = newValue }
    }
}

