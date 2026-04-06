# NEXUS-OS

**Autonomous Surveillance Operating System for OpenComputers 1.12.2**

A full custom OS replacing OpenOS with a matrix-themed GUI desktop, modular surveillance applications, drone fleet management, and deep mod integration.

---

## Hardware Requirements

| Component | Requirement |
|-----------|------------|
| **CPU** | Tier 3 |
| **GPU** | Tier 3 (required — 160×50, 256 colors, VRAM buffers) |
| **RAM** | 2× Tier 3.5 recommended (minimum 1× Tier 3) |
| **HDD** | Tier 3 (or RAID) |
| **Screen** | Tier 3 |
| **Internet Card** | Required for installer download mode |
| **Network Card** | Required for networking, drone control, SIGINT |
| **Motion Sensor** | Required for entity tracking |
| **Geolyzer** | Required for terrain mapping |
| **Navigation Upgrade** | Recommended for drone positioning |

### Optional (enables mod drivers)

- **Adapter Block** + mod machines (AE2, Big Reactors, IC2, Mekanism, Draconic Evolution, Ender IO, Thermal Expansion)
- **Redstone I/O** or **Redstone Card**
- **Transposer**
- **Chunk Loader Upgrade**

### For Drones

- Drone with Tier 2+ components
- Wireless Network Card
- Navigation Upgrade (recommended)
- EEPROM (flash `firmware/drone_boot.lua`)

---

## Installation

### Method 1: Local Copy (recommended)

1. Copy the entire `nexus/` folder contents to the root of your OpenComputers HDD
2. The file structure should be:
   ```
   /init.lua
   /boot/
   /lib/
   /drivers/
   /bin/
   /apps/
   /firmware/
   /etc/
   /var/
   ```
3. Reboot the computer

### Method 2: Installer Script

1. From an OpenOS shell, run:
   ```
   cp /path/to/install.lua /tmp/install.lua
   /tmp/install.lua
   ```
2. Select install mode (local copy or download)
3. Follow the on-screen prompts
4. Reboot when prompted

---

## First Boot

On first boot, NEXUS-OS will:

1. Display a **matrix rain** boot animation
2. Run **POST** (Power-On Self-Test) showing detected hardware
3. Drop into the **kernel shell** (PID 1)

From the kernel shell, type:
- `desktop` — Launch the GUI desktop environment
- `help` — Show available commands
- `status` — System status
- `ps` — Process list
- `components` — List hardware components

---

## Desktop Environment

The desktop features:
- **Taskbar** at the bottom with window buttons, clock, and threat indicator
- **App Launcher** (Ctrl+L) to open applications
- **Window Manager** with drag, resize, minimize, close
- **Ctrl+Q** — Close focused window

### Color Themes

Three built-in themes (changeable in Settings):
- **Matrix** — Green on black (default)
- **Phantom** — Purple on dark
- **Ember** — Red/orange on dark

---

## Applications

### Tracker (`tracker.app`)
Real-time entity tracking via motion sensor. Radar display with player/hostile/passive/drone classification. Alert system for player detection.

### Mapper (`mapper.app`)
Geolyzer-based terrain mapper. 2D layer view with ore detection and hardness color coding. Adjustable Y-level and scan radius. Save maps to `/var/maps/`.

### SIGINT (`sigint.app`)
Signal Intelligence — modem packet capture and analysis. Port scanner, live packet feed, frequency analysis chart, network node discovery.

### Drones (`drones.app`)
Drone fleet management console. Deploy commands: Tail (follow player), Patrol (waypoint cycle), Orbit (circle coordinates), Recon (fly-scan-return). Battery monitoring, telemetry display, fleet radar view.

### AE2 Monitor (`ae2mon.app`)
Applied Energistics 2 network monitor. Storage overview, item search, power usage tracking, crafting CPU status. Requires Adapter block adjacent to ME Controller.

### Reactor Monitor (`reactor.app`)
Multi-reactor monitoring dashboard. Auto-detects: Big Reactors, BR Turbines, IC2 Reactors, Draconic Reactors, Mekanism Induction Matrix. Energy sparklines, toggle controls.

### Network Monitor (`netmon.app`)
Network topology viewer. Node discovery, traffic monitoring, ping latency. Shows all NEXUS-OS nodes on the network.

### Terminal (`terminal.app`)
Built-in terminal emulator running the NEXUS shell. Supports command history, environment variables, and external commands from `/bin/`.

### Settings (`settings.app`)
System configuration. Theme selection with live preview, component inventory, system information (RAM, VRAM, uptime, processes).

---

## Drone Operation

### Setup

1. Build a drone with a wireless network card
2. Flash `firmware/drone_boot.lua` onto the drone's EEPROM
3. Ensure the base station has a wireless network card and is running NEXUS-OS
4. Power on the drone — it will broadcast a boot request
5. The base station's drone server automatically deploys the runtime via OTA

### Commands

From the Drones app:
- **Tail** — Follow a named player at configurable distance
- **Patrol** — Cycle through waypoints (manual or from Navigation upgrade)
- **Orbit** — Circle a coordinate at set radius and altitude
- **Recon** — Fly to target, scan area, return home
- **Home** — Return to base
- **Halt** — Emergency stop

