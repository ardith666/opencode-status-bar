import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "fs"
import { basename } from "path"
import { join } from "path"
import { homedir } from "os"

const STATE_DIR = join(homedir(), ".config", "opencode", "statusbar", "state.d")
const BUNDLE_ID = "com.local.opencodestatusbar"
const EXEC = "OpenCodeStatusBar"
const TOOL_LABELS: Record<string, string> = {
  Bash: "Running command", Edit: "Editing", Write: "Writing",
  Read: "Reading", Grep: "Searching", Glob: "Searching",
  WebFetch: "Browsing web", WebSearch: "Searching web",
  Task: "Delegating", TodoWrite: "Planning",
}

const safeId = (s: string) =>
  String(s || "").replace(/[^A-Za-z0-9_.-]/g, "").slice(0, 64) || "unknown"

const statePath = (id: string) => join(STATE_DIR, safeId(id) + ".json")

const writeAtomic = (file: string, obj: object) => {
  mkdirSync(STATE_DIR, { recursive: true })
  const tmp = file + "." + process.pid + ".tmp"
  writeFileSync(tmp, JSON.stringify(obj))
  renameSync(tmp, file)
}

const renameSync = (from: string, to: string) => {
  try { writeFileSync(to, readFileSync(from)); rmSync(from) } catch {}
}

interface StateFile {
  state: string; label: string; tool: string; project: string
  sessionId: string; transcript: string; entrypoint: string
  term_program: string; pid: number; started: boolean
  startedAt: number; ts: number
}

const readState = (id: string): Partial<StateFile> => {
  try { return JSON.parse(readFileSync(statePath(id), "utf8")) } catch { return {} }
}

const safeStr = (v: unknown): string => (v ?? "").toString().slice(0, 128)

const appRunning = () => {
  try {
    const r = Bun.spawnSync(["pgrep", "-x", EXEC], { stdio: "ignore" })
    return r.exitCode === 0
  } catch { return false }
}

const launchApp = () => {
  try {
    Bun.spawnSync(["open", "-g", "-b", BUNDLE_ID], { stdio: "ignore" })
  } catch {}
}

export default async () => {
  const sessions = new Map<string, { busy: boolean; tool?: string }>()
  const pendingPermissions = new Set<string>()

  const setState = (
    sid: string,
    state: string,
    label: string,
    tool: string,
    project: string,
    startedAt?: number,
  ) => {
    if (!sid) return
    const id = safeId(sid)
    const prev = readState(id)
    const ts = Math.floor(Date.now() / 1000)
    const out: StateFile = {
      state, label,
      tool, project: project || prev.project || "",
      sessionId: sid, transcript: prev.transcript || "",
      entrypoint: process.env.OPENCODE_CLIENT || "cli",
      term_program: process.env.TERM_PROGRAM || "",
      pid: process.pid,
      started: true,
      startedAt: startedAt ?? prev.startedAt ?? 0,
      ts,
    }
    writeAtomic(statePath(id), out)
  }

  const removeSession = (sid: string) => {
    const id = safeId(sid)
    try { rmSync(statePath(id), { force: true }) } catch {}
    sessions.delete(id)
  }

  launchApp()

  return {
    event: async ({ event }: { event: any }) => {
      const t = event.type
      const p = event.properties || {}

      switch (t) {
        case "session.created": {
          const info = p.info || {}
          const sid = info.id || ""
          const project = info.directory ? basename(info.directory) : ""
          if (!sid) break
          sessions.set(safeId(sid), { busy: false })
          const prev = readState(sid)
          const ts = Math.floor(Date.now() / 1000)
          writeAtomic(statePath(sid), {
            state: "idle", label: "", tool: "", project,
            sessionId: sid, transcript: "", entrypoint: process.env.OPENCODE_CLIENT || "cli",
            term_program: process.env.TERM_PROGRAM || "", pid: process.pid,
            started: prev.started ?? false, startedAt: 0, ts,
          })
          if (!appRunning()) launchApp()
          break
        }

        case "session.status": {
          const sid = safeStr(p.sessionID)
          const status = p.status || {}
          const prev = readState(sid)
          if (status.type === "busy") {
            if (pendingPermissions.has(sid)) break
            sessions.set(sid, { ...sessions.get(sid), busy: true })
            if (prev.state !== "tool") {
              setState(sid, "thinking", "Thinking…", "", prev.project || "", Date.now() / 1000)
            }
          } else if (status.type === "idle") {
            sessions.set(sid, { ...sessions.get(sid), busy: false })
            if (!pendingPermissions.has(sid)) {
              setState(sid, "idle", "", "", prev.project || "")
            }
          }
          break
        }

        case "session.idle": {
          const sid = safeStr(p.sessionID)
          if (!pendingPermissions.has(sid)) {
            setState(sid, "idle", "", "", "")
          }
          break
        }

        case "permission.asked": {
          const perm = p || {}
          const sid = safeStr(perm.sessionID)
          if (!sid) break
          pendingPermissions.add(sid)
          sessions.set(sid, { ...sessions.get(sid), busy: false })
          setState(sid, "permission", "Waiting permission", "", "")
          break
        }

        case "permission.replied": {
          const sid = safeStr(p.sessionID)
          pendingPermissions.delete(sid)
          sessions.set(sid, { ...sessions.get(sid), busy: true })
          setState(sid, "thinking", "Thinking…", "", "")
          break
        }

        case "session.deleted": {
          removeSession(safeStr(p.info?.id || ""))
          break
        }

        case "session.error": {
          const sid = safeStr(p.sessionID)
          if (sid) setState(sid, "idle", "Error", "", "")
          break
        }
      }
    },

    "tool.execute.before": async (input: { tool: string; sessionID: string }) => {
      const sid = safeStr(input.sessionID)
      if (pendingPermissions.has(sid)) return
      const tool = input.tool || ""
      const label = TOOL_LABELS[tool] || "Using tool"
      sessions.set(sid, { ...sessions.get(sid), busy: true, tool })
      setState(sid, "tool", label, tool, "", Date.now() / 1000)
    },

    "tool.execute.after": async (input: { tool: string; sessionID: string; args: any }) => {
      const sid = safeStr(input.sessionID)
      if (pendingPermissions.has(sid)) return
      const prev = sessions.get(sid)
      sessions.set(sid, { ...prev, busy: true, tool: undefined })
      setState(sid, "thinking", "Thinking…", "", "", Date.now() / 1000)
    },
  }
}
