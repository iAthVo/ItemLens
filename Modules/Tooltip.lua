--[[
	ItemLens · Modules/Tooltip.lua
	Blocks added to the game tooltip:
	  1. Who has it: on ANY item or currency, which characters own it and how many (/il characters).
	  2. Favorites: what it is for and where to get it, only for favorite items (/il tooltip).
  3. Comparisons: two equipped pieces shown in a column instead of side by side (D-64).
	Bloques que se agregan al tooltip del juego:
	  1. Lo tienen: en CUALQUIER objeto o moneda, qué personajes lo tienen y cuántos (/il personajes).
	  2. Favoritos: para qué sirve y dónde se obtiene, solo en favoritos (/il tooltip).
  3. Comparaciones: dos piezas equipadas en columna en vez de lado a lado (D-64).
	© 2026 iAthVo_Kr · MIT License
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
	addOwners(tooltip, key)
	addFavorite(tooltip, key)
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

---------------------------------------------------------------------------
-- 3. Comparisons in a column (D-64) / Comparaciones en columna (D-64)
---------------------------------------------------------------------------
-- When an item is compared with TWO equipped pieces (two rings, two trinkets, main hand and
-- off hand), the game puts both "Equipped" tooltips side by side. Here the second one goes
-- below the first, on the same side. If it does not fit down to the bottom of the screen they
-- stay side by side. Only the anchor of the second tooltip changes; nothing is drawn.
-- Cuando un objeto se compara con DOS piezas equipadas (dos anillos, dos abalorios, mano
-- derecha e izquierda), el juego pone los dos tooltips de "Equipado" lado a lado. Aquí el
-- segundo va abajo del primero, del mismo lado. Si no cabe hasta abajo de la pantalla se
-- quedan lado a lado. Solo cambia el ancla del segundo tooltip; no se dibuja nada.
local GAP = 25 -- room for the "Equipped" tab of the lower one / espacio para la pestaña "Equipado" del de abajo

-- In a column both "Equipped" tooltips take the width of the wider one. The width is measured
-- ONCE per comparison (same three items) and kept: the game re-anchors the comparisons many
-- times while the mouse is still, and measuring each time made the width go back and forth.
-- It is released when the main tooltip hides or the compared items change.
-- En columna, los dos tooltips de "Equipado" toman el ancho del más ancho. El ancho se mide UNA
-- vez por comparación (los mismos tres objetos) y se conserva: el juego vuelve a acomodar las
-- comparaciones muchas veces con el mouse quieto, y medir cada vez hacía que el ancho fuera y
-- viniera. Se suelta al esconderse el tooltip principal o al cambiar los objetos comparados.
local function setMin(t, w, relayout)
	if (t.ilMin or 0) == w then return end
	t:SetMinimumWidth(w)
	t.ilMin = w
	if relayout then t:Show() end
end

local function linkOf(t)
	if not t.GetItem then return "" end
	local _, link = t:GetItem()
	return link or ""
end

-- Releasing keeps the measurement: some windows (vendors) re-open the tooltip several times a
-- second, and measuring again each time made the width blink. / Soltar conserva la medida:
-- algunas ventanas (vendedores) reabren el tooltip varias veces por segundo, y volver a medir
-- cada vez hacía parpadear el ancho.
local function release(p, s)
	if p and p.SetMinimumWidth then setMin(p, 0, false) end
	if s and s.SetMinimumWidth then setMin(s, 0, false) end
end

local function measure(p, s)
	setMin(p, 0, true); setMin(s, 0, true) -- natural widths / anchos naturales
	local wp, ws = p:GetWidth() or 0, s:GetWidth() or 0
	if math.abs(wp - ws) < 1 then return false end
	local narrow, target = (wp < ws) and p or s, math.max(wp, ws)
	setMin(narrow, target, true)
	-- If the minimum does not count the borders, correct it once. / Si el mínimo no cuenta los bordes, se corrige una vez.
	local extra = (narrow:GetWidth() or target) - target
	local value = target - (math.abs(extra) >= 1 and extra or 0)
	if value ~= target then setMin(narrow, value, true) end
	return { first = narrow == p, value = value }
end

local function equalize(main, p, s)
	if not (p.SetMinimumWidth and s.SetMinimumWidth) then return end
	local key = linkOf(main or p) .. "|" .. linkOf(p) .. "|" .. linkOf(s)
	if p.ilKey ~= key then
		p.ilKey = key
		p.ilFit = measure(p, s)
		return
	end
	-- Same items: re-apply the stored width only if it was lost (no new measuring).
	-- Mismos objetos: se vuelve a poner el ancho guardado solo si se perdió (sin medir otra vez).
	local fit = p.ilFit
	if not fit then return end
	local narrow = fit.first and p or s
	local other = fit.first and s or p
	if math.abs((narrow:GetWidth() or 0) - (other:GetWidth() or 0)) >= 1 then
		narrow:SetMinimumWidth(fit.value)
		narrow.ilMin = fit.value
		narrow:Show()
	end
end

local function stackPair(p, s)
	if not (ItemLensDB and ItemLensDB.options.compareStack ~= false) then return end
	if not (p and s and p:IsShown() and s:IsShown()) then return end
	local pl, pr, pb = p:GetLeft(), p:GetRight(), p:GetBottom()
	local sl, sr = s:GetLeft(), s:GetRight()
	if not (pl and pr and pb and sl and sr) then return end
	local side
	if sl >= pr - 1 then side = "right"      -- second one to the right / el segundo a la derecha
	elseif sr <= pl + 1 then side = "left"   -- second one to the left / el segundo a la izquierda
	else return end                          -- already stacked / ya está en columna
	equalize(nil, p, s)
	if pb - GAP - (s:GetHeight() or 0) < 0 then return end -- does not fit / no cabe
	s:ClearAllPoints()
	if side == "right" then
		s:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -GAP)
	else
		s:SetPoint("TOPRIGHT", p, "BOTTOMRIGHT", 0, -GAP)
	end
	s.ilStackSide = side
end

-- The height may change once the tooltip finishes filling (next frame): if it no longer fits,
-- it goes back beside the first one.
-- La altura puede cambiar cuando el tooltip termina de llenarse (siguiente cuadro): si ya no
-- cabe, regresa al lado del primero.
local function recheck(p, s)
	if not (p and s and s.ilStackSide and s:IsShown()) then return end
	local b = s:GetBottom()
	if b and b < 0 then
		s:ClearAllPoints()
		if s.ilStackSide == "right" then s:SetPoint("TOPLEFT", p, "TOPRIGHT")
		else s:SetPoint("TOPRIGHT", p, "TOPLEFT") end
	end
	s.ilStackSide = nil
end

-- Tooltips from inside ItemLens (D-65): the comparisons ALWAYS go to the right of the tooltip,
-- which is already outside the window, so nothing covers the window or the hovered row. The
-- second one goes below the first (column); if it does not fit, to its right.
-- Tooltips desde ItemLens (D-65): las comparaciones van SIEMPRE a la derecha del tooltip, que ya
-- está por fuera de la ventana; así nada tapa la ventana ni la fila del mouse. El segundo va
-- abajo del primero (columna); si no cabe, a su derecha.
-- If the column does not fit below, it moves up (never past the top of the screen); only if it
-- still does not fit does the second one go to the right of the first.
-- Si la columna no cabe hacia abajo, sube (nunca arriba de la pantalla); solo si aun así no cabe,
-- el segundo va a la derecha del primero.
local function forceRight(main, p, s)
	if not (p and p:IsShown()) then return end
	local two = s and s:IsShown()
	local column = two and ItemLensDB.options.compareStack ~= false
	local raise = 0
	if column then
		equalize(main, p, s)
		local ps = p:GetEffectiveScale()
		local mainTop = (main:GetTop() or 0) * main:GetEffectiveScale() / ps
		local screenTop = UIParent:GetHeight() * UIParent:GetEffectiveScale() / ps
		local need = (p:GetHeight() or 0) + GAP + (s:GetHeight() or 0)
		if need > mainTop then
			raise = math.min(need - mainTop, math.max(0, screenTop - mainTop))
			if need > mainTop + raise then column, raise = false, 0 end
		end
	end
	p:ClearAllPoints()
	p:SetPoint("TOPLEFT", main, "TOPRIGHT", 0, raise)
	if not two then return end
	s:ClearAllPoints()
	if column then
		s:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -GAP)
	else
		s:SetPoint("TOPLEFT", p, "TOPRIGHT", 0, 0)
	end
	s.ilStackSide = nil
