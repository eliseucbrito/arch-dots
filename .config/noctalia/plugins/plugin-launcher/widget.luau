--!nonstrict
-- Bar widget: just an icon that toggles the plugin launcher panel.

local PANEL_ID = "ecb/plugin-launcher:panel"

function update()
  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 5, align = "center" }, {
    ui.glyph({ name = "apps", size = 16 }),
  }))
  barWidget.setTooltip("Plugin Launcher — abrir painéis de plugins instalados")
end

function onClick()
  noctalia.togglePanel(PANEL_ID)
end
