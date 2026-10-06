--[[
	ItemLens · Core/Init.lua
	Saved variables, migrations, favorites, dressing room, window access and start-up.
	Variables guardadas, migraciones, favoritos, probador, acceso a la ventana y arranque.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local ADDON, IL = ...
local L = IL.L

-- Two version numbers: the public one follows the game patch (12.1.0.1 = patch 12.1.0, first
-- release for it); the internal build is X.Y.Z (big · cosmetic/config · minor).
-- Dos números de versión: el público sigue el parche del juego (12.1.0.1 = parche 12.1.0, primera
-- entrega para él); la build interna es X.Y.Z (grande · estético/configuración · menor).
IL.VERSION = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
IL.BUILD = C_AddOns.GetAddOnMetadata(ADDON, "X-Build") or "?"

---------------------------------------------------------------------------
-- Saved variables / Variables guardadas
---------------------------------------------------------------------------
local SCHEMA_VERSION = 1

local DEFAULTS = {
	schemaVersion = SCHEMA_VERSION,
	favorites = {},  -- [key] = true
	npcNames  = {},  -- NPC name cache (speed only) / caché de nombres de NPC (solo acelera)
	window    = nil, -- { point, relPoint, x, y }
	bank      = {},  -- ["Name-Realm"] = { t, items = { [key] = count } }
	warband   = nil, -- { t, items = { [key] = count } }
	chars     = {},  -- ["Name-Realm"] = { class, t, bags, equipped, currencies, classQuests }
	names     = {},  -- [itemID] = name, for the current namesLocale / para el idioma de namesLocale
	learned   = nil, -- see Modules/Learn.lua / ver Modules/Learn.lua
	options = {
		tooltip       = true,  -- favorites block in tooltips / bloque de favoritos en el tooltip
		ownersTooltip = true,  -- characters in tooltips / personajes en el tooltip
		bagClick      = true,  -- Shift+click opens ItemLens / Mayús+clic abre ItemLens
		bankPanel     = false,
		learn         = true,
		coll = { set = "mm", exp = "all", class = "all", state = "all", rewardOnly = false },
	},
}

local function applyDefaults(dst, src)
	for k, v in pairs(src) do
		if dst[k] == nil then
			dst[k] = type(v) == "table" and CopyTable(v) or v
		elseif type(v) == "table" and type(dst[k]) == "table" then
			applyDefaults(dst[k], v)
		end
	end
end

-- Upgrades data saved by older versions. / Actualiza datos guardados por versiones anteriores.
local function migrate(db)
	-- "altClick" was renamed to "bagClick". / "altClick" ahora se llama "bagClick".
	if db.options and db.options.altClick ~= nil then
		db.options.bagClick = db.options.altClick
		db.options.altClick = nil
	end
	-- Auction prices were removed. / Se quitaron los precios de subasta.
	db.ah = nil
	-- Entries saved while the realm was still empty ("Name-"). / Entradas guardadas con el reino vacío.
	for _, t in ipairs({ db.chars or {}, db.bank or {} }) do
		for k in pairs(t) do
			if type(k) == "string" and k:sub(-1) == "-" then t[k] = nil end
		end
	end
end

---------------------------------------------------------------------------
-- Favorites / Favoritos
---------------------------------------------------------------------------
function IL:IsFavorite(key) return ItemLensDB.favorites[key] == true end

function IL:ToggleFavorite(key)
	ItemLensDB.favorites[key] = not ItemLensDB.favorites[key] or nil
	self:RequestRefresh()
end

function IL:GetFavorites()
	local list = {}
	for key in pairs(ItemLensDB.favorites) do list[#list + 1] = key end
	return list
end

---------------------------------------------------------------------------
-- Dressing room / Probador
---------------------------------------------------------------------------
-- Gear, weapons, mounts and pets can be previewed. / Equipo, armas, monturas y mascotas.
function IL:CanDressUp(key)
	local kind, id = IL.SplitKey(key)
	if kind ~= "i" then return false end
	if C_Item.IsDressableItemByID and C_Item.IsDressableItemByID(id) then return true end
	if C_MountJournal and C_MountJournal.GetMountFromItem and C_MountJournal.GetMountFromItem(id) then return true end
	if C_PetJournal and C_PetJournal.GetPetInfoByItemID and C_PetJournal.GetPetInfoByItemID(id) then return true end
	return false
end

-- Opens Blizzard's dressing room. Returns true when it opened.
-- Abre el probador de Blizzard. Devuelve true si se abrió.
function IL:DressUp(key)
	local link = IL.Data:GetLink(key)
	if not link then
		local _, id = IL.SplitKey(key)
		link = "item:" .. id -- the dressing room also accepts a bare link / también acepta el link básico
	end
	if DressUpLink then return DressUpLink(link) and true or false end
	if DressUpItemLink then return DressUpItemLink(link) and true or false end
	return false
end

-- For click handlers: Ctrl+click (WoW's dress-up modifier) opens the dressing room.
-- Para los clics: Ctrl+clic (el modificador de probador de WoW) abre el probador.
function IL:HandleDressUpClick(key)
	if key and IsModifiedClick("DRESSUP") then
		IL:DressUp(key)
		return true
	end
	return false
end

---------------------------------------------------------------------------
-- Window access / Acceso a la ventana
---------------------------------------------------------------------------
-- Batches many asynchronous loads into a single redraw.
-- Agrupa muchas cargas asíncronas en un solo redibujado.
local refreshPending = false
function IL:RequestRefresh()
	if refreshPending then return end
	refreshPending = true
	C_Timer.After(0.15, function()
		refreshPending = false
		if IL.UI and IL.UI:IsShown() then IL.UI:Refresh() end
	end)
end

function IL:Toggle()
	if not IL.UI then return end
	IL.UI:SetShown(not IL.UI:IsShown())
end

function IL:OpenTo(key)
	if not IL.UI then return end
	IL.UI:Show()
	IL.UI:Select(key)
end

-- Key binding (Bindings.xml) and the minimap Addon Compartment.
-- Atajo de teclado (Bindings.xml) y el compartimento de accesorios del minimapa.
function ItemLens_Toggle() IL:Toggle() end
BINDING_HEADER_ITEMLENS = L.TITLE
BINDING_NAME_ITEMLENS_TOGGLE = L.BINDING_TOGGLE

function ItemLens_OnAddonCompartmentClick() IL:Toggle() end
function ItemLens_OnAddonCompartmentEnter(_, button)
	GameTooltip:SetOwner(button, "ANCHOR_LEFT")
	GameTooltip:SetText(L.TITLE .. " " .. IL.VERSION)
	GameTooltip:AddLine(L.COMPARTMENT_TIP, 1, 1, 1)
	GameTooltip:Show()
end
function ItemLens_OnAddonCompartmentLeave() GameTooltip:Hide() end

---------------------------------------------------------------------------
-- Shift+click on items anywhere / Mayús+clic en objetos de cualquier lugar
---------------------------------------------------------------------------
-- Works like WoW, depending on where the text cursor is:
--   · in the ItemLens search box → types the name there and opens the item
--   · in another text box (chat, auction house…) → WoW links it there; ItemLens stays out
--   · no text box focused → opens ItemLens on that item
-- Funciona como WoW, según dónde esté el cursor de texto:
--   · en el buscador de ItemLens → escribe el nombre ahí y abre el objeto
--   · en otro campo (chat, subastas…) → WoW lo enlaza ahí; ItemLens no interviene
--   · sin cursor en ningún campo → abre ItemLens en ese objeto
local function hookItemClicks()
	hooksecurefunc("HandleModifiedItemClick", function(link)
		if type(link) ~= "string" or not IsModifiedClick("CHATLINK") then return end
		local itemID = link:match("|Hitem:(%d+)")
		if not itemID then return end
		local key = "i" .. itemID

		local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
		local search = IL.UI and IL.UI.search
		if focus and search and focus == search then
			local name = link:match("|h%[(.-)%]|h") or IL.Data:GetDisplayName(key)
			name = strtrim((name:gsub("|A.-|a", ""))) -- drop the crafting-quality icon / sin ícono de calidad
			search:SetText(name)
			search:SetCursorPosition(#name)
			IL.UI:Select(key)
		elseif not focus and ItemLensDB.options.bagClick then
			IL:OpenTo(key)
		end
	end)
end

---------------------------------------------------------------------------
-- Start-up / Arranque
---------------------------------------------------------------------------
IL.OnEvents({ "ADDON_LOADED", "PLAYER_LOGIN" }, function(event, addon)
	if event == "ADDON_LOADED" and addon == ADDON then
		ItemLensDB = ItemLensDB or {}
		migrate(ItemLensDB)
		applyDefaults(ItemLensDB, DEFAULTS)
		ItemLensDB.schemaVersion = SCHEMA_VERSION
	elseif event == "PLAYER_LOGIN" then
		IL.Data:Init()
		IL.Learn:Init()
		IL.Scanner:Init()
		IL.Bank:Init()
		IL.Chars:Init()
		IL.Coll:Init()
		IL.UI = IL.CreateMainFrame()
		IL.Tooltip:Init()
		hookItemClicks()
	end
end)