end
Tooltip.ForceRight = forceRight -- exposed for tests / expuesto para las pruebas

local function fromItemLens(main)
	return main and main.ilOwner and main.GetOwner and main:GetOwner() == main.ilOwner
end

-- Some game windows (crafting orders) leave the comparison ON TOP of the main tooltip. If they
-- overlap, the comparison goes beside it: right if it fits, otherwise left.
-- Algunas ventanas del juego (pedidos de fabricación) dejan la comparación ENCIMA del tooltip
-- principal. Si se empalman, la comparación se pone a un lado: derecha si cabe, si no izquierda.
local function overlaps(a, b)
	local al, ar, at, ab = a:GetLeft(), a:GetRight(), a:GetTop(), a:GetBottom()
	local bl, br, bt, bb = b:GetLeft(), b:GetRight(), b:GetTop(), b:GetBottom()
	if not (al and ar and at and ab and bl and br and bt and bb) then return false end
	return al < br - 1 and ar > bl + 1 and ab < bt - 1 and at > bb + 1
end

-- After moving the first comparison, the second one (e.g. the off hand) must not end up hidden
-- under it or under the main tooltip: it goes below the first (column) or beside it.
-- Al mover la primera comparación, la segunda (p. ej. la mano izquierda) no debe quedar tapada
-- por ella ni por el tooltip principal: va abajo de la primera (columna) o a su lado.
local function placeSecond(main, p, s)
	if not (s and s:IsShown()) then return end
	if not (overlaps(p, s) or overlaps(main, s)) then return end
	local right = (p:GetLeft() or 0) >= (main:GetLeft() or 0) -- p went right of main / p quedó a la derecha
	s:ClearAllPoints()
	if ItemLensDB and ItemLensDB.options.compareStack ~= false then
		if right then s:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -GAP)
		else s:SetPoint("TOPRIGHT", p, "BOTTOMRIGHT", 0, -GAP) end
	else
		if right then s:SetPoint("TOPLEFT", p, "TOPRIGHT", 0, 0)
		else s:SetPoint("TOPRIGHT", p, "TOPLEFT", 0, 0) end
	end
