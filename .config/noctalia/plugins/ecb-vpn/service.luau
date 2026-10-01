--!nonstrict
-- Headless backend for the CIn VPN widget/panel: polls vpn.sh status and
-- runs connect/disconnect commands requested through noctalia.state.

local SCRIPT = noctalia.getenv("HOME") .. "/.config/noctalia/plugins/ecb-vpn/scripts/vpn.sh"

local snapshot = { connected = false, name = nil, hasPassword = false, busy = false, error = "" }
local busy = false

local function publish()
  snapshot.busy = busy
  noctalia.state.set("vpn_snapshot", snapshot)
end

local function refreshStatus()
  noctalia.runAsync(SCRIPT .. " status", function(result)
    if result and result.exitCode == 0 then
      local decoded = noctalia.json.decode(noctalia.string.trim(result.stdout or ""))
      if type(decoded) == "table" then
        snapshot.connected = decoded.connected == true
        snapshot.name = decoded.name
        snapshot.hasPassword = decoded.hasPassword == true
        snapshot.error = ""
      end
    else
      snapshot.error = noctalia.string.trim(result and result.stderr or "vpn.sh failed")
    end
    publish()
  end)
end

local function runAction(command)
  if busy then return end
  busy = true
  publish()
  noctalia.runAsync(SCRIPT .. " " .. command, function(result)
    busy = false
    if result == nil or result.exitCode ~= 0 then
      snapshot.error = noctalia.string.trim(result and result.stderr or "vpn.sh failed")
    else
      snapshot.error = ""
    end
    refreshStatus()
  end)
end

noctalia.state.watch("vpn_command", function(command)
  if command == "connect" then
    runAction("connect")
  elseif command == "disconnect" then
    runAction("disconnect")
  end
end)

noctalia.setUpdateInterval(10000)
refreshStatus()

function update()
  refreshStatus()
end

function onIpc(event, _payload)
  if event == "refresh" then
    refreshStatus()
  end
end
