--[[
	ItemLens · UI/AchDetail.lua
	Achievement detail panel (D-56): header (icon, name, tags, progress bar, reward) and a
	scrolling body: description, progress checklist, what is missing, requirements, how to get
	it (reputation quests and turn-ins) and the ItemLens guide.
	Panel de detalle de un logro (D-56): encabezado (ícono, nombre, etiquetas, barra de progreso,
	recompensa) y un cuerpo desplazable: descripción, lista de progreso, lo que falta, requisitos,
	cómo se consigue (misiones y entregas de reputación) y la guía de ItemLens.
	© 2026 iAthVo_Kr · MIT License
]]

local _, IL = ...
local L, S = IL.L, IL.Style
local C = S.C

local HEADER_H = 168 -- D-74: two tag columns, up to 3 lines / dos columnas de etiquetas, hasta 3 líneas
local MAX_MISSING = 60 -- missing mounts shown before "+N more" / monturas que faltan antes de "+N más"
local EXTENT = { section = 32, check = 30, checkSub = 46, req = 24, way = 46, mount = 26, more = 24, item = 42, thead = 18 }
local MAX_ITEMS = 40 -- items listed before "+N more" / objetos antes de "+N más" (D-67)
local ICON_CHECK = "|A:common-icon-checkmark:12:12|a"
local ICON_CROSS = "|A:common-icon-redx:12:12|a"
local OK_COLOR, MISS_COLOR = { 0.49, 0.78, 0.49 }, { 0.91, 0.47, 0.36 }
local CHARS_PER_LINE = 78 -- for the height of wrapped paragraphs / para la altura de párrafos

