--[[
	ItemLens · UI/Options.lua
	Options panel (D-60): window size slider, tooltip, Shift+click and learning switches, and
	re-centering the window. It opens over the window (gear button or /il options) and is also
	listed in the game's Options › AddOns.
	Panel de opciones (D-60): deslizador del tamaño de la ventana, interruptores de tooltip,
	Mayús+clic y aprendizaje, y volver a centrar la ventana. Se abre sobre la ventana (botón del
	engrane o /il opciones) y también aparece en Opciones › Accesorios del juego.
	© 2026 iAthVo_Kr · MIT License
]]

local _, IL = ...
local L, S = IL.L, IL.Style
local C = S.C

local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.8, 1.5, 0.05
local ROW_GAP = 14

-- Window size slider: the value is shown as a percentage; the size changes when you let go,
-- so the slider does not move under the mouse while dragging.
-- Deslizador del tamaño: el valor se muestra en porcentaje; el tamaño cambia al soltar, para
-- que el deslizador no se mueva bajo el mouse mientras lo arrastras.
local function buildSlider(parent, f)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(420, 46)
	holder.label = S.Text(holder, "ItemLensFontNormal", C.text)
	holder.label:SetPoint("TOPLEFT")
	holder.label:SetText(L.OPT_SCALE)
	holder.value = S.Text(holder, "ItemLensFontNumber", C.brass, "RIGHT")
	holder.value:SetPoint("TOPRIGHT")

	local sl = CreateFrame("Slider", nil, holder)
	sl:SetOrientation("HORIZONTAL")
	sl:SetPoint("BOTTOMLEFT", 0, 4)
	sl:SetPoint("BOTTOMRIGHT", 0, 4)
	sl:SetHeight(16)
	sl:SetMinMaxValues(SCALE_MIN, SCALE_MAX)
	sl:SetValueStep(SCALE_STEP)
	sl:SetObeyStepOnDrag(true)
	sl:EnableMouseWheel(true)
	local track = sl:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT"); track:SetPoint("RIGHT"); track:SetHeight(4)
	track:SetColorTexture(C.border[1], C.border[2], C.border[3])
	sl.fill = sl:CreateTexture(nil, "BORDER")
	sl.fill:SetPoint("LEFT"); sl.fill:SetHeight(4)
	sl.fill:SetColorTexture(C.title[1], C.title[2], C.title[3], 0.8)
	sl:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
	local thumb = sl:GetThumbTexture()
	if thumb then thumb:SetSize(32, 32) end

	local function show(v)
		holder.value:SetText(("%d %%"):format(math.floor(v * 100 + 0.5)))
		local w = sl:GetWidth()
		sl.fill:SetWidth(math.max(1, w * (v - SCALE_MIN) / (SCALE_MAX - SCALE_MIN)))
	end
	local function apply()
		ItemLensDB.options.scale = math.floor(sl:GetValue() / SCALE_STEP + 0.5) * SCALE_STEP
		f:ApplyScale()
	end
	sl:SetScript("OnValueChanged", function(_, v) show(v) end)
	sl:SetScript("OnMouseUp", apply)
	sl:SetScript("OnMouseWheel", function(self, delta)
		self:SetValue(math.max(SCALE_MIN, math.min(SCALE_MAX, self:GetValue() + delta * SCALE_STEP)))
		apply()
	end)
	holder.slider = sl
	function holder:Refresh()
		local v = tonumber(ItemLensDB.options.scale) or 1
		sl:SetValue(v)
		show(v)
	end
	return holder
end

-- Switch for a boolean option. / Interruptor de una opción de sí/no.
local function buildCheck(parent, option, label, tip)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(26, 26)
	cb.label = S.Text(cb, "ItemLensFontNormal", C.text)
	cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	cb.label:SetText(label)
	cb:SetHitRectInsets(0, -(cb.label:GetStringWidth() + 8), 0, 0)
	cb:SetScript("OnClick", function(self)
		ItemLensDB.options[option] = self:GetChecked() and true or false
		IL:RequestRefresh()
	end)
	if tip then
		cb:SetScript("OnEnter", function(self) S.SimpleTooltip(self, tip) end)
		cb:SetScript("OnLeave", GameTooltip_Hide)
	end
	function cb:Refresh() self:SetChecked(ItemLensDB.options[option] ~= false) end
	return cb
end

