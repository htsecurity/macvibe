import Foundation
import Observation
import ServiceManagement

enum Mode: String {
    case off, auto, forever
}

/// The helper's status file (`key=value` lines written by the root helper).
struct Status {
    var values: [String: String]

    init(text: String) {
        var v: [String: String] = [:]
        for line in text.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            v[String(line[..<eq])] = String(line[line.index(after: eq)...])
        }
        values = v
    }

    func int(_ key: String) -> Int { Int(values[key] ?? "") ?? 0 }
    func text(_ key: String) -> String { values[key] ?? "" }

    var updated: Date { Date(timeIntervalSince1970: Double(int("updated"))) }
    var active: Bool { text("active") == "1" }
    var mode: Mode { Mode(rawValue: text("mode")) ?? .off }
    var lidClosed: Bool { text("lid") == "closed" }
    var onCharger: Bool { text("power") == "ac" }
    var charging: Bool { text("charging") == "1" }
    var battery: Int { int("battery") }
    var temperature: Double { Double(text("temp")) ?? 0 }
    var thermal: String { text("thermal") }
    var agentsBusy: Int { int("agents_busy") }
    var agentsTotal: Int { int("agents_total") }
    var idleLeft: Int { Int(text("idle_left")) ?? -1 }
    var lowPowerActive: Bool { text("lowpower_active") == "1" }
    var event: String { text("event") }
    var eventTime: Date { Date(timeIntervalSince1970: Double(int("event_time"))) }
}

struct Settings {
    var minBattery = 20
    var maxTemp = 42
    var idleMinutes = 15
    var lowPower = true
}

@MainActor @Observable
final class Store {
    static let shared = Store()

    private(set) var status: Status?
    private(set) var settings = Settings()
    private(set) var helperInstalled = false
    private(set) var message: String?
    /// The mode we asked for and are waiting on the helper to apply.
    private(set) var pending: (mode: Mode, since: Int, asked: Date)?
    var preferredMode: Mode {
        didSet { UserDefaults.standard.set(preferredMode.rawValue, forKey: "preferredMode") }
    }

    private let shareDir: String
    private let stateDir: String
    private var loop: Task<Void, Never>?

    init() {
        let env = ProcessInfo.processInfo.environment
        shareDir = env["MACVIBE_SHARE"] ?? "/Library/Application Support/macvibe"
        stateDir = env["MACVIBE_STATE"] ?? "/var/db/macvibe"
        preferredMode = Mode(rawValue: UserDefaults.standard.string(forKey: "preferredMode") ?? "") ?? .auto
        if preferredMode == .off { preferredMode = .auto }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    // MARK: Derived state

    var isOn: Bool {
        if let pending { return pending.mode != .off }
        return status?.active ?? false
    }

    var helperStale: Bool {
        guard let status, helperInstalled else { return false }
        return Date().timeIntervalSince(status.updated) > 90
    }

    // MARK: Reading

    func refresh() {
        helperInstalled = FileManager.default.isWritableFile(atPath: "\(shareDir)/request")
        if let text = try? String(contentsOfFile: "\(stateDir)/status", encoding: .utf8) {
            status = Status(text: text)
        }
        settings = readSettings()
        resolvePending()
    }

    private func resolvePending() {
        guard let pending, let status else { return }
        let applied = pending.mode == .off
            ? status.text("requested") == "off"
            : status.text("session") == String(pending.since)
        if applied {
            self.pending = nil
            if pending.mode != .off && !status.active && !status.event.isEmpty {
                message = "Can’t stay awake: \(status.event)"
            }
        } else if Date().timeIntervalSince(pending.asked) > 8 {
            self.pending = nil
            message = "The helper didn’t respond. Try reinstalling."
        }
    }

    private func readSettings() -> Settings {
        var s = Settings()
        guard let text = try? String(contentsOfFile: "\(shareDir)/settings", encoding: .utf8) else { return s }
        let v = Status(text: text)
        func clamp(_ key: String, _ fallback: Int, _ range: ClosedRange<Int>) -> Int {
            guard let n = Int(v.text(key)) else { return fallback }
            return min(max(n, range.lowerBound), range.upperBound)
        }
        s.minBattery = clamp("min_battery", s.minBattery, 5...60)
        s.maxTemp = clamp("max_temp", s.maxTemp, 35...50)
        s.idleMinutes = clamp("idle_minutes", s.idleMinutes, 1...240)
        s.lowPower = clamp("low_power", 1, 0...1) == 1
        return s
    }

    // MARK: Writing (plain files the helper watches; no password needed)

    func setOn(_ on: Bool) {
        request(on ? preferredMode : .off)
    }

    func choose(_ mode: Mode) {
        preferredMode = mode
        if isOn { request(mode) }
    }

    private func request(_ mode: Mode) {
        message = nil
        let since = Int(Date().timeIntervalSince1970)
        let text = "mode=\(mode.rawValue)\nsince=\(since)\nboot=\(Self.bootID())\n"
        do {
            // Write in place: the file belongs to you inside a root-owned folder.
            try text.write(toFile: "\(shareDir)/request", atomically: false, encoding: .utf8)
            pending = (mode, since, Date())
        } catch {
            message = "Couldn’t reach the helper. Is it installed?"
        }
    }

    func update(_ change: (inout Settings) -> Void) {
        change(&settings)
        let s = settings
        let text = "min_battery=\(s.minBattery)\nmax_temp=\(s.maxTemp)\nidle_minutes=\(s.idleMinutes)\nlow_power=\(s.lowPower ? 1 : 0)\n"
        do {
            try text.write(toFile: "\(shareDir)/settings", atomically: false, encoding: .utf8)
        } catch {
            message = "Couldn’t save settings. Is the helper installed?"
        }
    }

    func dismissMessage() { message = nil }

    // MARK: Open at login

    private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled

    func setOpensAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            message = "Couldn’t change Open at Login: \(error.localizedDescription)"
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: Helpers

    static func bootID() -> Int {
        var tv = timeval()
        var size = MemoryLayout<timeval>.size
        sysctlbyname("kern.boottime", &tv, &size, nil, 0)
        return tv.tv_sec
    }

    static var installCommand: String {
        let dir = Bundle.main.object(forInfoDictionaryKey: "MacVibeSourceDir") as? String ?? "~/macvibe"
        return "cd '\(dir)' && sudo ./install.sh"
    }
}