local function paraExtent(text)
	local lines = math.max(1, math.ceil(#(text or "") / CHARS_PER_LINE))
	return lines * 16 + 10
end

-- Criterion row height: name, place line, and the wrapped suggestion (D-70).
-- Alto de la fila de criterio: nombre, línea de lugar y la sugerencia con ajuste (D-70).
local HINT_CHARS = 66
local function checkExtent(d)
	local h = d.hasSub and 46 or 30
	if d.c.hint then h = h + math.max(1, math.ceil(#(L.ACH_HINT:format(d.c.hint)) / HINT_CHARS)) * 14 + 2 end
	return h
end

local function canOpen(achID) return achID and IL.Ach:Ensure().byID[achID] ~= nil end

---------------------------------------------------------------------------
-- Rows / Filas
---------------------------------------------------------------------------
local function onClick(self)
	local d = self.data
	if not d then return end
	-- An item opens its detail (Catalog); Shift+click links it. D-67
	-- Un objeto abre su detalle (Catálogo); Mayús+clic lo enlaza. D-67
	if d.type == "item" then
		local key = "i" .. d.itemID
		if IsModifiedClick("CHATLINK") then return IL.InsertLink(IL.Data:GetLink(key)) end
		return IL.UI:Select(key)
	end
	local achID = (d.type == "check" and d.c.ach) or (d.type == "req" and d.ach)
	if achID and canOpen(achID) then return IL.UI:Select("a" .. achID) end
	-- A criterion that is an item opens it (D-74). / Un criterio que es un objeto lo abre (D-74).
	if d.type == "check" and d.c.item then
		local key = "i" .. d.c.item
		if IsModifiedClick("CHATLINK") then return IL.InsertLink(IL.Data:GetLink(key)) end
		return IL.UI:Select(key)
	end
end

local function onEnter(self)
	local d = self.data
	if not d then return end
	if d.type == "item" then
		S.OutsideTooltip(self)
		GameTooltip:SetItemByID(d.itemID)
		GameTooltip:Show()
		return
	end
	if d.type == "check" and (d.c.tip or d.c.hint or self.left:IsTruncated() or self.sub:IsTruncated()) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(d.c.text, 1, 1, 1, 1, true)
		if self.sub:IsShown() then GameTooltip:AddLine(self.sub:GetText(), C.muted[1], C.muted[2], C.muted[3], true) end
		if d.c.hint then GameTooltip:AddLine(L.ACH_HINT:format(d.c.hint), C.brass[1], C.brass[2], C.brass[3], true) end
		if d.c.tip then GameTooltip:AddLine(L.ACH_TIP_ATT .. " " .. d.c.tip, C.textSoft[1], C.textSoft[2], C.textSoft[3], true) end
		GameTooltip:Show()
	elseif d.type == "step" and self.left:IsTruncated() then
		S.SimpleTooltip(self, d.text)
	elseif (d.type == "req" or d.type == "way") and self.left:IsTruncated() then
		S.SimpleTooltip(self, self.left:GetText())
	end
end

local function buildRow(row)
	row.bg = S.Fill(row, C.card)
	row.hl = row:CreateTexture(nil, "HIGHLIGHT")
	row.hl:SetAllPoints()
	row.hl:SetColorTexture(1, 1, 1, 0.035)
	row.mark = S.Text(row, "ItemLensFontNormal")
	row.icon = S.Icon(row, 18)
	row.left = S.Text(row, "ItemLensFontNormal")
	row.sub = S.Text(row, "ItemLensFontSmallMuted", C.muted)
	row.right = S.Text(row, "ItemLensFontNumber", C.mono, "RIGHT")
	row.line = S.SectionLine(row)
	row.hint = S.Text(row, "ItemLensFontSmallMuted", C.textSoft) -- criterion suggestion (D-70) / sugerencia
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
	row.pin:SetScript("OnClick", function(self) IL.Int:SetWaypoint(self.target) end)
	row.pin:SetScript("OnEnter", function(self) S.SimpleTooltip(self, L.PIN) end)
	row.pin:SetScript("OnLeave", GameTooltip_Hide)
	row:RegisterForClicks("LeftButtonUp")
	row:SetScript("OnClick", onClick)
	row:SetScript("OnEnter", onEnter)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row.built = true
end

local function resetRow(row)
	for _, r in ipairs({ row.mark, row.icon, row.left, row.sub, row.right, row.pin, row.hint }) do
		r:Hide()
		r:ClearAllPoints()
	end
	row.bg:Hide()
	row.hl:Hide()
	row.line:Hide()
	S.SetColor(row.sub, C.mono)
	row.left:SetFontObject("ItemLensFontNormal")
	row.left:SetWordWrap(false)
	row.left:SetJustifyV("MIDDLE")
	S.SetColor(row.left, C.text)
	row:EnableMouse(true)
end

-- Pin on the right; returns the right inset for the text. / Pin a la derecha; devuelve el margen.
local function showPin(row, target)
	if not IL.Int:CanWaypoint(target) then return -12 end
	row.pin.target = target
	row.pin:SetPoint("RIGHT")
	row.pin:Show()
	return -48
end

local RENDER = {}

function RENDER.section(row, d)
	row:EnableMouse(false)
	S.SectionTitle(row, d.text)
end

-- Wrapped paragraph (description, guide). / Párrafo con ajuste (descripción, guía).
function RENDER.para(row, d)
	row:EnableMouse(false)
	row.left:SetWordWrap(true)
	row.left:SetJustifyV("TOP")
	S.SetColor(row.left, d.muted and C.muted or C.textSoft)
	row.left:SetPoint("TOPLEFT", 2, -4)
	row.left:SetPoint("BOTTOMRIGHT", -2, 2)
	row.left:SetText(d.text)
	row.left:Show()
end

-- Criterion: ✓/✗, text, amount, second line (reputation, NPC, item, object) and pin.
-- Criterio: ✓/✗, texto, cantidad, segunda línea (reputación, NPC, objeto) y pin.
function RENDER.check(row, d)
	local c, Int = d.c, IL.Int
	row.bg:Show()
	if c.ach and canOpen(c.ach) then row.hl:Show() end
	-- Table like the LogrosDoc (D-70): # name · place · suggestion, and the state column on the
	-- right, always in the same place (the pin column is kept even without a pin).
	-- Tabla como el LogrosDoc (D-70): # nombre · lugar · sugerencia, y la columna de estado a la
	-- derecha, siempre en el mismo lugar (se guarda la columna del pin aunque no haya pin).
	local pin = c.map and c.x and { map = c.map, x = c.x, y = c.y, npc = c.npc, title = c.text } or nil
	showPin(row, pin)
	local right = -48
	row.mark:SetPoint("CENTER", row, "TOPRIGHT", right - 12, -15)
	row.mark:SetText(c.done and ICON_CHECK or ICON_CROSS)
	row.mark:Show()
	right = right - 28
	if c.need and not c.done then
		row.right:SetPoint("TOPRIGHT", right, -8)
		row.right:SetText((BreakUpLargeNumbers and BreakUpLargeNumbers(c.have) or c.have) .. " / " .. (BreakUpLargeNumbers and BreakUpLargeNumbers(c.need) or c.need))
		row.right:Show()
		right = right - row.right:GetStringWidth() - 10
	end
	local parts = {}
	if c.note then parts[#parts + 1] = c.note end
	if c.npc then parts[#parts + 1] = L.ACH_NPC:format(Int:GetNPCName(c.npc)) end
	if c.item then
		-- The item and how to get it (D-74). / El objeto y cómo se obtiene (D-74).
		local how = IL.Data:GetObtainSummary("i" .. c.item)
		parts[#parts + 1] = L.ACH_ITEM:format(IL.Data:GetDisplayName("i" .. c.item)) .. (how and (" — " .. how) or "")
	end
	if c.object and IL.DB.objects and IL.DB.objects[c.object] then parts[#parts + 1] = Int:GetObjectName(c.object) end
	if c.map and c.x then parts[#parts + 1] = Int:GetZoneName(c.map) .. "  " .. Int:FormatCoords(c.x, c.y) end
	if c.tip then parts[#parts + 1] = L.ACH_TIP_MARK end
	local sub = table.concat(parts, " · ")
	row.left:SetPoint("TOPLEFT", 12, -8)
	row.left:SetPoint("RIGHT", right, 0)
	if (c.ach and canOpen(c.ach)) or c.item then S.SetColor(row.left, C.brassHi) else S.SetColor(row.left, c.done and C.textSoft or C.text) end
	row.left:SetText("|cff" .. S.HEX.brass .. (c.n or "") .. ".|r " .. c.text)
	row.left:Show()
	local y = -24
	if sub ~= "" then
		row.sub:SetPoint("TOPLEFT", 12, y)
		row.sub:SetPoint("RIGHT", -60, 0)
		row.sub:SetText(sub)
		row.sub:Show()
		y = y - 16
	end
	if c.hint then
		row.hint:SetWordWrap(true)
		row.hint:SetJustifyV("TOP")
		row.hint:SetPoint("TOPLEFT", 12, y)
		row.hint:SetPoint("BOTTOMRIGHT", -60, 4)
		row.hint:SetText(L.ACH_HINT:format(c.hint))
		row.hint:Show()
	end
end

-- Column titles above the criteria (D-70). / Títulos de columna sobre los criterios (D-70).
function RENDER.thead(row, d)
	row:EnableMouse(false)
	row.left:SetFontObject("ItemLensFontSmallMuted")
	S.SetColor(row.left, C.muted)
	row.left:SetPoint("LEFT", 12, 0)
	row.left:SetText(L.ACH_COL_CRIT)
	row.left:Show()
	row.right:SetPoint("RIGHT", -48, 0)
	S.SetColor(row.right, C.muted)
	row.right:SetText(L.ACH_COL_STATE)
	row.right:Show()
end

-- Requirement line; an achievement in the tab can be opened. / Requisito; un logro de la pestaña se abre.
function RENDER.req(row, d)
	local open = d.ach and canOpen(d.ach)
	if open then row.hl:Show() end
	row.left:SetPoint("LEFT", 4, 0)
	row.left:SetPoint("RIGHT", -4, 0)
	S.SetColor(row.left, open and C.brassHi or C.textSoft)
	local mark = ""
	if d.ach then mark = (IL.Ach:IsCompleted("a" .. d.ach) and ICON_CHECK or ICON_CROSS) .. " " end
	row.left:SetText(mark .. d.text)
	row.left:Show()
end

-- Way to raise a reputation: quest, turn-in, NPC and place. / Forma de subir reputación.
function RENDER.way(row, d)
	local w, Int = d.w, IL.Int
	row.bg:Show()
	local pin = w.map and w.x and { map = w.map, x = w.x, y = w.y, npc = w.npc } or nil
	local right = showPin(row, pin)
	local title = Int:GetFactionName(d.faction) .. " · " .. Int:GetQuestTitle(w.quest)
	if w.repeatable then title = title .. "  " .. S.Muted(L.ACH_REPEATABLE) end
	row.left:SetPoint("TOPLEFT", 12, -7)
	row.left:SetPoint("RIGHT", right, 0)
	row.left:SetText(title)
	row.left:Show()
	local parts = {}
	if w.item then parts[#parts + 1] = L.ACH_TURN_IN:format(w.count or 1, IL.Data:GetDisplayName("i" .. w.item)) end
	if w.npc then parts[#parts + 1] = Int:GetNPCName(w.npc) end
	if w.map then parts[#parts + 1] = Int:GetZoneName(w.map, w.npc) .. "  " .. Int:FormatCoords(w.x, w.y) end
	if w.max then parts[#parts + 1] = L.ACH_UP_TO:format(Int:StandingName(w.max, d.faction)) end
	row.sub:SetPoint("BOTTOMLEFT", 12, 7)
	row.sub:SetPoint("RIGHT", right, 0)
	row.sub:SetText(table.concat(parts, " · "))
	row.sub:Show()
end

-- Missing mount. / Montura que falta.
-- Guide step with a place: number, wrapped text, zone + coordinates and pin. D-69
-- Paso de guía con lugar: número, texto con ajuste, zona + coordenadas y pin. D-69
function RENDER.step(row, d)
	local Int = IL.Int
	row.bg:Show()
	local right = showPin(row, { map = d.map, x = d.x, y = d.y, title = L.ACH_GUIDE_PLAIN })
	row.left:SetWordWrap(true)
	row.left:SetJustifyV("TOP")
	S.SetColor(row.left, C.textSoft)
	row.left:SetPoint("TOPLEFT", 12, -7)
	row.left:SetPoint("RIGHT", right, 0)
	row.left:SetPoint("BOTTOM", 0, 24)
	row.left:SetText(d.n .. ". " .. d.text)
	row.left:Show()
	row.sub:SetPoint("BOTTOMLEFT", 12, 7)
	row.sub:SetPoint("RIGHT", right, 0)
	row.sub:SetText(Int:GetZoneName(d.map) .. "  " .. Int:FormatCoords(d.x, d.y))
	row.sub:Show()
end

function RENDER.mount(row, d)
	row.icon:SetPoint("LEFT", 12, 0)
	row.icon.tex:SetTexture(d.icon)
	row.icon:Show()
	row.left:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
	row.left:SetPoint("RIGHT", -4, 0)
	S.SetColor(row.left, C.textSoft)
	row.left:SetText(d.name)
	row.left:Show()
end

-- Item the achievement needs: icon, name, how to get it, how many you have. D-67
-- Objeto que pide el logro: ícono, nombre, cómo se obtiene, cuántos tienes. D-67
function RENDER.item(row, d)
	local Data, key = IL.Data, "i" .. d.itemID
	row.bg:Show()
	row.hl:Show()
	row.icon:SetPoint("LEFT", 10, 0)
	row.icon.tex:SetTexture(Data:GetIcon(key))
	row.icon:Show()
	local owned = 0
	for _, o in ipairs(IL.Chars:GetOwners(key) or {}) do owned = owned + (o.total or 0) end
	row.right:SetPoint("RIGHT", -12, 0)
	row.right:SetText(owned > 0 and ("× " .. owned) or "")
	row.right:Show()
	row.left:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 2)
	row.left:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
	row.left:SetText(Data:GetDisplayName(key))
	row.left:SetTextColor(S.QualityColor(Data:GetQuality(key)))
	row.left:Show()
	local how = Data:GetObtainSummary(key)
	if not how then
		local notes = Data:GetAchObtainNotes(key)
		how = notes and notes[1]
	end
	row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, -2)
	row.sub:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
	row.sub:SetText(how or L.ACH_ITEM_UNKNOWN)
	row.sub:Show()
end

function RENDER.more(row, d)
	row:EnableMouse(false)
	row.left:SetFontObject("ItemLensFontSmallMuted")
	S.SetColor(row.left, C.muted)
	row.left:SetPoint("LEFT", 12, 0)
	row.left:SetText(d.text)
	row.left:Show()
end

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
function IL.CreateAchDetail(parent)
	local panel = CreateFrame("Frame", nil, parent)

	local header = CreateFrame("Frame", nil, panel)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_H)
	S.HLine(header, header, 0)
	panel.header = header

	-- Big icon: Shift+click links the achievement in chat. / Ícono: Mayús+clic lo enlaza en el chat.
	local icon = S.Icon(header, 50)
	icon:SetPoint("TOPLEFT", 22, -18)
	icon:EnableMouse(true)
	icon:SetScript("OnEnter", function(self)
		if not panel.id then return end
		S.OutsideTooltip(self)
		local link = GetAchievementLink and GetAchievementLink(panel.id)
		if link then GameTooltip:SetHyperlink(link) else GameTooltip:SetText(IL.Ach:GetName("a" .. panel.id)) end
		GameTooltip:Show()
	end)
	icon:SetScript("OnLeave", GameTooltip_Hide)
	panel.iconFrame = S.FactionFrame(icon) -- faction color around the icon (D-59) / color de facción
	icon:SetScript("OnMouseUp", function(_, button)
		if button == "LeftButton" and panel.id and IsModifiedClick("CHATLINK") and GetAchievementLink then
			IL.InsertLink(GetAchievementLink(panel.id))
		end
	end)
	panel.icon = icon

	panel.facBadge = S.FactionBadge(header) -- Horde / Alliance / both (D-59, D-60)
	panel.facBadge:SetPoint("TOPRIGHT", -20, -14)

	local name = S.Text(header, "ItemLensFontLarge")
	name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 14, -1)
	name:SetPoint("RIGHT", panel.facBadge, "LEFT", -12, 0)
	panel.name = name

	-- Tags in two columns (D-74), so nothing is cut off:
	--   left: completed · availability (and why) · famous   right: points · account/character · category
	-- Etiquetas en dos columnas (D-74), para que no se corte nada:
	--   izquierda: completado · disponibilidad (y motivo) · famoso   derecha: puntos · cuenta/personaje · categoría
	local cols = CreateFrame("Frame", nil, header)
	cols:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -8)
	cols:SetPoint("RIGHT", header, "RIGHT", -20, 0)
	cols:SetHeight(46)
	local function column(anchorLeft)
		local fs = S.Text(cols, "ItemLensFontSmall")
		fs:SetWordWrap(true)
		fs:SetSpacing(3)
		fs:SetJustifyV("TOP")
		fs:SetMaxLines(3)
		if anchorLeft then
			fs:SetPoint("TOPLEFT")
			fs:SetPoint("BOTTOMRIGHT", cols, "BOTTOM", -8, 0)
		else
			fs:SetPoint("TOPLEFT", cols, "TOP", 8, 0)
			fs:SetPoint("BOTTOMRIGHT")
		end
		return fs
	end
	panel.tags, panel.tagsR = column(true), column(false)

	-- Progress bar / Barra de progreso
	local track = CreateFrame("Frame", nil, header)
	track:SetPoint("TOPLEFT", cols, "BOTTOMLEFT", 0, -8)
	track:SetSize(260, 8)
	S.Fill(track, C.panelDeep)
	S.Border(track, C.border)
	local fill = track:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMLEFT", 1, 1)
	fill:SetColorTexture(C.brass[1], C.brass[2], C.brass[3])
	panel.fill, panel.track = fill, track
	local pct = S.Text(header, "ItemLensFontSmall", C.textSoft)
	pct:SetPoint("LEFT", track, "RIGHT", 10, 0)
	panel.pct = pct

	-- Mark all (D-79): every place of the achievement on the map (TomTom), even when it is done.
	-- Click: all · Shift+click: only the missing criteria · right click: remove them.
	-- Marcar todo (D-79): todos los lugares del logro en el mapa (TomTom), aunque ya esté hecho.
	-- Clic: todos · Mayús+clic: solo los criterios que faltan · clic derecho: quitarlos.
	local markAll = S.FlatButton(header, 10, 22)
	S.Border(markAll, C.border)
	markAll.icon = markAll:CreateTexture(nil, "ARTWORK")
	markAll.icon:SetSize(14, 14)
	markAll.icon:SetPoint("LEFT", 6, 0)
	markAll.icon:SetAtlas("Waypoint-MapPin-ChatIcon")
	markAll.text:ClearAllPoints()
	markAll.text:SetPoint("LEFT", markAll.icon, "RIGHT", 4, 0)
	markAll:SetPoint("RIGHT", header, "RIGHT", -20, 0)
	markAll:SetPoint("TOP", track, "TOP", 0, 7)
	markAll:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	markAll:SetScript("OnClick", function(_, button)
		if not panel.key then return end
		if button == "RightButton" then
			IL:Print(L.PIN_CLEARED, IL.Int:ClearWaypoints())
			return
		end
		IL.Int:SetWaypoints(IL.Ach:Places(panel.key, IsShiftKeyDown()))
	end)
	markAll:SetScript("OnEnter", function(self)
		S.OutsideTooltip(self)
		GameTooltip:SetText(L.PIN_ALL_TITLE)
		GameTooltip:AddLine(L.PIN_ALL_TIP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	markAll:SetScript("OnLeave", GameTooltip_Hide)
	markAll:Hide()
	panel.markAll = markAll

	local reward = S.Text(header, "ItemLensFontSmall", C.textSoft)
	reward:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, -10)
	reward:SetPoint("RIGHT", header, "RIGHT", -20, 0)
	panel.reward = reward

	local box = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
	box:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 22, -6)
	box:SetPoint("BOTTOMRIGHT", -30, 8)
	local bar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 8, 0)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 8, 0)
	local view = CreateScrollBoxListLinearView(0, 0, 0, 0, 2)
	view:SetElementExtentCalculator(function(_, d)
		if d.type == "para" then return paraExtent(d.text) end
		if d.type == "step" then return paraExtent(d.n .. ". " .. d.text .. "      ") + 22 end -- D-69
		if d.type == "check" then return checkExtent(d) end
		return EXTENT[d.type] or 24
	end)
	view:SetElementInitializer("Button", initRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(box, bar)
	panel.box = box

	local emptyText = S.Text(panel, "ItemLensFontNormalMuted", C.muted, "CENTER")
	emptyText:SetPoint("CENTER")
	emptyText:SetText(L.ACH_PICK_ONE)
	panel.emptyText = emptyText

	function panel:SetKey(key)
		local same = key == self.key
		self.key = key
		self:Refresh(same)
	end

	function panel:Refresh(keepScroll)
		local key = self.key
		local Ach = IL.Ach
		local info = key and Ach:Info(key)
		self.emptyText:SetShown(not info)
		self.header:SetShown(info ~= nil)
		self.box:SetShown(info ~= nil)
		if not info then bar:Hide() return end
		self.id = info.id

		self.icon.tex:SetTexture(info.icon)
		self.name:SetText(info.name)
		S.SetColor(self.name, info.completed and C.brassHi or C.text)

		local t, r = {}, {}
		if info.completed then t[#t + 1] = "|cff7cc77c" .. ICON_CHECK .. " " .. L.ACH_DONE_ON:format(info.date or "") .. "|r" end
		local status, why = Ach:Status(key)
		if status then
			t[#t + 1] = (status == "yes" and "|cff7cc77c" or status == "no" and "|cffe8785c" or "|cffc8a765")
				.. L.ACH_STATUS[status] .. (why and (" (" .. why .. ")") or "") .. "|r" -- timed: D-82
		end
		local faction = Ach:Faction(key)
		self.facBadge:Set(faction, L)
		self.iconFrame:Set(faction)
		local rank = Ach:FamousRank(key)
		if rank then t[#t + 1] = "|cff" .. S.HEX.brass .. L.ACH_FAMOUS_N:format(rank) .. "|r" end
		r[#r + 1] = "|cff" .. S.HEX.brass .. L.ACH_POINTS:format(info.points) .. "|r  ·  " .. (info.account and L.ACH_ACCOUNT or L.ACH_CHAR)
		r[#r + 1] = S.Muted(Ach:CategoryText(key))
		self.tags:SetText(table.concat(t, "\n"))
		self.tagsR:SetText(table.concat(r, "\n"))

		local criteria = Ach:Criteria(key)
		local done, total = Ach:Progress(key, criteria)
		local frac = math.min(1, done / math.max(1, total))
		self.fill:SetWidth(math.max(1, 258 * frac))
		self.fill:SetShown(frac > 0)
		local nf = BreakUpLargeNumbers or tostring
		self.pct:SetText(nf(done) .. " / " .. nf(total) .. "  ·  " .. math.floor(frac * 100 + 0.5) .. " %")
		self.reward:SetText(info.reward and ("|cff" .. S.HEX.title .. L.ACH_REWARD .. "|r |cff" .. S.HEX.brass .. info.reward .. "|r") or "")

		-- Two or more places: the Mark all button (D-79). / Dos o más lugares: el botón Marcar todo.
		local places = Ach:Places(key, false, criteria)
		self.markAll:SetShown(#places >= 2)
		if #places >= 2 then
			self.markAll.text:SetText(L.PIN_ALL:format(#places))
			self.markAll:SetWidth(self.markAll.text:GetStringWidth() + 34)
		end

		local rows = {}
		local function add(d) rows[#rows + 1] = d end
		if info.desc ~= "" then add({ type = "para", text = info.desc }) end

		if #criteria > 0 then
			local n = 0
			for _, c in ipairs(criteria) do if c.done then n = n + 1 end end
			add({ type = "section", text = L.ACH_PROGRESS:format(n, #criteria) })
			add({ type = "thead" })
			for _, c in ipairs(criteria) do
				local hasSub = c.note or c.npc or c.item or (c.map and c.x) or c.tip
				add({ type = "check", c = c, hasSub = hasSub and true or false })
			end
		end

		-- Items it needs, each one opens its detail (D-67). / Objetos que pide; cada uno abre su detalle.
		local items = Ach:NeededItems(key)
		if items and #items > 0 then
			add({ type = "section", text = L.ACH_ITEMS .. " · " .. #items })
			for i, id in ipairs(items) do
				if i > MAX_ITEMS then
					add({ type = "more", text = L.ACH_ITEMS_MORE:format(#items - MAX_ITEMS) })
					break
				end
				add({ type = "item", itemID = id })
			end
		end

		-- Mount achievements: what you still miss. / Logros de monturas: lo que te falta.
		if Ach:CollectionKind(key) == "mounts" and not info.completed then
			local groups = Ach:MissingMounts()
			local count, shown = 0, 0
			for _, g in ipairs(groups) do count = count + #g.items end
			add({ type = "section", text = L.ACH_MISSING_MOUNTS:format(count) })
			for _, g in ipairs(groups) do
				if shown >= MAX_MISSING then break end
				add({ type = "more", text = g.source .. " · " .. #g.items })
				for _, m in ipairs(g.items) do
					if shown >= MAX_MISSING then break end
					add({ type = "mount", name = m.name, icon = m.icon })
					shown = shown + 1
				end
			end
			if count > shown then add({ type = "more", text = L.ACH_MORE:format(count - shown) }) end
		end

		add({ type = "section", text = L.ACH_REQUIREMENTS })
		for _, r in ipairs(Ach:Requirements(key, criteria)) do add({ type = "req", text = r.text, ach = r.ach }) end

		-- How to get it: ways to raise each pending reputation. / Cómo subir cada reputación pendiente.
		local ways, seen = {}, {}
		for _, c in ipairs(criteria) do
			if c.faction and not c.done and not seen[c.faction] then
				seen[c.faction] = true
				for _, w in ipairs(Ach:RepWays(c.faction)) do ways[#ways + 1] = { faction = c.faction, w = w } end
			end
		end
		if #ways > 0 then
			add({ type = "section", text = L.ACH_HOW })
			for i, w in ipairs(ways) do
				if i > 12 then break end
				add({ type = "way", faction = w.faction, w = w.w })
			end
		end

		-- Guide: the 50 famous ones always; any other achievement when it has one (D-69).
		-- A step with coordinates gets a pin. / Un paso con coordenadas lleva pin.
		-- Guía: los 50 famosos siempre; cualquier otro logro cuando tiene una (D-69).
		local guide = L.ACH_GUIDES and L.ACH_GUIDES[info.id]
		if rank or guide then
			add({ type = "section", text = rank and L.ACH_GUIDE:format(rank) or L.ACH_GUIDE_PLAIN })
			if guide then
				for i, step in ipairs(guide) do
					if type(step) == "table" then
						add({ type = "step", n = i, text = step[1], map = step[2], x = step[3], y = step[4] })
					else
						add({ type = "para", text = i .. ". " .. step })
					end
				end
			else
				add({ type = "para", text = L.ACH_GUIDE_TODO, muted = true })
			end
		end

		box:SetDataProvider(CreateDataProvider(rows), keepScroll and true or false)
	end

	return panel
end
