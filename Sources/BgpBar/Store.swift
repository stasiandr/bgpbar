import Foundation
import UserNotifications

/// One `~/.claude/progress/<id>.json` state file written by bgp.
struct BgpTask: Identifiable, Decodable, Equatable {
    let id: String
    let label: String
    let pid: Int32
    let cmd: [String]
    var status: String
    let started: Double
    let updated: Double
    let frac: Double?
    let eta: Double?
    let guess: Double?
    let failures: Int
    let last_line: String
    let summary: String
    let counts: String?
    let cwd: String?

    var isRunning: Bool { status == "running" }
    var logURL: URL { Store.dir.appendingPathComponent("\(id).log") }

    var elapsed: Double { (isRunning ? Date().timeIntervalSince1970 : updated) - started }

    /// Real progress when bgp parsed it, otherwise elapsed time against the -e guess.
    var progress: (value: Double, estimated: Bool)? {
        if let frac { return (min(max(frac, 0), 1), false) }
        if let guess, guess > 0 { return (min(elapsed / guess, 1), true) }
        return nil
    }

    /// "124/200 · 25s · ещё ~15s", the same line bgp prints in the Tasks pane.
    var detail: String {
        var parts: [String] = []
        if let counts { parts.append(counts) }
        parts.append(fmtDur(elapsed))
        if isRunning {
            if frac != nil {
                parts.append(eta.map { "ещё ~\(fmtDur($0))" } ?? "ещё ?")
            } else if let guess {
                parts.append(elapsed <= guess ? "из ~\(fmtDur(guess))" : "дольше на \(fmtDur(elapsed - guess))")
            }
        } else {
            parts.append(status == "done" ? "готово" : status)
        }
        if failures > 0 { parts.append("✗ \(failures) failed") }
        return parts.joined(separator: " · ")
    }
}

func fmtDur(_ s: Double) -> String {
    let s = Int(s.rounded())
    if s < 60 { return "\(s)s" }
    if s < 3600 { return String(format: "%dm%02ds", s / 60, s % 60) }
    return String(format: "%dh%02dm", s / 3600, s % 3600 / 60)
}

@MainActor
final class Store: ObservableObject {
    nonisolated static let dir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/progress")
    /// Finished tasks stay listed this long, like `bgp status`.
    static let keepFinished: Double = 3600

    @Published private(set) var tasks: [BgpTask] = []
    @Published private(set) var tick = Date()

    private var dismissed: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "dismissed") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "dismissed") }
    }
    private var knownRunning: Set<String> = []
    private var timer: Timer?

    var running: [BgpTask] { tasks.filter(\.isRunning) }
    var recentFailure: Bool { tasks.contains { $0.status != "running" && $0.status != "done" } }

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func reload() {
        tick = Date()
        let now = tick.timeIntervalSince1970
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.dir, includingPropertiesForKeys: nil)) ?? []
        let hidden = dismissed
        var fresh: [BgpTask] = []
        for f in files where f.pathExtension == "json" {
            guard let data = try? Data(contentsOf: f),
                  var t = try? JSONDecoder().decode(BgpTask.self, from: data) else { continue }
            if t.isRunning && kill(t.pid, 0) != 0 && errno == ESRCH { t.status = "died" }
            if !t.isRunning && (now - t.updated > Self.keepFinished || hidden.contains(t.id)) { continue }
            fresh.append(t)
        }
        fresh.sort { ($0.isRunning ? 0 : 1, -$0.started) < ($1.isRunning ? 0 : 1, -$1.started) }

        // Notify about tasks we saw running that have just finished.
        for t in fresh where !t.isRunning && knownRunning.contains(t.id) { notify(t) }
        knownRunning = Set(fresh.filter(\.isRunning).map(\.id))

        if fresh != tasks { tasks = fresh }
    }

    func dismiss(_ t: BgpTask) {
        dismissed.insert(t.id)
        reload()
    }

    func clearFinished() {
        dismissed.formUnion(tasks.filter { !$0.isRunning }.map(\.id))
        reload()
    }

    /// bgp forwards SIGINT to the command, then records the exit as failed.
    func stop(_ t: BgpTask) {
        kill(t.pid, SIGINT)
    }

    private func notify(_ t: BgpTask) {
        let c = UNMutableNotificationContent()
        c.title = (t.status == "done" ? "✓ " : "✗ ") + t.label
        c.body = t.detail
        if t.status != "done" { c.sound = .default }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: t.id, content: c, trigger: nil))
    }
}
