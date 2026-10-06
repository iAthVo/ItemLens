--[[
	ItemLens · UI/Style.lua
	The "Obsidian & Brass" look: color tokens, expansion colors and small widget builders.
	Uses the game's native fonts only.
	El estilo "Obsidiana y latón": colores, colores de expansión y constructores de elementos.
	Usa solo las fuentes nativas del juego.
	© 2026 TavoD_Gus_KrG · MIT License
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
	panel     = rgb("111217", 0.97),
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
	muted     = rgb("8A857B"),
	mono      = rgb("B9B3A6"),
}
S.HEX = { brass = "c8a765", muted = "8a857b", text = "ece7dc", mono = "b9b3a6" }

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
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
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
	chip.text = S.Text(chip, "GameFontNormalSmall")
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
	b.text = S.Text(b, "GameFontHighlight")
	b.text:SetPoint("CENTER")
	return b
end

-- Standard tooltip with wrapped white text. / Tooltip estándar con texto blanco ajustado.
function S.SimpleTooltip(owner, text, anchor)
	GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
	GameTooltip:SetText(text, 1, 1, 1, 1, true)
	GameTooltip:Show()
end