end

local function unoverlap(main, p, s)
	if not (main and p and main:IsShown() and p:IsShown() and main.GetRight) then return end
	if not overlaps(main, p) then
		if s then placeSecond(main, p, s) end
		return
	end
	local screenW = UIParent:GetWidth() * UIParent:GetEffectiveScale() / p:GetEffectiveScale()
	local mr = main:GetRight() * main:GetEffectiveScale() / p:GetEffectiveScale()
	p:ClearAllPoints()
	if mr + (p:GetWidth() or 0) <= screenW then
		p:SetPoint("TOPLEFT", main, "TOPRIGHT", 0, 0)
	else
		p:SetPoint("TOPRIGHT", main, "TOPLEFT", 0, 0)
	end
	if s then placeSecond(main, p, s) end
end
Tooltip.Unoverlap = unoverlap -- exposed for tests / expuesto para las pruebas

local function arrange(main, p, s)
	if not ItemLensDB then return end
	if not fromItemLens(main) then unoverlap(main, p, s) end
	if not (s and s:IsShown()) then release(p, s) end -- a single comparison: natural width / una sola: ancho natural
	if fromItemLens(main) then forceRight(main, p, s) else stackPair(p, s) end
end

local function restack(main, p, s)
	arrange(main, p, s)
	if C_Timer and C_Timer.After then
		C_Timer.After(0, function()
			pcall(arrange, main, p, s)
			if not fromItemLens(main) then pcall(recheck, p, s) end
		end)
	end
