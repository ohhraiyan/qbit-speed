# qBittorrent Speed

Live download/upload speed from a qBittorrent WebUI instance, shown as a
[Noctalia](https://github.com/noctalia-dev) shell bar widget.

![status](https://img.shields.io/badge/noctalia-v5%20plugin-cba6f7)

## Features

- Live download/upload speed, polled on an adjustable interval
- Toggle units between `MB/s` (bytes, binary) and `Mb/s` (bits, decimal)
- Show/hide download and upload independently
- Custom glyph and color per direction (accepts hex or a theme role name)
- Small status dot reflects whether the WebUI is currently reachable
- Click the widget to force an immediate refresh + notification

## Requirements

- Noctalia shell (v5, plugin API 3+)
- `curl` on `PATH`
- A reachable qBittorrent WebUI (Tools → Options → Web UI in qBittorrent)

## Install

```bash
git clone https://github.com/ohhraiyan/qbit-speed.git \
  ~/.local/share/noctalia/plugins/qbit-speed
```

Then in Noctalia: **Settings → Plugins**, find **qBittorrent Speed** in the
list and enable it. Add the **qBittorrent Speed** widget to a bar section
from the bar layout editor.

To update later:

```bash
cd ~/.local/share/noctalia/plugins/qbit-speed
git pull
```

Then disable/re-enable the plugin (or restart Noctalia) so the updated
script actually gets picked up — local plugin sources aren't hot-reloaded on
file change.

## Configuration

**Plugin settings** (Settings → Plugins → gear icon on this plugin's row):

| Setting | Description | Default |
|---|---|---|
| Host | qBittorrent WebUI host or IP | `192.168.0.123` |
| Port | qBittorrent WebUI port | `8080` |
| Username | WebUI login username | `admin` |
| Password | WebUI login password (stored/shown as plain text) | *(empty)* |
| Poll interval (ms) | How often to refresh | `2000` |

**Widget settings** (open the widget's own config panel from the bar layout
editor):

| Setting | Description | Default |
|---|---|---|
| Speed unit | `MB/s` (bytes) or `Mb/s` (bits) | `MB/s` |
| Show download speed | Toggle the download readout | on |
| Download glyph | Icon shown next to download speed | `arrow-down` |
| Download color | Hex or theme role | `#89b4fa` |
| Show upload speed | Toggle the upload readout | on |
| Upload glyph | Icon shown next to upload speed | `arrow-up` |
| Upload color | Hex or theme role | `#fab387` |

If your qBittorrent WebUI has authentication bypassed for your subnet
(**Tools → Options → Web UI → Bypass authentication for clients in
whitelisted IP subnets**), username/password can be left as-is — the
plugin only logs in when a request comes back unauthenticated.

## How it works

qBittorrent's WebUI API is cookie-session based, but Noctalia's built-in
`noctalia.http()` doesn't expose response headers, so there's no way to read
or replay the `Set-Cookie` a login sets. Instead the plugin shells out to
`curl` (via `noctalia.runAsync`) with a cookie jar stored in the plugin's
data directory: it tries `/api/v2/transfer/info` with the existing jar, and
only logs in (`/api/v2/auth/login`) if that comes back unauthenticated,
then retries.

## License

MIT
