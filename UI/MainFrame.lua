--[[
	ItemLens · UI/MainFrame.lua
	Main window: title bar, tabs and search, the list on the left (with the Collections filter bar)
	and the detail panel on the right. The bank panel docks to its right edge.
	Ventana principal: barra de título, pestañas y buscador, la lista a la izquierda (con la barra
	de filtros de Colecciones) y el detalle a la derecha. El panel de banco se pega a su borde derecho.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...
local L, S = IL.L, IL.Style
local C = S.C

local WIDTH, HEIGHT, LIST_W = 840, 540, 300
local ROW_H, HEADER_H = 52, 28
local TABS = { { "bag", L.TAB_BAG }, { "dict", L.TAB_DICT }, { "coll", L.TAB_COLL }, { "fav", L.TAB_FAV } }
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
local FOLDED_BY_DEFAULT = { bag = false, dict = true, coll = true }

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
local function foldGroups(groups, isFolded, searching)
	local out, count = {}, 0
	for _, g in ipairs(groups) do
		if #g.keys > 0 then
			local folded = not searching and isFolded(g.id)
			out[#out + 1] = { header = true, groupId = g.id, text = g.text, icon = g.icon, folded = folded,
				count = #g.keys, have = g.have, total = g.total }
			if not folded then
				for _, key in ipairs(g.keys) do out[#out + 1] = key end
			end
			count = count + #g.keys
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
	row.name = S.Text(row, "GameFontHighlight")
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 10, -2)
	row.name:SetPoint("RIGHT", row.star, "LEFT", -6, 0)
	row.sub = S.Text(row, "GameFontDisableSmall", C.muted)
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 10, 2)
	row.sub:SetPoint("RIGHT", row.star, "LEFT", -6, 0)
	row.state = row:CreateTexture(nil, "OVERLAY")
	row.state:SetSize(14, 14)
	row.state:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 3, -3)
	-- Foldable group header: +/− glyph, optional icon, name and count.
	-- Encabezado de grupo plegable: signo +/−, ícono opcional, nombre y cantidad.
	row.glyph = S.Text(row, "GameFontDisable")
	row.glyph:SetPoint("LEFT", 6, 0)
	row.glyph:SetWidth(10)
	row.groupIcon = row:CreateTexture(nil, "ARTWORK")
	row.groupIcon:SetSize(16, 16)
	row.groupIcon:SetPoint("LEFT", row.glyph, "RIGHT", 4, 0)
	row.groupIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.headerText = S.Text(row, "GameFontNormalSmall", C.muted)
	row.headerCount = S.Text(row, "GameFontDisableSmall", C.mono, "RIGHT")
	row.headerCount:SetPoint("RIGHT", -8, 0)
	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", function(self)
		if self.groupId then return IL.UI:ToggleGroup(self.groupId) end
		if not self.key then return end
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
	if isHeader then row.sel:Hide() end
end

local function initListRow(row, entry)
	if not row.built then buildListRow(row) end
	-- Group header: { header, groupId, text, icon, folded, count, have, total }
	-- Encabezado de grupo
	if type(entry) == "table" then
		setRowMode(row, true)
		row.key, row.groupId = nil, entry.groupId
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

	-- In Collections the second line is the place. / En Colecciones la segunda línea es el lugar.
	local place = IL.UI and IL.UI.tab == "coll" and Data:GetPlace(key)
	row.sub:SetText(place or listSubText(key))

	local exp = Data:GetExpansion(key)
	if exp then row.chip:SetExpansion(exp, false) else row.chip:Hide() end
	if row.chip:IsShown() then row.star:SetPoint("RIGHT", row.chip, "LEFT", -6, 0) else row.star:SetPoint("RIGHT", -10, 0) end
	row.star:SetShown(IL:IsFavorite(key))
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
		local point, _, relPoint, x, y = f:GetPoint()
		ItemLensDB.window = { point, relPoint, x, y }
	end)
	S.HLine(title, title, 0)

	local logo = title:CreateTexture(nil, "ARTWORK")
	logo:SetSize(16, 16)
	logo:SetPoint("LEFT", 16, 0)
	logo:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	logo:SetVertexColor(C.brass[1], C.brass[2], C.brass[3])

	local text = S.Text(title, "GameFontNormalLarge", C.brass)
	text:SetPoint("LEFT", logo, "RIGHT", 8, 0)
	text:SetText(L.TITLE)

	local close = CreateFrame("Button", nil, title, "UIPanelCloseButtonNoScripts")
	close:SetPoint("RIGHT", -6, 0)
	close:SetScript("OnClick", function() f:Hide() end)

	local version = S.Text(title, "GameFontDisableSmall", C.muted, "RIGHT")
	version:SetPoint("RIGHT", close, "LEFT", -8, 0)
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
		b.text = S.Text(b, "GameFontHighlight")
		b.text:SetPoint("CENTER")
		b.id, b.label = t[1], t[2]
		b:SetScript("OnClick", function() f:SetTab(t[1]) end)
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
	bankBtn.text = S.Text(bankBtn, "GameFontHighlight")
	bankBtn.text:SetPoint("CENTER")
	bankBtn:SetScript("OnClick", function()
		ItemLensDB.options.bankPanel = not ItemLensDB.options.bankPanel
		f.bankPanel:SetShown(ItemLensDB.options.bankPanel)
		f:RefreshBankButton()
	end)
	f.bankBtn = bankBtn

	local search = CreateFrame("EditBox", nil, bar, "SearchBoxTemplate")
	search:SetPoint("LEFT", group, "RIGHT", 16, 0)
	search:SetPoint("RIGHT", -18, 0)
	search:SetHeight(26)
	search:SetAutoFocus(false)
	search.Instructions:SetText(L.SEARCH)
	search:HookScript("OnTextChanged", function(self)
		f.query = strlower(strtrim(self:GetText() or ""))
		f:RefreshList()
		if f.bankPanel and f.bankPanel:IsShown() then f.bankPanel:Refresh() end
	end)
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
	reward.label = S.Text(reward, "GameFontHighlightSmall", C.textSoft)
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

