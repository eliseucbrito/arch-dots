--!nonstrict
-- CIn VPN bar widget: shows a lock glyph reflecting service.luau's status
-- snapshot. Click opens the connect/disconnect panel.

local PANEL_ID = "ecb/vpn:panel"

local snapshot = noctalia.state.get("vpn_snapshot") or { connected = false, name = nil, busy = false }

local function render()
  local connected = snapshot.connected == true
  local color = connected and "primary" or "on_surface_variant"
  local container = barWidget.isVertical() and ui.column or ui.row

  barWidget.render(container({ gap = 5, align = "center" }, {
    ui.glyph({ name = connected and "lock" or "lock-open", size = 16, color = color }),
  }))

  if connected then
    barWidget.setTooltip("VPN CIn: " .. tostring(snapshot.name or "conectada"))
  elseif snapshot.busy == true then
    barWidget.setTooltip("VPN CIn: conectando…")
  else
    barWidget.setTooltip("VPN CIn desconectada — clique para conectar")
  end
end

noctalia.state.watch("vpn_snapshot", function(value)
  if type(value) == "table" then
    snapshot = value
    render()
  end
end)

render()

function update()
  render()
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end
