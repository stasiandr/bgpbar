import AppKit
import ServiceManagement
import SwiftUI

@main
struct BgpBarApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            MenuLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar item: the leading running task's percent, or a quiet gauge when idle.
struct MenuLabel: View {
    @ObservedObject var store: Store

    var body: some View {
        let running = store.running
        if let first = running.first {
            let pct = first.progress.map { "\($0.estimated ? "~" : "")\(Int($0.value * 100))%" } ?? fmtDur(first.elapsed)
            let more = running.count > 1 ? " +\(running.count - 1)" : ""
            Label("\(pct)\(more)", systemImage: progressSymbol(first.progress?.value ?? 0))
                .labelStyle(.titleAndIcon)
        } else if store.recentFailure {
            Image(systemName: "exclamationmark.circle")
        } else {
            Image(systemName: "gauge.with.dots.needle.0percent")
        }
    }

    private func progressSymbol(_ v: Double) -> String {
        switch v {
        case ..<0.25: "circle.dotted"
        case ..<0.5: "circle.lefthalf.filled"
        case ..<0.75: "circle.bottomrighthalf.pattern.checkered"
        default: "circle.fill"
        }
    }
}

struct PanelView: View {
    @ObservedObject var store: Store
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.tasks.isEmpty {
                Text("Нет задач bgp")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(24)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(store.tasks) { t in
                            TaskRow(task: t, store: store)
                            if t.id != store.tasks.last?.id { Divider() }
                        }
                    }
                }
                .frame(maxHeight: 460)
                .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Toggle("При входе", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { _, on in
                        try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
                Spacer()
                if store.tasks.contains(where: { !$0.isRunning }) {
                    Button("Убрать завершённые") { store.clearFinished() }
                }
                Button("Выйти") { NSApp.terminate(nil) }
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 380)
    }
}

struct TaskRow: View {
    let task: BgpTask
    @ObservedObject var store: Store
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                statusIcon
                Text(task.label).font(.headline).lineLimit(1)
                Spacer()
                if hover { actions }
            }
            if let p = task.progress, task.isRunning {
                ProgressView(value: p.value)
                    .tint(p.estimated ? .secondary : .accentColor)
                    .help(p.estimated ? "Прогресс по оценке -e" : "Прогресс из вывода команды")
            }
            Text(task.detail)
                .font(.caption.monospacedDigit())
                .foregroundStyle(task.status == "done" || task.isRunning ? Color.secondary : Color.red)
            if !task.last_line.isEmpty {
                Text("› " + task.last_line)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .background(hover ? Color.primary.opacity(0.05) : .clear)
        .onHover { hover = $0 }
        .onTapGesture { NSWorkspace.shared.open(task.logURL) }
        .help(([task.cwd].compactMap { $0 } + [task.cmd.joined(separator: " ")]).joined(separator: "\n"))
    }

    @ViewBuilder private var statusIcon: some View {
        switch task.status {
        case "running": ProgressView().controlSize(.mini)
        case "done": Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        default: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 8) {
            Button { NSWorkspace.shared.open(task.logURL) } label: { Image(systemName: "doc.text") }
                .help("Открыть лог")
            if task.isRunning {
                Button { store.stop(task) } label: { Image(systemName: "stop.circle") }
                    .help("Остановить (SIGINT)")
            } else {
                Button { store.dismiss(task) } label: { Image(systemName: "xmark") }
                    .help("Убрать из списка")
            }
        }
        .buttonStyle(.borderless)
    }
}
