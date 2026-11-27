--[[
	ItemLens · UI/MainFrame.lua
	Main window: title bar, tabs and search, the list on the left (with the Collections filter bar)
	and the detail panel on the right. The bank panel docks to its right edge.
	Ventana principal: barra de título, pestañas y buscador, la lista a la izquierda (con la barra
	de filtros de Colecciones) y el detalle a la derecha. El panel de banco se pega a su borde derecho.
	© 2026 iAthVo_Kr · MIT License
]]

local _, IL = ...
local L, S = IL.L, IL.Style
local C = S.C

local WIDTH, HEIGHT, LIST_W = 980, 620, 340
-- The list width can be dragged (D-61): limits keep the filters and the detail readable.
-- El ancho de la lista se puede arrastrar (D-61): los límites dejan legibles filtros y detalle.
local LIST_MIN, LIST_MAX, DETAIL_MIN = 224, 620, 420 -- 224 = 30 % narrower than 320 / 30 % más angosta
local ROW_H, HEADER_H = 52, 28
local TABS = { { "bag", L.TAB_BAG }, { "dict", L.TAB_DICT }, { "coll", L.TAB_COLL }, { "ach", L.TAB_ACH }, { "fav", L.TAB_FAV } }
-- Achievements tab filters (D-56). / Filtros de la pestaña Logros (D-56).
local ACH_FILTERS = { "all", "missing", "have" } -- D-72: only three; the search box does the rest
local ACH_AVAIL = { "all", "yes", "timed", "no" } -- D-82: the availability button cycles these
-- Search in everything ItemLens knows: from 3 letters, up to 200 results.
-- Búsqueda en todo lo que conoce ItemLens: desde 3 letras, hasta 200 resultados.
local GLOBAL_MIN, GLOBAL_LIMIT = 3, 200
local ARROW = "|TInterface\\Buttons\\Arrow-Down-Up:12:12|t" -- the native font has no ▾ / la fuente no tiene ▾
local STATE_ATLAS = { have = "common-icon-checkmark", missing = "common-icon-redx" }

