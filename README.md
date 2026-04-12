# qBittorrent Speeds – Noctalia Plugin

A Noctalia Shell plugin that shows **live download and upload speeds** from one or more qBittorrent instances directly in your bar.

## Features

- 📥📤 Live per-instance download **and** upload speeds in the bar widget
- 🖱️ Click the bar widget to open a detail panel with per-instance stats (speed, totals, torrent count, connection status)
- ➕ Add unlimited qBittorrent instances (local, seedbox, remote)
- ⚙️ Configurable refresh interval (1–30 s)
- 🔒 Per-instance username/password authentication via qBittorrent's Web API
- 🌙 Fully themed with Noctalia's design system

## Requirements

- Noctalia Shell ≥ 3.6.0
- qBittorrent with **Web UI enabled** (Tools → Preferences → Web UI)
- The Web UI must be reachable from the machine running Noctalia

## Installation

```bash
cd ~/.config/noctalia/plugins/
git clone https://github.com/yourusername/noctalia-plugins qbittorrent-speeds
# or just copy the folder
```

Then register in `~/.config/noctalia/plugins.json`:

```json
{
  "qbittorrent-speeds": {
    "enabled": true,
    "sourceUrl": "https://github.com/yourusername/noctalia-plugins"
  }
}
```

Restart Noctalia, go to **Settings → Plugins**, enable *qBittorrent Speeds*, then add it to your bar in **Settings → Bar**.

## Configuration

Open **Settings → Plugins → qBittorrent Speeds → Configure** to:

- Add / remove qBittorrent instances (name, host URL, username, password)
- Toggle download / upload display in the bar widget
- Set the polling refresh interval

## qBittorrent Web UI Setup

1. Open qBittorrent → **Tools → Preferences → Web UI**
2. Enable **Web User Interface**
3. Set a port (default 8080)
4. Set a username and password
5. Optionally: disable "Host header validation" if connecting from a remote host

The plugin uses qBittorrent's **Web API v2** (`/api/v2/transfer/info`, `/api/v2/torrents/count`).

## File Structure

```
qbittorrent-speeds/
├── manifest.json      # Plugin metadata & default settings
├── BarWidget.qml      # Bar widget – combined speeds from all instances
├── Panel.qml          # Detail panel – per-instance breakdown
├── Settings.qml       # Settings UI – manage instances & options
└── README.md
```
