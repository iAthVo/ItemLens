--[[
	ItemLens · UI/Style.lua
	The "Obsidian & Brass" look: color tokens, expansion colors and small widget builders.
	Uses the game's native fonts only.
	El estilo "Obsidiana y latón": colores, colores de expansión y constructores de elementos.
	Usa solo las fuentes nativas del juego.
	© 2026 iAthVo_Kr · MIT License
]]

local _, IL = ...

local S = {}
IL.Style = S

local function rgb(hex, a)
	return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, a or 1 }
end

---------------------------------------------------------------------------
-- Colors / Colores
---------------------------------------------------------------------------
S.C = {
	panel     = rgb("111217"), -- opaque: nothing behind shows through / opaco: no se transparenta
	panelDeep = rgb("0B0C10"),
	card      = rgb("14151B"),
	tab       = rgb("23242C"), -- active tab and segment / pestaña y segmento activos
	selected  = rgb("1B1C23"),
	hover     = rgb("17181E"),
	iconBg    = rgb("1C1D24"),
	border    = rgb("2A2A31"),
	borderFav = rgb("3A3528"),
	divider   = rgb("22232A"),
	brass     = rgb("C8A765"),
	brassHi   = rgb("E3C98E"),
	text      = rgb("ECE7DC"),
	textSoft  = rgb("CFC9BC"),
	muted     = rgb("A29D92"), -- secondary text, readable on the panel / texto secundario legible
	mono      = rgb("B9B3A6"),
	title     = rgb("8CC4F0"), -- labels and section titles (light blue) / etiquetas y títulos (azul claro)
	horde     = rgb("E5484D"), -- Horde red / rojo de la Horda (D-59)
	alliance  = rgb("4D8DF0"), -- Alliance blue / azul de la Alianza (D-59)
}
S.HEX = { brass = "c8a765", muted = "a29d92", text = "ece7dc", mono = "b9b3a6", title = "8cc4f0",
	horde = "e5484d", alliance = "4d8df0" }

-- One distinct, light color per expansion (Blizzard ID), readable on the dark panel.
-- Un color claro y distinto por expansión (ID de Blizzard), legible sobre el panel oscuro.
S.EXP = {
	[0]  = rgb("D6CCB4"), -- Classic: parchment / pergamino
	[1]  = rgb("B4D36A"), -- The Burning Crusade: Outland green / verde de Terrallende
	[2]  = rgb("8FD6E8"), -- Wrath of the Lich King: ice / hielo
	[3]  = rgb("E8775C"), -- Cataclysm: fire / fuego
	[4]  = rgb("E3CF63"), -- Mists of Pandaria: pandaren gold / oro pandaren
	[5]  = rgb("C7967C"), -- Warlords of Draenor: iron / hierro
	[6]  = rgb("63D27E"), -- Legion: fel / vil
	[7]  = rgb("6E9CEB"), -- Battle for Azeroth: sea / mar
	[8]  = rgb("B9C7D6"), -- Shadowlands: spectral silver / plata espectral
	[9]  = rgb("7CC7B4"), -- Dragonflight
	[10] = rgb("E0A659"), -- The War Within
	[11] = rgb("B4A6F0"), -- Midnight
}
S.EXP_OTHER = rgb("A8A398")

