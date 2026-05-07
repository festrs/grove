import SwiftUI

/// Live view of `NetworkActivityLog`. Lists the recent burst warnings,
/// per-endpoint counts, and the tail of the request stream — designed for
/// catching runaway loops where the same path fires repeatedly.
struct NetworkInspectorView: View {
    @State private var log = NetworkActivityLog.shared

    var body: some View {
        List {
            summarySection
            burstSection
            statsSection
            recentSection
        }
        .navigationTitle("Network Inspector")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") { log.reset() }
            }
        }
    }

    private var sortedStats: [NetworkActivityLog.EndpointStat] {
        log.stats.values.sorted { $0.total > $1.total }
    }

    private var summarySection: some View {
        Section {
            HStack {
                Text("Calls (last 60s)")
                Spacer()
                Text(verbatim: "\(log.totalCallsLastMinute)")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(log.totalCallsLastMinute > 30 ? .orange : .primary)
            }
            HStack {
                Text("Total tracked")
                Spacer()
                Text(verbatim: "\(log.events.count)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var burstSection: some View {
        if !log.burstWarnings.isEmpty {
            Section("Burst warnings") {
                ForEach(log.burstWarnings.reversed(), id: \.self) { warn in
                    Text(verbatim: warn)
                        .font(.caption.monospaced())
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        if !sortedStats.isEmpty {
            Section("Endpoints") {
                ForEach(sortedStats) { stat in
                    endpointRow(stat)
                }
            }
        }
    }

    private func endpointRow(_ stat: NetworkActivityLog.EndpointStat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: stat.key)
                .font(.subheadline.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
            HStack(spacing: 12) {
                Text(verbatim: "\(stat.total)×")
                    .foregroundStyle(.primary)
                if stat.succeeded > 0 {
                    Text(verbatim: "ok \(stat.succeeded)")
                        .foregroundStyle(.green)
                }
                if stat.failed > 0 {
                    Text(verbatim: "fail \(stat.failed)")
                        .foregroundStyle(.red)
                }
                if stat.burstCount > 0 {
                    Text(verbatim: "🔥\(stat.burstCount)")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text(verbatim: "\(stat.lastDurationMS)ms")
                    .foregroundStyle(.secondary)
            }
            .font(.caption.monospaced())
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if !log.events.isEmpty {
            Section("Recent (newest first)") {
                ForEach(Array(log.events.suffix(80).reversed())) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: NetworkActivityLog.Event) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: NetworkActivityLog.timeString(event.timestamp))
                .foregroundStyle(.secondary)
            Text(verbatim: event.method)
                .foregroundStyle(.blue)
            Text(verbatim: event.path)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            statusBadge(event)
            Text(verbatim: "\(event.durationMS)ms")
                .foregroundStyle(.secondary)
        }
        .font(.caption2.monospaced())
    }

    private func statusBadge(_ event: NetworkActivityLog.Event) -> some View {
        Group {
            if let status = event.status {
                Text(verbatim: "\(status)")
                    .foregroundStyle(event.success ? .green : .red)
            } else {
                Text(verbatim: "ERR")
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NetworkInspectorView()
    }
}
