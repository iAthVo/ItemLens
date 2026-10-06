--[[
	ItemLens · Core/Commands.lua
	Slash commands (/il, /itemlens). Every command accepts its Spanish and English name.
	Comandos de chat (/il, /itemlens). Cada comando acepta su nombre en español y en inglés.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...
local L = IL.L

local function toggleOption(name, label)
	ItemLensDB.options[name] = not ItemLensDB.options[name]
	IL:Print(L.TOGGLED, label, ItemLensDB.options[name] and L.ON or L.OFF)
end

-- The first line of each block carries the public version and the internal build.
-- La primera línea de cada bloque lleva la versión pública y la build interna.
local function printLines(lines)
	for i, line in ipairs(lines) do print(i == 1 and line:format(IL.VERSION, IL.BUILD) or line) end
end

local COMMANDS = {
	{ { "" }, function() IL:Toggle() end },
	{ { "tooltip" }, function() toggleOption("tooltip", L.OPT_TOOLTIP) end },
	{ { "personajes", "characters" }, function() toggleOption("ownersTooltip", L.OPT_OWNERS) end },
	{ { "clic", "click" }, function() toggleOption("bagClick", L.OPT_CLICK) end },
	{ { "aprender", "learn" }, function()
		toggleOption("learn", L.OPT_LEARN)
		IL:Print(L.LEARN_STATUS, IL.Learn:Counts())
	end },
	{ { "aprender borrar", "learn clear" }, function()
		IL.Learn:Clear()
		IL:Print(L.LEARN_CLEARED)
	end },
	{ { "reset" }, function()
		ItemLensDB.window = nil
		if IL.UI then IL.UI:RestorePosition() end
		IL:Print(L.RESET_DONE)
	end },
	{ { "creditos", "créditos", "credits" }, function() printLines(L.CREDITS) end },
}

local handlers = {}
for _, cmd in ipairs(COMMANDS) do
	for _, name in ipairs(cmd[1]) do handlers[name] = cmd[2] end
end

SLASH_ITEMLENS1 = "/il"
SLASH_ITEMLENS2 = "/itemlens"
SlashCmdList.ITEMLENS = function(msg)
	msg = strtrim(msg or "")
	-- An item or currency link opens it. / Un enlace de objeto o moneda lo abre.
	local itemID = msg:match("|Hitem:(%d+)")
	local currencyID = msg:match("|Hcurrency:(%d+)")
	if itemID then return IL:OpenTo("i" .. itemID) end
	if currencyID then return IL:OpenTo("c" .. currencyID) end

	local handler = handlers[msg:lower()]
	if handler then handler() else printLines(L.HELP) end
end
