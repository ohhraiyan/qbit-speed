--!nonstrict
-- Live qBittorrent WebUI download/upload speed for the Noctalia bar.
--
-- Auth: qBittorrent's WebUI API is cookie-session based (POST
-- /api/v2/auth/login sets a SID cookie), but noctalia.http()'s HttpResponse
-- only exposes {ok, status, body} — no headers, so no way to read/replay
-- Set-Cookie through it. Shelling out to curl with a cookie jar sidesteps
-- that entirely.
--
-- Rendering: barWidget.render() (declarative ui.* tree) instead of
-- setText/setGlyph, since per-direction glyph + color needs two independently
-- styled label/glyph pairs, which the plain text API can't do.

local host = noctalia.getConfig("host") or "192.168.0.123"
local port = noctalia.getConfig("port") or 8080
local username = noctalia.getConfig("username") or ""
local password = noctalia.getConfig("password") or ""
local pollMs = noctalia.getConfig("poll_interval_ms") or 2000

local dataDir = noctalia.pluginDataDir() or "/tmp"
local jarPath = dataDir .. "/qbit-session.cookie"

local dlSpeed = 0
local upSpeed = 0
local connected = false
local busy = false

local function fmtSpeed(bytesPerSec: number): string
  local mode = noctalia.getConfig("unit_mode") or "bytes"
  local val = bytesPerSec
  local units
  local base

  if mode == "bits" then
    val = val * 8
    units = { "b/s", "Kb/s", "Mb/s", "Gb/s" }
    base = 1000
  else
    units = { "B/s", "KB/s", "MB/s", "GB/s" }
    base = 1024
  end

  local i = 1
  while val >= base and i < #units do
    val = val / base
    i += 1
  end
  local decimals = (i == 1) and 0 or 1
  return string.format("%." .. decimals .. "f %s", val, units[i])
end

-- Defensive: some settings surfaces round-trip bools as the strings "true"/
-- "false" rather than real booleans. A stray truthy non-empty string would
-- silently defeat the toggle (Lua treats "false" as truthy), so normalize.
local function toBool(value, default)
  if value == nil then
    return default
  end
  if type(value) == "boolean" then
    return value
  end
  if type(value) == "string" then
    return value == "true"
  end
  return default
end

local function render()
  local showDownload = toBool(noctalia.getConfig("show_download"), true)
  local showUpload = toBool(noctalia.getConfig("show_upload"), true)

  local downloadGlyph = noctalia.getConfig("download_glyph") or "arrow-down"
  local downloadColor = noctalia.getConfig("download_color") or "#89b4fa"
  local uploadGlyph = noctalia.getConfig("upload_glyph") or "arrow-up"
  local uploadColor = noctalia.getConfig("upload_color") or "#fab387"

  local content = {}

  table.insert(content, ui.box({
    width = 6,
    height = 6,
    radius = 3,
    fill = connected and "success" or "error",
  }))

  if showDownload then
    table.insert(content, ui.glyph({ name = downloadGlyph, size = 12, color = downloadColor }))
    table.insert(content, ui.label({ text = fmtSpeed(dlSpeed), color = downloadColor }))
  end

  if showUpload then
    table.insert(content, ui.glyph({ name = uploadGlyph, size = 12, color = uploadColor }))
    table.insert(content, ui.label({ text = fmtSpeed(upSpeed), color = uploadColor }))
  end

  if #content == 1 then
    -- both directions hidden; fall back to a plain status label so the
    -- widget isn't just a bare dot
    table.insert(content, ui.label({ text = connected and "qBit" or "qBit offline" }))
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 6, align = "center" }, content))

  barWidget.setTooltip({
    { key = "Host", value = host .. ":" .. tostring(port) },
    { key = "Down", value = fmtSpeed(dlSpeed) },
    { key = "Up", value = fmtSpeed(upSpeed) },
    { key = "Status", value = connected and "connected" or "unreachable" },
    -- Debug aid: if this doesn't match plugin.toml's version after a reload,
    -- the running instance is still the old script and needs a harder kick
    -- (disable/enable via `noctalia msg plugins`, or a full restart).
    { key = "Script ver", value = "1.1.1" },
  })
end

local function buildCommand(): string
  local base = "http://" .. host .. ":" .. tostring(port)
  local userEnc = noctalia.string.urlEncode(username)
  local passEnc = noctalia.string.urlEncode(password)
  local jar = "'" .. jarPath .. "'"
  -- Referer must match the WebUI origin or qBittorrent's CSRF check 403s the
  -- login POST on newer builds, even with correct credentials.
  local ref = '-H "Referer: ' .. base .. '"'
  local parts = {
    "JAR=" .. jar,
    'RESP="$(curl -s -4 --max-time 5 ' .. ref .. ' -b "$JAR" -c "$JAR" "' .. base .. '/api/v2/transfer/info")"',
    'FIRST="$(printf \'%s\' "$RESP" | head -c1)"',
    'if [ "$FIRST" != "{" ]; then',
    '  curl -s -4 --max-time 5 ' .. ref .. ' -c "$JAR" --data "username=' .. userEnc .. '&password=' .. passEnc .. '" "' .. base .. '/api/v2/auth/login" -o /dev/null',
    '  RESP="$(curl -s -4 --max-time 5 ' .. ref .. ' -b "$JAR" "' .. base .. '/api/v2/transfer/info")"',
    "fi",
    'printf \'%s\' "$RESP"',
  }
  return table.concat(parts, "\n")
end

local function poll()
  if busy then
    return
  end
  busy = true
  noctalia.runAsync(buildCommand(), function(result)
    busy = false
    if result.exitCode ~= 0 or result.stdout == "" then
      connected = false
      render()
      return
    end
    local data, err = noctalia.json.decode(result.stdout)
    if err or not data then
      connected = false
      render()
      return
    end
    connected = true
    dlSpeed = data.dl_info_speed or 0
    upSpeed = data.up_info_speed or 0
    render()
  end, 8000)
end

function update()
  noctalia.setUpdateInterval(pollMs)
  poll()
end

-- Fires when any setting (plugin- or widget-level) changes, e.g. flipping
-- unit_mode or a color — re-render immediately instead of waiting for the
-- next poll tick.
function onConfigChanged()
  render()
end

function onClick()
  poll()
  noctalia.notify("qBittorrent", fmtSpeed(dlSpeed) .. " down / " .. fmtSpeed(upSpeed) .. " up")
end