local function section(parent, text, anchor, gap)
	local t = S.Text(parent, "ItemLensFontNormal", C.title)
	if anchor then t:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -(gap or 22)) else t:SetPoint("TOPLEFT", 28, -24) end
	t:SetText(text)
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetHeight(1)
	line:SetColorTexture(C.title[1], C.title[2], C.title[3], 0.25)
	line:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
	line:SetPoint("RIGHT", parent, "RIGHT", -28, 0)
	return line
end

function IL.CreateOptions(f)
	local p = CreateFrame("Frame", nil, f)
	p:SetPoint("TOPLEFT", 1, -45)   -- below the title bar / debajo de la barra de título
	p:SetPoint("BOTTOMRIGHT", -1, 1)
	p:SetFrameLevel(f:GetFrameLevel() + 40)
	p:EnableMouse(true)             -- blocks clicks to the list behind / bloquea clics a la lista
	S.Fill(p, C.panel)
	p:Hide()

	local title = S.Text(p, "ItemLensFontTitle", C.brass)
	title:SetPoint("TOPLEFT", 28, -22)
	title:SetText(L.OPTIONS_TITLE)

	local done = S.FlatButton(p, 110, 28)
	done:SetPoint("TOPRIGHT", -24, -16)
	S.Border(done, C.border)
	done.text:SetText(L.OPT_DONE)
	S.SetColor(done.text, C.brass)
	done:SetScript("OnClick", function() p:Hide() end)

	-- Window / Ventana
	local l1 = section(p, L.OPT_SECTION_WINDOW, title, 26)
	local slider = buildSlider(p, f)
	slider:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -ROW_GAP)
	local center = S.FlatButton(p, 150, 26)
	center:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -ROW_GAP)
	S.Border(center, C.border)
	center.text:SetText(L.OPT_CENTER)
	center:SetWidth(center.text:GetStringWidth() + 24)
	center:SetScript("OnClick", function()
		ItemLensDB.window = nil
		f:RestorePosition()
	end)
	local scaleTip = S.Text(p, "ItemLensFontSmallMuted", C.muted)
	scaleTip:SetPoint("LEFT", center, "RIGHT", 14, 0)
	scaleTip:SetText(L.OPT_SCALE_TIP)

	-- Tooltip
	local l2 = section(p, L.OPT_SECTION_TOOLTIP, center)
	local c1 = buildCheck(p, "tooltip", L.OPT_TOOLTIP, L.OPT_TOOLTIP_TIP)
	c1:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", -4, -10)
	local c2 = buildCheck(p, "ownersTooltip", L.OPT_OWNERS, L.OPT_OWNERS_TIP)
	c2:SetPoint("TOPLEFT", c1, "BOTTOMLEFT", 0, -4)
	local c5 = buildCheck(p, "compareStack", L.OPT_COMPARE, L.OPT_COMPARE_TIP)
	c5:SetPoint("TOPLEFT", c2, "BOTTOMLEFT", 0, -4)

	-- General
	local l3 = section(p, L.OPT_SECTION_GENERAL, c5, 18)
	local c3 = buildCheck(p, "bagClick", L.OPT_CLICK, L.OPT_CLICK_TIP)
	c3:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", -4, -10)
	local c4 = buildCheck(p, "learn", L.OPT_LEARN, L.OPT_LEARN_TIP)
	c4:SetPoint("TOPLEFT", c3, "BOTTOMLEFT", 0, -4)

	local foot = S.Text(p, "ItemLensFontSmallMuted", C.muted)
	foot:SetPoint("BOTTOMLEFT", 28, 18)
	foot:SetText(L.OPT_FOOTER:format(IL.VERSION, IL.BUILD))

	local controls = { slider, c1, c2, c5, c3, c4 }
	function p:Refresh() for _, c in ipairs(controls) do c:Refresh() end end
	return p
end

-- Entry in the game's Options › AddOns: a short text and a button that opens the panel.
-- Entrada en Opciones › Accesorios del juego: un texto corto y un botón que abre el panel.
function IL.RegisterGameOptions()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local canvas = CreateFrame("Frame")
	local t = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	t:SetPoint("TOPLEFT", 16, -16)
	t:SetText(L.TITLE)
	local d = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -10)
	d:SetText(L.OPT_GAME_TEXT)
	local b = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
	b:SetSize(200, 26)
	b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -14)
	b:SetText(L.OPTIONS_TITLE)
	b:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		if IL.UI then
			IL.UI:Show()
			IL.UI:ToggleOptions(true)
		end
	end)
	pcall(function()
		local category = Settings.RegisterCanvasLayoutCategory(canvas, L.TITLE)
		Settings.RegisterAddOnCategory(category)
	end)
end
