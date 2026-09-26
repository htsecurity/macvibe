// Exercises the app's Store against the real helper script (with fake pmset/ioreg).
// Built and run by tests/test_app.sh.
import Foundation

var failures = 0
@MainActor func check(_ name: String, _ ok: Bool) {
    if !ok { print("FAIL \(name)"); failures += 1 }
}

let env = ProcessInfo.processInfo.environment
let share = env["MACVIBE_SHARE"]!
let helper = env["MACVIBE_HELPER"]!

func file(_ name: String) -> String {
    (try? String(contentsOfFile: "\(share)/\(name)", encoding: .utf8)) ?? ""
}

func runHelper() {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: helper)
    try! p.run()
    p.waitUntilExit()
}

let store = Store.shared
store.refresh()
check("helper detected as installed", store.helperInstalled)
check("starts off", !store.isOn)

store.choose(.auto)
store.setOn(true)
check("switch writes an auto request", file("request").contains("mode=auto\n"))
check("request carries this boot", file("request").contains("boot=\(Store.bootID())\n"))
check("switch shows on while waiting", store.isOn && store.pending != nil)

runHelper()
store.refresh()
check("helper applied the request", store.pending == nil)
check("status says active", store.status?.active == true)
check("no error message", store.message == nil)

store.choose(.forever)
check("changing mode while on re-requests", file("request").contains("mode=forever\n"))
runHelper()
store.refresh()
check("forever applied", store.status?.mode == .forever)

store.update { $0.idleMinutes = 25 }
check("settings saved", file("settings").contains("idle_minutes=25\n"))
runHelper()
store.refresh()
check("settings read back", store.settings.idleMinutes == 25)
check("helper echoes settings", store.status?.text("idle_minutes") == "25")

store.setOn(false)
check("switch off writes off", file("request").contains("mode=off\n"))
runHelper()
store.refresh()
check("off applied", !store.isOn && store.status?.active == false)

UserDefaults.standard.removeObject(forKey: "preferredMode")
print(failures == 0 ? "ok" : "\(failures) failed")
exit(failures == 0 ? 0 : 1)
