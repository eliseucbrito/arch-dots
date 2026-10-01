--!nonstrict
-- Plugin launcher panel: scans the plugins directory, reads each
-- plugin.toml with a minimal line-based parser, and lists every plugin.
-- Plugins that declare at least one [[panel]] entry get an "Abrir" button
-- that calls noctalia.togglePanel("<id>:<panel-id>").

-- Local/dev plugins live directly under the data dir; plugins installed
-- from a git source (official/community) get checked out one level
-- deeper, under materialized/<source-name>/<plugin-dir>.
local HOME = noctalia.getenv("HOME")
local SCAN_ROOTS = {
  { dir = HOME .. "/.local/share/noctalia/plugins" },
  { dir = HOME .. "/.local/state/noctalia/plugins/materialized/official" },
  { dir = HOME .. "/.local/state/noctalia/plugins/materialized/community" },
}

-- Minimal TOML reader: only understands what plugin.toml manifests use
-- (root key = "value" pairs and [[table]] array-of-tables headers).
-- Good enough to pull id/name/icon and panel entry ids; anything else
-- in the file is ignored.
local function parseManifest(text)
  local manifest = { panels = {} }
  local currentTable = nil
  local currentPanel = nil

  for line in text:gmatch("[^\r\n]+") do
    local trimmed = noctalia.string.trim(line)
    if trimmed == "" or trimmed:sub(1, 1) == "#" then
      -- skip blanks/comments
    else
      local tableHeader = trimmed:match("^%[%[([%w_%.]+)%]%]$")
      local sectionHeader = trimmed:match("^%[([%w_%.]+)%]$")
      if tableHeader then
        currentTable = tableHeader
        if currentTable == "panel" then
          currentPanel = { id = nil, entry = nil }
          table.insert(manifest.panels, currentPanel)
        else
          currentPanel = nil
        end
      elseif sectionHeader then
        currentTable = sectionHeader
        currentPanel = nil
      else
        local key, value = trimmed:match("^([%w_]+)%s*=%s*(.-)%s*$")
        if key and value then
          local stringValue = value:match('^"(.-)"$')
          if stringValue then
            value = stringValue
          end
          if currentTable == nil then
            manifest[key] = value
          elseif currentTable == "panel" and currentPanel then
            currentPanel[key] = value
          end
        end
      end
    end
  end

  return manifest
end

local plugins = {}
local errorMessage = ""

local function scan()
  plugins = {}
  errorMessage = ""

  local seenIds = {}
  local readErrors = {}

  for _, root in ipairs(SCAN_ROOTS) do
    local entries, listErr = noctalia.listDir(root.dir)
    if entries == nil then
      table.insert(readErrors, root.dir .. ": " .. tostring(listErr))
    else
      for _, entryName in ipairs(entries) do
        local manifestPath = root.dir .. "/" .. entryName .. "/plugin.toml"
        if noctalia.fileExists(manifestPath) then
          local content = noctalia.readFile(manifestPath)
          if content then
            local ok, manifest = pcall(parseManifest, content)
            if ok and manifest.id and manifest.name and not seenIds[manifest.id] then
              seenIds[manifest.id] = true
              table.insert(plugins, {
                dirName = entryName,
                id = manifest.id,
                name = manifest.name,
                icon = manifest.icon or "puzzle",
                description = manifest.description,
                panels = manifest.panels,
              })
            end
          end
        end
      end
    end
  end

  if #plugins == 0 and #readErrors > 0 then
    errorMessage = "Não foi possível ler diretórios de plugins:\n" .. table.concat(readErrors, "\n")
  end

  table.sort(plugins, function(a, b) return a.name:lower() < b.name:lower() end)
end

local function render()
  local rows = {}

  table.insert(rows, ui.row({ gap = 8, align = "center" }, {
    ui.glyph({ name = "apps", size = 20, color = "primary" }),
    ui.label({ text = "Plugins instalados", fontWeight = "bold", flexGrow = 1 }),
    ui.button({ glyph = "refresh", glyphSize = 14, variant = "ghost", controlSize = "sm", onClick = "onRefresh" }),
  }))

  if errorMessage ~= "" then
    table.insert(rows, ui.label({ text = errorMessage, color = "error", maxLines = 3 }))
  elseif #plugins == 0 then
    table.insert(rows, ui.label({ text = "Nenhum plugin encontrado.", color = "on_surface_variant" }))
  end

  local listRows = {}
  for _, plugin in ipairs(plugins) do
    local hasPanel = #plugin.panels > 0

    local actionButton
    if hasPanel then
      local panelEntry = plugin.panels[1]
      local panelAddr = plugin.id .. ":" .. tostring(panelEntry.id)
      actionButton = ui.button({
        key = "open-" .. plugin.id,
        text = "Abrir",
        variant = "primary",
        controlSize = "sm",
        onClick = function() noctalia.togglePanel(panelAddr) end,
      })
    else
      actionButton = ui.label({
        text = "sem painel",
        color = "on_surface_variant",
        fontSize = 12,
      })
    end

    table.insert(listRows, ui.row({
      key = "row-" .. plugin.id,
      gap = 8,
      align = "center",
      padding = 6,
      radius = 8,
    }, {
      ui.glyph({ name = plugin.icon, size = 18, color = "on_surface" }),
      ui.label({ text = plugin.name, flexGrow = 1, maxLines = 1 }),
      actionButton,
    }))
  end

  table.insert(rows, ui.scroll({ gap = 4, flexGrow = 1 }, listRows))

  panel.render(ui.column({ gap = 10, padding = 12, flexGrow = 1 }, rows))
end

function onOpen(_context)
  scan()
  render()
end

function onRefresh()
  scan()
  render()
end

function onIpc(event, _payload)
  if event == "refresh" then
    scan()
    render()
  end
end
