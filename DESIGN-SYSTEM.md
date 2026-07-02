# System Group Design

## Overview

The System group displays live hardware resource metrics in the status bar menu, positioned between the **Sessions** and **Options** sections.

```
┌─────────────────────────────┐
│ System                      │  ← header (disabled, gray)
│ CPU: 47%                    │
│ RAM: 8.2/16.0 GB            │
│─────────────────────────────│  ← separator
```

## Menu Layout

Populated in `populateMenu()` at line 847:

```swift
menu.addItem(header("System"))       // section header
menu.addItem("CPU: XX%")             // disabled menu item
menu.addItem("RAM: X.X/XX.X GB")     // disabled menu item
menu.addItem(.separator())
```

Formatting:
- **CPU**: integer percentage, e.g. `CPU: 47%`
- **RAM**: one decimal place, e.g. `RAM: 8.2/16.0 GB`

Values are cached properties (`cpuUsage`, `ramUsed`, `ramTotal`) updated every tick (0.4 s). Menu reads the cached values at open time — no blocking I/O on menu render.

## CPU Usage

### Data Source
`host_cpu_load_info_data_t` via `host_statistics()` with flavor `HOST_CPU_LOAD_INFO`. Returns cumulative tick counts since boot across four buckets:

| Field | Represents |
|-------|-----------|
| `cpu_ticks.0` | User (user-space) |
| `cpu_ticks.1` | System (kernel) |
| `cpu_ticks.2` | Idle |
| `cpu_ticks.3` | Nice (low-priority) |

### Delta Calculation

Since ticks are cumulative, usage is derived from the delta between consecutive reads:

```swift
totalDelta = (userΔ + systemΔ + idleΔ + niceΔ)
idleDelta  = idleΔ
cpuUsage   = (totalDelta - idleDelta) / totalDelta × 100
```

### Seed at Init

`prevCpuTicks` is seeded in `init()` via an initial `updateSystemStats()` call before the timer starts. This ensures the first `tick()` at 0.4 s produces a valid delta, avoiding a ~0.4 s window where `cpuUsage` would be 0.

### Polling Interval

- Timer fires every **0.4 seconds** (loop mode `.common`)
- CPU delta is calculated fresh on every tick
- Menu reads the latest cached value without re-querying mach

## RAM Usage

### Total
`ProcessInfo.processInfo.physicalMemory` — total physical RAM in bytes.

### Used
Derived from `vm_statistics64_data_t` via `host_statistics64()` with `HOST_VM_INFO64`:

```swift
ramUsed = (active_count + wire_count + compressor_page_count) × page_size
```

| Field | Meaning |
|-------|---------|
| `active_count` | Pages currently mapped and recently used |
| `wire_count`   | Pages locked in memory (cannot be paged out) |
| `compressor_page_count` | Pages compressed by memory pressure |

## Temperature (SMC, optional)

On real Mac hardware, CPU temperature is read from AppleSMC via `IOConnectCallStructMethod` with an 80-byte `SMCParam` struct:

1. **`kSMCGetKeyInfo`** (function 2, `d8 = 5`) — query data type and size for a key
2. **`kSMCReadKey`** (function 2, `d8 = 6`) — read the value

### Keys Tried (in order)
| Key | Description | Format |
|-----|-------------|--------|
| `TC0P` | CPU proximity | `sp78` (signed 7.8 fixed-point, divide by 256) |
| `TC01` | CPU core 1 | `sp78` |
| `TC0D` | CPU die | `sp78` or `flt ` |

### Fallback
If no SMC key succeeds (e.g. Hackintosh with VirtualSMC), `temperature` stays `nil` and the temperature row is omitted from the menu.

## State Properties

```swift
var cpuUsage: Double = 0
var ramUsed: UInt64 = 0
var ramTotal: UInt64 = 0
var temperature: Double?     // nil = unavailable, hide row
var prevCpuTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
```

## Lifecycle

```
init()
  └─ loadConfig()
  └─ UserDefaults init
  └─ menu setup
  └─ updateSystemStats()       ← seed prevCpuTicks
  └─ Timer(0.4s) → tick()

tick()
  ├─ reloadConfigIfNeeded()
  ├─ checkLifecycle()
  ├─ reloadSessions()
  ├─ evaluate()
  ├─ updateSystemStats()       ← update cpuUsage, ramUsed, temperature
  └─ if menuIsOpen → refreshOpenMenuRows()

populateMenu()
  └─ reads cached cpuUsage, ramUsed, ramTotal, temperature
```

## Key Files

| File | Role |
|------|------|
| `Sources/main.swift:1969` | `updateSystemStats()` implementation |
| `Sources/main.swift:847` | Menu population for System section |
| `Sources/main.swift:339` | Property declarations |
| `Sources/main.swift:664` | Seed call in `init()` |
