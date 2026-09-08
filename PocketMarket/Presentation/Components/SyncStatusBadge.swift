//
//  SyncStatusBadge.swift
//  PocketMarket
//
//  Created by Indu Pandey on 08/09/26.
//
import SwiftUI

struct SyncStatusBadge: View {
    let state: SyncState

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.55), in: Capsule())
            .foregroundStyle(.white)
    }

    private var text: String {
        switch state {
        case .synced: return "Synced"
        case .pendingCreate: return "Pending"
        case .pendingUpdate: return "Pending"
        case .syncing: return "Syncing"
        case .failed: return "Retry"
        }
    }

    private var icon: String {
        switch state {
        case .synced: return "checkmark.circle.fill"
        case .pendingCreate, .pendingUpdate: return "clock.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
}

/// Top-level app-wide sync banner (distinct from the per-item badge above),
/// bound to `SyncStatus` from the repository — shows overall connectivity
/// and queue depth rather than one listing's state.
struct GlobalSyncStatusView: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 6) {
            switch status.state {
            case .idle:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(status.lastSyncedAt.map { "Synced • \($0.formatted(date: .omitted, time: .shortened))" } ?? "Synced")
            case .syncing:
                ProgressView().controlSize(.mini)
                Text("Syncing \(status.pendingCount) change\(status.pendingCount == 1 ? "" : "s")…")
            case .offline:
                Image(systemName: "wifi.slash").foregroundStyle(.orange)
                Text(status.pendingCount > 0 ? "Offline • \(status.pendingCount) queued" : "Offline")
            case .error(let message):
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                Text(message)
            }
        }
        .font(.footnote)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