local function buildEmptyState(listPane)
	local empty = CreateFrame("Frame", nil, listPane)
	empty:SetPoint("TOPLEFT", 20, -40)
	empty:SetPoint("TOPRIGHT", -20, -40)
	empty:SetHeight(120)
	empty.star = S.Star(empty, 28)
	empty.star:SetPoint("TOP")
	S.SetStar(empty.star, false)
	empty.title = S.Text(empty, "GameFontHighlight", nil, "CENTER")
	empty.title:SetPoint("TOP", empty.star, "BOTTOM", 0, -10)
	empty.text = S.Text(empty, "GameFontDisableSmall", C.muted, "CENTER")
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
	listPane:SetWidth(LIST_W)
	local sep = listPane:CreateTexture(nil, "ARTWORK")
	sep:SetColorTexture(unpack(C.divider))
	sep:SetPoint("TOPRIGHT"); sep:SetPoint("BOTTOMRIGHT"); sep:SetWidth(1)

	local listFooter = buildFooter(listPane, -1)
	f.listCount = S.Text(listFooter, "GameFontDisableSmall", C.muted)
	f.listCount:SetPoint("LEFT", 16, 0)

	f.collBar = buildCollectionBar(f, listPane)

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

	f.bankPanel = IL.CreateBankPanel(f)

	-- Behavior / Comportamiento ---------------------------------------------------
	function f:RestorePosition()
		self:ClearAllPoints()
		local w = ItemLensDB.window
		if w and w[1] then self:SetPoint(w[1], UIParent, w[2], w[3], w[4]) else self:SetPoint("CENTER") end
	end

	function f:RefreshBankButton()
		local open = ItemLensDB.options.bankPanel
		self.bankBtn.text:SetText(open and L.BANK_BTN_OPEN or L.BANK_BTN)
		self.bankBtn.bg:SetShown(open)
		S.SetColor(self.bankBtn.text, open and C.brass or C.muted)
		self:RefreshTabs()
	end

	-- Tab widths change ("Favorites N"), so the row is laid out again each time.
	-- Order: Bags, Bank, Catalog, Collections, Favorites.
	-- El ancho de las pestañas cambia ("Favoritos N"), así que se reacomodan cada vez.
	-- Orden: Mochila, Banco, Catálogo, Colecciones, Favoritos.
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
		for _, b in ipairs({ tabs[1], self.bankBtn, tabs[2], tabs[3], tabs[4] }) do
			b:ClearAllPoints()
			b:SetPoint("LEFT", x, 0)
			x = x + b:GetWidth() + 2
		end
		self.tabGroup:SetWidth(x + 1)
	end

	-- The filter bar exists only in Collections; the list starts below it.
	-- La barra de filtros solo existe en Colecciones; la lista empieza debajo de ella.
	function f:SetTab(id)
		self.tab = id
		local coll = id == "coll"
		self.collBar:SetShown(coll)
		self.listBox:ClearAllPoints()
		if coll then self.listBox:SetPoint("TOPLEFT", self.collBar, "BOTTOMLEFT", 0, -6)
		else self.listBox:SetPoint("TOPLEFT", 8, -8) end
		self.listBox:SetPoint("BOTTOMRIGHT", listFooter, "TOPRIGHT", -18, 6)
		self.listBox:ScrollToBegin()
		self:RefreshList()
	end

	function f:GetKeys()
		if self.tab == "bag" then return IL.Scanner:GetBagKeys() end
		if self.tab == "fav" then
			local list = IL:GetFavorites()
			table.sort(list, function(a, b) return IL.Data:GetDisplayName(a) < IL.Data:GetDisplayName(b) end)
			return list
		end
		-- Catalog: names are resolved once before sorting (thousands of entries).
		-- Catálogo: los nombres se calculan una vez antes de ordenar (miles de entradas).
		IL.Data:StartNameLoader()
		local named = {}
		for _, key in ipairs(IL.Data:GetDictionaryKeys()) do named[#named + 1] = { key, IL.Data:GetDisplayName(key) } end
		table.sort(named, function(a, b) return a[2] < b[2] end)
		local list = {}
		for i, p in ipairs(named) do list[i] = p[1] end
		return list
	end

	-- Folded state per tab, saved: options.folded[tab][groupId] = true/false (nil = default).
	-- Estado plegado por pestaña, guardado: options.folded[pestaña][grupo] = true/false (nil = por defecto).
	function f:IsFolded(groupId)
		local saved = ItemLensDB.options.folded[self.tab] or {}
		local v = saved[groupId]
		if v == nil then return FOLDED_BY_DEFAULT[self.tab] == true end
		return v
	end

	function f:ToggleGroup(groupId)
		local o = ItemLensDB.options.folded
		o[self.tab] = o[self.tab] or {}
		o[self.tab][groupId] = not self:IsFolded(groupId)
		self:RefreshList()
	end

	local function isFolded(groupId) return f:IsFolded(groupId) end

	function f:RefreshCollections()
		self.collBar:Refresh()
		local o = ItemLensDB.options.coll
		local elements, have, total = IL.Coll:BuildList({ set = o.set, exp = o.exp, class = o.class,
			state = o.state, query = self.query, rewardOnly = o.rewardOnly })
		local list, count = foldGroups(collectionGroups(elements, o.set), isFolded, self.query ~= "")
		self.listBox:SetDataProvider(CreateDataProvider(list), true)
		self.listCount:SetText(L.COLL_FOOTER:format(have, total))
		self.empty:SetShown(count == 0)
		self.empty.star:Hide()
		self.empty.title:SetText("")
		self.empty.text:SetText(L.NO_RESULTS)
	end

	-- Text or item-ID filter. / Filtro por texto o por ID de objeto.
	local function matcher(q)
		local qID = q:match("^%d+$")
		return function(key)
			return q == "" or (qID and key:sub(2) == qID) or strlower(IL.Data:GetDisplayName(key)):find(q, 1, true) ~= nil
		end, qID
	end

	local function filterKeys(keys, matches)
		local out = {}
		for _, key in ipairs(keys) do if matches(key) then out[#out + 1] = key end end
		return out
	end

	function f:RefreshList()
		self:RefreshTabs()
		if self.tab == "coll" then return self:RefreshCollections() end

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
			local all = self:GetKeys()
			totalKeys = #all
			local keys, names = filterKeys(all, matches), {}
			for _, key in ipairs(keys) do names[key] = IL.Data:GetDisplayName(key) end
			list, count = foldGroups(groupByLetter(keys, names), isFolded, q ~= "")
			-- Any item ID can be opened, even outside the list. / Cualquier ID se abre, aunque no esté.
			if qID and count == 0 then list, count = { "i" .. qID }, 1 end
		else
			local all = self:GetKeys()
			totalKeys = #all
			list = filterKeys(all, matches)
			count = #list
		end
		self.listBox:SetDataProvider(CreateDataProvider(list), true)

		if self.tab == "dict" then
			local running, done, totalLoad = IL.Data:GetLoaderProgress()
			self.listCount:SetText(running and L.DICT_LOADING:format(done, totalLoad)
				or L.DICT_FOOTER:format(count, totalKeys))
		else
			self.listCount:SetText(L.N_ITEMS:format(count))
		end

		local emptyFavs = self.tab == "fav" and totalKeys == 0
		self.empty:SetShown(count == 0)
		self.empty.star:SetShown(emptyFavs)
		self.empty.title:SetText(emptyFavs and L.EMPTY_FAVS_TITLE or "")
		self.empty.text:SetText(emptyFavs and L.EMPTY_FAVS_TEXT or L.NO_RESULTS)
	end

	function f:Select(key)
		self.selected = key
		self.detail:SetKey(key)
		self.listBox:ForEachFrame(function(row)
			initListRow(row, row.GetElementData and row:GetElementData() or row.key)
		end)
		if self.bankPanel:IsShown() then self.bankPanel:Refresh() end
	end

	function f:Refresh()
		self:RefreshList()
		self.detail:Refresh(true)
		if self.bankPanel:IsShown() then self.bankPanel:Refresh() end	end

	f:SetScript("OnShow", function(self)
		self:Refresh()
		if not self.selected then
			local first = self.tab ~= "coll" and self:GetKeys()[1] or nil
			if first then self:Select(first) else self.detail:SetKey(nil) end
		end
	end)

	f:RefreshBankButton()
	f:RestorePosition()
	return f
end