-- Dropdown menu with radio options; falls back to cycling when MenuUtil is missing.
-- Menú desplegable con opciones; si no hay MenuUtil, pasa a la siguiente opción.
local function openMenu(owner, items, isSelected, onPick)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			for _, it in ipairs(items) do
				local el = root:CreateRadio(it.text, function() return isSelected(it.value) end, function() onPick(it.value) end)
				if it.disabled and el and el.SetEnabled then pcall(el.SetEnabled, el, false) end
			end
		end)
		return
	end
	local idx = 1
	for i, it in ipairs(items) do if isSelected(it.value) then idx = i end end
	for step = 1, #items do
		local nextItem = items[((idx + step - 1) % #items) + 1]
		if not nextItem.disabled then onPick(nextItem.value) return end
	end
end

---------------------------------------------------------------------------
-- Foldable groups / Grupos plegables
---------------------------------------------------------------------------
-- Bags start open; the Catalog (thousands of entries) and Collections start folded.
-- La Mochila empieza abierta; el Catálogo (miles de entradas) y Colecciones, plegados.
local FOLDED_BY_DEFAULT = { bag = false, dict = true, coll = true, ach = true }

-- First letter for the Catalog: accents fold into their letter, Ñ is its own letter after
-- N, anything else goes under "#".
-- Primera letra para el Catálogo: los acentos van con su letra, la Ñ es letra propia después
-- de la N y lo demás va en "#".
local ACCENTS = {
	["á"] = "A", ["à"] = "A", ["â"] = "A", ["ä"] = "A", ["Á"] = "A", ["À"] = "A", ["Â"] = "A", ["Ä"] = "A",
	["é"] = "E", ["è"] = "E", ["ê"] = "E", ["ë"] = "E", ["É"] = "E", ["È"] = "E", ["Ê"] = "E", ["Ë"] = "E",
	["í"] = "I", ["ì"] = "I", ["î"] = "I", ["ï"] = "I", ["Í"] = "I", ["Ì"] = "I", ["Î"] = "I", ["Ï"] = "I",
	["ó"] = "O", ["ò"] = "O", ["ô"] = "O", ["ö"] = "O", ["Ó"] = "O", ["Ò"] = "O", ["Ô"] = "O", ["Ö"] = "O",
	["ú"] = "U", ["ù"] = "U", ["û"] = "U", ["ü"] = "U", ["Ú"] = "U", ["Ù"] = "U", ["Û"] = "U", ["Ü"] = "U",
	["ç"] = "C", ["Ç"] = "C", ["ñ"] = "Ñ", ["Ñ"] = "Ñ",
}

local function firstLetter(name)
	local c = (name or ""):match("^[%z\1-\127\194-\244][\128-\191]*")
	if not c then return "#" end
	if ACCENTS[c] then return ACCENTS[c] end
	if c:match("^%a$") then return c:upper() end
	return "#"
end

local function letterRank(letter)
	if letter == "#" then return 1000 end
	if letter == "Ñ" then return ("N"):byte() + 0.5 end
	return letter:byte()
end

-- Keys already sorted by name → { { id = letter, text = letter, keys }, … }
-- Claves ya ordenadas por nombre → grupos por letra.
local function groupByLetter(keys, names)
	local byLetter, groups = {}, {}
	for _, key in ipairs(keys) do
		local letter = firstLetter(names[key])
		local g = byLetter[letter]
		if not g then
			g = { id = letter, text = letter, keys = {} }
			byLetter[letter] = g
			groups[#groups + 1] = g
		end
		g.keys[#g.keys + 1] = key
	end
	table.sort(groups, function(a, b) return letterRank(a.id) < letterRank(b.id) end)
	return groups
end

-- Groups → list elements: a header per non-empty group, its keys only when unfolded.
-- While searching nothing is folded. Returns the elements and the number of keys.
-- Grupos → elementos de la lista: un encabezado por grupo con algo, sus claves solo si está
-- desplegado. Al buscar no se pliega nada. Devuelve los elementos y la cantidad de claves.
-- A group may be a parent (isParent) whose sub-groups (parent = its id) follow it: folding the
-- parent hides them all; its count is theirs. Sub-groups are indented and may have their own
-- default (defaultFolded).
-- Un grupo puede ser padre (isParent) y sus subgrupos (parent = su id) van después: plegar el
-- padre los esconde todos; su cantidad es la de ellos. Los subgrupos van con sangría y pueden
-- tener su propio valor por defecto (defaultFolded).
-- Any depth (D-78): a parent counts every group below it, and folding it hides them all.
-- Cualquier profundidad (D-78): un padre cuenta todos los grupos debajo y plegarlo los esconde.
local function foldGroups(groups, isFolded, searching)
	-- Sub-groups come after their parent: sum from the end. / Los subgrupos van después: suma desde el final.
	local sumN, sumHave, anyHave = {}, {}, {}
	for i = #groups, 1, -1 do
		local g = groups[i]
		local n = (sumN[g.id] or 0) + #g.keys
		local h = (sumHave[g.id] or 0) + (g.have or 0)
		sumN[g.id], sumHave[g.id] = n, h
		if g.have then anyHave[g.id] = true end
		if g.parent then
			sumN[g.parent] = (sumN[g.parent] or 0) + n
			sumHave[g.parent] = (sumHave[g.parent] or 0) + h
			if anyHave[g.id] then anyHave[g.parent] = true end
		end
	end
	local out, count, hidden, depthOf = {}, 0, {}, {}
	for _, g in ipairs(groups) do
		local depth = g.parent and ((depthOf[g.parent] or 0) + 1) or (g.indent and 1 or 0)
		depthOf[g.id] = depth
		count = count + #g.keys
		local blocked = g.parent and hidden[g.parent]
		local n = sumN[g.id]
		if blocked or n == 0 then
			hidden[g.id] = true
		else
			local folded = not searching and isFolded(g.id, g.defaultFolded)
			hidden[g.id] = folded
			local e = { header = true, groupId = g.id, text = g.text, icon = g.icon, folded = folded, count = n,
				depth = depth, indent = depth > 0 or nil }
			if g.isParent then
				if anyHave[g.id] then e.have, e.total = sumHave[g.id], n end
			else
				e.have, e.total = g.have, g.total
			end
			out[#out + 1] = e
			if not folded then
				for _, key in ipairs(g.keys) do out[#out + 1] = key end
			end
		end
	end
	return out, count
end

-- Collections list (headers + keys) → groups. / Lista de Colecciones (encabezados + claves) → grupos.
local function collectionGroups(elements, set)
	local groups, current = {}, nil
	for _, e in ipairs(elements) do
		if type(e) == "table" then
			current = { id = set .. ":" .. tostring(e.id), text = e.text, have = e.have, total = e.total, keys = {} }
			groups[#groups + 1] = current
		elseif current then
			current.keys[#current.keys + 1] = e
		end
	end
	return groups
end

IL.ListGroups = { FirstLetter = firstLetter, GroupByLetter = groupByLetter, Fold = foldGroups } -- for tests / para pruebas

local function coloredClassName(id)
	local name, file = GetClassInfo(id)
	local cc = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
	if name and cc and cc.WrapTextInColorCode then return cc:WrapTextInColorCode(name) end
	return name or L.CLASS_N:format(id)
end

---------------------------------------------------------------------------
-- List rows / Filas de la lista
---------------------------------------------------------------------------
local function buildListRow(row)
	row.sel = S.Fill(row, C.selected)
	row.hl = row:CreateTexture(nil, "HIGHLIGHT")
	row.hl:SetAllPoints()
	row.hl:SetColorTexture(1, 1, 1, 0.035)
	row.icon = S.Icon(row, 34)
	row.icon:SetPoint("LEFT", 10, 0)
	row.chip = S.Chip(row)
	row.chip:SetPoint("RIGHT", -10, 0)
	row.star = S.Star(row, 13)
	row.star:SetPoint("RIGHT", row.chip, "LEFT", -6, 0)
	row.name = S.Text(row, "ItemLensFontList")
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
	row.name:SetPoint("RIGHT", row.star, "LEFT", -6, 0)
	row.sub = S.Text(row, "ItemLensFontListSmall", C.muted)
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 2)
	row.sub:SetPoint("RIGHT", row.star, "LEFT", -6, 0)
	row.fac = S.FactionGlow(row, row.icon) -- one-faction glow (D-59) / resplandor de facción
	row.state = row:CreateTexture(nil, "OVERLAY")
	row.state:SetSize(14, 14)
	row.state:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 3, -3)
	-- Foldable group header: +/− glyph, optional icon, name and count.
	-- Encabezado de grupo plegable: signo +/−, ícono opcional, nombre y cantidad.
	row.glyph = S.Text(row, "ItemLensFontListMuted")
	row.glyph:SetPoint("LEFT", 6, 0)
	row.glyph:SetWidth(10)
	row.groupIcon = row:CreateTexture(nil, "ARTWORK")
	row.groupIcon:SetSize(16, 16)
	row.groupIcon:SetPoint("LEFT", row.glyph, "RIGHT", 4, 0)
	row.groupIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.headerText = S.Text(row, "ItemLensFontListSmall", C.muted)
	row.headerCount = S.Text(row, "ItemLensFontListSmall", C.mono, "RIGHT")
	row.headerCount:SetPoint("RIGHT", -8, 0)
	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", function(self)
		if self.groupId then return IL.UI:ToggleGroup(self.groupId) end
		if not self.key then return end
		if self.key:sub(1, 1) == "a" then -- achievement: Shift+click links it / logro: Mayús+clic lo enlaza
			local link = GetAchievementLink and GetAchievementLink(tonumber(self.key:sub(2)))
			if IsModifiedClick("CHATLINK") and link then return IL.InsertLink(link) end
			return IL.UI:Select(self.key)
		end
		if IL:HandleDressUpClick(self.key) then return end
		if IsModifiedClick("CHATLINK") then return IL.InsertLink(IL.Data:GetLink(self.key)) end
		IL.UI:Select(self.key)
	end)
	row.built = true
end

-- Second line of a row: exchanges, purpose, how to get it, or the item type.
-- Segunda línea de una fila: canjes, para qué sirve, cómo se obtiene o el tipo de objeto.
local function listSubText(key)
	local Data = IL.Data
	local stats = Data:GetTokenStats(key)
	if stats then return L.N_EXCH_M_VENDORS:format(stats.offers, stats.vendors) end
	local summary = Data:GetPurpose(key)
	if Data:GetUses(key) or Data:GetCrafts(key) then return summary end
	local sources = Data:GetSources(key)
	if sources then return L.OBTAINED_WITH .. ": " .. Data:GetDisplayName(sources[1][1]) end
	return Data:GetObtainSummary(key) or summary or Data:GetItemType(key) or ""
end

local function setRowMode(row, isHeader)
	for _, r in ipairs({ row.icon, row.chip, row.star, row.name, row.sub, row.state }) do r:SetShown(not isHeader) end
	for _, r in ipairs({ row.glyph, row.headerText, row.headerCount }) do r:SetShown(isHeader) end
	if not isHeader then row.groupIcon:Hide() end
	if isHeader then row.sel:Hide(); row.fac:Set(nil) end
end

-- Achievement row: icon, name, progress or date, points; ✓ done, ✗ no longer available.
-- Fila de logro: ícono, nombre, progreso o fecha, puntos; ✓ hecho, ✗ ya no disponible.
local function initAchRow(row, key)
	local Ach = IL.Ach
	local info = Ach:Info(key)
	row.key, row.groupId = key, nil
	row.icon.tex:SetTexture(info and info.icon)
	row.name:SetText(info and info.name or Ach:GetName(key))
	local selected = IL.UI and IL.UI.selected == key
	S.SetColor(row.name, selected and C.brassHi or C.text)
	row.sel:SetShown(selected)
	local status = Ach:Status(key)
	if info and info.completed then
		row.state:SetAtlas(STATE_ATLAS.have)
		row.state:Show()
	elseif status == "no" then
		row.state:SetAtlas(STATE_ATLAS.missing)
		row.state:Show()
	else
		row.state:Hide()
	end
	local sub
	if info and info.completed then sub = L.ACH_DONE_ON:format(info.date or "")
	elseif status == "no" then sub = L.ACH_STATUS.no
	else
		local done, total = Ach:Progress(key)
		sub = total > 1 and ((BreakUpLargeNumbers and BreakUpLargeNumbers(done) or done) .. " / " .. (BreakUpLargeNumbers and BreakUpLargeNumbers(total) or total))
			or (status and L.ACH_STATUS[status]) or L.ACH_PENDING
	end
	local rank = Ach:FamousRank(key)
	if rank then sub = "|cff" .. S.HEX.brass .. L.ACH_FAMOUS_N:format(rank) .. "|r  " .. sub end
	-- Timed (D-82): until which patch, in amber. / Por tiempo limitado: hasta qué parche, en ámbar.
	if status == "timed" and not (info and info.completed) then
		sub = "|cffc8a765" .. L.ACH_UNTIL_SHORT:format(Ach:PatchText(Ach:RemovedPatch(key))) .. "|r  " .. sub
	end
	row.sub:SetText(sub)
	row.chip.bg:SetColorTexture(C.brass[1], C.brass[2], C.brass[3], 0.12)
	S.SetColor(row.chip.text, C.brass)
	row.chip.text:SetText(info and info.points or "")
	row.chip:SetWidth(row.chip.text:GetStringWidth() + 14)
	row.chip:Show()
	row.star:Hide()
	row.fac:Set(Ach:Faction(key))
end

local function initListRow(row, entry)
	if not row.built then buildListRow(row) end
	-- Group header: { header, groupId, text, icon, folded, count, have, total }
	-- Encabezado de grupo
	if type(entry) == "table" then
		setRowMode(row, true)
		row.key, row.groupId = nil, entry.groupId
		row.glyph:ClearAllPoints()
		row.glyph:SetPoint("LEFT", 6 + 14 * (entry.depth or (entry.indent and 1 or 0)), 0) -- sangría por nivel (D-78)
		row.glyph:SetText(entry.folded and "+" or "-")
		row.groupIcon:SetShown(entry.icon ~= nil)
		if entry.icon then row.groupIcon:SetTexture(entry.icon) end
		row.headerText:ClearAllPoints()
		row.headerText:SetPoint("LEFT", entry.icon and row.groupIcon or row.glyph, "RIGHT", 6, 0)
		row.headerText:SetPoint("RIGHT", row.headerCount, "LEFT", -8, 0)
		row.headerText:SetText(strupper(entry.text or ""))
		row.headerCount:SetText(entry.have and (entry.have .. " / " .. entry.total) or tostring(entry.count))
		return
	end
	setRowMode(row, false)
	if entry:sub(1, 1) == "a" then return initAchRow(row, entry) end
	local Data, key = IL.Data, entry
	row.key, row.groupId = key, nil

	local state = IL.Coll:GetState(key)
	if state and STATE_ATLAS[state] then
		row.state:SetAtlas(STATE_ATLAS[state])
		row.state:Show()
	else
		row.state:Hide()
	end

	row.icon.tex:SetTexture(Data:GetIcon(key))
	row.name:SetText(Data:GetDisplayName(key))
	local selected = IL.UI and IL.UI.selected == key
	if selected then S.SetColor(row.name, C.brassHi) else row.name:SetTextColor(S.QualityColor(Data:GetQuality(key))) end
	row.sel:SetShown(selected)

	-- In Collections the second line says how to get it and where (D-74), not only the zone.
	-- En Colecciones la segunda línea dice cómo se obtiene y dónde (D-74), no solo la zona.
	local sub = listSubText(key)
	if IL.UI and IL.UI.tab == "coll" then
		local how, place = Data:GetObtainSummary(key), Data:GetPlace(key)
		if how and place and not how:find(place, 1, true) then sub = how .. "  ·  " .. place
		else sub = how or place or sub end
	end
	row.sub:SetText(sub)

	local exp = Data:GetExpansion(key)
	if exp then row.chip:SetExpansion(exp, false) else row.chip:Hide() end
	if row.chip:IsShown() then row.star:SetPoint("RIGHT", row.chip, "LEFT", -6, 0) else row.star:SetPoint("RIGHT", -10, 0) end
	row.star:SetShown(IL:IsFavorite(key))
	row.fac:Set(Data:GetFaction(key))
end

---------------------------------------------------------------------------
-- Window parts / Partes de la ventana
---------------------------------------------------------------------------
local function buildTitleBar(f)
	local title = CreateFrame("Frame", nil, f)
	title:SetPoint("TOPLEFT"); title:SetPoint("TOPRIGHT")
	title:SetHeight(44)
	title:EnableMouse(true)
	title:RegisterForDrag("LeftButton")
	title:SetScript("OnDragStart", function() f:StartMoving() end)
	title:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		-- Whole pixels: a window at half a pixel blurs every letter. / Píxeles enteros: a medio
		-- píxel todas las letras se ven borrosas.
		local point, _, relPoint, x, y = f:GetPoint()
		x, y = math.floor(x + 0.5), math.floor(y + 0.5)
		ItemLensDB.window = { point, relPoint, x, y }
		f:ClearAllPoints()
		f:SetPoint(point, UIParent, relPoint, x, y)
	end)
	S.HLine(title, title, 0)

	local logo = title:CreateTexture(nil, "ARTWORK")
	logo:SetSize(16, 16)
	logo:SetPoint("LEFT", 16, 0)
	logo:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	logo:SetVertexColor(C.brass[1], C.brass[2], C.brass[3])

	local text = S.Text(title, "ItemLensFontTitle", C.brass)
	text:SetPoint("LEFT", logo, "RIGHT", 8, 0)
	text:SetText(L.TITLE)

	local close = CreateFrame("Button", nil, title, "UIPanelCloseButtonNoScripts")
	close:SetPoint("RIGHT", -6, 0)
	close:SetScript("OnClick", function() f:Hide() end)

	-- Options (D-60) / Opciones (D-60)
	local gear = CreateFrame("Button", nil, title)
	gear:SetSize(22, 22)
	gear:SetPoint("RIGHT", close, "LEFT", -6, 0)
	gear.tex = gear:CreateTexture(nil, "ARTWORK")
	gear.tex:SetAllPoints()
	gear.tex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	gear.tex:SetVertexColor(C.brass[1], C.brass[2], C.brass[3])
	gear:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	gear:SetScript("OnClick", function() f:ToggleOptions() end)
	gear:SetScript("OnEnter", function(self) S.SimpleTooltip(self, L.OPTIONS_TITLE) end)
	gear:SetScript("OnLeave", GameTooltip_Hide)

	local version = S.Text(title, "ItemLensFontSmallMuted", C.muted, "RIGHT")
	version:SetPoint("RIGHT", gear, "LEFT", -10, 0)
	version:SetText("v" .. IL.VERSION .. "  ·  /il")
	return title
end

-- Tabs, the bank toggle (placed after "Bags") and the search box.
-- Pestañas, el botón del banco (después de "Mochila") y el buscador.
local function buildTabBar(f, title)
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", title, "BOTTOMLEFT")
	bar:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT")
	bar:SetHeight(52)
	S.HLine(bar, bar, 0)

	local group = CreateFrame("Frame", nil, bar)
	group:SetPoint("LEFT", 16, 0)
	group:SetHeight(32)
	S.Fill(group, C.panelDeep)
	f.tabGroup = group

	f.tabButtons = {}
	for _, t in ipairs(TABS) do
		local b = CreateFrame("Button", nil, group)
		b:SetHeight(26)
		b.bg = S.Fill(b, C.tab)
		b.text = S.Text(b, "ItemLensFontNormal")
		b.text:SetPoint("CENTER")
		b.id, b.label = t[1], t[2]
		b:SetScript("OnClick", function() f:SetTab(t[1], true) end)
		f.tabButtons[#f.tabButtons + 1] = b
	end

	-- Not a tab: it opens/closes the side panel and turns brass while open.
	-- No es una pestaña: abre/cierra el panel lateral y se marca en latón mientras está abierto.
	local bankBtn = CreateFrame("Button", nil, group)
	bankBtn:SetHeight(26)
	bankBtn.bg = S.Fill(bankBtn, C.tab)
	bankBtn.hl = bankBtn:CreateTexture(nil, "HIGHLIGHT")
	bankBtn.hl:SetAllPoints()
	bankBtn.hl:SetColorTexture(1, 1, 1, 0.04)
	bankBtn.text = S.Text(bankBtn, "ItemLensFontNormal")
	bankBtn.text:SetPoint("CENTER")
	bankBtn:SetScript("OnClick", function()
		ItemLensDB.options.bankPanel = not ItemLensDB.options.bankPanel
		f.bankPanel:SetShown(ItemLensDB.options.bankPanel)
		f:RefreshBankButton()
	end)
	f.bankBtn = bankBtn

	-- Faction filter (D-59): All / Horde only / Alliance only, for every tab.
	-- Filtro de facción (D-59): Todas / Solo Horda / Solo Alianza, en todas las pestañas.
	local facBtn = S.FlatButton(bar, 120, 26)
	facBtn:SetPoint("LEFT", group, "RIGHT", 12, 0)
	S.Border(facBtn, C.border)
	facBtn:SetScript("OnClick", function(self)
		local items = {
			{ value = "all", text = L.FACTION_ALL },
			{ value = "horde", text = S.FactionCrest(1) .. " " .. L.FACTION_ONLY_HORDE },
			{ value = "alliance", text = S.FactionCrest(2) .. " " .. L.FACTION_ONLY_ALLIANCE },
		}
		openMenu(self, items, function(v) return ItemLensDB.options.faction == v end, function(v)
			ItemLensDB.options.faction = v
			f:RefreshFactionButton()
			f.listBox:ScrollToBegin()
			f:RefreshList()
		end)
	end)
	facBtn:SetScript("OnEnter", function(self) S.SimpleTooltip(self, L.FACTION_TIP) end)
	facBtn:SetScript("OnLeave", GameTooltip_Hide)
	f.facBtn = facBtn

	-- "« Back": brings back the last search after it was cleared (D-74).
	-- "« Volver": regresa la última búsqueda después de borrarla (D-74).
	local backBtn = S.FlatButton(bar, 10, 26)
	backBtn:SetPoint("LEFT", facBtn, "RIGHT", 8, 0)
	S.Border(backBtn, C.border)
	backBtn.text:SetText(L.SEARCH_BACK)
	backBtn:SetWidth(backBtn.text:GetStringWidth() + 18)
	f.backBtn = backBtn

	local search = CreateFrame("EditBox", nil, bar, "SearchBoxTemplate")
	search:SetPoint("LEFT", backBtn, "RIGHT", 10, 0)
	search:SetPoint("RIGHT", -18, 0)
	search:SetHeight(26)
	search:SetAutoFocus(false)
	search.Instructions:SetText(L.SEARCH)
	-- Searches once you stop typing (0.3 s), not on every key: searching everything ItemLens
	-- knows is too heavy to repeat per letter. Clearing the box is immediate.
	-- Busca cuando dejas de escribir (0.3 s), no con cada tecla: buscar en todo lo que conoce
	-- ItemLens es demasiado pesado para repetirlo por letra. Borrar el texto es inmediato.
	local pending
	local function apply()
		pending = nil
		f.query = strlower(strtrim(search:GetText() or ""))
		f:RefreshList()
		if f.bankPanel and f.bankPanel:IsShown() then f.bankPanel:Refresh() end
	end
	local lastText = ""
	local function refreshBack()
		local can = f.lastQuery ~= nil and strtrim(search:GetText() or "") == ""
		backBtn:SetEnabled(can)
		S.SetColor(backBtn.text, can and C.brass or C.muted)
	end
	search:HookScript("OnTextChanged", function(self)
		if pending then pending:Cancel() end
		local text = strtrim(self:GetText() or "")
		-- Remember what was there before it was cleared. / Recuerda lo que había antes de borrarlo.
		if text == "" and lastText ~= "" then f.lastQuery = lastText end
		lastText = text
		refreshBack()
		if text == "" then return apply() end
		pending = C_Timer.NewTimer(0.3, apply)
	end)
	backBtn:SetScript("OnClick", function()
		if not f.lastQuery then return end
		search:SetText(f.lastQuery)
		search:SetCursorPosition(#f.lastQuery)
	end)
	backBtn:SetScript("OnEnter", function(self)
		if f.lastQuery then S.SimpleTooltip(self, L.SEARCH_BACK_TIP:format(f.lastQuery)) end
	end)
	backBtn:SetScript("OnLeave", GameTooltip_Hide)
	refreshBack()
	f.search = search
	return bar
end

-- Collections filter bar, three rows: set · expansion + class · state (+ "With reward").
-- Barra de filtros de Colecciones, tres filas: conjunto · expansión + clase · estado (+ "Con recompensa").
local function buildCollectionBar(f, listPane)
	local cb = CreateFrame("Frame", nil, listPane)
	cb:SetPoint("TOPLEFT", 8, -8)
	cb:SetPoint("TOPRIGHT", -9, -8)
	cb:SetHeight(90)
	cb:Hide()
	local opts = function() return ItemLensDB.options.coll end
	local function apply() f.listBox:ScrollToBegin(); f:RefreshList() end

	local setBtn = S.FlatButton(cb, 10, 24)
	setBtn:SetPoint("TOPLEFT"); setBtn:SetPoint("TOPRIGHT")
	S.Border(setBtn, C.border)
	setBtn:SetScript("OnClick", function(self)
		local items = {}
		for _, id in ipairs(IL.Coll.SETS) do items[#items + 1] = { value = id, text = L.COLL_SETS[id] } end
		openMenu(self, items, function(v) return opts().set == v end, function(v)
			opts().set, opts().exp = v, "all"
			-- Quests and artifacts start on your own class. / Misiones y artefactos empiezan en tu clase.
			opts().class = (v == "quests" or v == "art") and (select(3, UnitClass("player")) or "all") or "all"
			apply()
		end)
	end)
	cb.setBtn = setBtn

	local expBtn = S.FlatButton(cb, 112, 24)
	expBtn:SetPoint("TOPLEFT", setBtn, "BOTTOMLEFT", 0, -8)
	S.Border(expBtn, C.border)
	expBtn:SetScript("OnClick", function(self)
		local items = { { value = "all", text = L.COLL_ALL } }
		for _, e in ipairs(IL.Coll:GetExpansions(opts().set)) do
			items[#items + 1] = { value = e, text = IL.Data:ExpansionName(e) }
		end
		openMenu(self, items, function(v) return opts().exp == v end, function(v) opts().exp = v; apply() end)
	end)
	cb.expBtn = expBtn

	-- Class filter, only active for class-bound sets. All 13 classes are listed; those without
	-- entries in the set are dimmed and cannot be picked.
	-- Filtro de clase, solo activo en conjuntos que dependen de la clase. Salen las 13 clases;
	-- las que no tienen entradas en el conjunto aparecen atenuadas y no se pueden elegir.
	local classBtn = S.FlatButton(cb, 10, 24)
	classBtn:SetPoint("LEFT", expBtn, "RIGHT", 8, 0)
	classBtn:SetPoint("RIGHT", cb, "RIGHT", 0, 0)
	S.Border(classBtn, C.border)
	classBtn:SetScript("OnClick", function(self)
		if #IL.Coll:GetClasses(opts().set) == 0 then return end
		local items = { { value = "all", text = L.COLL_ALL_CLASSES } }
		for _, c in ipairs(IL.Coll:GetClassCounts(opts().set)) do
			local label = coloredClassName(c.id) .. " (" .. c.count .. ")"
			if c.count == 0 then label = S.Muted((GetClassInfo(c.id) or L.CLASS_N:format(c.id)) .. " (0)") end
			items[#items + 1] = { value = c.id, text = label, disabled = c.count == 0 }
		end
		openMenu(self, items, function(v) return opts().class == v end, function(v) opts().class = v; apply() end)
	end)
	classBtn:SetScript("OnEnter", function(self)
		if #IL.Coll:GetClasses(opts().set) == 0 then S.SimpleTooltip(self, L.COLL_CLASS_NA) end
	end)
	classBtn:SetScript("OnLeave", GameTooltip_Hide)
	cb.classBtn = classBtn

	cb.stateBtns = {}
	local prev
	for _, def in ipairs({ { "all", L.STATE_ALL }, { "missing", L.STATE_MISSING }, { "have", L.STATE_HAVE } }) do
		local b = S.FlatButton(cb, 10, 24)
		b.text:SetText(def[2])
		b:SetWidth(b.text:GetStringWidth() + 14)
		if prev then b:SetPoint("LEFT", prev, "RIGHT", 2, 0) else b:SetPoint("TOPLEFT", expBtn, "BOTTOMLEFT", 0, -8) end
		b.id = def[1]
		b:SetScript("OnClick", function() opts().state = def[1]; apply() end)
		cb.stateBtns[#cb.stateBtns + 1] = b
		prev = b
	end

	-- "With reward" checkbox, class quests only. / Casilla "Con recompensa", solo misiones de clase.
	local reward = CreateFrame("CheckButton", nil, cb, "UICheckButtonTemplate")
	reward:SetSize(22, 22)
	reward:SetPoint("LEFT", prev, "RIGHT", 6, 0)
	reward.label = S.Text(reward, "ItemLensFontSmall", C.textSoft)
	reward.label:SetPoint("LEFT", reward, "RIGHT", 1, 0)
	reward.label:SetText(L.COLL_REWARD_ONLY)
	reward:SetScript("OnClick", function(self) opts().rewardOnly = self:GetChecked() and true or false; apply() end)
	reward:SetScript("OnEnter", function(self) S.SimpleTooltip(self, L.COLL_REWARD_TIP) end)
	reward:SetScript("OnLeave", GameTooltip_Hide)
	cb.reward = reward

	function cb:Refresh()
		local o = opts()
		self.setBtn.text:SetText(L.COLL_SET:format(L.COLL_SETS[o.set] or "?") .. "  " .. ARROW)
		self.expBtn.text:SetText(L.COLL_EXP:format(o.exp == "all" and L.COLL_ALL
			or (IL.Data:ExpansionShort(o.exp) or IL.Data:ExpansionName(o.exp))) .. "  " .. ARROW)

		local hasClasses = #IL.Coll:GetClasses(o.set) > 0
		self.classBtn:SetAlpha(hasClasses and 1 or 0.45)
		if hasClasses then
			local current = o.class == "all" and L.COLL_ALL_CLASSES or coloredClassName(o.class)
			self.classBtn.text:SetText(L.COLL_CLASS:format(current) .. "  " .. ARROW)
		else
			self.classBtn.text:SetText(L.COLL_CLASS:format("—"))
		end

		-- Quests read "All / Missing / Done". / En misiones: "Todas / Faltan / Hechas".
		local isQuests = o.set == "quests"
		for _, b in ipairs(self.stateBtns) do
			if b.id == "all" then b.text:SetText(isQuests and L.COLL_ALL or L.STATE_ALL)
			elseif b.id == "have" then b.text:SetText(isQuests and L.STATE_DONE or L.STATE_HAVE) end
			b:SetWidth(b.text:GetStringWidth() + 14)
			local on = b.id == o.state
			S.SetColor(b.text, on and C.brass or C.muted)
			b.bg:SetColorTexture(unpack(on and C.tab or C.panelDeep))
		end
		self.reward:SetShown(isQuests)
		self.reward:SetChecked(o.rewardOnly and true or false)
	end

	return cb
end

-- Achievements filter bar: two rows of chips. / Barra de filtros de Logros: dos filas de botones.
local function buildAchBar(f, listPane)
	local ab = CreateFrame("Frame", nil, listPane)
	ab:SetPoint("TOPLEFT", 8, -8)
	ab:SetPoint("TOPRIGHT", -9, -8)
	ab:SetHeight(56)
	ab:Hide()
	ab.btns = {}
	for _, id in ipairs(ACH_FILTERS) do
		local b = S.FlatButton(ab, 10, 24)
		b.text:SetText(L.ACH_FILTER[id])
		b:SetWidth(b.text:GetStringWidth() + 14)
		b.id = id
		b:SetScript("OnClick", function()
			ItemLensDB.options.ach.filter = id
			f.listBox:ScrollToBegin()
			f:RefreshList()
		end)
		ab.btns[#ab.btns + 1] = b
	end
	-- Availability (D-82): one button, each click moves to the next state.
	-- Disponibilidad (D-82): un solo botón, cada clic pasa al siguiente estado.
	local availBtn = S.FlatButton(ab, 10, 24)
	availBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	availBtn:SetScript("OnClick", function(_, button)
		local o = ItemLensDB.options.ach
		local n = #ACH_AVAIL
		local i = 1
		for k, v in ipairs(ACH_AVAIL) do if v == o.avail then i = k end end
		i = button == "RightButton" and ((i - 2) % n + 1) or (i % n + 1)
		o.avail = ACH_AVAIL[i]
		ab.laidW = nil
		f.listBox:ScrollToBegin()
		f:RefreshList()
	end)
	availBtn:SetScript("OnEnter", function(self)
		S.OutsideTooltip(self)
		GameTooltip:SetText(L.ACH_AVAIL_TITLE)
		GameTooltip:AddLine(L.ACH_AVAIL_TIP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	availBtn:SetScript("OnLeave", GameTooltip_Hide)
	availBtn.isAvail = true
	ab.btns[#ab.btns + 1] = availBtn
	ab.availBtn = availBtn
	-- The buttons wrap to the list width, which can be dragged (D-61).
	-- Los botones se acomodan al ancho de la lista, que se puede arrastrar (D-61).
	function ab:Layout()
		local maxW = math.max(100, math.floor(self:GetWidth() + 0.5))
		if self.laidW == maxW then return end
		self.laidW = maxW
		local rowStart, prev, x, rows = nil, nil, 0, 0
		for _, b in ipairs(self.btns) do
			b:ClearAllPoints()
			if prev and x + b:GetWidth() + 2 <= maxW then
				b:SetPoint("LEFT", prev, "RIGHT", 2, 0)
				x = x + b:GetWidth() + 2
			else
				if rowStart then b:SetPoint("TOPLEFT", rowStart, "BOTTOMLEFT", 0, -6) else b:SetPoint("TOPLEFT") end
				rowStart, x, rows = b, b:GetWidth(), rows + 1
			end
			prev = b
		end
		self:SetHeight(rows * 24 + (rows - 1) * 6 + 2)
	end
	-- Re-anchoring inside OnSizeChanged left the buttons undrawn until the tab changed: the
	-- layout waits for the next frame (once, however many size changes arrive).
	-- Reanclar dentro de OnSizeChanged dejaba los botones sin dibujar hasta cambiar de pestaña:
	-- el acomodo espera al siguiente cuadro (una vez, lleguen los cambios que lleguen).
	ab:SetScript("OnSizeChanged", function(self)
		if self.layoutPending then return end
		self.layoutPending = true
		C_Timer.After(0, function()
			self.layoutPending = false
			self.laidW = nil
			self:Layout()
		end)
	end)
	ab:SetScript("OnShow", function(self) self:Layout() end)
	function ab:Refresh()
		local o = ItemLensDB.options.ach
		-- Old saved filters (famous, map…) fall back to all (D-72). / Filtros viejos → Todos (D-72).
		if o.filter ~= "all" and o.filter ~= "missing" and o.filter ~= "have" then o.filter = "all" end
		o.exp, o.kind = nil, nil -- D-71, D-70: ya no se usan
		local okAvail = false
		for _, v in ipairs(ACH_AVAIL) do if v == o.avail then okAvail = true end end
		if not okAvail then o.avail = "all" end
		local ab2 = self.availBtn
		ab2.id = o.avail
		ab2.text:SetText(L.ACH_AVAIL[o.avail])
		local w = math.floor(ab2.text:GetStringWidth() + 14)
		if ab2:GetWidth() ~= w then ab2:SetWidth(w); self.laidW = nil; self:Layout() end
		S.SetColor(ab2.text, o.avail ~= "all" and C.brass or C.muted)
		ab2.bg:SetColorTexture(unpack(o.avail ~= "all" and C.tab or C.panelDeep))
		local cur = o.filter
		for _, b in ipairs(self.btns) do
			if b.isAvail then break end
			local on = b.id == cur
			S.SetColor(b.text, on and C.brass or C.muted)
			b.bg:SetColorTexture(unpack(on and C.tab or C.panelDeep))
		end
	end
	return ab
end

local function buildEmptyState(listPane)
	local empty = CreateFrame("Frame", nil, listPane)
	empty:SetPoint("TOPLEFT", 20, -40)
	empty:SetPoint("TOPRIGHT", -20, -40)
	empty:SetHeight(120)
	empty.star = S.Star(empty, 28)
	empty.star:SetPoint("TOP")
	S.SetStar(empty.star, false)
	empty.title = S.Text(empty, "ItemLensFontNormal", nil, "CENTER")
	empty.title:SetPoint("TOP", empty.star, "BOTTOM", 0, -10)
	empty.text = S.Text(empty, "ItemLensFontSmallMuted", C.muted, "CENTER")
	empty.text:SetPoint("TOP", empty.title, "BOTTOM", 0, -6)
	empty.text:SetWidth(240)
	empty.text:SetWordWrap(true)
	return empty
end

local function buildFooter(parent, rightInset)
	local footer = CreateFrame("Frame", nil, parent)
	footer:SetPoint("BOTTOMLEFT"); footer:SetPoint("BOTTOMRIGHT", rightInset or 0, 0)
	footer:SetHeight(30)
	S.TopLine(footer)
	return footer
end

---------------------------------------------------------------------------
-- Window / Ventana
---------------------------------------------------------------------------
function IL.CreateMainFrame()
	local f = CreateFrame("Frame", "ItemLensFrame", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetFrameStrata("HIGH")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:Hide()
	S.Fill(f, C.panel)
	S.Border(f, C.border)
	tinsert(UISpecialFrames, "ItemLensFrame") -- Esc closes it / Esc la cierra
	f.tab, f.query = "bag", ""

	local title = buildTitleBar(f)
	local bar = buildTabBar(f, title)

	-- List / Lista ------------------------------------------------------------
	local listPane = CreateFrame("Frame", nil, f)
	listPane:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
	listPane:SetPoint("BOTTOMLEFT", 0, 0)
	listPane:SetWidth(math.max(LIST_MIN, math.min(LIST_MAX, tonumber(ItemLensDB.options.listWidth) or LIST_W)))
	local sep = listPane:CreateTexture(nil, "ARTWORK")
	sep:SetColorTexture(unpack(C.divider))
	sep:SetPoint("TOPRIGHT"); sep:SetPoint("BOTTOMRIGHT"); sep:SetWidth(1)

	-- Draggable divider between the list and the detail; double-click returns to the default width.
	-- Divisor arrastrable entre la lista y el detalle; doble clic vuelve al ancho de siempre.
	local split = CreateFrame("Frame", nil, f)
	split:SetPoint("TOPLEFT", listPane, "TOPRIGHT", -4, 0)
	split:SetPoint("BOTTOMLEFT", listPane, "BOTTOMRIGHT", -4, 0)
	split:SetWidth(9)
	split:SetFrameLevel(listPane:GetFrameLevel() + 30)
	split:EnableMouse(true)
	split.hl = split:CreateTexture(nil, "OVERLAY")
	split.hl:SetPoint("TOP"); split.hl:SetPoint("BOTTOM"); split.hl:SetWidth(2)
	split.hl:SetColorTexture(C.title[1], C.title[2], C.title[3], 0.7)
	split.hl:Hide()
	split.grip = split:CreateTexture(nil, "OVERLAY")
	split.grip:SetSize(3, 28)
	split.grip:SetPoint("CENTER")
	split.grip:SetColorTexture(C.title[1], C.title[2], C.title[3], 0.9)
	split.grip:Hide()
	local function setListWidth(w)
		local maxW = math.min(LIST_MAX, f:GetWidth() - DETAIL_MIN)
		w = math.floor(math.max(LIST_MIN, math.min(maxW, w)) + 0.5)
		listPane:SetWidth(w)
		return w
	end
	split:SetScript("OnEnter", function(self)
		self.hl:Show(); self.grip:Show()
		S.SimpleTooltip(self, L.SPLIT_TIP)
	end)
	split:SetScript("OnLeave", function(self)
		if not self.dragging then self.hl:Hide(); self.grip:Hide() end
		GameTooltip_Hide()
	end)
	split:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local now = GetTime()
		if self.lastClick and now - self.lastClick < 0.35 then
			self.lastClick = nil
			ItemLensDB.options.listWidth = nil
			setListWidth(LIST_W)
			return
		end
		self.lastClick = now
		self.dragging = true
		GameTooltip_Hide()
		self:SetScript("OnUpdate", function()
			local x = GetCursorPosition() / f:GetEffectiveScale()
			setListWidth(x - f:GetLeft())
		end)
	end)
	split:SetScript("OnMouseUp", function(self)
		if not self.dragging then return end
		self.dragging = false
		self:SetScript("OnUpdate", nil)
		ItemLensDB.options.listWidth = listPane:GetWidth()
		if not self:IsMouseOver() then self.hl:Hide(); self.grip:Hide() end
	end)

	local listFooter = buildFooter(listPane, -1)
	f.listCount = S.Text(listFooter, "ItemLensFontSmallMuted", C.muted)
	f.listCount:SetPoint("LEFT", 16, 0)

	f.collBar = buildCollectionBar(f, listPane)
	f.achBar = buildAchBar(f, listPane)

	local box = CreateFrame("Frame", nil, listPane, "WowScrollBoxList")
	box:SetPoint("TOPLEFT", 8, -8)
	box:SetPoint("BOTTOMRIGHT", listFooter, "TOPRIGHT", -18, 6)
	local sb = CreateFrame("EventFrame", nil, listPane, "MinimalScrollBar")
	sb:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
	sb:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView(0, 0, 0, 0, 2)
	view:SetElementExtentCalculator(function(_, d) return type(d) == "table" and HEADER_H or ROW_H end)
	view:SetElementInitializer("Button", initListRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, sb, view)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, sb)
	f.listBox = box

	f.empty = buildEmptyState(listPane)

	-- Detail / Detalle ----------------------------------------------------------
	local detailPane = CreateFrame("Frame", nil, f)
	detailPane:SetPoint("TOPLEFT", listPane, "TOPRIGHT")
	detailPane:SetPoint("BOTTOMRIGHT")

	-- Empty footer, aligned with the list footer. / Pie vacío, alineado con el pie de la lista.
	local footer = buildFooter(detailPane)

	f.detail = IL.CreateDetail(detailPane)
	f.detail:SetPoint("TOPLEFT")
	f.detail:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT")
	-- Achievements have their own detail panel in the same place. / Los logros tienen su propio panel.
	f.achDetail = IL.CreateAchDetail(detailPane)
	f.achDetail:SetPoint("TOPLEFT")
	f.achDetail:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT")
	f.achDetail:Hide()

	f.bankPanel = IL.CreateBankPanel(f)

	-- Behavior / Comportamiento ---------------------------------------------------
	-- Window size from the options (0.8–1.5). / Tamaño de la ventana según las opciones.
	function f:ApplyScale()
		local s = tonumber(ItemLensDB.options.scale) or 1
		self:SetScale(math.max(0.8, math.min(1.5, s)))
	end

	function f:ToggleOptions(show)
		if not self.options then self.options = IL.CreateOptions(self) end
		if show == nil then show = not self.options:IsShown() end
		self.options:SetShown(show)
		if show then self.options:Refresh() end
	end

	function f:RestorePosition()
		self:ApplyScale()
		self:ClearAllPoints()
		local w = ItemLensDB.window
		if w and w[1] then self:SetPoint(w[1], UIParent, w[2], w[3], w[4]) else self:SetPoint("CENTER") end
	end

	function f:RefreshFactionButton()
		local o = ItemLensDB.options.faction
		local label = (o == "horde" and (S.FactionCrest(1) .. " |cff" .. S.HEX.horde .. L.FACTION_ONLY_HORDE .. "|r"))
			or (o == "alliance" and (S.FactionCrest(2) .. " |cff" .. S.HEX.alliance .. L.FACTION_ONLY_ALLIANCE .. "|r"))
			or (S.FactionCrest(1, 12) .. S.FactionCrest(2, 12) .. " " .. L.FACTION_ALL)
		self.facBtn.text:SetText(label .. "  " .. ARROW)
		self.facBtn:SetWidth(self.facBtn.text:GetStringWidth() + 18)
		S.SetColor(self.facBtn.text, o == "all" and C.muted or C.text)
	end

	function f:RefreshBankButton()
		local open = ItemLensDB.options.bankPanel
		self.bankBtn.text:SetText(open and L.BANK_BTN_OPEN or L.BANK_BTN)
		self.bankBtn.bg:SetShown(open)
		S.SetColor(self.bankBtn.text, open and C.brass or C.muted)
		self:RefreshTabs()
	end

	-- Tab widths change ("Favorites N"), so the row is laid out again each time.
	-- Order: Bags, Bank, Catalog, Collections, Achievements, Favorites.
	-- El ancho de las pestañas cambia ("Favoritos N"), así que se reacomodan cada vez.
	-- Orden: Mochila, Banco, Catálogo, Colecciones, Logros, Favoritos.
	function f:RefreshTabs()
		local nFav = #IL:GetFavorites()
		for _, b in ipairs(self.tabButtons) do
			local on = b.id == self.tab
			b.bg:SetShown(on)
			b.text:SetText(b.id == "fav" and (b.label .. " " .. nFav) or b.label)
			b:SetWidth(b.text:GetStringWidth() + 26)
			S.SetColor(b.text, on and C.text or C.muted)
		end
		self.bankBtn:SetWidth(self.bankBtn.text:GetStringWidth() + 26)
		local tabs = self.tabButtons
		local x = 3
		for _, b in ipairs({ tabs[1], self.bankBtn, tabs[2], tabs[3], tabs[4], tabs[5] }) do
			b:ClearAllPoints()
			b:SetPoint("LEFT", x, 0)
			x = x + b:GetWidth() + 2
		end
		self.tabGroup:SetWidth(x + 1)
	end

	-- The filter bar exists only in Collections; the list starts below it.
	-- La barra de filtros solo existe en Colecciones; la lista empieza debajo de ella.
	-- Achievements: their filter bar and their own detail panel. / Logros: su barra y su propio detalle.
	-- byUser (a tab button): the search is cleared; "« Back" brings it back (D-74).
	-- byUser (botón de pestaña): se borra la búsqueda; "« Volver" la regresa (D-74).
	function f:SetTab(id, byUser)
		if byUser and id ~= self.tab and strtrim(self.search:GetText() or "") ~= "" then
			self.search:SetText("")
			self.search:ClearFocus()
		end
		local wasAch = self.tab == "ach"
		self.tab = id
		local coll, ach = id == "coll", id == "ach"
		self.collBar:SetShown(coll)
		self.achBar:SetShown(ach)
		self.listBox:ClearAllPoints()
		if coll then self.listBox:SetPoint("TOPLEFT", self.collBar, "BOTTOMLEFT", 0, -6)
		elseif ach then self.listBox:SetPoint("TOPLEFT", self.achBar, "BOTTOMLEFT", 0, -6)
		else self.listBox:SetPoint("TOPLEFT", 8, -8) end
		self.listBox:SetPoint("BOTTOMRIGHT", listFooter, "TOPRIGHT", -18, 6)
		self.detail:SetShown(not ach)
		self.achDetail:SetShown(ach)
		self.search.Instructions:SetText(ach and L.ACH_SEARCH or L.SEARCH)
		self.listBox:ScrollToBegin()
		self:RefreshList()
		-- Switching into or out of Achievements keeps a selection that fits the panel.
		-- Al entrar o salir de Logros se elige algo que corresponda al panel.
		if ach ~= wasAch then
			local sel = self.selected
			local isAchKey = sel and sel:sub(1, 1) == "a"
			if ach and not isAchKey then
				local first = IL.ACH.famous[1]
				self:Select(self.lastAch or (first and "a" .. first))
			elseif not ach and isAchKey then
				self.lastAch = sel
				self:Select(self.lastItem)
			end
		end
	end

	function f:GetKeys()
		if self.tab == "bag" then return IL.Scanner:GetBagKeys() end
		if self.tab == "fav" then
			local list = IL:GetFavorites()
			table.sort(list, function(a, b) return IL.Data:GetDisplayName(a) < IL.Data:GetDisplayName(b) end)
			return list
		end
		-- Catalog: sorted once, and again only when the name loader finishes or the list changes.
		-- Catálogo: se ordena una vez, y otra solo al terminar la carga de nombres o si cambia la lista.
		IL.Data:StartNameLoader()
		local keys = IL.Data:GetDictionaryKeys()
		local version = IL.Data.namesVersion or 0
		local c = self.dictSorted
		if c and c.version == version and c.source == keys then return c.list, c.names end
		local named = {}
		for _, key in ipairs(keys) do named[#named + 1] = { key, IL.Data:GetDisplayName(key) } end
		table.sort(named, function(a, b) return a[2] < b[2] end)
		local list, names = {}, {}
		for i, p in ipairs(named) do list[i] = p[1]; names[p[1]] = p[2] end
		self.dictSorted = { version = version, source = keys, list = list, names = names }
		return list, names
	end

	-- Folded state per tab, saved: options.folded[tab][groupId] = true/false (nil = default).
	-- Estado plegado por pestaña, guardado: options.folded[pestaña][grupo] = true/false (nil = por defecto).
	-- A group's own default wins over the tab's (currency sub-groups, D-63).
	-- El valor propio de un grupo gana al de la pestaña (subgrupos de monedas, D-63).
	function f:IsFolded(groupId, default)
		local saved = ItemLensDB.options.folded[self.tab] or {}
		local v = saved[groupId]
		if v == nil then
			if default ~= nil then return default end
			return FOLDED_BY_DEFAULT[self.tab] == true
		end
		return v
	end

	function f:ToggleGroup(groupId)
		local o = ItemLensDB.options.folded
		o[self.tab] = o[self.tab] or {}
		o[self.tab][groupId] = not self:IsFolded(groupId, self.groupDefaults and self.groupDefaults[groupId])
		self:RefreshList()
	end

	local function isFolded(groupId, default)
		f.groupDefaults = f.groupDefaults or {}
		f.groupDefaults[groupId] = default
		return f:IsFolded(groupId, default)
	end

	-- Global search (D-67): on EVERY tab, below the tab's own results, everything else ItemLens
	-- knows that matches, by type: items, currencies, achievements. What the tab already shows
	-- is left out. Clicking a result opens it in the right tab (Select).
	-- Búsqueda global (D-67): en TODAS las pestañas, abajo de lo de la pestaña, todo lo demás que
	-- conoce ItemLens y coincide, por tipo: objetos, monedas, logros. Lo que la pestaña ya muestra
	-- no se repite. Al hacer clic se abre en la pestaña que le toca (Select).
	local GLOBAL_TYPES = {
		{ id = "all:i", text = function() return L.SEARCH_ALL_ITEMS end, find = function(q, ex) return IL.Data:SearchAll(q, ex, GLOBAL_LIMIT) end },
		{ id = "all:c", text = function() return L.SEARCH_ALL_CURRENCIES end, find = function(q, ex) return IL.Data:SearchCurrencies(q, ex, GLOBAL_LIMIT) end },
		{ id = "all:a", text = function() return L.SEARCH_ALL_ACH end, find = function(q, ex) return IL.Ach:Search(q, ex, GLOBAL_LIMIT) end },
	}
	local function appendGlobal(list, q)
		if #q < GLOBAL_MIN or q:match("^%d+$") then return 0 end
		IL.Data:StartFullNameLoader()
		local shown = {}
		for _, e in ipairs(list) do if type(e) == "string" then shown[e] = true end end
		local added = 0
		for _, t in ipairs(GLOBAL_TYPES) do
			local ok, keys, cut = pcall(t.find, q, shown)
			if ok and keys then
				if ItemLensDB.options.faction ~= "all" then
					local kept = {}
					for _, key in ipairs(keys) do if IL:FactionPass(key) then kept[#kept + 1] = key end end
					keys = kept
				end
				if #keys > 0 then
					list[#list + 1] = { header = true, groupId = t.id, text = t.text(),
						count = cut and (GLOBAL_LIMIT .. "+") or #keys }
					for _, key in ipairs(keys) do list[#list + 1] = key end
					added = added + #keys
				end
			end
		end
		return added
	end

	function f:RefreshCollections()
		self.collBar:Refresh()
		local o = ItemLensDB.options.coll
		local elements, have, total = IL.Coll:BuildList({ set = o.set, exp = o.exp, class = o.class,
			state = o.state, query = self.query, rewardOnly = o.rewardOnly })
		local groups = collectionGroups(elements, o.set)
		if ItemLensDB.options.faction ~= "all" then
			for _, g in ipairs(groups) do
				local kept = {}
				for _, key in ipairs(g.keys) do if IL:FactionPass(key) then kept[#kept + 1] = key end end
				g.keys = kept
			end
		end
		local list, count = foldGroups(groups, isFolded, self.query ~= "")
		local extra = appendGlobal(list, self.query)
		self.listBox:SetDataProvider(CreateDataProvider(list), true)
		self.listCount:SetText(L.COLL_FOOTER:format(have, total))
		self.empty:SetShown(count == 0 and extra == 0)
		self.empty.star:Hide()
		self.empty.title:SetText("")
		self.empty.text:SetText(L.NO_RESULTS)
	end

	-- Text or item-ID filter. / Filtro por texto o por ID de objeto.
	local function matcher(q)
		local qID = q:match("^%d+$")
		return function(key)
			if not IL:FactionPass(key) then return false end
			return q == "" or (qID and key:sub(2) == qID) or strlower(IL.Data:GetDisplayName(key)):find(q, 1, true) ~= nil
		end, qID
	end

	local function filterKeys(keys, matches)
		local out = {}
		for _, key in ipairs(keys) do if matches(key) then out[#out + 1] = key end end
		return out
	end

	-- Achievements: every one, by expansion › section › topic, foldable like the bags (D-72, D-78).
	-- Logros: todos, por expansión › sección › tema, plegables como las bolsas (D-72, D-78).
	function f:RefreshAchievements()
		self.achBar:Refresh()
		local filter = ItemLensDB.options.ach.filter
		local groups, shown, have = IL.Ach:BuildGroups(filter, self.query, ItemLensDB.options.ach.avail)
		local list, count = foldGroups(groups, isFolded, self.query ~= "")
		local extra = appendGlobal(list, self.query)
		self.listBox:SetDataProvider(CreateDataProvider(list), true)
		self.listCount:SetText(L.ACH_FOOTER:format(have, shown))
		self.empty:SetShown(count == 0 and extra == 0)
		self.empty.star:Hide()
		self.empty.title:SetText("")
		self.empty.text:SetText(L.NO_RESULTS)
	end

	function f:RefreshList()
		self:RefreshTabs()
		if self.tab == "coll" then return self:RefreshCollections() end
		if self.tab == "ach" then return self:RefreshAchievements() end

		local q = self.query
		local matches, qID = matcher(q)
		local list, count, totalKeys

		if self.tab == "bag" then
			-- One foldable group per bag, then currencies. / Un grupo plegable por bolsa y luego monedas.
			local groups = IL.Scanner:GetBagGroups()
			totalKeys = 0
			for _, g in ipairs(groups) do
				totalKeys = totalKeys + #g.keys
				g.keys = filterKeys(g.keys, matches)
			end
			list, count = foldGroups(groups, isFolded, q ~= "")
		elseif self.tab == "dict" then
			-- A foldable group per letter. / Un grupo plegable por letra.
			local all, names = self:GetKeys()
			totalKeys = #all
			local keys = filterKeys(all, matches)
			list, count = foldGroups(groupByLetter(keys, names), isFolded, q ~= "")
			-- Any item ID can be opened, even outside the list. / Cualquier ID se abre, aunque no esté.
			if qID and count == 0 then list, count = { "i" .. qID }, 1 end
		else
			local all = self:GetKeys()
			totalKeys = #all
			list = filterKeys(all, matches)
			count = #list
		end
		-- A name that is not in this tab is looked up in everything ItemLens knows and listed
		-- below, under "In all of ItemLens".
		-- Un nombre que no está en esta pestaña se busca en todo lo que conoce ItemLens y se
		-- muestra abajo, en "En todo ItemLens".
		local extra = appendGlobal(list, q)
		self.listBox:SetDataProvider(CreateDataProvider(list), true)

		local fullRunning, fullDone, fullTotal = IL.Data:GetFullLoadProgress()
		if fullRunning and q ~= "" then
			self.listCount:SetText(L.SEARCH_LOADING:format(fullDone, fullTotal))
		elseif self.tab == "dict" then
			local running, done, totalLoad = IL.Data:GetLoaderProgress()
			self.listCount:SetText(running and L.DICT_LOADING:format(done, totalLoad)
				or L.DICT_FOOTER:format(count, totalKeys))
		else
			self.listCount:SetText(L.N_ITEMS:format(count))
		end

		local emptyFavs = self.tab == "fav" and totalKeys == 0
		self.empty:SetShown(count == 0 and extra == 0)
		self.empty.star:SetShown(emptyFavs)
		self.empty.title:SetText(emptyFavs and L.EMPTY_FAVS_TITLE or "")
		self.empty.text:SetText(emptyFavs and L.EMPTY_FAVS_TEXT or L.NO_RESULTS)
	end

	-- An achievement key ("a123") goes to the achievements panel; anything else to the item panel.
	-- Opening an item from elsewhere (Shift+click) while in Achievements switches to the Catalog.
	-- Una clave de logro ("a123") va al panel de logros; lo demás, al de objetos.
	-- Abrir un objeto desde fuera (Mayús+clic) estando en Logros cambia al Catálogo.
	function f:Select(key)
		local isAch = key and key:sub(1, 1) == "a"
		if key and not isAch and self.tab == "ach" then
			self.lastItem = key
			return self:SetTab("dict")
		end
		-- An achievement found from another tab opens Achievements (D-67).
		-- Un logro encontrado desde otra pestaña abre Logros (D-67).
		if isAch and self.tab ~= "ach" then
			self.lastAch = key
			self.selected = nil
			return self:SetTab("ach")
		end
		self.selected = key
		if isAch then self.achDetail:SetKey(key) else
			self.lastItem = key or self.lastItem
			self.detail:SetKey(key)
		end
		self.listBox:ForEachFrame(function(row)
			initListRow(row, row.GetElementData and row:GetElementData() or row.key)
		end)
		if self.bankPanel:IsShown() then self.bankPanel:Refresh() end
	end

	function f:Refresh()
		self:RefreshList()
		if self.tab == "ach" then self.achDetail:Refresh(true) else self.detail:Refresh(true) end
		if self.bankPanel:IsShown() then self.bankPanel:Refresh() end
	end

	f:SetScript("OnShow", function(self)
		self:Refresh()
		if not self.selected then
			local first
			if self.tab == "ach" then first = IL.ACH.famous[1] and ("a" .. IL.ACH.famous[1])
			elseif self.tab ~= "coll" then first = self:GetKeys()[1] end
			if first then self:Select(first) else self.detail:SetKey(nil) end
		end
	end)

	f:RefreshBankButton()
	f:RefreshFactionButton()
	f:RestorePosition()
	return f
end
