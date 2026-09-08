//
//  Reachability.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//  Thin wrapper over NWPathMonitor, exposed as a Combine publisher so the
//  SyncEngine and UI sync-status badge can both observe connectivity
//  without polling.
//

import Foundation
import Network
import Combine
import os

private let logger = Logger(subsystem: "com.pocketmarket", category: "Reachability")

final class Reachability {
    static let shared = Reachability()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.pocketmarket.reachability")

    /// CurrentValueSubject instead of @Published so `.value` is already
    /// updated when subscribers fire — avoids the willSet timing pitfall.
    private let _isConnected = CurrentValueSubject<Bool, Never>(true)

    var isConnected: Bool { _isConnected.value }

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        _isConnected.eraseToAnyPublisher()
    }

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                logger.notice("NWPathMonitor → connected=\(connected)")
                self?._isConnected.send(connected)
            }
        }
        monitor.start(queue: queue)
    }

    /// Force a fresh connectivity check by starting a one-shot
    /// NWPathMonitor probe. The long-lived monitor can miss WiFi
    /// reconnects on the simulator; this catches the stale state.
    func recheckConnectivity() {
        let probe = NWPathMonitor()
        probe.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            DispatchQueue.main.async {
                let current = self?._isConnected.value ?? false
                if connected != current {
                    logger.notice("Probe detected change: \(current) → \(connected)")
                    self?._isConnected.send(connected)
                }
            }
            probe.cancel()
        }
        probe.start(queue: queue)
    }
}


