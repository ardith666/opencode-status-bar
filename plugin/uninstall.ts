import { existsSync, rmSync } from "fs"
import { homedir } from "os"
import { join } from "path"

const pluginPath = join(homedir(), ".config", "opencode", "plugins", "statusbar.ts")
const stateDir = join(homedir(), ".config", "opencode", "statusbar")

if (existsSync(pluginPath)) {
  rmSync(pluginPath)
  console.log("Removed statusbar plugin")
}
if (existsSync(stateDir)) {
  rmSync(stateDir, { recursive: true, force: true })
  console.log("Removed statusbar state directory")
}
