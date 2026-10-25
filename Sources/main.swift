import AppKit
import SwiftUI
import ServiceManagement
import IOKit
import IOKit.pwr_mgt

typealias LocalState<Value> = SwiftUI.State<Value>

let appID = "local.naco.RestLeaf"
let accent = Color(red: 0.12, green: 0.51, blue: 0.43)

struct Preferences {
    var work: Int = 40
    var rest: Int = 10
    var showTime = false
    var sound = false
    var language: AppLanguage = .system
    static func load() -> Self {
        let d = UserDefaults.standard
        return Self(work: max(1, min(240, d.object(forKey: "work") as? Int ?? 40)),
                    rest: max(1, min(120, d.object(forKey: "rest") as? Int ?? 10)),
                    showTime: d.bool(forKey: "showTime"), sound: d.bool(forKey: "sound"),
                    language: AppLanguage(rawValue: d.string(forKey: "language") ?? "system") ?? .system)
    }
    func save() {
        let d = UserDefaults.standard
        d.set(work, forKey: "work"); d.set(rest, forKey: "rest")
        d.set(showTime, forKey: "showTime"); d.set(sound, forKey: "sound"); d.set(language.rawValue, forKey: "language")
    }
}

struct SettingsView: View {
    @LocalState var prefs: Preferences
    @LocalState var launchAtLogin: Bool
    @LocalState var error = ""
    var save: (Preferences, Bool) -> String?
    var preview: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage).resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L("app_name")).font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(L("tagline")).foregroundStyle(.secondary)
                }
                Spacer()
            }
            VStack(spacing: 18) {
                HStack {
                    Label(L("screen_time"), systemImage: "display"); Spacer()
                    Stepper(value: $prefs.work, in: 1...240) {
                        HStack { TextField(L("minutes_unit"), value: $prefs.work, format: .number).textFieldStyle(.roundedBorder).frame(width: 52).accessibilityLabel(L("work_accessibility")); Text(L("minutes_unit")) }
                    }.fixedSize()
                }
                HStack {
                    Label(L("break_duration"), systemImage: "leaf"); Spacer()
                    Stepper(value: $prefs.rest, in: 1...120) {
                        HStack { TextField(L("minutes_unit"), value: $prefs.rest, format: .number).textFieldStyle(.roundedBorder).frame(width: 52).accessibilityLabel(L("rest_accessibility")); Text(L("minutes_unit")) }
                    }.fixedSize()
                }
            }.padding(18).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 15) {
                Toggle(L("launch_login"), isOn: $launchAtLogin)
                Toggle(L("show_time"), isOn: $prefs.showTime)
                Toggle(L("sound"), isOn: $prefs.sound)
            }.toggleStyle(.switch)
            Picker(L("language"), selection: $prefs.language) {
                Text(L("follow_system")).tag(AppLanguage.system)
                Text("English").tag(AppLanguage.english)
                Text("简体中文").tag(AppLanguage.chinese)
            }
            Text(L("usage_hint"))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            HStack {
                Button(L("preview"), action: preview)
                Spacer()
                Button(L("save")) {
                    prefs.work = max(1, min(240, prefs.work)); prefs.rest = max(1, min(120, prefs.rest))
                    error = save(prefs, launchAtLogin) ?? ""
                }.buttonStyle(.borderedProminent).tint(accent).keyboardShortcut(.defaultAction)
            }
            Text(L("footer"))
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }.padding(26).frame(width: 500).background(Color(nsColor: .windowBackgroundColor))
    }
}

struct RestButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .foregroundStyle(prominent ? Color.white : Color.primary)
            .background(prominent ? accent.opacity(configuration.isPressed ? 0.7 : 1) : Color.primary.opacity(configuration.isPressed ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct BannerView: View {
    var heading: String
    var detail: String
    var primary: String
    var action: () -> Void
    var snooze: (() -> Void)?
    var leave: (() -> Void)?
    var close: () -> Void
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "leaf.fill").font(.system(size: 25, weight: .medium))
                .foregroundStyle(accent).frame(width: 48, height: 48)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 9) {
                Text(heading).font(.system(size: 21, weight: .semibold))
                Text(detail).font(.system(size: 13)).foregroundStyle(.secondary)
                HStack(spacing: 9) {
                    Button(primary, action: action).buttonStyle(RestButtonStyle(prominent: true))
                    if let snooze { Button(L("snooze"), action: snooze).buttonStyle(RestButtonStyle()) }
                    if let leave { Button(L("away_action"), action: leave).buttonStyle(RestButtonStyle()) }
                }.padding(.top, 3)
                Text(L("auto_hide"))
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            Button(action: close) { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) }
                .buttonStyle(.plain).help(L("dismiss"))
        }.padding(22).frame(width: 540, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(accent.opacity(0.35), lineWidth: 1.5))
            .padding(10)
    }
}

