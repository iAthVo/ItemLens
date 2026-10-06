--[[
	ItemLens · UI/BankPanel.lua
	Side panel attached to the right of the main window: Character bank | Warband bank, with the
	items grouped under a header per bank tab (name and icon from the game).
	It shares the main search box. Clicking an item opens its detail.
	Panel lateral pegado a la derecha de la ventana: Banco del personaje | Banda guerrera, con los
	objetos agrupados bajo un encabezado por pestaña del banco (nombre e ícono del juego).
	Usa el mismo buscador de la ventana principal. Clic en un objeto → su detalle.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...
local L, S = IL.L, IL.Style
local C = S.C

local WIDTH = 280
local ROW_H, HEADER_H = 36, 28
local SEGMENTS = { { "bank", "BANK_CHAR" }, { "warband", "BANK_WARBAND" } }

---------------------------------------------------------------------------
-- Rows: a tab header ({ header = true, … }) or an item ({ key, count })
-- Filas: encabezado de pestaña ({ header = true, … }) u objeto ({ key, count })
---------------------------------------------------------------------------
local function buildRow(row)
	row.sel = S.Fill(row, C.selected)
	row.hl = row:CreateTexture(nil, "HIGHLIGHT")
	row.hl:SetAllPoints()
	row.hl:SetColorTexture(1, 1, 1, 0.035)
	row.icon = S.Icon(row, 26)
	row.icon:SetPoint("LEFT", 8, 0)
	row.count = S.Text(row, "NumberFontNormal", C.mono, "RIGHT")
	row.count:SetPoint("RIGHT", -10, 0)
	row.name = S.Text(row, "GameFontHighlight")
	row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.name:SetPoint("RIGHT", row.count, "LEFT", -8, 0)

	-- Tab header / Encabezado de pestaña
	row.tabIcon = row:CreateTexture(nil, "ARTWORK")
	row.tabIcon:SetSize(16, 16)
	row.tabIcon:SetPoint("LEFT", 6, 0)
	row.tabIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	row.headerText = S.Text(row, "GameFontNormalSmall", C.muted)
	row.headerText:SetPoint("LEFT", row.tabIcon, "RIGHT", 6, 0)
	row.headerCount = S.Text(row, "GameFontDisableSmall", C.mono, "RIGHT")
	row.headerCount:SetPoint("RIGHT", -10, 0)
	row.headerText:SetPoint("RIGHT", row.headerCount, "LEFT", -8, 0)

	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", function(self)
		if not self.key then return end
		if IL:HandleDressUpClick(self.key) then return end
		if IsModifiedClick("CHATLINK") then return IL.InsertLink(IL.Data:GetLink(self.key)) end
		IL.UI:Select(self.key)
	end)
	row:SetScript("OnEnter", function(self)
		if not self.key then return end
		local kind, id = IL.SplitKey(self.key)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if kind == "i" then GameTooltip:SetItemByID(id) else GameTooltip:SetCurrencyByID(id) end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row.built = true
end

local function setRowMode(row, isHeader)
	for _, r in ipairs({ row.icon, row.count, row.name }) do r:SetShown(not isHeader) end
	for _, r in ipairs({ row.tabIcon, row.headerText, row.headerCount }) do r:SetShown(isHeader) end
	row.hl:SetShown(not isHeader)
	if isHeader then row.sel:Hide() end
end

local function initRow(row, d)
	if not row.built then buildRow(row) end
	if d.header then
		setRowMode(row, true)
		row.key = nil
		row.tabIcon:SetTexture(d.icon or 133784) -- default: bag icon / por defecto: ícono de bolsa
		row.headerText:SetText(strupper(d.text))
		row.headerCount:SetText(L.N_ITEMS:format(d.count))
		return
	end
	setRowMode(row, false)
	local Data = IL.Data
	row.key = d.key
	row.icon.tex:SetTexture(Data:GetIcon(d.key))
	row.name:SetText(Data:GetDisplayName(d.key))
	local selected = IL.UI and IL.UI.selected == d.key
	if selected then S.SetColor(row.name, C.brassHi) else row.name:SetTextColor(S.QualityColor(Data:GetQuality(d.key))) end
	row.sel:SetShown(selected)
	row.count:SetText("× " .. (BreakUpLargeNumbers and BreakUpLargeNumbers(d.count) or d.count))
end

---------------------------------------------------------------------------
-- List building / Armado de la lista
---------------------------------------------------------------------------
-- Matching items of one group, exchange tokens first and then by name.
-- Objetos de un grupo que coinciden con la búsqueda, primero los tokens y luego por nombre.
local function matchingItems(items, query)
	local Data = IL.Data
	local list, names = {}, {}
	for key, count in pairs(items or {}) do
		local name = Data:GetDisplayName(key)
		if query == "" or strlower(name):find(query, 1, true) then
			list[#list + 1] = { key = key, count = count }
			names[key] = name
		end
	end
	table.sort(list, function(a, b)
		local ta, tb = Data:IsToken(a.key), Data:IsToken(b.key)
		if ta ~= tb then return ta end
		return names[a.key] < names[b.key]
	end)
	return list
end

-- With tabs: a header per tab that has matches. Old copies without tabs: a flat list.
-- Returns the elements and how many items matched.
-- Con pestañas: un encabezado por pestaña con coincidencias. Copias viejas sin pestañas: lista plana.
-- Devuelve los elementos y cuántos objetos coincidieron.
local function buildElements(items, tabs, query)
	local out, total = {}, 0
	if not tabs or #tabs == 0 then
		out = matchingItems(items, query)
		return out, #out
	end
	for _, tab in ipairs(tabs) do
		local list = matchingItems(tab.items, query)
		if #list > 0 then
			local title = (tab.name and tab.name ~= "") and tab.name or L.BANK_TAB_N:format(tab.index)
			out[#out + 1] = { header = true, text = title, icon = tab.icon, count = #list }
			for _, it in ipairs(list) do out[#out + 1] = it end
			total = total + #list
		end
	end
	return out, total
end
IL.BankPanelBuildElements = buildElements -- exposed for tests / expuesto para las pruebas

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
function IL.CreateBankPanel(main)
	local p = CreateFrame("Frame", nil, main)
	p:SetPoint("TOPLEFT", main, "TOPRIGHT", 6, 0)
	p:SetPoint("BOTTOMLEFT", main, "BOTTOMRIGHT", 6, 0)
	p:SetWidth(WIDTH)
	p:EnableMouse(true)
	S.Fill(p, C.panel)
	S.Border(p, C.border)
	p.which = "bank"

	-- Title / Título
	local head = CreateFrame("Frame", nil, p)
	head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT")
	head:SetHeight(44)
	S.HLine(head, head, 0)
	local title = S.Text(head, "GameFontNormal", C.brass)
	title:SetPoint("LEFT", 16, 0)
	title:SetText(L.BANK_TITLE)

	-- Character | Warband selector / Selector Personaje | Banda guerrera
	local seg = CreateFrame("Frame", nil, p)
	seg:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 12, -10)
	seg:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT", -12, -10)
	seg:SetHeight(30)
	S.Fill(seg, C.panelDeep)
	p.segButtons = {}
	for i, def in ipairs(SEGMENTS) do
		local b = CreateFrame("Button", nil, seg)
		b:SetHeight(24)
		b.bg = S.Fill(b, C.tab)
		b.text = S.Text(b, "GameFontHighlightSmall")
		b.text:SetPoint("CENTER")
		b.text:SetText(L[def[2]])
		b.id = def[1]
		if i == 1 then
			b:SetPoint("TOPLEFT", 3, -3)
			b:SetPoint("RIGHT", seg, "CENTER", -1, 0)
		else
			b:SetPoint("TOPRIGHT", -3, -3)
			b:SetPoint("LEFT", seg, "CENTER", 1, 0)
		end
		b:SetScript("OnClick", function() p.which = def[1]; p.box:ScrollToBegin(); p:Refresh() end)
		p.segButtons[#p.segButtons + 1] = b
	end

	-- Footer: where the data comes from and when / Pie: de dónde vienen los datos y cuándo
	local foot = CreateFrame("Frame", nil, p)
	foot:SetPoint("BOTTOMLEFT"); foot:SetPoint("BOTTOMRIGHT")
	foot:SetHeight(30)
	S.TopLine(foot)
	p.status = S.Text(foot, "GameFontDisableSmall", C.muted)
	p.status:SetPoint("BOTTOMLEFT", 14, 9)
	p.status:SetPoint("RIGHT", -10, 0)

	-- List / Lista
	local box = CreateFrame("Frame", nil, p, "WowScrollBoxList")
	box:SetPoint("TOPLEFT", seg, "BOTTOMLEFT", -4, -8)
	box:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", -18, 6)
	local sb = CreateFrame("EventFrame", nil, p, "MinimalScrollBar")
	sb:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
	sb:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView(0, 0, 0, 0, 2)
	view:SetElementExtentCalculator(function(_, d) return d.header and HEADER_H or ROW_H end)
	view:SetElementInitializer("Button", initRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, sb, view)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, sb)
	p.box = box

	local empty = S.Text(p, "GameFontDisableSmall", C.muted, "CENTER")
	empty:SetPoint("TOPLEFT", seg, "BOTTOMLEFT", 10, -40)
	empty:SetPoint("TOPRIGHT", seg, "BOTTOMRIGHT", -10, -40)
	empty:SetWordWrap(true)
	p.empty = empty

	function p:Refresh()
		for _, b in ipairs(self.segButtons) do
			local on = b.id == self.which
			b.bg:SetShown(on)
			S.SetColor(b.text, on and C.text or C.muted)
		end

		local items, source, t, tabs = IL.Bank:Get(self.which)
		local elements, matched = buildElements(items, tabs, main.query or "")
		self.box:SetDataProvider(CreateDataProvider(elements), true)

		if not items then empty:SetText(L.BANK_EMPTY)
		elseif matched == 0 then empty:SetText(L.NO_RESULTS) end
		empty:SetShown(not items or matched == 0)

		if not items then self.status:SetText("")
		elseif source == "syndicator" then self.status:SetText(L.BANK_SRC_SYN:format(matched))
		else self.status:SetText(L.BANK_SRC_OWN:format(matched, date("%d/%m %H:%M", t))) end
	end

	p:SetScript("OnShow", function(self) self:Refresh() end)
	p:SetShown(ItemLensDB.options.bankPanel)
	return p
end
