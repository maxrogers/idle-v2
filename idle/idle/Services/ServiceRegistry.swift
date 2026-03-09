import Foundation
import SwiftUI
import Observation

@Observable
final class ServiceRegistry {
    private(set) var services: [any VideoServicePlugin] = []
    private(set) var enabledServiceIDs: Set<String> = []
    private(set) var serviceOrder: [String] = []

    private let defaults = UserDefaults.standard
    private let orderKey = "serviceOrder"
    private let enabledKey = "enabledServices"

    init() {
        loadPersistedState()
    }

    var enabledServices: [any VideoServicePlugin] {
        serviceOrder.compactMap { id in
            services.first { $0.id == id }
        }.filter { enabledServiceIDs.contains($0.id) }
    }

    func register(_ service: any VideoServicePlugin) {
        guard !services.contains(where: { $0.id == service.id }) else { return }
        services.append(service)
        if !serviceOrder.contains(service.id) {
            serviceOrder.append(service.id)
            persistState()
        }
    }

    func setEnabled(_ serviceID: String, enabled: Bool) {
        if enabled {
            enabledServiceIDs.insert(serviceID)
        } else {
            enabledServiceIDs.remove(serviceID)
        }
        persistState()
    }

    func moveService(from source: IndexSet, to destination: Int) {
        serviceOrder.move(fromOffsets: source, toOffset: destination)
        persistState()
    }

    func isEnabled(_ serviceID: String) -> Bool {
        enabledServiceIDs.contains(serviceID)
    }

    // MARK: - Private

    private func loadPersistedState() {
        if let order = defaults.stringArray(forKey: orderKey) {
            serviceOrder = order
        }
        if let enabled = defaults.stringArray(forKey: enabledKey) {
            enabledServiceIDs = Set(enabled)
        }
    }

    private func persistState() {
        defaults.set(serviceOrder, forKey: orderKey)
        defaults.set(Array(enabledServiceIDs), forKey: enabledKey)
    }
}