---------------------------------------------------------------------------
-- Fonts (D-60) / Letras (D-60)
---------------------------------------------------------------------------
-- The game's own font file (D-15) at fixed, larger sizes with a soft shadow, so text stays sharp
-- at any interface scale. UI files use these names instead of GameFont*.
-- El archivo de letra del propio juego (D-15) en tamaños fijos más grandes y con sombra suave,
-- para que el texto se vea nítido en cualquier escala de interfaz. La interfaz usa estos nombres
-- en lugar de GameFont*.
local FONTS = {
	ItemLensFontLarge       = { 17, "text" },
	ItemLensFontTitle       = { 16, "brass" },
	ItemLensFontNormal      = { 13, "text" },
	ItemLensFontNormalMuted = { 13, "muted" },
	ItemLensFontSmall       = { 12, "text" },
	ItemLensFontSmallMuted  = { 12, "muted" },
	ItemLensFontNumber      = { 13, "mono" },
	-- List on the left, about 20 % smaller (D-61) / Lista de la izquierda, ~20 % más chica (D-61)
	ItemLensFontList        = { 11, "text" },
	ItemLensFontListMuted   = { 11, "muted" },
	ItemLensFontListSmall   = { 10, "muted" },
}
if CreateFont then
	local file = (GameFontHighlight and GameFontHighlight.GetFont and GameFontHighlight:GetFont()) or STANDARD_TEXT_FONT
		or "Fonts\\FRIZQT__.TTF"
	for name, d in pairs(FONTS) do
		local fo = _G[name] or CreateFont(name)
		fo:SetFont(file, d[1], "")
		local c = S.C[d[2]]
		fo:SetTextColor(c[1], c[2], c[3])
		fo:SetShadowOffset(1, -1)
		fo:SetShadowColor(0, 0, 0, 0.9)
	end
end

-- "Learned while you play" mark: a small book. / Marca de "aprendido mientras juegas": un librito.
S.LEARNED = "|TInterface\\Icons\\INV_Misc_Book_09:12:12:0:0:64:64:6:58:6:58|t"

function S.SetColor(region, color)
	region:SetTextColor(color[1], color[2], color[3])
end

-- Wraps text in the muted color. / Envuelve un texto en el color atenuado.
function S.Muted(text)
	return "|cff" .. S.HEX.muted .. text .. "|r"
end

function S.QualityColor(quality)
	local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
	if c then return c.r, c.g, c.b end
	return S.C.text[1], S.C.text[2], S.C.text[3]
end

---------------------------------------------------------------------------
-- Widgets / Elementos
---------------------------------------------------------------------------
function S.Fill(frame, color, layer)
	local t = frame:CreateTexture(nil, layer or "BACKGROUND")
	t:SetAllPoints()
	t:SetColorTexture(unpack(color))
	return t
end

-- 1 px border made of four textures. / Borde de 1 px con cuatro texturas.
function S.Border(frame, color)
	local function edge()
		local t = frame:CreateTexture(nil, "BORDER")
		t:SetColorTexture(unpack(color))
		return t
	end
	local top, bottom, left, right = edge(), edge(), edge(), edge()
	top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
	bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
	left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
	right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)
end

-- Horizontal divider under an anchor. / Divisor horizontal debajo de un ancla.
function S.HLine(parent, anchor, yOff)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(unpack(S.C.divider))
	t:SetHeight(1)
	t:SetPoint("TOPLEFT", anchor or parent, "BOTTOMLEFT", 0, yOff or 0)
	t:SetPoint("TOPRIGHT", anchor or parent, "BOTTOMRIGHT", 0, yOff or 0)
	return t
end

-- Divider along the top edge of a frame. / Divisor en el borde superior de un marco.
function S.TopLine(frame)
	local t = frame:CreateTexture(nil, "ARTWORK")
	t:SetColorTexture(unpack(S.C.divider))
	t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
	return t
end

function S.Text(parent, font, color, justify)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "ItemLensFontNormal")
	if color then S.SetColor(fs, color) end
	fs:SetJustifyH(justify or "LEFT")
	fs:SetWordWrap(false)
	return fs
end

-- Icon with a dark frame. / Ícono con marco oscuro.
function S.Icon(parent, size)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(size, size)
	S.Fill(holder, S.C.iconBg)
	S.Border(holder, S.C.border)
	local tex = holder:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", 1, -1)
	tex:SetPoint("BOTTOMRIGHT", -1, 1)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	holder.tex = tex
	return holder
end

