<p align="center">
  <img src="https://img.shields.io/badge/macOS-12%2B-brightgreen" alt="macOS 12+">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
  <img src="https://img.shields.io/badge/version-1.0.0-orange" alt="Version 1.0.0">
  <img src="https://img.shields.io/badge/arch-arm64%20%7C%20x86__64-lightgrey" alt="Universal Binary">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift 5">
  <img src="https://img.shields.io/badge/Bun-Typescript-14151a" alt="Bun">
</p>

<h1 align="center">
  ⌘ OpenCode Status Bar
</h1>

<p align="center">
  <strong>Tiny macOS menu bar app that puts OpenCode's live status — always one glance away.</strong><br>
  No windows. No dock icon. No analytics. Just a pixel in your menu bar.
</p>

> Built so you can tab away during a long thinking stretch and see, at a glance, whether OpenCode is working, waiting on you, or done.

<img width="600" height="488" alt="OpenCode Status Bar screenshot" src="https://github.com/user-attachments/assets/a44257a6-99f0-437e-892c-5a7c1a33ce9a" />

---

## ✨ What it shows

| State | What you see |
|-------|-------------|
| **Thinking** | Animated icon + live timer (`1m 1s`) |
| **Running a tool** | Short label: `Editing`, `Reading`, `Running command`, `Searching` |
| **Awaiting permission** | Paused yellow dot |
| **Idle / done** | Rests on terminal icon |

### ⚙️ Options

| Feature | Description |
|---------|-------------|
| **Show timer** | Toggle the elapsed clock on/off |
| **Completion sound** | Soft chime when a turn >1 min finishes (user-selectable .mp3) |
| **Notification sound** | Always plays Tink when OpenCode asks for permission (no toggle) |
| **Animation style** | OpenCode Spark · Block Build · Terminal Pulse · Bounce · Pulse · Dots |
| **Hide idle sessions** | Auto-hide after 5m / 15m / 30m / 1h / never |
| **Break Time** | Break reminder with two modes: fullscreen overlay or Sound Only |
| **Sound Only** | Plays `tic-toc.wav` on interval, no fullscreen overlay (hides Duration & Labels) |
| **Customize** | Submenu with Change Icon, Change Sound, Colors, Labels, Reset All |
| **Colors** | Per-state color picker for Thinking, Idle, Permission, Tool — applies to status text & icon |
| **Auto-update** | One-click "Update available" in menu |

---

## 🔥 Multi-session

Run multiple OpenCode sessions side-by-side. The menu bar surfaces the **highest-priority** session:

> A session awaiting permission **always** jumps above one that's thinking.

The dropdown lists **every live session** — project name, status, timer, and CLI/APP badge. Click any session to focus its terminal or the OpenCode Desktop app.

---

## 🖥️ Where it works

| Surface | Tracked? |
|---------|:--------:|
| OpenCode CLI (terminal) | ✅ |
| OpenCode Desktop | ✅ |
| Terminal, iTerm, VS Code, Warp | ✅ |

---

## 📦 Install

```bash
# 1. Build
./build.sh

# 2. Launch once (wires up the plugin automatically)
open build/OpenCodeStatusBar.app

# 3. Start an OpenCode session — the icon appears in your menu bar
```

The app copies its plugin to `~/.config/opencode/plugins/statusbar.ts` and the plugin writes state to `~/.config/opencode/statusbar/state.d/`. Everything is automatic.

### Updating

Rebuild and re-launch. The plugin is overwritten on each launch if the content differs.

---

## ⚡ How it works

```
OpenCode (Bun)  ──►  plugin/statusbar.ts  ──►  ~/.config/opencode/statusbar/state.d/*.json
                                                      │
                                                      ▼
                                              Swift app polls every 0.4s
                                                      │
                                                      ▼
                                              Menu bar icon + dropdown
```

- **Stateless.** OpenCode fires lifecycle events → plugin writes JSON → app reads JSON → renders icon.
- **Self-managing.** Plugin auto-launches the app when a session starts.
- **Private.** Zero data collection. One daily GitHub API call for update checks.

---

## 🛠️ Build from source

```bash
# Prerequisites: macOS 12+, Xcode Command Line Tools, Bun
./build.sh
```

The script:
1. Compiles all Swift sources with `swiftc -O` for arm64 + x86_64
2. Merges into a **universal binary** via `lipo`
3. Creates `.app` bundle with embedded `Info.plist`
4. Bundles plugin, icon, and assets into `Resources/`

Output: `build/OpenCodeStatusBar.app`

---

## ❓ Troubleshooting

App not showing? Plugin not installed?

- Check the plugin file exists: `~/.config/opencode/plugins/statusbar.ts`
- Check state directory: `~/.config/opencode/statusbar/state.d/`
- Launch the app manually: `open build/OpenCodeStatusBar.app`

---

## 🗑️ Uninstall

```bash
bun run plugin/uninstall.ts
# Then delete the app
```

Removes the plugin and state directory from `~/.config/opencode/`.

---

## 📄 License

MIT