end
Tooltip.StackPair = stackPair -- exposed for tests / expuesto para las pruebas

local function shoppingOf(tooltip)
	local list = tooltip and tooltip.shoppingTooltips
	if list then return tooltip, list[1], list[2] end
end

-- Safety net: crafting orders and some vendors place the comparison on top of the tooltip by a
-- path no anchoring hook sees, and vendors do it again on every refresh. While a comparison is
-- shown it checks EVERY frame (a few position reads) that it is not on top of its main tooltip;
-- it runs after the game's tooltip update, so the overlap is fixed before the frame is drawn.
-- Checking only 10 times a second made it blink at vendors.
-- Red de seguridad: los pedidos de fabricación y algunos vendedores ponen la comparación encima
-- del tooltip por un camino que ningún gancho de anclaje ve, y los vendedores lo repiten en cada
-- refresco. Mientras una comparación está visible revisa en CADA cuadro (unas cuantas lecturas
-- de posición) que no esté encima de su tooltip principal; corre después de la actualización del
-- tooltip del juego, así que el empalme se corrige antes de dibujar. Revisar solo 10 veces por
-- segundo lo hacía parpadear con los vendedores.
local function watchOverlap(self)
	local main = self.GetOwner and self:GetOwner()
	if not (main and main.GetRight and main.shoppingTooltips) or fromItemLens(main) then return end
	local list = main.shoppingTooltips
	if self ~= list[1] and self ~= list[2] then return end
	if overlaps(main, self) then
		if self == list[1] then
			unoverlap(main, self, list[2])
		elseif list[1] and list[1]:IsShown() then
			-- the second one goes below the first / el segundo va abajo del primero
			self:ClearAllPoints()
			self:SetPoint("TOPLEFT", list[1], "BOTTOMLEFT", 0, -GAP)
		end
	end
end

local function hookCompare()
	for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }) do
		local t = _G[name]
		if t and t.HookScript then t:HookScript("OnUpdate", function(self, e) pcall(watchOverlap, self, e) end) end
	end
	-- The widths are released when the MAIN tooltip hides. / Los anchos se sueltan al esconderse el tooltip PRINCIPAL.
	for _, main in ipairs({ GameTooltip, ItemRefTooltip }) do
		if main and main.HookScript then
			main:HookScript("OnHide", function(self)
				local list = self.shoppingTooltips
				if list then pcall(release, list[1], list[2]) end
			end)
		end
	end
	if TooltipComparisonManager and TooltipComparisonManager.AnchorShoppingTooltips then
		hooksecurefunc(TooltipComparisonManager, "AnchorShoppingTooltips", function(self)
			pcall(restack, shoppingOf(self.tooltip))
		end)
	end
	if GameTooltip_AnchorComparisonTooltips then -- older clients / clientes anteriores
		hooksecurefunc("GameTooltip_AnchorComparisonTooltips", function(tt, _, s1, s2) pcall(restack, tt, s1, s2) end)
	end
	if GameTooltip_ShowCompareItem then -- extra safety net / red de seguridad extra
		hooksecurefunc("GameTooltip_ShowCompareItem", function(tooltip)
			pcall(restack, shoppingOf(tooltip or GameTooltip))
		end)
	end
end

function Tooltip:Init()
	if hooksecurefunc then pcall(hookCompare) end
	if not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall then return end
	hook(Enum.TooltipDataType.Item, "i")
	if Enum.TooltipDataType.Currency then hook(Enum.TooltipDataType.Currency, "c") end
end