-- Expansion tag. / Etiqueta de expansión.
function S.Chip(parent)
	local chip = CreateFrame("Frame", nil, parent)
	chip:SetHeight(18)
	chip.bg = chip:CreateTexture(nil, "BACKGROUND")
	chip.bg:SetAllPoints()
	chip.text = S.Text(chip, "ItemLensFontSmall")
	chip.text:SetPoint("CENTER")
	function chip:SetExpansion(exp, long)
		local c = S.EXP[exp] or S.EXP_OTHER
		local label = long and IL.Data:ExpansionName(exp) or IL.Data:ExpansionShort(exp)
		if not label then self:Hide() return end
		self.bg:SetColorTexture(c[1], c[2], c[3], 0.14)
		S.SetColor(self.text, c)
		self.text:SetText(label)
		self:SetWidth(self.text:GetStringWidth() + 14)
		self:Show()
	end
	return chip
end

-- Favorite star (native atlas). / Estrella de favorito (atlas nativo).
function S.Star(parent, size)
	local t = parent:CreateTexture(nil, "OVERLAY")
	t:SetSize(size, size)
	t:SetAtlas("PetJournal-FavoritesIcon")
	return t
end

function S.SetStar(tex, on)
	tex:SetDesaturated(not on)
	tex:SetAlpha(on and 1 or 0.45)
end

-- Flat button with a centered label. / Botón plano con texto centrado.
function S.FlatButton(parent, w, h)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = S.Fill(b, S.C.panelDeep)
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints()
	b.hl:SetColorTexture(1, 1, 1, 0.04)
	b.text = S.Text(b, "ItemLensFontNormal")
	b.text:SetPoint("CENTER")
	return b
end

-- Label of a header row ("Expansion", "Zone"…): light blue, bold.
-- Etiqueta de un renglón del encabezado ("Expansión", "Zona"…): azul claro, gruesa.
function S.Label(parent)
	local fs = S.Text(parent, "ItemLensFontSmall", S.C.title)
	fs:SetWidth(100)
	return fs
end

-- Section title in a detail list: light blue with a thin line under it. Call on a row that has
-- `left` and a `line` texture (see S.SectionLine).
-- Título de sección en una lista de detalle: azul claro con una línea fina debajo. Se usa en
-- una fila que tiene `left` y una textura `line` (ver S.SectionLine).
function S.SectionLine(row)
	local t = row:CreateTexture(nil, "ARTWORK")
	t:SetHeight(1)
	t:SetColorTexture(S.C.title[1], S.C.title[2], S.C.title[3], 0.25)
	t:Hide()
	return t
end

function S.SectionTitle(row, text)
	row.left:SetFontObject("ItemLensFontNormal")
	S.SetColor(row.left, S.C.title)
	row.left:SetPoint("BOTTOMLEFT", 2, 8)
	row.left:SetText(text)
	row.left:Show()
	row.line:ClearAllPoints()
	row.line:SetPoint("BOTTOMLEFT", 2, 3)
	row.line:SetPoint("BOTTOMRIGHT", -2, 3)
	row.line:Show()
end

---------------------------------------------------------------------------
-- Faction (D-59) / Facción (D-59)
---------------------------------------------------------------------------
-- 1 Horde, 2 Alliance. Crests are the game's own faction icons.
-- 1 Horda, 2 Alianza. Los escudos son los íconos de facción del juego.
S.FACTION_ICON = { [1] = "Interface\\FriendsFrame\\PlusManz-Horde", [2] = "Interface\\FriendsFrame\\PlusManz-Alliance" }

function S.FactionColor(f)
	return (f == 1 and S.C.horde) or (f == 2 and S.C.alliance) or nil
end

-- Inline crest for a text ("|T…|t"). / Escudo dentro de un texto.
function S.FactionCrest(f, size)
	local path = S.FACTION_ICON[f]
	if not path then return "" end
	size = size or 14
	return ("|T%s:%d:%d|t"):format(path, size, size)
end

-- "Horde" / "Alliance" / "Horde and Alliance" with crests and color. / Con escudos y color.
function S.FactionText(f, L)
	if f == 1 then return S.FactionCrest(1) .. " |cff" .. S.HEX.horde .. L.FACTION_HORDE .. "|r" end
	if f == 2 then return S.FactionCrest(2) .. " |cff" .. S.HEX.alliance .. L.FACTION_ALLIANCE .. "|r" end
	return S.FactionCrest(1) .. S.FactionCrest(2) .. " |cff" .. S.HEX.mono .. L.FACTION_BOTH .. "|r"