### Protocol

Drones communicate on modem port 9200 using the `NX_DRONE_*` message protocol:
- `NX_DRONE_BOOT` — Boot request
- `NX_DRONE_CODE` — OTA code delivery
- `NX_DRONE_CMD` — Command dispatch
- `NX_DRONE_HEARTBEAT` — Periodic heartbeat
- `NX_DRONE_TELEMETRY` — Full telemetry report
- `NX_DRONE_ALERT` — Alert condition (low energy, target lost)

---

## Shell Commands

| Command | Description |
|---------|-------------|
| `ls [path]` | List directory contents |
| `cat <file>` | Display file contents |
| `edit <file>` | Text editor (Ctrl+S save, Ctrl+Q quit) |
| `top` | Process table and memory usage |
| `ifconfig` | Network interface info |
| `ping [addr]` | Ping a node or discover all |
| `reboot` | Reboot the computer |

---

## Network Protocol

NEXUS-OS nodes communicate using an encrypted packet protocol:

- **Port 9100** — Data messages
- **Port 9101** — Acknowledgments
- **Port 9102** — Discovery
- **Port 9200** — Drone communication

Packets include XOR cipher encryption, sequence numbers for dedup, and ACK/retry for reliable delivery (3 retries, 2s timeout).

---

## File Structure

```
/
├── init.lua              # Kernel entry point
├── install.lua           # Installer script
├── boot/
│   ├── 01_hardware.lua   # Hardware detection
│   ├── 02_memory.lua     # Custom require() & filesystem
│   ├── 03_scheduler.lua  # Coroutine scheduler
│   └── 04_events.lua     # Event system
├── lib/
│   ├── serial.lua        # Serialization
│   ├── config.lua        # Config file management
│   ├── logger.lua        # Logging with rotation
│   ├── theme.lua         # Color themes
│   ├── net.lua           # Network protocol
│   ├── process.lua       # Process management
│   ├── ipc.lua           # Inter-process communication
│   ├── boot_anim.lua     # Boot animation
│   ├── desktop.lua       # Desktop environment
│   ├── drone_server.lua  # Drone fleet server
│   └── gui/
│       ├── screen.lua    # VRAM double buffer
│       ├── widget.lua    # Base widget
│       ├── container.lua # Widget container
│       ├── workspace.lua # Root workspace
│       ├── window.lua    # Window manager
│       ├── taskbar.lua   # Taskbar
│       ├── button.lua    # Button widget
│       ├── textfield.lua # Text input
│       ├── listview.lua  # Sortable list
│       ├── scrollview.lua# Scroll container
│       ├── tabbar.lua    # Tab bar
│       ├── chart.lua     # Sparkline/bar chart
│       ├── radar.lua     # Radar display
│       ├── progress.lua  # Progress bar
│       └── modal.lua     # Modal dialogs
├── drivers/
│   ├── gpu.lua           # GPU driver
│   ├── keyboard.lua      # Keyboard + hotkeys
│   ├── modem.lua         # Network modem
│   ├── geolyzer.lua      # Terrain scanner
│   ├── motion.lua        # Motion sensor
│   ├── redstone.lua      # Redstone I/O
│   ├── navigation.lua    # Navigation upgrade
│   ├── chunkloader.lua   # Chunk loader
│   ├── transposer.lua    # Item transfer
│   ├── adapter.lua       # Generic adapter
│   ├── ae2.lua           # Applied Energistics 2
│   ├── bigreactors.lua   # Big Reactors
│   ├── ic2.lua           # IndustrialCraft 2
│   ├── mekanism.lua      # Mekanism
│   ├── draconic.lua      # Draconic Evolution
│   ├── enderio.lua       # Ender IO
│   └── thermal.lua       # Thermal Expansion
├── bin/
│   ├── sh.lua            # Shell interpreter
│   ├── ls.lua            # Directory listing
│   ├── cat.lua           # File viewer
│   ├── top.lua           # Process monitor
│   ├── ifconfig.lua      # Network info
│   ├── ping.lua          # Network ping
│   ├── reboot.lua        # System reboot
│   └── edit.lua          # Text editor
├── apps/
│   ├── tracker.app/      # Entity tracker
│   ├── mapper.app/       # Terrain mapper
│   ├── sigint.app/       # Signal intelligence
│   ├── drones.app/       # Drone fleet control
│   ├── ae2mon.app/       # AE2 monitor
│   ├── reactor.app/      # Reactor monitor
│   ├── netmon.app/       # Network monitor
│   ├── terminal.app/     # Terminal emulator
│   └── settings.app/     # System settings
├── firmware/
│   ├── drone_boot.lua    # Drone EEPROM (<4KB)
│   ├── drone_core.lua    # Drone OTA runtime
│   ├── drone_tail.lua    # Tail mode module
│   ├── drone_patrol.lua  # Patrol mode module
│   ├── drone_orbit.lua   # Orbit mode module
│   └── drone_recon.lua   # Recon mode module
├── etc/
│   └── os.cfg            # System configuration
├── var/
│   ├── log/              # Log files
│   ├── maps/             # Saved terrain maps
│   └── drone_telemetry/  # Drone data
└── tmp/                  # Temporary files
```

---

## License

MIT License. See LICENSE file.
