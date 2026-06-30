import Cocoa

final class ToggleView: NSView {
    static let w: CGFloat = 33, h: CGFloat = 16
    private let track = CALayer()
    private let knob = CALayer()
    private var lastToggle = Date.distantPast
    private var hovered = false
    var isOn: Bool { didSet { updateState(animated: true) } }
    var onToggle: ((Bool) -> Void)?

    init(isOn: Bool) {
        self.isOn = isOn
        super.init(frame: NSRect(x: 0, y: 0, width: ToggleView.w, height: ToggleView.h))
        layer = CALayer()
        wantsLayer = true
        track.frame = bounds
        track.cornerRadius = bounds.height / 2
        layer?.addSublayer(track)
        let kh = bounds.height - 4, kw = kh + 3
        knob.bounds = CGRect(x: 0, y: 0, width: kw, height: kh)
        knob.cornerRadius = kh / 2
        knob.backgroundColor = NSColor.white.cgColor
        layer?.addSublayer(knob)
        updateState(animated: false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: NSSize { NSSize(width: ToggleView.w, height: ToggleView.h) }

    private func knobCenter() -> CGPoint {
        let kw = knob.bounds.width
        return CGPoint(x: isOn ? bounds.width - kw / 2 - 2 : kw / 2 + 2, y: bounds.height / 2)
    }

    private func trackColor() -> CGColor {
        if isOn {
            let accent = NSColor.controlAccentColor
            return (hovered ? (accent.blended(withFraction: 0.10, of: .white) ?? accent) : accent).cgColor
        }
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let base: CGFloat = dark ? 1.0 : 0.0
        let alpha: CGFloat = (dark ? 0.30 : 0.34) + (hovered ? 0.10 : 0)
        return NSColor(white: base, alpha: alpha).cgColor
    }

    private func updateState(animated: Bool) {
        let toColor = trackColor()
        let toPos = knobCenter()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if animated {
            let spring = CASpringAnimation(keyPath: "position")
            spring.fromValue = NSValue(point: knob.presentation()?.position ?? knob.position)
            spring.toValue = NSValue(point: toPos)
            spring.damping = 16; spring.stiffness = 260; spring.mass = 1; spring.initialVelocity = 0
            spring.duration = spring.settlingDuration
            knob.add(spring, forKey: "position")
            let col = CABasicAnimation(keyPath: "backgroundColor")
            col.fromValue = track.presentation()?.backgroundColor ?? track.backgroundColor
            col.toValue = toColor
            col.duration = 0.2
            track.add(col, forKey: "backgroundColor")
        }
        knob.position = toPos
        track.backgroundColor = toColor
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateState(animated: false)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; updateState(animated: false) }
    override func mouseExited(with event: NSEvent) { hovered = false; updateState(animated: false) }

    override func mouseDown(with event: NSEvent) {
        guard Date().timeIntervalSince(lastToggle) > 0.1 else { return }
        lastToggle = Date()
        isOn.toggle()
        onToggle?(isOn)
    }
}

final class SessionRowView: NSView {
    let id: String
    var onClick: (() -> Void)?
    private let iconView = NSImageView()
    private let nameField = NSTextField(labelWithString: "")
    private let timerField = NSTextField(labelWithString: "")
    private let pillView = NSImageView()
    private let pad: CGFloat = 14, iconSize: CGFloat = 16, rowH: CGFloat = 24, timerW: CGFloat = 74
    private let highlightView = NSVisualEffectView()
    private var hovered = false
    private var iconBaseTint: NSColor?
    private var pillNormal: NSImage?, pillSelected: NSImage?

    init(id: String, width: CGFloat) {
        self.id = id
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: rowH))
        autoresizingMask = [.width]
        highlightView.material = .selection
        highlightView.state = .active
        highlightView.isEmphasized = true
        highlightView.wantsLayer = true
        highlightView.layer?.cornerRadius = 5
        highlightView.isHidden = true
        addSubview(highlightView)
        iconView.frame = NSRect(x: pad, y: (rowH - iconSize) / 2, width: iconSize, height: iconSize)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.autoresizingMask = [.maxXMargin]
        addSubview(iconView)
        nameField.font = .menuFont(ofSize: 0)
        nameField.textColor = .labelColor
        nameField.lineBreakMode = .byTruncatingTail
        nameField.frame = NSRect(x: pad + iconSize + 8, y: (rowH - 16) / 2, width: 160, height: 16)
        nameField.autoresizingMask = [.maxXMargin]
        addSubview(nameField)
        timerField.font = NSFont.monospacedSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize - 2, weight: .regular)
        timerField.textColor = .secondaryLabelColor
        timerField.alignment = .right
        timerField.autoresizingMask = [.minXMargin]
        addSubview(timerField)
        pillView.imageScaling = .scaleNone
        pillView.autoresizingMask = [.minXMargin]
        addSubview(pillView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setIcon(_ img: NSImage?) { iconView.image = img }

    func configure(icon: NSImage?, iconTint: NSColor?, name: String, timer: String?,
                   pillNormal: NSImage?, pillSelected: NSImage?, pillInset: CGFloat, timerGap: CGFloat) {
        let w = bounds.width
        iconView.image = icon
        iconBaseTint = iconTint
        iconView.contentTintColor = hovered ? .white : iconTint
        nameField.stringValue = name
        self.pillNormal = pillNormal; self.pillSelected = pillSelected
        let pill = hovered ? pillSelected : pillNormal
        var pillLeft = w - pillInset
        if let pill = pill {
            pillView.isHidden = false
            pillView.image = pill
            pillView.frame = NSRect(x: w - pillInset - pill.size.width, y: (rowH - pill.size.height) / 2,
                                    width: pill.size.width, height: pill.size.height)
            pillLeft = pillView.frame.minX
        } else { pillView.isHidden = true }
        if let timer = timer {
            timerField.isHidden = false
            timerField.stringValue = timer
            timerField.frame = NSRect(x: pillLeft - timerGap - timerW, y: (rowH - 16) / 2, width: timerW, height: 16)
        } else { timerField.isHidden = true }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { setHover(true) }
    override func mouseExited(with event: NSEvent) { setHover(false) }
    private func setHover(_ h: Bool) {
        hovered = h
        highlightView.isHidden = !h
        nameField.textColor = h ? .white : .labelColor
        timerField.textColor = h ? .white : .secondaryLabelColor
        iconView.contentTintColor = h ? .white : iconBaseTint
        if !pillView.isHidden { pillView.image = h ? pillSelected : pillNormal }
    }
    override func layout() {
        super.layout()
        highlightView.frame = bounds.insetBy(dx: 5, dy: 0)
    }
    override func mouseDown(with event: NSEvent) { onClick?() }
}

final class StatusController: NSObject, NSMenuDelegate {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let stateDir = (NSHomeDirectory() as NSString).appendingPathComponent(".config/opencode/statusbar/state.d")
    let opencodeDesktopBundleID = "com.anomaly.opencodedesktop"

    var pollTimer: Timer?
    var animTimer: Timer?
    var spinTimer: Timer?
    var spinAngle: CGFloat = 0
    var frameIdx = 0

    var stalePruneAge: TimeInterval { UserDefaults.standard.object(forKey: "hideIdleAfter") as? Double ?? 1800 }

    struct Session {
        var id: String, state: String, label: String, project: String, transcript: String
        var entrypoint: String
        var termProgram: String
        var pid: Int32
        var started: Bool
        var startedAt: Double, ts: Double
        var eff: String = ""

        init(json o: [String: Any], id: String) {
            self.id = id
            self.state = o["state"] as? String ?? "idle"
            self.label = o["label"] as? String ?? ""
            self.project = o["project"] as? String ?? ""
            self.transcript = o["transcript"] as? String ?? ""
            self.entrypoint = o["entrypoint"] as? String ?? ""
            self.termProgram = o["term_program"] as? String ?? ""
            self.pid = Int32(truncatingIfNeeded: (o["pid"] as? NSNumber)?.intValue ?? 0)
            self.started = o["started"] as? Bool ?? false
            self.startedAt = (o["startedAt"] as? NSNumber)?.doubleValue ?? 0
            self.ts = (o["ts"] as? NSNumber)?.doubleValue ?? 0
        }
    }
    var sessions: [String: Session] = [:]
    var fileMTimes: [String: Date] = [:]
    var soundPrev: [String: String] = [:]
    var turnStart: [String: Double] = [:]
    var menuIsOpen = false
    var sessionMenuItems: [(item: NSMenuItem, id: String)] = []
    var activeBase = ""
    var startedAt: Double = 0
    var activeColor: NSColor? = nil

    let amber = NSColor(srgbRed: 0.95, green: 0.73, blue: 0.18, alpha: 1)

    var animStyle = AnimStyle.block
    var showTimer = false
    var playCompletionSound = false
    lazy var completionSound: NSSound? = {
        guard let p = Bundle.main.path(forResource: "completion", ofType: "mp3"),
              let s = NSSound(contentsOfFile: p, byReference: true) else { return nil }
        s.volume = 0.7
        return s
    }()

    // OpenCode geometric animation: blocks build/pulse
    let blockFrames: [NSImage] = {
        let side: CGFloat = 16
        let count = 8
        return (0..<count).map { i in
            let size = NSSize(width: side, height: side)
            let progress = CGFloat(i) / CGFloat(count - 1)
            let img = NSImage(size: size, flipped: false) { rect in
                guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
                let inset = CGFloat(8 - i) * 0.5
                let r = rect.insetBy(dx: inset, dy: inset)
                NSColor.black.withAlphaComponent(0.15 + progress * 0.85).setFill()
                ctx.fill(r)
                let inner = r.insetBy(dx: 2, dy: 2)
                NSColor.black.setFill()
                ctx.fill(inner)
                return true
            }
            img.isTemplate = true
            return img
        }
    }()

    let termGlyphs = ["▖", "▘", "▝", "▗"]
    let termSub = 12
    let termCycle: Double = 2.0
    lazy var termMasks: [NSImage] = termGlyphs.map { glyph in
        let side: CGFloat = 16
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold),
                .foregroundColor: NSColor.black,
            ]
            (glyph as NSString).draw(at: NSPoint(x: 2, y: 0), withAttributes: attrs)
            return true
        }
        img.isTemplate = true
        return img
    }

    let sparkFrameCount = 40

    var fps: Double {
        switch animStyle {
        case .spark: return 15
        case .block: return 12
        case .term:  return Double(termGlyphs.count * termSub) / termCycle
        }
    }
    var frameCount: Int {
        switch animStyle {
        case .spark: return sparkFrameCount
        case .block: return blockFrames.count
        case .term:  return termGlyphs.count * termSub
        }
    }

    override init() {
        super.init()
        let d = UserDefaults.standard
        if d.object(forKey: "showTimer") != nil { showTimer = d.bool(forKey: "showTimer") }
        if d.object(forKey: "completionSound") != nil { playCompletionSound = d.bool(forKey: "completionSound") }
        if let s = d.string(forKey: "animStyle"), let st = AnimStyle(rawValue: s) { animStyle = st }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        render(label: "", color: nil, animate: false, startedAt: 0)
        let t = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        pollTimer = t
        tick()
        ensurePluginInstalled()
        checkForUpdate()
    }

    func ensurePluginInstalled() {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let pluginDir = "\(home)/.config/opencode/plugins"
        let pluginSrc = Bundle.main.path(forResource: "statusbar", ofType: "ts")
        let pluginDst = "\(pluginDir)/statusbar.ts"
        guard let src = pluginSrc else { return }
        try? fm.createDirectory(atPath: pluginDir, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: pluginDst) || fm.contentsEqual(atPath: src, andPath: pluginDst) == false {
            try? fm.copyItem(atPath: src, toPath: pluginDst)
        }
    }

    static func locateNode() -> String? {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var candidates = [
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
            "\(home)/.volta/bin/node",
            "\(home)/.asdf/shims/node",
        ]
        let nvmDir = "\(home)/.nvm/versions/node"
        if let versions = try? fm.contentsOfDirectory(atPath: nvmDir) {
            for v in versions.sorted(by: >) { candidates.append("\(nvmDir)/\(v)/bin/node") }
        }
        for path in candidates where fm.isExecutableFile(atPath: path) { return path }
        for args in [["-ilc", "command -v node"], ["-lc", "command -v node"]] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/zsh")
            p.arguments = args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            guard (try? p.run()) != nil else { continue }
            p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = (String(data: data, encoding: .utf8) ?? "")
                .split(separator: "\n").last.map(String.init)?
                .trimmingCharacters(in: .whitespaces) ?? ""
            if !path.isEmpty, fm.isExecutableFile(atPath: path) { return path }
        }
        return nil
    }

    var currentVersion: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0" }
    let releaseAPIURL = "https://api.github.com/repos/anomalyco/opencode-status-bar/releases/latest"
    let releasePageURL = "https://github.com/anomalyco/opencode-status-bar/releases/latest"

    func checkForUpdate() {
        let d = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        if now - d.double(forKey: "lastUpdateCheck") < 86400 { return }
        guard let url = URL(string: releaseAPIURL) else { return }
        var req = URLRequest(url: url)
        req.setValue("OpenCodeStatusBar", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String else { return }
            let ver = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            UserDefaults.standard.set(ver, forKey: "latestVersion")
            UserDefaults.standard.set(now, forKey: "lastUpdateCheck")
        }.resume()
    }

    func versionIsNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    @objc func openLatestRelease() {
        if let url = URL(string: releasePageURL) { NSWorkspace.shared.open(url) }
    }

    // MARK: menu

    func menuWillOpen(_ menu: NSMenu) {
        menuIsOpen = true
        spinTimer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.spinTick() }
        RunLoop.main.add(t, forMode: .common)
        spinTimer = t
    }
    func menuDidClose(_ menu: NSMenu) {
        menuIsOpen = false
        sessionMenuItems.removeAll()
        spinTimer?.invalidate(); spinTimer = nil
    }

    func spinTick() {
        spinAngle += 5
        guard let img = rotatedSpinner(spinAngle) else { return }
        let now = Date().timeIntervalSince1970
        for (item, id) in sessionMenuItems {
            guard let s = sessions[id], let v = item.view as? SessionRowView else { continue }
            let eff = s.eff.isEmpty ? effectiveState(s, now: now) : s.eff
            if eff == "thinking" || eff == "tool" { v.setIcon(img) }
        }
    }

    func refreshOpenMenuRows() {
        let now = Date().timeIntervalSince1970
        for (item, id) in sessionMenuItems {
            guard let s = sessions[id], let v = item.view as? SessionRowView else { continue }
            let eff = s.eff.isEmpty ? effectiveState(s, now: now) : s.eff
            configureSessionRow(v, s, eff: eff)
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        checkForUpdate()

        sessionMenuItems.removeAll()
        let now = Date().timeIntervalSince1970
        let allOrdered = sessions.values.sorted { $0.ts > $1.ts }
        let ordered = allOrdered.filter { s in
                let eff = s.eff.isEmpty ? effectiveState(s, now: now) : s.eff
                let resting = !(eff == "permission" || eff == "thinking" || eff == "tool")
                let gated = s.entrypoint == "opencode-desktop"
                return !gated || s.started || !resting
            }
        var visible = ordered.filter { s in
            let eff = s.eff.isEmpty ? effectiveState(s, now: now) : s.eff
            let resting = !(eff == "permission" || eff == "thinking" || eff == "tool")
            return !(stalePruneAge > 0 && resting && now - s.ts > stalePruneAge)
        }
        if visible.isEmpty, let lead = ordered.first { visible = [lead] }

        if !visible.isEmpty {
            menu.addItem(header("Sessions"))
            for s in visible {
                let eff = s.eff.isEmpty ? effectiveState(s, now: now) : s.eff
                let view = SessionRowView(id: s.id, width: CGFloat(uiConfig()["boxWidth"] ?? 300))
                let sid = s.id, ep = s.entrypoint, tp = s.termProgram
                view.onClick = { [weak self] in menu.cancelTracking(); self?.openSession(sid, entrypoint: ep, termProgram: tp) }
                configureSessionRow(view, s, eff: eff)
                let it = NSMenuItem()
                it.view = view
                menu.addItem(it)
                sessionMenuItems.append((it, s.id))
            }
            menu.addItem(.separator())
        } else if opencodeDesktopRunning() {
            menu.addItem(header("Sessions"))
            let open = NSMenuItem(title: "Open OpenCode", action: #selector(openOpencode), keyEquivalent: "")
            open.target = self
            menu.addItem(open)
            menu.addItem(.separator())
        }

        menu.addItem(header("Options"))

        menu.addItem(toggleRow(title: "Show timer", isOn: showTimer) { [weak self] on in
            self?.showTimer = on
            UserDefaults.standard.set(on, forKey: "showTimer")
            self?.applyTitle()
        })
        menu.addItem(toggleRow(title: "Completion sound (1m+)", isOn: playCompletionSound) { [weak self] on in
            self?.playCompletionSound = on
            UserDefaults.standard.set(on, forKey: "completionSound")
        })

        let animParent = NSMenuItem(title: "Animation Style", action: nil, keyEquivalent: "")
        let animSub = NSMenu()
        for (style, name) in [(AnimStyle.spark, "OpenCode Spark"), (AnimStyle.block, "Block Build"), (AnimStyle.term, "Terminal Pulse")] {
            let it = NSMenuItem(title: name, action: #selector(chooseStyle(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = style.rawValue
            it.state = animStyle == style ? .on : .off
            animSub.addItem(it)
        }
        animParent.submenu = animSub
        menu.addItem(animParent)

        let hideParent = NSMenuItem(title: "Hide idle sessions", action: nil, keyEquivalent: "")
        let hideSub = NSMenu()
        let curHide = stalePruneAge
        for (name, secs) in [("5 minutes", 300.0), ("15 minutes", 900.0), ("30 minutes", 1800.0), ("1 hour", 3600.0), ("Never", 0.0)] {
            let it = NSMenuItem(title: name, action: #selector(chooseHideIdle(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = secs
            it.state = curHide == secs ? .on : .off
            hideSub.addItem(it)
        }
        hideParent.submenu = hideSub
        menu.addItem(hideParent)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Version \(currentVersion)", action: nil, keyEquivalent: ""))
        if let latest = UserDefaults.standard.string(forKey: "latestVersion"), versionIsNewer(latest, than: currentVersion) {
            let up = NSMenuItem(title: "Update available", action: #selector(openLatestRelease), keyEquivalent: "")
            up.target = self
            menu.addItem(up)
        }
        let q = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        q.target = self
        menu.addItem(q)
    }

    func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return NSMenuItem.sectionHeader(title: title) }
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.isEnabled = false
        return it
    }

    func toggleRow(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) -> NSMenuItem {
        let width = CGFloat(uiConfig()["boxWidth"] ?? 300), height: CGFloat = 24, leftInset: CGFloat = 14, rightInset: CGFloat = 12
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        row.autoresizingMask = [.width]

        let labelFont = NSFont.menuFont(ofSize: 0)
        let attr = NSMutableAttributedString(string: title, attributes: [.font: labelFont, .foregroundColor: NSColor.labelColor])
        if let r = title.range(of: " (") {
            attr.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: NSRange(r.lowerBound..<title.endIndex, in: title))
        }
        let label = NSTextField(labelWithAttributedString: attr)
        label.sizeToFit()
        label.setFrameOrigin(NSPoint(x: leftInset, y: (height - label.frame.height) / 2))
        label.autoresizingMask = [.maxXMargin]
        row.addSubview(label)

        let toggle = ToggleView(isOn: isOn)
        toggle.onToggle = onToggle
        toggle.setFrameOrigin(NSPoint(x: width - toggle.frame.width - rightInset, y: (height - toggle.frame.height) / 2))
        toggle.autoresizingMask = [.minXMargin]
        row.addSubview(toggle)

        let item = NSMenuItem()
        item.view = row
        return item
    }

    func sessionMenuLine(_ s: Session) -> String {
        let now = Date().timeIntervalSince1970
        let eff = s.eff.isEmpty ? effectiveState(s, now: now) : s.eff
        var line = truncated(sessionName(s))
        if eff == "thinking" || eff == "tool", s.startedAt > 0 {
            line += "  " + elapsed(max(0, Int(now - s.startedAt)))
        }
        return line
    }

    func uiConfig() -> [String: Double] {
        let p = (NSHomeDirectory() as NSString).appendingPathComponent(".config/opencode/statusbar/uiconfig.json")
        guard let d = FileManager.default.contents(atPath: p),
              let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        return j.compactMapValues { ($0 as? NSNumber)?.doubleValue }
    }

    func configureSessionRow(_ v: SessionRowView, _ s: Session, eff: String) {
        let cfg = uiConfig()
        let now = Date().timeIntervalSince1970
        let nameMax = Int(cfg["nameMax"] ?? 16)
        let working = (eff == "thinking" || eff == "tool") && s.startedAt > 0
        let resting = !(eff == "permission" || eff == "thinking" || eff == "tool")
        let tag = surfaceTag(s.entrypoint)
        v.configure(icon: sessionSymbol(s, eff: eff),
                    iconTint: resting ? .tertiaryLabelColor : .labelColor,
                    name: truncated(sessionName(s), max: nameMax, keep: nameMax),
                    timer: working ? elapsed(max(0, Int(now - s.startedAt))) : nil,
                    pillNormal: tag.isEmpty ? nil : pillImage(tag),
                    pillSelected: tag.isEmpty ? nil : pillImage(tag, selected: true),
                    pillInset: CGFloat(cfg["pillInset"] ?? 12),
                    timerGap: CGFloat(cfg["timerGap"] ?? 10))
    }

    func statusText(_ s: Session, eff: String) -> String {
        switch eff {
        case "permission":       return "Waiting permission"
        case "thinking", "tool": return workingLabel(s)
        default:                 return s.state == "done" ? "Done" : "Idle"
        }
    }

    func sessionName(_ s: Session) -> String {
        s.project.isEmpty ? "session" : s.project
    }

    func surfaceTag(_ entrypoint: String) -> String {
        switch entrypoint {
        case "opencode-desktop": return "APP"
        case "":                 return ""
        default:                 return "CLI"
        }
    }

    func pillImage(_ text: String, selected: Bool = false) -> NSImage {
        let t = text as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 9.5, weight: .semibold)
        let pad: CGFloat = 7, h: CGFloat = 15
        let cfg = uiConfig()
        let dy = CGFloat(cfg["pillTextY"] ?? -1)
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let bgAlpha = CGFloat(cfg[dark ? "pillBgDark" : "pillBgLight"] ?? (dark ? 0.14 : 0.10))
        let bg = selected ? NSColor.white.withAlphaComponent(0.22)
                          : (dark ? NSColor.white : NSColor.black).withAlphaComponent(bgAlpha)
        let fg = selected ? NSColor.white : NSColor.labelColor
        let w = ceil(t.size(withAttributes: [.font: font]).width) + pad * 2
        return NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
            bg.setFill()
            NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2).fill()
            let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
            let ts = t.size(withAttributes: a)
            t.draw(at: NSPoint(x: (rect.width - ts.width) / 2, y: (rect.height - ts.height) / 2 + dy), withAttributes: a)
            return true
        }
    }

    func sessionSymbol(_ s: Session, eff: String) -> NSImage? {
        switch eff {
        case "permission":       return symbolImage("exclamationmark.circle.fill", tint: amber)
        case "thinking", "tool": return rotatedSpinner(spinAngle)
        default:                 return restingCaret
        }
    }

    lazy var restingCaret: NSImage? = {
        let glyph = "\u{276F}" as NSString
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let side = spinnerBase?.size.width ?? 15
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black]
            let g = glyph.size(withAttributes: attrs)
            glyph.draw(at: NSPoint(x: (side - g.width) / 2, y: (side - g.height) / 2), withAttributes: attrs)
            return true
        }
        img.isTemplate = true
        return img
    }()

    lazy var spinnerBase: NSImage? = {
        let name: String
        if #available(macOS 15.0, *) { name = "progress.indicator" } else { name = "rays" }
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        guard let sym = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return nil }
        let side = ceil(max(sym.size.width, sym.size.height)) + 2
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            sym.draw(in: NSRect(x: (side - sym.size.width) / 2, y: (side - sym.size.height) / 2,
                                width: sym.size.width, height: sym.size.height))
            return true
        }
        img.isTemplate = true
        return img
    }()

    func rotatedSpinner(_ angleDeg: CGFloat) -> NSImage? {
        guard let base = spinnerBase else { return nil }
        let size = base.size
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: -angleDeg * .pi / 180)
            ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
            base.draw(in: rect)
            return true
        }
        img.isTemplate = true
        return img
    }

    func symbolImage(_ name: String, tint: NSColor? = nil) -> NSImage? {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }
        if let tint = tint, #available(macOS 12.0, *) {
            return img.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [tint]))
        }
        img.isTemplate = true
        return img
    }

    func truncated(_ s: String, max: Int = 20, keep: Int = 18) -> String {
        s.count > max ? String(s.prefix(keep)) + "…" : s
    }

    func priority(of eff: String) -> Int {
        switch eff {
        case "permission":       return 2
        case "thinking", "tool": return 1
        default:                 return 0
        }
    }

    func workingLabel(_ s: Session) -> String {
        if !s.label.isEmpty { return s.label }
        return s.state == "tool" ? "Working…" : "Thinking…"
    }

    func elapsed(_ secs: Int) -> String {
        let m = secs / 60, s = secs % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }

    @objc func quit() { NSApp.terminate(nil) }

    @objc func openOpencode() {
        let ws = NSWorkspace.shared
        if let url = ws.urlForApplication(withBundleIdentifier: "com.anomaly.opencodedesktop") {
            ws.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func openSession(_ id: String, entrypoint: String, termProgram: String) {
        if entrypoint == "opencode-desktop" { openOpencode(); return }
        let app: String
        switch termProgram {
        case "Apple_Terminal": app = "Terminal"
        case "iTerm.app":      app = "iTerm"
        case "vscode":         app = "Visual Studio Code"
        case "WarpTerminal":   app = "Warp"
        case "":               return
        default:               app = termProgram
        }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", app]
        try? p.run()
    }

    @objc func chooseHideIdle(_ sender: NSMenuItem) {
        guard let secs = sender.representedObject as? Double else { return }
        UserDefaults.standard.set(secs, forKey: "hideIdleAfter")
    }

    @objc func chooseStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let st = AnimStyle(rawValue: raw) else { return }
        animStyle = st
        UserDefaults.standard.set(raw, forKey: "animStyle")
        animTimer?.invalidate(); animTimer = nil
        frameIdx = 0
        evaluate()
    }

    // MARK: state polling

    func tick() {
        checkLifecycle()
        reloadSessions()
        evaluate()
        if menuIsOpen { refreshOpenMenuRows() }
    }

    func stateFileNames() -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: stateDir)) ?? []).filter { $0.hasSuffix(".json") }
    }

    func reloadSessions() {
        let fm = FileManager.default
        let files = stateFileNames()
        let present = Set(files)
        for key in Array(fileMTimes.keys) where !present.contains(key) {
            fileMTimes[key] = nil
            sessions[(key as NSString).deletingPathExtension] = nil
        }
        for f in files {
            let full = (stateDir as NSString).appendingPathComponent(f)
            guard let attrs = try? fm.attributesOfItem(atPath: full),
                  let m = attrs[.modificationDate] as? Date else { continue }
            if fileMTimes[f] == m { continue }
            fileMTimes[f] = m
            guard let data = fm.contents(atPath: full),
                  let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let id = (f as NSString).deletingPathExtension
            sessions[id] = Session(json: o, id: id)
        }
    }

    func evaluate() {
        let now = Date().timeIntervalSince1970
        var chime = false

        for id in Array(sessions.keys) {
            guard var s = sessions[id] else { continue }
            s.eff = effectiveState(s, now: now)
            let dead = s.pid > 0 ? !pidAlive(s.pid)
                                 : (s.eff == "idle" && stalePruneAge > 0 && now - s.ts > stalePruneAge)
            if dead {
                try? FileManager.default.removeItem(atPath: (stateDir as NSString).appendingPathComponent(id + ".json"))
                sessions[id] = nil; fileMTimes[id + ".json"] = nil; soundPrev[id] = nil; turnStart[id] = nil
                continue
            }
            sessions[id] = s
            if soundEdgeDone(s, now: now) { chime = true }
        }
        for id in Array(soundPrev.keys) where sessions[id] == nil { soundPrev[id] = nil; turnStart[id] = nil }
        if chime, playCompletionSound { completionSound?.play() }

        let lead = sessions.values.max { a, b in
            let pa = priority(of: a.eff), pb = priority(of: b.eff)
            return pa == pb ? a.ts < b.ts : pa < pb
        }
        statusItem.button?.toolTip = lead.map(sessionMenuLine)

        guard let lead = lead else { renderResting(); return }
        switch lead.eff {
        case "permission":
            render(label: statusText(lead, eff: lead.eff), color: amber, animate: false, startedAt: 0, dot: true)
        case "thinking", "tool":
            render(label: statusText(lead, eff: lead.eff), color: nil, animate: true, startedAt: lead.startedAt)
        default:
            renderResting()
        }
    }

    func renderResting() { render(label: "", color: nil, animate: false, startedAt: 0) }

    func effectiveState(_ s: Session, now: Double) -> String {
        if s.state == "thinking" || s.state == "tool" || s.state == "permission" {
            let cap: Double = s.state == "permission" ? 7200 : 900
            if now - s.ts > cap { return "idle" }
            if !s.transcript.isEmpty, let last = lastTurnLine(ofFileAt: s.transcript),
               last.contains("interrupted by user") { return "idle" }
            return s.state
        }
        return s.state == "done" ? "idle" : s.state
    }

    func soundEdgeDone(_ s: Session, now: Double) -> Bool {
        let prev = soundPrev[s.id] ?? ""
        if s.state == "thinking" || s.state == "tool", s.startedAt > 0 { turnStart[s.id] = s.startedAt }
        var edge = false
        if s.state == "done", prev != "done", let st = turnStart[s.id], st > 0, now - st >= 60 { edge = true }
        if s.state == "done" { turnStart[s.id] = 0 }
        soundPrev[s.id] = s.state
        return edge
    }

    // MARK: self-quit lifecycle

    func opencodeDesktopRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == opencodeDesktopBundleID }
    }

    func opencodeProcessRunning() -> Bool {
        !stateFileNames().isEmpty || !((try? FileManager.default.contentsOfDirectory(atPath: stateDir)) ?? []).isEmpty
    }

    func sessionCount() -> Int { stateFileNames().count }

    func pidAlive(_ pid: Int32) -> Bool {
        if pid <= 0 { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }

    func checkLifecycle() {
        // Status bar app stays alive — no self-quit
    }

    func lastLine(ofFileAt path: String) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fh.close() }
        let size = (try? fh.seekToEnd()) ?? 0
        let chunk: UInt64 = 8192
        try? fh.seek(toOffset: size > chunk ? size - chunk : 0)
        guard let data = try? fh.readToEnd(), let s = String(data: data, encoding: .utf8) else { return nil }
        return s.split(separator: "\n").last { !$0.isEmpty }.map(String.init)
    }

    func lastTurnLine(ofFileAt path: String) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? fh.close() }
        let size = (try? fh.seekToEnd()) ?? 0
        let chunk: UInt64 = 8192
        try? fh.seek(toOffset: size > chunk ? size - chunk : 0)
        guard let data = try? fh.readToEnd(), let s = String(data: data, encoding: .utf8) else { return nil }
        return s.split(separator: "\n").last {
            $0.contains("\"type\":\"user\"") || $0.contains("\"type\":\"assistant\"")
        }.map(String.init)
    }

    // MARK: render

    func render(label: String, color: NSColor?, animate: Bool, startedAt: Double, dot: Bool = false) {
        guard let button = statusItem.button else { return }
        button.contentTintColor = nil
        activeBase = label
        activeColor = color
        self.startedAt = startedAt

        if animate {
            if animTimer == nil {
                let t = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] _ in self?.animStep() }
                RunLoop.main.add(t, forMode: .common)
                animTimer = t
            }
        } else {
            animTimer?.invalidate(); animTimer = nil
            frameIdx = 0
            button.image = dot ? dotIcon(color: color) : restingIcon(color: color)
        }
        applyTitle()
        if button.image == nil { button.image = dot ? dotIcon(color: color) : restingIcon(color: color) }
    }

    func animStep() {
        frameIdx = (frameIdx + 1) % frameCount
        statusItem.button?.image = iconImage(color: activeColor, frame: frameIdx)
        applyTitle()
    }

    func applyTitle() {
        var t = activeBase
        if showTimer, startedAt > 0 {
            let secs = Int(Date().timeIntervalSince1970 - startedAt)
            if secs > 0 { t = activeBase.isEmpty ? elapsed(secs) : activeBase + " " + elapsed(secs) }
        }
        statusItem.button?.title = t
    }

    func restingIcon(color: NSColor?) -> NSImage? {
        let side: CGFloat = 18
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let r = rect.insetBy(dx: 3, dy: 3)
            ctx.setLineWidth(2)
            NSColor.black.setStroke()
            ctx.stroke(r)
            let inner = r.insetBy(dx: 3, dy: 3)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(CGRect(x: inner.minX, y: inner.midY, width: inner.width, height: inner.height / 2))
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.4).cgColor)
            ctx.fill(CGRect(x: inner.minX, y: inner.minY, width: inner.width, height: inner.height / 2))
            return true
        }
        img.isTemplate = true
        return img
    }

    func dotIcon(color: NSColor?) -> NSImage? {
        let side: CGFloat = 18
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            NSColor.black.setFill()
            ctx.fillEllipse(in: rect.insetBy(dx: 3, dy: 3))
            return true
        }
        img.isTemplate = true
        return img
    }

    func iconImage(color: NSColor?, frame: Int) -> NSImage? {
        switch animStyle {
        case .spark:
            return sparkIcon(frame: frame, color: color)
        case .block:
            return resizeImage(blockFrames[frame % blockFrames.count], color: color)
        case .term:
            let glyphIdx = (frame / termSub) % termGlyphs.count
            let progress = CGFloat(frame % termSub) / CGFloat(termSub)
            return animatedGlyph(glyphIdx, progress: progress, color: color)
        }
    }

    func sparkIcon(frame: Int, color: NSColor?) -> NSImage? {
        let side: CGFloat = 18
        let total = sparkFrameCount
        let f = CGFloat(frame % total) / CGFloat(total)
        let inset: CGFloat = 2
        let r = CGRect(x: inset, y: inset, width: side - 2*inset, height: side - 2*inset)
        let w = r.width, h = r.height
        let perim = 2 * (w + h)
        let dist = f * perim

        var dotX: CGFloat, dotY: CGFloat
        if dist < w {
            dotX = r.minX + dist
            dotY = r.minY
        } else if dist < w + h {
            dotX = r.maxX
            dotY = r.minY + (dist - w)
        } else if dist < 2 * w + h {
            dotX = r.maxX - (dist - w - h)
            dotY = r.maxY
        } else {
            dotX = r.minX
            dotY = r.maxY - (dist - 2*w - h)
        }

        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            NSColor.black.withAlphaComponent(0.3).setStroke()
            ctx.setLineWidth(1.5)
            ctx.stroke(r)
            NSColor.black.setFill()
            let dotR: CGFloat = 2.5
            ctx.fillEllipse(in: CGRect(x: dotX - dotR, y: dotY - dotR, width: dotR * 2, height: dotR * 2))
            return true
        }
        img.isTemplate = true
        return img
    }

    func resizeImage(_ img: NSImage, color: NSColor?) -> NSImage? {
        let side: CGFloat = 18
        let resized = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            img.draw(in: rect)
            return true
        }
        resized.isTemplate = true
        return resized
    }

    func animatedGlyph(_ idx: Int, progress: CGFloat, color: NSColor?) -> NSImage? {
        let side: CGFloat = 18
        let glyph = termGlyphs[idx]
        let alpha = 0.3 + (1.0 - abs(progress - 0.5) * 2) * 0.7
        let img = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold),
                .foregroundColor: NSColor.black.withAlphaComponent(alpha),
            ]
            (glyph as NSString).draw(at: NSPoint(x: 1, y: 1), withAttributes: attrs)
            return true
        }
        img.isTemplate = true
        return img
    }
}

// MARK: enum and app delegate

enum AnimStyle: String {
    case spark = "spark"
    case block = "block"
    case term = "term"
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = StatusController()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
