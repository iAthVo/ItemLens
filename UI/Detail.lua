--[[
	ItemLens · UI/Detail.lua
	Detail panel: header (icon, name, expansion, collection state, summary rows) and a scrolling
	body with sections: what it's for, needed for, where to exchange, how to get it, crafts, owners.
	Panel de detalle: encabezado (ícono, nombre, expansión, estado de colección, resumen) y un
	cuerpo desplazable con secciones: para qué sirve, se necesita para, dónde canjearlo, cómo se
	obtiene, se usa para fabricar y quién lo tiene.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...
local L, S = IL.L, IL.Style
local C = S.C

local EXTENT = { section = 30, vendor = 40, item = 26, source = 44, use = 44, origin = 44, text = 20, owner = 22, more = 22, empty = 30 }
local MAX_CRAFTS = 40
local HEADER_FULL, HEADER_SHORT = 152, 130
local ICON_CHECK = "|A:common-icon-checkmark:12:12|a "
local ICON_CROSS = "|A:common-icon-redx:12:12|a "
local DASH = S.Muted("—")

local function learnedMark(learned) return learned and (" " .. S.LEARNED) or "" end

local function showKeyTooltip(owner, key)
	local kind, id = IL.SplitKey(key)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if kind == "i" then
		GameTooltip:SetItemByID(id)
	elseif kind == "f" then -- artifact appearance: show its weapon / apariencia: su arma
		local a = IL.Data:GetArtifact(id)
		if a and a.weapon then GameTooltip:SetItemByID(a.weapon) else GameTooltip:SetText(IL.Data:GetDisplayName(key)) end
	elseif kind == "q" then
		GameTooltip:SetText(IL.Data:GetDisplayName(key), 1, 1, 1)
	else
		GameTooltip:SetCurrencyByID(id)
	end
	GameTooltip:Show()
end

local function classText(classID)
	local name, file = GetClassInfo(classID or 0)
	local cc = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
	return (cc and cc.WrapTextInColorCode and cc:WrapTextInColorCode(name)) or name or DASH
end

---------------------------------------------------------------------------
-- Rows / Filas
---------------------------------------------------------------------------
local function onRowClick(self)
	local d = self.data
	if not d then return end
	if d.type == "vendor" then
		d.panel:ToggleVendor(d.v.npc)
	elseif d.type == "item" then
		local key = "i" .. d.itemID
		if IL:HandleDressUpClick(key) then return end
		if IsModifiedClick("CHATLINK") then IL.InsertLink(IL.Data:GetLink(key)) else IL.UI:Select(key) end
	elseif d.type == "origin" and d.origin.k == "c" then
		IL.UI:Select("i" .. d.origin.id) -- "Comes from <container>" opens it / abre el contenedor
	elseif d.type == "source" then
		if IsModifiedClick("CHATLINK") then IL.InsertLink(IL.Data:GetLink(d.token)) else IL.UI:Select(d.token) end
	end
end

local function onRowEnter(self)
	local d = self.data
	if not d then return end
	if d.type == "item" then
		showKeyTooltip(self, "i" .. d.itemID)
	elseif d.type == "source" then
		showKeyTooltip(self, d.token)
	elseif (d.type == "origin" and d.origin.learned) or (d.type == "vendor" and d.v.learned) then
		S.SimpleTooltip(self, S.LEARNED .. " " .. L.LEARNED_TIP)
	elseif d.type == "text" and self.left:IsTruncated() then
		S.SimpleTooltip(self, d.text)
	end
end

local function buildRow(row)
	row.bg = S.Fill(row, C.card)
	row.hl = row:CreateTexture(nil, "HIGHLIGHT")
	row.hl:SetAllPoints()
	row.hl:SetColorTexture(1, 1, 1, 0.035)

	row.glyph = S.Text(row, "GameFontDisable")
	row.icon = S.Icon(row, 18)
	row.left = S.Text(row, "GameFontHighlight")
	row.sub = S.Text(row, "GameFontDisableSmall", C.muted)
	row.right = S.Text(row, "NumberFontNormal", C.mono, "RIGHT")
	row.count = S.Text(row, "GameFontDisableSmall", C.muted, "RIGHT")

	-- Map pin button / Botón de pin en el mapa
	row.pin = CreateFrame("Button", nil, row)
	row.pin:SetSize(36, 36)
	row.pin.tex = row.pin:CreateTexture(nil, "ARTWORK")
	row.pin.tex:SetSize(18, 18)
	row.pin.tex:SetPoint("CENTER")
	row.pin.tex:SetAtlas("Waypoint-MapPin-ChatIcon")
	row.pin.hl = row.pin:CreateTexture(nil, "HIGHLIGHT")
	row.pin.hl:SetAllPoints()
	row.pin.hl:SetColorTexture(1, 1, 1, 0.06)
	row.pin.sep = row.pin:CreateTexture(nil, "BORDER")
	row.pin.sep:SetColorTexture(unpack(C.divider))
	row.pin.sep:SetPoint("TOPLEFT"); row.pin.sep:SetPoint("BOTTOMLEFT"); row.pin.sep:SetWidth(1)
	row.pin:SetScript("OnClick", function(self) IL.Int:SetWaypoint(self.vendor) end)
	row.pin:SetScript("OnEnter", function(self) S.SimpleTooltip(self, L.PIN) end)
	row.pin:SetScript("OnLeave", GameTooltip_Hide)

	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", onRowClick)
	row:SetScript("OnEnter", onRowEnter)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row.built = true
end

local function resetRow(row)
	for _, r in ipairs({ row.glyph, row.icon, row.left, row.sub, row.right, row.count, row.pin }) do
		r:Hide()
		r:ClearAllPoints()
	end
	row.bg:Hide()
	row.hl:Show()
	row.left:SetFontObject("GameFontHighlight")
	S.SetColor(row.left, C.text)
	row:EnableMouse(true)
end

local function showPin(row, target)
	if not IL.Int:CanWaypoint(target) then return false end
	row.pin:SetPoint("RIGHT", 0, 0)
	row.pin.vendor = target
	row.pin:Show()
	return true
end

-- Two-line card: title on top, place and coordinates below, optional pin on the right.
-- Tarjeta de dos líneas: título arriba, lugar y coordenadas abajo, pin opcional a la derecha.
local function twoLineCard(row, title, subtitle, pinTarget)
	row.bg:Show()
	row.hl:Hide()
	local right = IL.Int:CanWaypoint(pinTarget) and -48 or -12
	row.left:SetPoint("TOPLEFT", 12, -7)
	row.left:SetPoint("RIGHT", right, 0)
	row.left:SetText(title)
	row.left:Show()
	row.sub:SetPoint("BOTTOMLEFT", 12, 7)
	row.sub:SetPoint("RIGHT", right, 0)
	row.sub:SetText(subtitle)
	row.sub:Show()
	showPin(row, pinTarget)
end

local RENDER = {}

-- Section title / Título de sección
function RENDER.section(row, d)
	row.hl:Hide()
	row:EnableMouse(false)
	row.left:SetFontObject("GameFontNormalSmall")
	S.SetColor(row.left, C.muted)
	row.left:SetPoint("BOTTOMLEFT", 2, 6)
	row.left:SetText(d.text)
	row.left:Show()
end

-- Vendor (expandable) / Vendedor (desplegable)
function RENDER.vendor(row, d)
	local Int, v = IL.Int, d.v
	row.bg:Show()
	row.glyph:SetPoint("LEFT", 12, 0)
	row.glyph:SetText(d.open and "-" or "+")
	row.glyph:Show()
	row.left:SetPoint("LEFT", 30, 0)
	row.left:SetText(Int:GetNPCName(v.npc) .. learnedMark(v.learned))
	row.left:Show()
	row.sub:SetPoint("LEFT", row.left, "RIGHT", 10, 0)
	row.sub:SetText(Int:GetZoneName(v.map, v.npc))
	row.sub:Show()
	local rightEdge = showPin(row, v) and -44 or -8
	row.count:SetPoint("RIGHT", rightEdge, 0)
	row.count:SetText(L.N_ITEMS:format(#v.items))
	row.count:Show()
	row.right:SetPoint("RIGHT", row.count, "LEFT", -12, 0)
	row.right:SetText(Int:FormatCoords(v.x, v.y))
	row.right:Show()
	row.sub:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
end

-- Item with quantity / Objeto con cantidad
function RENDER.item(row, d)
	local key = "i" .. d.itemID
	row.icon:SetPoint("LEFT", 32, 0)
	row.icon.tex:SetTexture(IL.Data:GetIcon(key))
	row.icon:Show()
	row.left:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.left:SetPoint("RIGHT", -70, 0)
	row.left:SetText(IL.Data:GetDisplayName(key) .. learnedMark(d.learned))
	row.left:SetTextColor(S.QualityColor(IL.Data:GetQuality(key)))
	row.left:Show()
	row.right:SetPoint("RIGHT", -12, 0)
	S.SetColor(row.right, C.brass)
	row.right:SetText("× " .. d.qty)
	row.right:Show()
end

-- Token that buys this item / Token con el que se compra
function RENDER.source(row, d)
	local Int = IL.Int
	row.bg:Show()
	row.icon:SetPoint("LEFT", 10, 0)
	row.icon.tex:SetTexture(IL.Data:GetIcon(d.token))
	row.icon:Show()
	row.left:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 6)
	row.left:SetText(IL.Data:GetDisplayName(d.token) .. "  |cff" .. S.HEX.brass .. "× " .. d.qty .. "|r" .. learnedMark(d.learned))
	row.left:SetTextColor(S.QualityColor(IL.Data:GetQuality(d.token)))
	row.left:Show()
	local v = IL.Data:GetVendor(d.npc) or { npc = d.npc }
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, -6)
	row.sub:SetText(Int:GetNPCName(d.npc) .. " · " .. Int:GetZoneName(v.map, d.npc) .. "  " .. Int:FormatCoords(v.x, v.y))
	row.sub:Show()
	showPin(row, v)
end

-- "Boss drop  Onyxia" / "Raid: Onyxia's Lair (Normal)  24.7, 56.8"  [pin]
function RENDER.origin(row, d)
	local Int, o = IL.Int, d.origin
	local label, name, where = IL.Data.ObtainLine(o)
	local seen = o.count and o.count > 1 and ("  " .. S.Muted(L.LEARN_SEEN:format(o.count))) or ""
	local title = (o.learned and (S.LEARNED .. " ") or "") .. S.Muted(label) .. "   " .. name .. seen
	local pin = { map = o.map, x = o.x, y = o.y,
		npc = (o.k == "n" or o.k == "v") and o.id or nil,
		title = o.k == "o" and Int:GetObjectName(o.id) or nil }
	twoLineCard(row, title, strtrim((where or "") .. "  " .. Int:FormatCoords(o.x, o.y)), pin)
	if o.k == "c" then row.hl:Show() end -- the container is clickable / el contenedor es clicable
end

-- Something the item is needed for / Algo para lo que se necesita
function RENDER.use(row, d)
	local Int, u = IL.Int, d.use
	local zone = u[3] and Int:GetZoneName(u[3]) or ""
	local pin = { map = u[3], x = u[4], y = u[5], npc = u[1] == "n" and u[2] or nil,
		title = u[1] == "o" and Int:GetObjectName(u[2]) or nil }
	twoLineCard(row, IL.Data.UseLine(u), zone .. "  " .. Int:FormatCoords(u[4], u[5]), pin)
	-- Keep the text clear of the pin column even when there is no pin.
	-- Deja libre la columna del pin aunque no haya pin.
	row.left:SetPoint("RIGHT", -48, 0)
	row.sub:SetPoint("RIGHT", -48, 0)
end

function RENDER.text(row, d)
	row.hl:Hide()
	row.left:SetPoint("LEFT", 2, 0)
	row.left:SetPoint("RIGHT", -2, 0)
	S.SetColor(row.left, C.textSoft)
	row.left:SetText(d.text)
	row.left:Show()
end

-- Character: name (class color) · bags / bank / equipped · total
-- Personaje: nombre (color de clase) · bolsas / banco / equipado · total
function RENDER.owner(row, d)
	local o = d.owner
	row.hl:Hide()
	row.left:SetPoint("LEFT", 2, 0)
	local cc = o.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[o.class]
	if cc then row.left:SetTextColor(cc.r, cc.g, cc.b) end
	row.left:SetText(o.name)
	row.left:Show()
	local parts = {}
	if (o.bags or 0) > 0 then parts[#parts + 1] = L.OWN_BAGS:format(o.bags) end
	if (o.bank or 0) > 0 and not o.warband then parts[#parts + 1] = L.OWN_BANK:format(o.bank) end
	if (o.equipped or 0) > 0 then parts[#parts + 1] = L.OWN_EQUIPPED:format(o.equipped) end
	row.sub:SetPoint("LEFT", row.left, "RIGHT", 10, 0)
	row.sub:SetText(table.concat(parts, " · "))
	row.sub:Show()
	row.right:SetPoint("RIGHT", -12, 0)
	row.right:SetText("× " .. (BreakUpLargeNumbers and BreakUpLargeNumbers(o.total) or o.total))
	row.right:Show()
end

-- "+ N more" and empty-state lines / "+ N más" y líneas de estado vacío
function RENDER.more(row, d)
	row.hl:Hide()
	row:EnableMouse(false)
	row.left:SetFontObject("GameFontDisableSmall")
	S.SetColor(row.left, C.muted)
	row.left:SetPoint("LEFT", d.type == "more" and 32 or 2, 0)
	row.left:SetText(d.text)
	row.left:Show()
end
RENDER.empty = RENDER.more

local function initRow(row, d)
	if not row.built then buildRow(row) end
	resetRow(row)
	row.data = d
	local render = RENDER[d.type]
	if render then render(row, d) end
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
function IL.CreateDetail(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel.open = {} -- expanded vendors per key / vendedores desplegados por clave

	-- Header / Encabezado ------------------------------------------------
	local header = CreateFrame("Frame", nil, panel)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_FULL)
	S.HLine(header, header, 0)
	panel.header = header

	-- Big icon: tooltip on hover, Ctrl+click dressing room, Shift+click chat link.
	-- Ícono grande: tooltip al pasar, Ctrl+clic probador, Mayús+clic enlace al chat.
	local icon = S.Icon(header, 50)
	icon:SetPoint("TOPLEFT", 22, -18)
	icon:EnableMouse(true)
	icon:SetScript("OnEnter", function(self) if panel.key then showKeyTooltip(self, panel.key) end end)
	icon:SetScript("OnLeave", GameTooltip_Hide)
	icon:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or not panel.key then return end
		if IL:HandleDressUpClick(panel.key) then return end
		if IsModifiedClick("CHATLINK") then IL.InsertLink(IL.Data:GetLink(panel.key)) end
	end)
	panel.icon = icon

	local fav = S.FlatButton(header, 104, 28)
	fav:SetPoint("TOPRIGHT", -20, -18)
	S.Border(fav, C.borderFav)
	fav.star = S.Star(fav, 14)
	fav.star:SetPoint("LEFT", 10, 0)
	fav.text:ClearAllPoints()
	fav.text:SetPoint("LEFT", fav.star, "RIGHT", 6, 0)
	S.SetColor(fav.text, C.brass)
	fav:SetScript("OnClick", function() if panel.key then IL:ToggleFavorite(panel.key) end end)
	panel.fav = fav

	-- Dressing room button, only for items that can be previewed.
	-- Botón de probador, solo para objetos que se pueden probar.
	local dress = S.FlatButton(header, 92, 28)
	dress:SetPoint("RIGHT", fav, "LEFT", -8, 0)
	S.Border(dress, C.border)
	dress.text:SetText(L.DRESSUP)
	S.SetColor(dress.text, C.textSoft)
	dress:SetScript("OnClick", function() if panel.key then IL:DressUp(panel.key) end end)
	dress:SetScript("OnEnter", function(self) S.SimpleTooltip(self, L.DRESSUP_TIP, "ANCHOR_LEFT") end)
	dress:SetScript("OnLeave", GameTooltip_Hide)
	dress:Hide()
	panel.dress = dress

	local name = S.Text(header, "GameFontHighlightLarge")
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -1)
	name:SetPoint("RIGHT", fav, "LEFT", -12, 0)
	panel.name = name

	-- Expansion row: label + colored chip, then the collection state.
	-- Renglón de expansión: etiqueta + etiqueta de color, luego el estado de colección.
	local expLabel = S.Text(header, "GameFontDisableSmall", C.muted)
	expLabel:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -9)
	expLabel:SetWidth(84)
	expLabel:SetText(L.EXPANSION)
	panel.chip = S.Chip(header)
	panel.chip:SetPoint("LEFT", expLabel, "RIGHT", 0, 0)
	panel.expUnknown = S.Text(header, "GameFontHighlightSmall", C.muted)
	panel.expUnknown:SetPoint("LEFT", expLabel, "RIGHT", 0, 0)
	panel.collState = S.Text(header, "GameFontHighlightSmall")

	-- Label/value rows. Their labels change for quests and artifacts.
	-- Renglones etiqueta/valor. Sus etiquetas cambian en misiones y artefactos.
	local function labelRow(anchor)
		local label = S.Text(header, "GameFontDisableSmall", C.muted)
		label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
		label:SetWidth(84)
		local value = S.Text(header, "GameFontHighlight")
		value:SetPoint("LEFT", label, "RIGHT", 0, 0)
		value:SetPoint("RIGHT", header, "RIGHT", -20, 0)
		return label, value
	end
	panel.exLabel, panel.exValue = labelRow(expLabel)
	panel.puLabel, panel.puValue = labelRow(panel.exLabel)
	panel.ahLabel, panel.ahValue = labelRow(panel.puLabel) -- quests: place · artifacts: set

	function panel:SetFourthRow(shown)
		self.ahLabel:SetShown(shown)
		self.ahValue:SetShown(shown)
		self.header:SetHeight(shown and HEADER_FULL or HEADER_SHORT)
	end

	-- Scrolling body / Cuerpo desplazable ------------------------------------
	local box = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
	box:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 22, -6)
	box:SetPoint("BOTTOMRIGHT", -30, 8)
	local bar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 8, 0)
	local view = CreateScrollBoxListLinearView(0, 0, 0, 0, 2)
	view:SetElementExtentCalculator(function(_, d) return EXTENT[d.type] or 24 end)
	view:SetElementInitializer("Button", initRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
	panel.box = box

	local emptyText = S.Text(panel, "GameFontDisable", C.muted, "CENTER")
	emptyText:SetPoint("CENTER")
	emptyText:SetText(L.PICK_ONE)
	panel.emptyText = emptyText

	local function show(rows, keepScroll)
		box:SetDataProvider(CreateDataProvider(rows), keepScroll and true or false)
	end

	-- Behavior / Comportamiento ----------------------------------------------
	function panel:ToggleVendor(npc)
		local o = self.open[self.key] or {}
		o[npc] = not o[npc] or nil
		self.open[self.key] = o
		self:Refresh(true)
	end

	-- A new item starts with its first (nearest) vendor expanded.
	-- Un objeto nuevo empieza con su primer vendedor (el más cercano) desplegado.
	function panel:SetKey(key)
		if key == self.key then return self:Refresh(true) end
		self.key = key
		if key and not self.open[key] then
			local offers = IL.Data:GetOffers(key)
			self.open[key] = offers and offers[1] and { [offers[1].npc] = true } or {}
		end
		self:Refresh(false)
	end

	-- Class quest: class, rewards, place and your characters of that class.
	-- Misión de clase: clase, recompensas, lugar y tus personajes de esa clase.
	function panel:RefreshQuest(key, keepScroll)
		local Data = IL.Data
		local _, id = IL.SplitKey(key)
		local q = Data:GetClassQuest(id) or { rewards = {} }
		S.SetColor(self.name, C.text)
		self.exLabel:SetText(L.Q_CLASS)
		self.exValue:SetText(classText(q.class))
		self.puLabel:SetText(L.Q_REWARDS)
		self.puValue:SetText(#q.rewards > 0 and L.N_ITEMS:format(#q.rewards) or DASH)
		self:SetFourthRow(true)
		self.ahLabel:SetText(L.Q_PLACE)
		self.ahValue:SetText(Data:GetPlace(key) or DASH)

		local rows = {}
		local function add(d) rows[#rows + 1] = d end
		if q.map then
			add({ type = "section", text = L.Q_SECTION_PLACE })
			add({ type = "origin", origin = { k = "z", id = q.map, map = q.map, x = q.x, y = q.y } })
		end
		if #q.rewards > 0 then
			add({ type = "section", text = L.Q_SECTION_REWARDS })
			for _, itemID in ipairs(q.rewards) do add({ type = "item", itemID = itemID, qty = 1 }) end
		end
		add({ type = "section", text = L.Q_SECTION_CHARS })
		local chars = IL.Coll:GetQuestChars(id)
		if #chars == 0 then add({ type = "empty", text = L.Q_NO_CHARS }) end
		for _, ch in ipairs(chars) do
			local mark = ch.done and (ICON_CHECK .. L.Q_DONE_BY) or (ICON_CROSS .. L.Q_PENDING_FOR)
			add({ type = "text", text = mark .. ": " .. ch.name })
		end
		show(rows, keepScroll)
	end

	-- Artifact appearance: class, weapon, set and how to unlock it.
	-- Apariencia de artefacto: clase, arma, conjunto y cómo se consigue.
	function panel:RefreshArtifact(key, keepScroll)
		local Data, Int = IL.Data, IL.Int
		local _, id = IL.SplitKey(key)
		local a = Data:GetArtifact(id) or { origins = {} }
		self.exLabel:SetText(L.Q_CLASS)
		self.exValue:SetText(classText(a.class))
		self.puLabel:SetText(L.ART_WEAPON)
		self.puValue:SetText(a.weapon and Data:GetDisplayName("i" .. a.weapon) or DASH)
		self:SetFourthRow(true)
		self.ahLabel:SetText(L.ART_SET)
		self.ahValue:SetText(Int:GetHeaderName(a.set) or DASH)

		local rows = {}
		local function add(d) rows[#rows + 1] = d end
		add({ type = "section", text = L.ART_SECTION_HOW })
		for _, o in ipairs(a.origins) do add({ type = "origin", origin = o }) end
		if #a.origins == 0 then
			-- No own origin: its set explains it (PvP prestige, challenge, hidden…).
			-- Sin origen propio: lo explica su conjunto (prestigio JcJ, desafío, oculta…).
			add({ type = "text", text = L.ART_SET_ONLY:format(Int:GetHeaderName(a.set) or "?") })
		end
		if a.weapon then
			add({ type = "section", text = L.ART_WEAPON:upper() })
			add({ type = "item", itemID = a.weapon, qty = 1 })
		end
		show(rows, keepScroll)
	end

	-- Items and currencies. / Objetos y monedas.
	function panel:RefreshItem(key, keepScroll)
		local Data = IL.Data
		self.puLabel:SetText(L.PURPOSE)
		self:SetFourthRow(false)

		local stats = Data:GetTokenStats(key)
		local offers = Data:GetOffers(key)
		local sources = Data:GetSources(key)
		local origins = Data:GetObtain(key)

		-- Header summary: exchanges, bought with, or main origin.
		-- Resumen del encabezado: canjes, se compra con, u origen principal.
		if stats then
			self.exLabel:SetText(L.EXCHANGES)
			self.exValue:SetText(L.N_ITEMS_M_VENDORS:format(stats.offers, stats.vendors))
		elseif sources then
			local s = sources[1]
			self.exLabel:SetText(L.OBTAINED_WITH)
			local extra = #sources > 1 and ("  " .. S.Muted("(+" .. (#sources - 1) .. ")")) or ""
			self.exValue:SetText(Data:GetDisplayName(s[1]) .. " |cff" .. S.HEX.brass .. "× " .. s[3] .. "|r" .. extra)
		elseif origins then
			self.exLabel:SetText(L.OBTAINED)
			self.exValue:SetText(Data:GetObtainSummary(key))
		else
			self.exLabel:SetText(L.EXCHANGES)
			self.exValue:SetText(DASH)
		end

		local summary, purpose = Data:GetPurpose(key)
		self.puValue:SetText(summary or DASH)

		local rows = {}
		local function add(d) rows[#rows + 1] = d end

		local desc = Data:GetDescription(key)
		if #purpose > 0 or desc then
			add({ type = "section", text = L.PURPOSE_SECTION })
			for _, line in ipairs(purpose) do add({ type = "text", text = line }) end
			for _, line in ipairs(desc or {}) do add({ type = "text", text = line }) end
		end

		-- Always shown for items. / Siempre visible en objetos.
		local uses = Data:GetUses(key)
		if IL.SplitKey(key) == "i" then
			add({ type = "section", text = L.NEEDED_FOR })
			for _, u in ipairs(uses or {}) do add({ type = "use", use = u }) end
			if not uses then add({ type = "empty", text = L.NO_USES }) end
		end

		if offers then
			add({ type = "section", text = L.WHERE })
			local open = self.open[key] or {}
			for _, v in ipairs(offers) do
				local isOpen = open[v.npc] and true or false
				add({ type = "vendor", v = v, open = isOpen, panel = self })
				if isOpen then
					for _, it in ipairs(v.items) do add({ type = "item", itemID = it[1], qty = it[2], learned = it[3] }) end
				end
			end
		end

		if origins or sources then
			add({ type = "section", text = L.SOURCES })
			for _, o in ipairs(origins or {}) do add({ type = "origin", origin = o }) end
			for _, s in ipairs(sources or {}) do
				add({ type = "source", token = s[1], npc = s[2], qty = s[3], learned = s[4] })
			end
		end

		local crafts = Data:GetCrafts(key)
		if crafts then
			add({ type = "section", text = L.CRAFTS_SECTION })
			for i, it in ipairs(crafts) do
				if i > MAX_CRAFTS then
					add({ type = "more", text = L.MORE_CRAFTS:format(#crafts - MAX_CRAFTS) })
					break
				end
				add({ type = "item", itemID = it[1], qty = it[2], learned = it[3] })
			end
		end

		if not offers and not sources and not uses and not crafts and not origins then
			add({ type = "empty", text = L.NO_EXCHANGE })
		end

		local owners = IL.Chars:GetOwners(key)
		if owners then
			add({ type = "section", text = L.OWNERS })
			for _, o in ipairs(owners) do add({ type = "owner", owner = o }) end
		end

		show(rows, keepScroll)
	end

	function panel:Refresh(keepScroll)
		local key = self.key
		self.emptyText:SetShown(not key)
		self.header:SetShown(key ~= nil)
		self.box:SetShown(key ~= nil)
		if not key then bar:Hide() return end

		local Data = IL.Data
		local kind = IL.SplitKey(key)
		self.icon.tex:SetTexture(Data:GetIcon(key))
		self.name:SetText(Data:GetDisplayName(key))
		self.name:SetTextColor(S.QualityColor(Data:GetQuality(key)))

		local exp = Data:GetExpansion(key)
		if exp then
			self.chip:SetExpansion(exp, true)
			self.expUnknown:Hide()
		else
			self.chip:Hide()
			self.expUnknown:SetText(L.UNKNOWN_EXP)
			self.expUnknown:Show()
		end

		-- Collection state next to the expansion. / Estado de colección junto a la expansión.
		local isQuest = kind == "q"
		local state = IL.Coll:GetState(key)
		self.collState:ClearAllPoints()
		self.collState:SetPoint("LEFT", self.chip:IsShown() and self.chip or self.expUnknown, "RIGHT", 12, 0)
		if state == "have" then
			self.collState:SetText(ICON_CHECK .. (isQuest and L.Q_DONE or L.COLL_HAVE))
			self.collState:SetTextColor(0.49, 0.78, 0.49)
		elseif state == "missing" then
			self.collState:SetText(ICON_CROSS .. (isQuest and L.Q_PENDING or L.COLL_MISSING))
			self.collState:SetTextColor(0.91, 0.47, 0.36)
		elseif state == "otherclass" then
			self.collState:SetText(L.COLL_OTHERCLASS)
			S.SetColor(self.collState, C.muted)
		end
		self.collState:SetShown(state ~= nil)

		-- The name shrinks to make room for the dressing room button.
		-- El nombre se acorta para dejar lugar al botón de probador.
		local canDress = IL:CanDressUp(key)
		self.dress:SetShown(canDress)
		self.name:SetPoint("RIGHT", canDress and self.dress or self.fav, "LEFT", -12, 0)

		local fav = IL:IsFavorite(key)
		S.SetStar(self.fav.star, fav)
		self.fav.text:SetText(fav and L.FAV_ON or L.FAV_OFF)

		if isQuest then
			self:RefreshQuest(key, keepScroll)
		elseif kind == "f" then
			self:RefreshArtifact(key, keepScroll)
		else
			self:RefreshItem(key, keepScroll)
		end
	end

	return panel
end
