import AppKit
import SwiftUI

struct PanelView: View {
    let store: Store

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            VStack(spacing: 12) {
                if !store.helperInstalled {
                    SetupCard()
                }
                HeroCard(store: store)
                if let message = store.message {
                    Banner(text: message) { store.dismissMessage() }
                } else if store.helperStale {
                    Banner(text: "The helper isn’t responding. Reinstall with sudo ./install.sh.", onClose: nil)
                }
                if store.helperInstalled {
                    StatusGrid(status: store.status, isOn: store.isOn)
                    BatteryCareCard(store: store)
                }
                Footer(store: store)
            }
        }
        .padding(14)
        .frame(width: 340)
        .animation(.smooth(duration: 0.35), value: store.isOn)
        .animation(.smooth(duration: 0.35), value: store.message)
    }
}

// MARK: - Hero

private struct HeroCard: View {
    let store: Store

    private var on: Bool { store.isOn }

    private var subtitle: String {
        guard store.helperInstalled else { return "Finish setup to get started" }
        guard on else { return "Sleeps when the lid closes" }
        if store.pending != nil { return "Turning on…" }
        if store.status?.lidClosed == true { return "Working with the lid closed" }
        return "Ready: close the lid anytime"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { store.setOn(!on) } label: {
                    Image(systemName: on ? "cup.and.heat.waves.fill" : "cup.and.saucer.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(on ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .circle)
                .disabled(!store.helperInstalled)
                .help(on ? "Turn off" : "Stay awake with the lid closed")

                VStack(alignment: .leading, spacing: 2) {
                    Text("MacVibe")
                        .font(.system(size: 15, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 0)
                Toggle("Stay awake with the lid closed", isOn: Binding(get: { on }, set: { store.setOn($0) }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!store.helperInstalled)
            }

            Picker("Mode", selection: Binding(get: { store.preferredMode }, set: { store.choose($0) })) {
                Text("While agents work").tag(Mode.auto)
                Text("Until I turn it off").tag(Mode.forever)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .disabled(!store.helperInstalled)
        }
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

// MARK: - Status tiles

private struct StatusGrid: View {
    let status: Status?
    let isOn: Bool

    var body: some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                battery
                heat
            }
            GridRow {
                agents
                lid
            }
        }
    }

    private var battery: Tile {
        guard let s = status else { return Tile(symbol: "battery.100percent", tint: .secondary, value: "–", caption: "Battery") }
        let level = s.battery
        let symbol = s.charging ? "battery.100percent.bolt"
            : level > 87 ? "battery.100percent" : level > 62 ? "battery.75percent"
            : level > 37 ? "battery.50percent" : level > 12 ? "battery.25percent" : "battery.0percent"
        let tint: Color = s.charging ? .green : level <= 20 ? .red : .primary
        let caption = s.charging ? "Charging" : s.onCharger ? "On charger" : "On battery"
        return Tile(symbol: symbol, tint: tint, value: "\(level)%", caption: caption)
    }

    private var heat: Tile {
        guard let s = status else { return Tile(symbol: "thermometer.medium", tint: .secondary, value: "–", caption: "Temperature") }
        let t = s.temperature
        let (symbol, tint, word): (String, Color, String) =
            s.thermal != "nominal" && s.thermal != "moderate" ? ("thermometer.high", .red, "Hot")
            : t >= 40 ? ("thermometer.high", .orange, "Warm")
            : t >= 36 ? ("thermometer.medium", .yellow, "Warm")
            : ("thermometer.low", .teal, "Cool")
        return Tile(symbol: symbol, tint: tint, value: String(format: "%.1f°", t), caption: "Battery · \(word)")
    }

    private var agents: Tile {
        guard let s = status else { return Tile(symbol: "sparkles", tint: .secondary, value: "–", caption: "Agents") }
        if s.agentsTotal == 0 {
            return Tile(symbol: "sparkles", tint: .secondary, value: "None", caption: "No agents running")
        }
        let working = s.agentsBusy > 0
        return Tile(symbol: "sparkles", tint: working ? .purple : .secondary,
                    value: working ? "\(s.agentsBusy) working" : "Idle",
                    caption: "\(s.agentsTotal) agent session\(s.agentsTotal == 1 ? "" : "s")")
    }

    private var lid: Tile {
        guard let s = status else { return Tile(symbol: "laptopcomputer", tint: .secondary, value: "–", caption: "Lid") }
        let caption: String
        if isOn && s.lidClosed && s.idleLeft >= 0 && s.agentsBusy == 0 {
            caption = "Sleeps in \((s.idleLeft + 59) / 60) min if idle"
        } else if isOn && s.lowPowerActive {
            caption = "Low Power Mode on"
        } else if isOn {
            caption = "Stays awake when closed"
        } else {
            caption = "Sleeps when closed"
        }
        return Tile(symbol: "laptopcomputer",
                    tint: isOn ? .accentColor : .secondary,
                    value: s.lidClosed ? "Closed" : "Open", caption: caption)
    }
}

// MARK: - Battery care

private struct BatteryCareCard: View {
    let store: Store

    var body: some View {
        let s = store.settings
        VStack(spacing: 6) {
            SectionLabel(text: "Battery Care")
            VStack(spacing: 2) {
                StepperRow(symbol: "battery.25percent", title: "Sleep when battery hits", value: s.minBattery,
                           range: 5...60, step: 5, format: { "\($0)%" }) { v in store.update { $0.minBattery = v } }
                Divider().padding(.leading, 28)
                StepperRow(symbol: "thermometer.high", title: "Sleep when warmer than", value: s.maxTemp,
                           range: 35...50, step: 1, format: { "\($0)°C" }) { v in store.update { $0.maxTemp = v } }
                Divider().padding(.leading, 28)
                StepperRow(symbol: "moon.zzz", title: "Sleep when idle for", value: s.idleMinutes,
                           range: 5...120, step: 5, format: { "\($0) min" }) { v in store.update { $0.idleMinutes = v } }
                Divider().padding(.leading, 28)
                HStack(spacing: 10) {
                    RowIcon(symbol: "leaf")
                    Text("Low Power Mode when closed")
                    Spacer(minLength: 8)
                    Toggle("Low Power Mode when closed",
                           isOn: Binding(get: { s.lowPower }, set: { v in store.update { $0.lowPower = v } }))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
                .font(.system(size: 12.5))
                .frame(minHeight: 30)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
            .disabled(!store.helperInstalled)
        }
    }
}

// MARK: - Setup, banners, footer

private struct SetupCard: View {
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Finish setup", systemImage: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
            Text("Install the background helper once. In Terminal, go to the MacVibe folder, run this, and enter your Mac password:")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("sudo ./install.sh")
                    .font(.system(size: 12, design: .monospaced))
                Spacer()
                Button(copied ? "Copied" : "Copy Command") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Store.installCommand, forType: .string)
                    copied = true
                }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .glassEffect(.regular.tint(.orange.opacity(0.25)), in: .rect(cornerRadius: 20))
    }
}

private struct Banner: View {
    let text: String
    let onClose: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(text)
                .font(.system(size: 11.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let onClose {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .glassEffect(.regular.tint(.orange.opacity(0.2)), in: .capsule)
        .transition(.blurReplace)
    }
}

private struct Footer: View {
    let store: Store

    var body: some View {
        VStack(spacing: 8) {
            if let s = store.status, !s.event.isEmpty {
                Text("Last automatic stop: \(s.event), \(s.eventTime.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
            }
            HStack {
                Toggle("Open at Login", isOn: Binding(get: { store.opensAtLogin }, set: { store.setOpensAtLogin($0) }))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11.5))
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.glass)
                    .controlSize(.small)
            }
            .padding(.leading, 6)
        }
    }
}
