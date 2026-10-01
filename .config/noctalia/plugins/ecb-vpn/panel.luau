--!nonstrict
-- CIn VPN panel: connect/disconnect, plus a one-time password field that
-- writes straight to the Secret Service via vpn.sh set-password (never
-- through plugin state or settings.toml).

local SCRIPT = noctalia.getenv("HOME") .. "/.config/noctalia/plugins/ecb-vpn/scripts/vpn.sh"

local snapshot = noctalia.state.get("vpn_snapshot") or { connected = false, name = nil, hasPassword = false, busy = false, error = "" }
local passwordDraft = ""
local savingPassword = false
local feedback = ""
local feedbackError = false

local function render()
  local connected = snapshot.connected == true
  local rows = {}

  table.insert(rows, ui.row({ gap = 8, align = "center" }, {
    ui.glyph({ name = connected and "lock" or "lock-open", size = 20, color = connected and "primary" or "on_surface_variant" }),
    ui.label({
      text = connected and ("Conectado · " .. tostring(snapshot.name or "")) or "VPN desconectada",
      fontWeight = "bold",
      flexGrow = 1,
    }),
  }))

  if snapshot.error ~= "" then
    table.insert(rows, ui.label({ text = snapshot.error, color = "error", maxLines = 2 }))
  end
  if feedback ~= "" then
    table.insert(rows, ui.label({ text = feedback, color = feedbackError and "error" or "tertiary", maxLines = 2 }))
  end

  if connected then
    table.insert(rows, ui.button({
      text = "Desconectar",
      glyph = "lock-open",
      variant = "destructive",
      enabled = snapshot.busy ~= true,
      onClick = "onDisconnect",
    }))
  else
    if snapshot.hasPassword ~= true then
      table.insert(rows, ui.label({ text = "Defina a senha do CIn antes de conectar:", color = "on_surface_variant" }))
      table.insert(rows, ui.input({
        key = "vpn-password",
        value = passwordDraft,
        placeholder = "Senha do CIn",
        obscure = true,
        onChange = "onPasswordChange",
      }))
      table.insert(rows, ui.button({
        text = savingPassword and "Salvando…" or "Salvar senha",
        glyph = "device-floppy",
        variant = "primary",
        enabled = passwordDraft ~= "" and not savingPassword,
        onClick = "onSavePassword",
      }))
    else
      table.insert(rows, ui.button({
        text = snapshot.busy == true and "Conectando…" or "Conectar",
        glyph = "lock",
        variant = "primary",
        enabled = snapshot.busy ~= true,
        onClick = "onConnect",
      }))
      table.insert(rows, ui.button({
        text = "Trocar senha salva",
        variant = "ghost",
        onClick = "onResetPassword",
      }))
    end
  end

  panel.render(ui.column({ gap = 10, padding = 12 }, rows))
end

noctalia.state.watch("vpn_snapshot", function(value)
  if type(value) == "table" then
    snapshot = value
    render()
  end
end)

function onOpen(_context)
  render()
end

function onPasswordChange(value)
  passwordDraft = value
end

function onSavePassword()
  if passwordDraft == "" or savingPassword then return end
  savingPassword = true
  feedback = ""
  render()
  noctalia.runAsync({ SCRIPT, "set-password", passwordDraft }, function(result)
    savingPassword = false
    passwordDraft = ""
    if result and result.exitCode == 0 then
      feedback = "Senha salva no keyring."
      feedbackError = false
    else
      feedback = noctalia.string.trim(result and result.stderr or "Falha ao salvar a senha")
      feedbackError = true
    end
    noctalia.runAsync(SCRIPT .. " status", function(statusResult)
      if statusResult and statusResult.exitCode == 0 then
        local decoded = noctalia.json.decode(noctalia.string.trim(statusResult.stdout or ""))
        if type(decoded) == "table" then
          snapshot.hasPassword = decoded.hasPassword == true
        end
      end
      render()
    end)
  end)
end

function onResetPassword()
  snapshot.hasPassword = false
  feedback = ""
  render()
end

function onConnect()
  feedback = ""
  noctalia.state.set("vpn_command", "connect")
end

function onDisconnect()
  feedback = ""
  noctalia.state.set("vpn_command", "disconnect")
end
