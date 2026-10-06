--[[
	ItemLens · Modules/Tooltip.lua
	Blocks added to the game tooltip:
	  1. Who has it: on ANY item or currency, which characters own it and how many (/il characters).
	  2. Favorites: what it is for and where to get it, only for favorite items (/il tooltip).
	  A single "Shift+click: open in ItemLens" hint closes the block.
	Bloques que se agregan al tooltip del juego:
	  1. Lo tienen: en CUALQUIER objeto o moneda, qué personajes lo tienen y cuántos (/il personajes).
	  2. Favoritos: para qué sirve y dónde se obtiene, solo en favoritos (/il tooltip).
	  Una sola pista "Mayús+clic: abrir en ItemLens" cierra el bloque.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...
local L, S = IL.L, IL.Style

local Tooltip = {}
IL.Tooltip = Tooltip

local STAR = "|A:PetJournal-FavoritesIcon:12:12|a "

-- 1. Who has it. Returns true if it added anything. / Lo tienen. Devuelve true si agregó algo.
local function addOwners(tooltip, key)
	if not ItemLensDB.options.ownersTooltip then return false end
	local owners = IL.Chars:GetOwners(key)
	if not owners then return false end
	local muted, mono = S.C.muted, S.C.mono

	tooltip:AddLine(" ")
	local total = 0
	for _, o in ipairs(owners) do
		total = total + o.total
		local cc = o.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[o.class]
		local r, g, b = 0.93, 0.91, 0.86
		if cc then r, g, b = cc.r, cc.g, cc.b end
		local parts = {}
		if (o.bags or 0) > 0 then parts[#parts + 1] = L.OWN_BAGS:format(o.bags) end
		if (o.bank or 0) > 0 and not o.warband then parts[#parts + 1] = L.OWN_BANK:format(o.bank) end
		if (o.equipped or 0) > 0 then parts[#parts + 1] = L.OWN_EQUIPPED:format(o.equipped) end
		local detail = #parts > 0 and (S.Muted(table.concat(parts, " · ")) .. "  ") or ""
		tooltip:AddDoubleLine(o.name, detail .. o.total, r, g, b, mono[1], mono[2], mono[3])
	end
	if #owners > 1 then
		tooltip:AddDoubleLine(L.TT_TOTAL, tostring(total), muted[1], muted[2], muted[3], 1, 1, 1)
	end
	return true
end

-- 2. Favorites block. Returns true if it added anything. / Bloque de favoritos.
local function addFavorite(tooltip, key)
	if not ItemLensDB.options.tooltip or not IL:IsFavorite(key) then return false end
	local Data, Int = IL.Data, IL.Int
	local brass, muted, text = S.C.brass, S.C.muted, S.C.text

	tooltip:AddLine(" ")
	tooltip:AddLine(STAR .. L.TT_HEADER, brass[1], brass[2], brass[3])

	local exp = Data:GetExpansion(key)
	local c = S.EXP[exp] or S.EXP_OTHER
	tooltip:AddDoubleLine(L.EXPANSION, Data:ExpansionName(exp), muted[1], muted[2], muted[3], c[1], c[2], c[3])

	local summary = Data:GetPurpose(key)
	if summary then tooltip:AddLine(L.TT_PURPOSE:format(summary), text[1], text[2], text[3], true) end

	local stats = Data:GetTokenStats(key)
	if stats then
		tooltip:AddLine(L.TT_EXCH:format(stats.offers, stats.vendors), text[1], text[2], text[3])
		local offers = Data:GetOffers(key)
		local v = offers and offers[1] -- already sorted: your zone first / ya ordenado: tu zona primero
		if v then
			local where = Int:GetZoneName(v.map, v.npc)
			local coords = Int:FormatCoords(v.x, v.y)
			if coords ~= "" then where = where .. " (" .. coords .. ")" end
			tooltip:AddLine(L.TT_NEAREST:format(Int:GetNPCName(v.npc), where), text[1], text[2], text[3])
		end
	else
		local sources = Data:GetSources(key)
		if sources then
			local s = sources[1]
			tooltip:AddLine(L.TT_OBTAINED:format(Data:GetDisplayName(s[1]), s[3]), text[1], text[2], text[3])
		else
			local obtain = Data:GetObtainSummary(key)
			if obtain then tooltip:AddLine(L.TT_OBTAIN:format(obtain), text[1], text[2], text[3], true) end
		end
	end
	return true
end

local function addAll(tooltip, key)
	if not ItemLensDB then return end
	local any = addOwners(tooltip, key)
	any = addFavorite(tooltip, key) or any
	if any and ItemLensDB.options.bagClick then
		local muted = S.C.muted
		tooltip:AddLine(L.TT_CLICK, muted[1], muted[2], muted[3])
	end
end
Tooltip.AddAll = addAll -- exposed for tests / expuesto para las pruebas

-- Only for the main tooltips, and never with secret IDs.
-- Solo en los tooltips principales y nunca con IDs secretos.
local function hook(dataType, prefix)
	TooltipDataProcessor.AddTooltipPostCall(dataType, function(tooltip, data)
		if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
		if not data or IL.IsSecret(data.id) or type(data.id) ~= "number" then return end
		pcall(addAll, tooltip, prefix .. data.id)
	end)
end

function Tooltip:Init()
	if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall then return end
	hook(Enum.TooltipDataType.Item, "i")
	if Enum.TooltipDataType.Currency then hook(Enum.TooltipDataType.Currency, "c") end
end