end

-- Faction glow for a list row: a solid bar on the left, a soft glow fading to the right, a thin
-- border and a crest on the icon corner. glow:Set(nil) hides it.
-- Resplandor de facción para una fila: barra sólida a la izquierda, resplandor suave que se
-- desvanece hacia la derecha, borde fino y escudo en la esquina del ícono. glow:Set(nil) lo oculta.
function S.FactionGlow(row, icon)
	local g = { parts = {} }
	local function tex(layer, sub)
		local t = row:CreateTexture(nil, layer, nil, sub)
		g.parts[#g.parts + 1] = t
		t:Hide()
		return t
	end
	g.fade = tex("BACKGROUND", 2)
	g.fade:SetPoint("TOPLEFT"); g.fade:SetPoint("BOTTOMLEFT")
	g.fade:SetPoint("RIGHT", row, "CENTER", 20, 0)
	g.fade:SetColorTexture(1, 1, 1, 1)
	g.bar = tex("ARTWORK", 2)
	g.bar:SetPoint("TOPLEFT"); g.bar:SetPoint("BOTTOMLEFT"); g.bar:SetWidth(3)
	g.top, g.bottom, g.right = tex("BORDER", 2), tex("BORDER", 2), tex("BORDER", 2)
	g.top:SetPoint("TOPLEFT"); g.top:SetPoint("TOPRIGHT"); g.top:SetHeight(1)
	g.bottom:SetPoint("BOTTOMLEFT"); g.bottom:SetPoint("BOTTOMRIGHT"); g.bottom:SetHeight(1)
	g.right:SetPoint("TOPRIGHT"); g.right:SetPoint("BOTTOMRIGHT"); g.right:SetWidth(1)
	if icon then
		g.crest = icon:CreateTexture(nil, "OVERLAY", nil, 7)
		g.crest:SetSize(15, 15)
		g.crest:SetPoint("TOPLEFT", -4, 4)
		g.crest:Hide()
		g.parts[#g.parts + 1] = g.crest
	end
	function g:Set(f)
		local c = S.FactionColor(f)
		for _, t in ipairs(self.parts) do t:SetShown(c ~= nil) end
		if not c then return end
		local r, gg, b = c[1], c[2], c[3]
		if self.fade.SetGradient and CreateColor then
			self.fade:SetGradient("HORIZONTAL", CreateColor(r, gg, b, 0.24), CreateColor(r, gg, b, 0))
		else
			self.fade:SetColorTexture(r, gg, b, 0.10)
		end
		self.bar:SetColorTexture(r, gg, b, 0.95)
		for _, e in ipairs({ self.top, self.bottom, self.right }) do e:SetColorTexture(r, gg, b, 0.45) end
		if self.crest then self.crest:SetTexture(S.FACTION_ICON[f]) end
	end
	return g
end

-- Faction badge for a detail header: crest(s) and "Horde" / "Alliance" / "Horde and Alliance"
-- on a tinted plate with a border of the faction color.
-- Insignia de facción para el encabezado del detalle: escudo(s) y "Horda" / "Alianza" /
-- "Horda y Alianza" sobre una placa teñida con borde del color de la facción.
function S.FactionBadge(parent)
	local b = CreateFrame("Frame", nil, parent)
	b:SetHeight(30)
	b:EnableMouse(true) -- the name shows on hover / el nombre se ve al pasar el mouse
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.edges = {}
	for i = 1, 4 do b.edges[i] = b:CreateTexture(nil, "BORDER") end
	local e = b.edges
	e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
	e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
	e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
	e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)
	b.crest1 = b:CreateTexture(nil, "ARTWORK")
	b.crest1:SetSize(22, 22)
	b.crest1:SetPoint("LEFT", 6, 0)
	b.crest2 = b:CreateTexture(nil, "ARTWORK")
	b.crest2:SetSize(22, 22)
	b.crest2:SetPoint("LEFT", b.crest1, "RIGHT", 2, 0)
	b:SetScript("OnEnter", function(self) if self.tip then S.SimpleTooltip(self, self.tip, "ANCHOR_LEFT") end end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	-- Crests only (D-61): one for a single faction, both for "Horde and Alliance".
	-- Solo escudos (D-61): uno si es de una facción, los dos si es de ambas.
	function b:Set(f, L)
		local c = S.FactionColor(f) or S.C.mono
		self.bg:SetColorTexture(c[1], c[2], c[3], f and 0.16 or 0.07)
		for _, t in ipairs(self.edges) do t:SetColorTexture(c[1], c[2], c[3], f and 0.7 or 0.3) end
		self.crest1:SetTexture(S.FACTION_ICON[f or 1])
		self.crest2:SetTexture(S.FACTION_ICON[2])
		self.crest2:SetShown(f == nil)
		self.tip = (f == 1 and L.FACTION_HORDE) or (f == 2 and L.FACTION_ALLIANCE) or L.FACTION_BOTH
		self:SetWidth(f and 34 or 58)
	end
	return b
end

-- 2 px colored frame around a big icon. / Marco de color de 2 px alrededor de un ícono grande.
function S.FactionFrame(frame)
	local g = { edges = {} }
	for i = 1, 4 do
		local t = frame:CreateTexture(nil, "OVERLAY", nil, 6)
		t:Hide()
		g.edges[i] = t
	end
	local e = g.edges
	e[1]:SetPoint("TOPLEFT", -2, 2); e[1]:SetPoint("TOPRIGHT", 2, 2); e[1]:SetHeight(2)
	e[2]:SetPoint("BOTTOMLEFT", -2, -2); e[2]:SetPoint("BOTTOMRIGHT", 2, -2); e[2]:SetHeight(2)
	e[3]:SetPoint("TOPLEFT", -2, 2); e[3]:SetPoint("BOTTOMLEFT", -2, -2); e[3]:SetWidth(2)
	e[4]:SetPoint("TOPRIGHT", 2, 2); e[4]:SetPoint("BOTTOMRIGHT", 2, -2); e[4]:SetWidth(2)
	function g:Set(f)
		local c = S.FactionColor(f)
		for _, t in ipairs(self.edges) do
			t:SetShown(c ~= nil)
			if c then t:SetColorTexture(c[1], c[2], c[3], 0.9) end
		end
	end
	return g
end

-- Item tooltips from inside ItemLens (D-65): the tooltip goes OUTSIDE the window, always to the
-- right (past the Bank panel, if open), from the window's top-right corner; its "Equipped"
-- comparisons go further right (Modules/Tooltip.lua). Nothing covers the window or the row.
-- Tooltips de objetos desde ItemLens (D-65): el tooltip sale POR FUERA de la ventana, siempre a la
-- derecha (después del panel del Banco, si está abierto), desde la esquina superior derecha; sus
-- comparaciones de "Equipado" van más a la derecha (Modules/Tooltip.lua). Nada tapa la ventana
-- ni la fila.
function S.OutsideTooltip(owner)
	local ui = IL.UI
	if not (ui and ui:IsShown() and ui:GetLeft() and owner and owner:GetTop()) then
		GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
		return
	end
	local us = ui:GetEffectiveScale()
	local r, top = ui:GetRight() * us, ui:GetTop() * us
	local bp = ui.bankPanel
	if bp and bp:IsShown() and bp:GetRight() then
		local bs = bp:GetEffectiveScale()
		r, top = math.max(r, bp:GetRight() * bs), math.max(top, bp:GetTop() * bs)
	end
	GameTooltip:SetOwner(owner, "ANCHOR_NONE")
	GameTooltip:ClearAllPoints()
	GameTooltip.ilOwner = owner -- comparisons to the right too / comparaciones también a la derecha
	local ts = GameTooltip:GetEffectiveScale()
	GameTooltip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (r + 6) / ts, top / ts)
end

-- Standard tooltip with wrapped white text. / Tooltip estándar con texto blanco ajustado.
function S.SimpleTooltip(owner, text, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
	GameTooltip:SetText(text, 1, 1, 1, 1, true)
	GameTooltip:Show()
end