final class QuietPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var prefs = Preferences.load()
    lazy var engine = RestEngine(work: Double(prefs.work * 60), rest: Double(prefs.rest * 60))
    var status: NSStatusItem!
    var timer: Timer?
    var hideTimer: Timer?
    var panel: QuietPanel?
    var countdown: NSWindow?
    var countdownLabel: NSTextField?
    var countdownButton: NSButton?
    var countdownTimer: Timer?
    var settings: NSWindow?
    var unavailable = Set<String>()
    var lidGate = LidSessionGate()
    var powerRoot: io_service_t = 0
    var lidNotifier: io_object_t = 0
    var lidPort: IONotificationPortRef?
    var lastPhase = Phase.working
    let testing = CommandLine.arguments.contains("--ui-test") || Bundle.main.object(forInfoDictionaryKey: "RestLeafUITest") as? Bool == true
    var testLog: URL { Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("UI-Test.log") }
    func log(_ value: String) {
        guard testing else { return }
        let line = "\(Date().timeIntervalSince1970) \(value)\n"
        if let handle = try? FileHandle(forWritingTo: testLog) { _ = try? handle.seekToEnd(); try? handle.write(contentsOf: Data(line.utf8)); try? handle.close() }
        else { try? Data(line.utf8).write(to: testLog) }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory applications have no Dock tile and never take focus at launch.
        NSApp.setActivationPolicy(.accessory)
        rebuildMainMenu()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu(); menu.delegate = self; status.menu = menu
        let center = NSWorkspace.shared.notificationCenter
        for (name, selector) in [
            (NSWorkspace.willSleepNotification, #selector(willSleep(_:))),
            (NSWorkspace.didWakeNotification, #selector(didWake(_:))),
            (NSWorkspace.screensDidSleepNotification, #selector(screensSleep(_:))),
            (NSWorkspace.screensDidWakeNotification, #selector(screensWake(_:)))
        ] { center.addObserver(self, selector: selector, name: name, object: nil) }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(locked(_:)), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(unlocked(_:)), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        // Query current session once so starting the app while locked cannot count as use.
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any], session["CGSSessionScreenIsLocked"] as? Bool == true { unavailable.insert("lock") }
        if !unavailable.isEmpty { engine.leave(Date()) }
        if testing { engine = RestEngine(work: 4, rest: 4); log("launched") ; installUITest() }
        let sleeping = !NSScreen.screens.isEmpty && NSScreen.screens.allSatisfy { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsAsleep(number.uint32Value) != 0
        }
        if sleeping { unavailable.insert("display"); engine.leave(Date()) }
        observeLid()
        update()
        if !testing && !UserDefaults.standard.bool(forKey: "onboarded") {
            UserDefaults.standard.set(true, forKey: "onboarded")
            openSettings()
        }
    }
    var cpuStart: Double = 0
    func cpuSeconds() -> Double {
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
    }
    func installUITest() {
        for running in NSRunningApplication.runningApplications(withBundleIdentifier: appID) where running.processIdentifier != ProcessInfo.processInfo.processIdentifier { running.terminate() }
        for phase in [Phase.working, .due, .resting, .away] {
            let icon = leafImage(phase)
            if let tiff = icon.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: testLog.deletingLastPathComponent().appendingPathComponent("menu-\(phase.rawValue).png"))
            }
        }
        Timer.scheduledTimer(withTimeInterval: 26, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.log("after26 phase=\(self.engine.phase.rawValue) bannerHidden=\(self.panel == nil)")
            self.startRest()
        }
        Timer.scheduledTimer(withTimeInterval: 55, repeats: false) { [weak self] _ in
            guard let self else { return }; self.cpuStart = self.cpuSeconds()
            self.log("idle-start phase=\(self.engine.phase.rawValue)")
        }
        Timer.scheduledTimer(withTimeInterval: 85, repeats: false) { [weak self] _ in
            guard let self else { return }
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            self.log("idle30 cpuSeconds=\(self.cpuSeconds() - self.cpuStart) peakRSSBytes=\(usage.ru_maxrss)")
            NSApp.terminate(nil)
        }
    }
    func rebuildMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        add(appMenu, L("settings"), #selector(openSettings), key: ",")
        appMenu.addItem(.separator())
        add(appMenu, L("quit"), #selector(quit), key: "q")
        appMenuItem.submenu = appMenu; mainMenu.addItem(appMenuItem); NSApp.mainMenu = mainMenu
    }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate(); hideTimer?.invalidate(); countdownTimer?.invalidate()
        if lidNotifier != 0 { IOObjectRelease(lidNotifier) }
        if let lidPort { IONotificationPortDestroy(lidPort) }
        if powerRoot != 0 { IOObjectRelease(powerRoot) }
    }
    func observeLid() {
        powerRoot = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard powerRoot != 0, let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        lidPort = port
        let result = IOServiceAddInterestNotification(port, powerRoot, kIOGeneralInterest, { context, _, type, argument in
            // IOPM.h: iokit_family_msg(sub_iokit_powermanagement, 0x100).
            let lidMessage: UInt32 = (0x38 << 26) | (13 << 14) | 0x100
            guard type == lidMessage, let context else { return }
            let owner = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            owner.lidChanged(closed: UInt(bitPattern: argument) & UInt(kClamshellStateBit) != 0)
        }, Unmanaged.passUnretained(self).toOpaque(), &lidNotifier)
        if result == KERN_SUCCESS, let source = IONotificationPortGetRunLoopSource(port)?.takeUnretainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        refreshLid()
    }
    func refreshLid() {
        guard powerRoot != 0,
              let value = IORegistryEntryCreateCFProperty(powerRoot, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool else { return }
        lidChanged(closed: value)
    }
    func lidChanged(closed: Bool) {
        lidGate.changed(closed: closed)
        if closed { engine.suspendForLid(Date()) }
        setUnavailable("lid", closed)
    }
    @objc func willSleep(_ n: Notification) { refreshLid(); setUnavailable("sleep", true) }
    @objc func didWake(_ n: Notification) {
        if let session = CGSessionCopyCurrentDictionary() as? [String: Any], session["CGSSessionScreenIsLocked"] as? Bool == true { unavailable.insert("lock") }
        refreshLid(); setUnavailable("sleep", false)
    }
    @objc func screensSleep(_ n: Notification) { setUnavailable("display", true) }
    @objc func screensWake(_ n: Notification) { setUnavailable("display", false) }
    @objc func locked(_ n: Notification) { setUnavailable("lock", true) }
    @objc func unlocked(_ n: Notification) { setUnavailable("lock", false) }
    func setUnavailable(_ reason: String, _ value: Bool) {
        if value { unavailable.insert(reason) } else { unavailable.remove(reason) }
        syncAvailability()
    }
    func syncAvailability() {
        if !unavailable.isEmpty { countdown?.close(); engine.leave(Date()); dismissBanner() }
        else if lidGate.consumeRestart(available: unavailable.isEmpty) {
            engine.reset(Date())
        } else { engine.returnFromAway(Date()) }
        update()
    }
    func update() {
        timer?.invalidate(); timer = nil
        let now = Date(); if lidGate.closed { engine.suspendForLid(now) }; _ = engine.tick(now)
        if !unavailable.isEmpty { engine.leave(now) }
        updateStatus(); refreshCountdown()
        let changed = engine.phase != lastPhase
        lastPhase = engine.phase
        if changed { log("phase \(engine.phase.rawValue)") }
        if changed && unavailable.isEmpty {
            if engine.phase == .due { showReminder() }
            if engine.phase == .ready { showFinished() }
        }
        if [.working, .resting, .paused].contains(engine.phase) && engine.deadline != .distantFuture {
            let delay = max(0.1, min(60, engine.remaining(now)))
            timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in self?.update() }
            timer?.tolerance = delay >= 60 ? 1 : 0.05
        }
    }
    func minutes(_ seconds: TimeInterval) -> String { L("minutes_format", max(1, Int(ceil(seconds / 60)))) }
    func statusText() -> String {
        switch engine.phase {
        case .working: return L("working_status", minutes(engine.remaining(Date())))
        case .due: return L("due_status")
        case .resting: return L("resting_status", minutes(engine.remaining(Date())))
        case .ready: return L("ready_status")
        case .away:
            let elapsed = Date().timeIntervalSince(engine.awaySince ?? Date())
            return L("away_status", Int(max(0, elapsed) / 60))
        case .paused: return L("paused_status")
        }
    }
    func updateStatus() {
        guard let button = status.button else { return }
        button.image = leafImage(engine.phase)
        button.imagePosition = .imageLeading
        button.title = prefs.showTime ? ([Phase.working, .resting].contains(engine.phase) ? " \(max(1, Int(ceil(engine.remaining(Date()) / 60))))m" : "") : ""
        button.toolTip = "\(L("app_name")) · \(statusText())"
        button.setAccessibilityLabel("\(L("app_name")), \(statusText())")
    }
    func leafImage(_ phase: Phase) -> NSImage {
        let image = NSImage(size: NSSize(width: 23, height: 20), flipped: false) { rect in
            NSColor.black.set()
            let leaf = NSBezierPath()
            leaf.move(to: NSPoint(x: 5, y: 4)); leaf.curve(to: NSPoint(x: 18, y: 17), controlPoint1: NSPoint(x: 1, y: 14), controlPoint2: NSPoint(x: 12, y: 18))
            leaf.curve(to: NSPoint(x: 5, y: 4), controlPoint1: NSPoint(x: 20, y: 9), controlPoint2: NSPoint(x: 14, y: 2))
            leaf.lineWidth = 1.45
            if phase == .resting || phase == .ready { leaf.fill() } else { leaf.stroke() }
            let stem = NSBezierPath(); stem.move(to: NSPoint(x: 3, y: 2)); stem.curve(to: NSPoint(x: 14, y: 13), controlPoint1: NSPoint(x: 8, y: 6), controlPoint2: NSPoint(x: 11, y: 8)); stem.lineWidth = 1.3; stem.stroke()
            if phase == .due { NSBezierPath(ovalIn: NSRect(x: 19, y: 2, width: 4, height: 4)).fill() }
            if phase == .paused || phase == .away {
                NSBezierPath(rect: NSRect(x: 18, y: 1, width: 1.6, height: 6)).fill()
                NSBezierPath(rect: NSRect(x: 21, y: 1, width: 1.6, height: 6)).fill()
            }
            return true
        }; image.isTemplate = true; return image
    }
    func menuWillOpen(_ menu: NSMenu) {
        update(); menu.removeAllItems()
        let title = NSMenuItem(title: L("app_name"), action: nil, keyEquivalent: ""); title.isEnabled = false; menu.addItem(title)
        let state = NSMenuItem(title: statusText(), action: nil, keyEquivalent: ""); state.isEnabled = false; menu.addItem(state)
        menu.addItem(.separator())
        if engine.phase == .ready { add(menu, L("continue_use"), #selector(reset)) }
        else if engine.phase == .resting { add(menu, L("view_countdown"), #selector(openCountdown)); add(menu, L("end_break"), #selector(reset)) }
        add(menu, engine.phase == .paused ? L("resume_timer") : L("away_action"), #selector(togglePause))
        if engine.phase == .due { add(menu, L("show_reminder"), #selector(showReminder)) }
        add(menu, L("restart"), #selector(reset)); menu.addItem(.separator())
        add(menu, L("settings"), #selector(openSettings), key: ",")
        add(menu, L("quit"), #selector(quit), key: "q")
    }
    func add(_ menu: NSMenu, _ title: String, _ selector: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.image = nil
        // Keep menu rows text-only on newer systems without requiring their SDK.
        if item.responds(to: NSSelectorFromString("setPreferredImageVisibility:")) { item.setValue(2, forKey: "preferredImageVisibility") }
        item.target = self; menu.addItem(item)
    }
    @objc func reset() { countdown?.close(); dismissBanner(); engine.reset(Date()); syncAvailability() }
    @objc func openCountdown() {
        if let countdown { NSApp.activate(ignoringOtherApps: true); countdown.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 245), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = L("countdown_title"); window.isReleasedWhenClosed = false; window.delegate = self
        let stack = NSStackView(); stack.orientation = .vertical; stack.spacing = 18; stack.alignment = .centerX
        let title = NSTextField(labelWithString: L("countdown_heading"))
        title.font = .systemFont(ofSize: 14, weight: .medium)
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 48, weight: .light)
        let note = NSTextField(labelWithString: L("countdown_hint"))
        note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabelColor
        let button = NSButton(title: L("end_break"), target: self, action: #selector(reset)); button.bezelStyle = .rounded
        [title, label, note, button].forEach { stack.addArrangedSubview($0) }
        let content = NSView(); content.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: content.centerXAnchor), stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)])
        window.contentView = content; countdown = window; countdownLabel = label; countdownButton = button
        refreshCountdown(); window.center(); NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refreshCountdown() }
        countdownTimer?.tolerance = 0.1
    }
    func refreshCountdown() {
        guard countdown != nil else { return }
        let remaining = engine.phase == .resting ? Int(ceil(engine.remaining(Date()))) : 0
        countdownLabel?.stringValue = String(format: "%02d:%02d", remaining / 60, remaining % 60)
        if remaining == 0 { countdownTimer?.invalidate(); countdownTimer = nil; countdownButton?.title = L("continue_use") }
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === countdown else { return }
        countdownTimer?.invalidate(); countdownTimer = nil; countdownLabel = nil; countdownButton = nil; countdown = nil
    }
    @objc func startRest() { dismissBanner(); engine.startRest(Date()); syncAvailability() }
    @objc func togglePause() {
        countdown?.close(); dismissBanner()
        if engine.phase == .paused { engine.resume(Date()); syncAvailability() }
        else { engine.pause(Date()); update() }
    }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showReminder() {
        let preview = engine.phase != .due
        showBanner(heading: L("break_heading"), detail: (preview ? L("preview_prefix") : "") + L("break_detail", prefs.rest), primary: L("start_break"), action: { [weak self] in self?.startRest() }, snooze: { [weak self] in
            guard let self else { return }; self.dismissBanner(); self.engine.snooze(Date()); self.update()
        }, leave: { [weak self] in self?.togglePause() })
    }
    func showFinished() {
        showBanner(heading: L("finished_heading"), detail: L("finished_detail"), primary: L("continue_use"), action: { [weak self] in self?.reset() }, snooze: nil, leave: nil)
    }
    func showBanner(heading: String, detail: String, primary: String, action: @escaping () -> Void, snooze: (() -> Void)?, leave: (() -> Void)?) {
        dismissBanner()
        let foreground = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        let p = QuietPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isFloatingPanel = true; p.hidesOnDeactivate = false; p.becomesKeyOnlyIfNeeded = true
        p.level = .floating; p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true; p.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: BannerView(heading: heading, detail: detail, primary: primary, action: action, snooze: snooze, leave: leave, close: { [weak self] in self?.dismissBanner() }))
        p.contentView = hosting
        let fitting = hosting.fittingSize
        let size = NSSize(width: 604, height: max(180, fitting.height))
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main!
        let frame = screen.visibleFrame
        p.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 16, width: size.width, height: size.height), display: true)
        p.orderFrontRegardless(); panel = p
        if testing, let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
            hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
            if let data = bitmap.representation(using: .png, properties: [:]) {
                try? data.write(to: testLog.deletingLastPathComponent().appendingPathComponent(engine.phase == .ready ? "完成提醒.png" : "休息提醒.png"))
            }
        }
        if prefs.sound { NSSound(named: "Pop")?.play() }
        log("banner shown frontBefore=\(foreground) frontAfter=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown") canBecomeKey=\(p.canBecomeKey)")
        hideTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in self?.dismissBanner(); self?.log("auto-hidden") }
    }
    func dismissBanner() { hideTimer?.invalidate(); hideTimer = nil; panel?.orderOut(nil); panel = nil }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openSettings(); return true }
    @objc func openSettings() {
        if let settings, settings.isVisible { NSApp.activate(ignoringOtherApps: true); settings.makeKeyAndOrderFront(nil); return }
        let view = SettingsView(prefs: prefs, launchAtLogin: SMAppService.mainApp.status == .enabled, save: { [weak self] prefs, login in
            guard let self else { return nil }
            do {
                let enabled = SMAppService.mainApp.status == .enabled
                if login && !enabled { try SMAppService.mainApp.register() }
                else if !login && SMAppService.mainApp.status != .notRegistered { try SMAppService.mainApp.unregister() }
                if login && SMAppService.mainApp.status == .requiresApproval { return L("login_approval") }
            } catch { return L("login_error", error.localizedDescription) }
            let languageChanged = self.prefs.language != prefs.language
            let timeChanged = self.prefs.work != prefs.work || self.prefs.rest != prefs.rest
            self.prefs = prefs; prefs.save()
            if languageChanged { self.dismissBanner(); self.countdown?.close(); self.rebuildMainMenu() }
            if timeChanged {
                self.engine.workDuration = Double(prefs.work * 60); self.engine.restDuration = Double(prefs.rest * 60)
                self.reset()
            } else { self.update() }
            self.settings?.close(); return nil
        }, preview: { [weak self] in self?.showReminder() })
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)
        window.title = L("settings_title"); window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false; window.center(); settings = window
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
    }
}

if CommandLine.arguments.contains("--self-test") { runEngineTests(); runLocalizationTests(); exit(0) }
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
