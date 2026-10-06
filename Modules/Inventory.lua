--[[
	ItemLens · Modules/Inventory.lua
	What you carry: the Bags tab (IL.Scanner), bank copies (IL.Bank) and every character on the
	account (IL.Chars), which powers "Who has it" from any character.
	Lo que cargas: la pestaña Mochila (IL.Scanner), las copias del banco (IL.Bank) y todos los
	personajes de la cuenta (IL.Chars), que alimentan "Lo tienen" desde cualquier personaje.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...
local L = IL.L

---------------------------------------------------------------------------
-- Bags tab / Pestaña Mochila
---------------------------------------------------------------------------
local Scanner = {}
IL.Scanner = Scanner

local bagCache = { all = {}, byBag = {}, currencies = {} }
local bagDirty = true

function Scanner:Init()
	IL.OnEvents({ "BAG_UPDATE_DELAYED", "CURRENCY_DISPLAY_UPDATE" }, function()
		bagDirty = true
		IL:RequestRefresh()
	end)
end

local function rescan()
	if not bagDirty then return end
	local all, byBag = {}, {}
	for _, bag in ipairs(IL.BagIDs()) do
		local items = IL.ScanContainers({ bag })
		byBag[bag] = items
		for key, n in pairs(items) do all[key] = (all[key] or 0) + n end
	end
	local currencies = IL.ScanCurrencies()
	for key, amount in pairs(currencies) do all[key] = amount end
	bagCache, bagDirty = { all = all, byBag = byBag, currencies = currencies }, false
end

-- Exchange tokens first (most exchanges first), then by name.
-- Primero los tokens (los de más canjes primero) y luego por nombre.
local function sortKeys(set)
	local Data = IL.Data
	local list, names = {}, {}
	for key in pairs(set) do
		list[#list + 1] = key
		names[key] = Data:GetDisplayName(key)
	end
	table.sort(list, function(a, b)
		local sa, sb = Data:GetTokenStats(a), Data:GetTokenStats(b)
		if (sa ~= nil) ~= (sb ~= nil) then return sa ~= nil end
		if sa and sb and sa.offers ~= sb.offers then return sa.offers > sb.offers end
		return names[a] < names[b]
	end)
	return list
end

-- Everything you carry plus owned exchange currencies, as one sorted list.
-- Todo lo que cargas más las monedas de canje que tienes, en una sola lista ordenada.
function Scanner:GetBagKeys()
	rescan()
	return sortKeys(bagCache.all)
end

-- Bag name and icon: backpack, then each equipped bag (its item name and icon).
-- Nombre e ícono de la bolsa: la mochila y luego cada bolsa equipada (nombre e ícono del objeto).
local function bagInfo(bag)
	if bag == 0 then return IL.L.BAG_BACKPACK, "Interface\\Buttons\\Button-Backpack-Up" end
	local name = C_Container.GetBagName and C_Container.GetBagName(bag)
	local invID = C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(bag)
	local icon = invID and GetInventoryItemTexture and GetInventoryItemTexture("player", invID)
	local usable = name and not IL.IsSecret(name) and name ~= ""
	return usable and name or IL.L.BAG_N:format(bag), icon
end

-- Grouped for the Bags tab: one group per bag with items, then owned currencies.
-- { { id, text, icon, keys }, … }
-- Agrupado para la pestaña Mochila: un grupo por bolsa con objetos y luego las monedas.
function Scanner:GetBagGroups()
	rescan()
	local groups = {}
	for _, bag in ipairs(IL.BagIDs()) do
		local items = bagCache.byBag[bag]
		if items and next(items) then
			local name, icon = bagInfo(bag)
			groups[#groups + 1] = { id = "bag" .. bag, text = name, icon = icon, keys = sortKeys(items) }
		end
	end
	if next(bagCache.currencies) then
		groups[#groups + 1] = { id = "currencies", text = IL.L.BAG_CURRENCIES, keys = sortKeys(bagCache.currencies) }
	end
	return groups
end

---------------------------------------------------------------------------
-- Bank and Warband bank / Banco y banco de banda guerrera
---------------------------------------------------------------------------
-- The game only lets add-ons read the bank while it is open, so ItemLens keeps a copy each
-- time you open it. Syndicator, if installed, fills in when there is no copy yet.
-- El juego solo deja leer el banco mientras está abierto, así que ItemLens guarda una copia
-- cada vez que lo abres. Syndicator, si está instalado, cubre mientras no hay copia.
local Bank = {}
IL.Bank = Bank

local bankOpen = false
local charBags, warbandBags = {}, {}

-- Container IDs by client: bank tabs (11.2+) or the older bank bags, in game order.
-- IDs de contenedor según el cliente: pestañas de banco (11.2+) o las bolsas antiguas, en orden.
local function collectBankBagIDs()
	for name, id in pairs(Enum.BagIndex or {}) do
		if type(name) == "string" and type(id) == "number" then
			if name:match("^CharacterBankTab_%d+$") or name:match("^BankBag_%d+$") or name == "Bank" or name == "Reagentbank" then
				charBags[#charBags + 1] = id
			elseif name:match("^AccountBankTab_%d+$") then
				warbandBags[#warbandBags + 1] = id
			end
		end
	end
	table.sort(charBags)
	table.sort(warbandBags)
end

-- Tab names and icons chosen by the player: { [bagID] = { name, icon } }.
-- Nombres e íconos de pestaña que eligió el jugador: { [bagID] = { name, icon } }.
local function tabInfo(bankType)
	local out = {}
	if not (C_Bank and C_Bank.FetchPurchasedBankTabData and bankType) then return out end
	local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
	for _, t in ipairs(ok and tabs or {}) do
		if t.ID and not IL.IsSecret(t.name) then out[t.ID] = { name = t.name, icon = t.icon } end
	end
	return out
end

-- A bank copy: merged items (for "Who has it") plus one entry per readable tab.
-- Returns nil when nothing could be read (the bank is only readable while open).
-- Una copia del banco: objetos juntos (para "Lo tienen") más una entrada por pestaña legible.
-- Devuelve nil si no se pudo leer nada (el banco solo se lee mientras está abierto).
function Bank.BuildCopy(bagIDs, bankType)
	local info = tabInfo(bankType)
	local merged, tabs, anySlots = {}, {}, false
	for index, bag in ipairs(bagIDs) do
		local items, slots = IL.ScanContainers({ bag })
		if slots > 0 then
			anySlots = true
			for key, n in pairs(items) do merged[key] = (merged[key] or 0) + n end
			local t = info[bag] or {}
			tabs[#tabs + 1] = { index = index, name = t.name, icon = t.icon, items = items }
		end
	end
	if not anySlots then return nil end
	return { t = time(), items = merged, tabs = tabs }
end

-- Saves only what could be read; otherwise the previous copy stays.
-- Guarda solo lo que se pudo leer; si no, se queda la copia anterior.
local function snapshotBank()
	if not bankOpen then return end
	local BankType = Enum.BankType or {}
	local key = IL.PlayerKey()
	local own = Bank.BuildCopy(charBags, BankType.Character)
	if own and key then ItemLensDB.bank[key] = own end
	local warband = Bank.BuildCopy(warbandBags, BankType.Account)
	if warband then ItemLensDB.warband = warband end
	IL:RequestRefresh()
end

function Bank:Init()
	ItemLensDB.bank = ItemLensDB.bank or {}
	collectBankBagIDs()
	IL.OnEvents({ "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED" }, function(event)
		if event == "BANKFRAME_OPENED" then
			bankOpen = true
			C_Timer.After(0.3, snapshotBank) -- let the tabs load / dar tiempo a que carguen las pestañas
		elseif event == "BANKFRAME_CLOSED" then
			snapshotBank()
			bankOpen = false
		else
			snapshotBank()
		end
	end)
end

local function itemIDFromSlot(item)
	if item.itemID then return item.itemID end
	local id = type(item.itemLink) == "string" and item.itemLink:match("item:(%d+)")
	return id and tonumber(id)
end

local function addSlots(items, slots)
	for _, item in pairs(slots or {}) do
		local id = type(item) == "table" and itemIDFromSlot(item)
		if id then
			local key = "i" .. id
			items[key] = (items[key] or 0) + (item.itemCount or 1)
		end
	end
end

-- Syndicator's copy, also split by tab. / La copia de Syndicator, también por pestaña.
local function fromSyndicator(which)
	if not IL.Int:HasSyndicator() then return nil end
	local ok, merged, tabs = pcall(function()
		local merged, tabs = {}, {}
		local function addTab(slots)
			local items = {}
			addSlots(items, slots)
			for key, n in pairs(items) do merged[key] = (merged[key] or 0) + n end
			tabs[#tabs + 1] = { index = #tabs + 1, items = items }
		end
		-- Every entry, in key order. / Todas las entradas, en orden de clave.
		local function each(t, fn)
			local keys = {}
			for k in pairs(t or {}) do keys[#keys + 1] = k end
			table.sort(keys, function(a, b)
				if type(a) == "number" and type(b) == "number" then return a < b end
				return tostring(a) < tostring(b)
			end)
			for _, k in ipairs(keys) do fn(t[k]) end
		end
		if which == "warband" then
			local w = Syndicator.API.GetWarband and Syndicator.API.GetWarband(1)
			each(w and w.bank, function(tab) addTab(tab.slots) end)
		else
			local data = Syndicator.API.GetCharacter(Syndicator.API.GetCurrentCharacter())
			each(data and data.bankTabs, function(tab) addTab(tab.slots) end)
			each(data and data.bank, function(bag) addTab(bag) end)
		end
		if not next(merged) then return nil end
		return merged, tabs
	end)
	if not ok or not merged then return nil end
	return merged, tabs
end

-- which = "bank" | "warband" → items { [key] = count }, source ("own" | "syndicator"), time,
-- tabs { { index, name, icon, items }, … } (nil for copies saved before tabs were recorded).
-- which = "bank" | "warband" → objetos { [clave] = cantidad }, fuente ("own" | "syndicator"), fecha,
-- pestañas { { index, name, icon, items }, … } (nil en copias guardadas antes de registrar pestañas).
function Bank:Get(which)
	local own
	if which == "warband" then own = ItemLensDB.warband else own = ItemLensDB.bank[IL.PlayerKey()] end
	if own and own.items and next(own.items) then return own.items, "own", own.t, own.tabs end
	local syn, tabs = fromSyndicator(which)
	if syn then return syn, "syndicator", nil, tabs end
	return nil
end

---------------------------------------------------------------------------
-- Characters on the account / Personajes de la cuenta
---------------------------------------------------------------------------
-- Each character that logs in saves its bags, equipped gear, exchange currencies and finished
-- class quests in ItemLensDB.chars (account-wide). The bank lives in ItemLensDB.bank.
-- Cada personaje que entra guarda sus bolsas, equipo puesto, monedas de canje y misiones de clase
-- hechas en ItemLensDB.chars (de la cuenta). El banco está en ItemLensDB.bank.
local Chars = {}
IL.Chars = Chars

local EQUIP_SLOTS = 19

local function scanEquipped()
	local items = {}
	for slot = 1, EQUIP_SLOTS do
		local id = GetInventoryItemID("player", slot)
		if id then items["i" .. id] = (items["i" .. id] or 0) + 1 end
	end
	return items
end

function Chars:Snapshot()
	local key = IL.PlayerKey()
	if not key then -- realm not available yet: retry / el reino aún no está: reintentar
		C_Timer.After(5, function() Chars:Snapshot() end)
		return
	end
	local _, class, classID = UnitClass("player")
	local doneQuests = {}
	if IL.Coll and classID then
		for _, questID in ipairs(IL.Coll:GetClassQuestIDs(classID)) do
			if C_QuestLog.IsQuestFlaggedCompleted(questID) then doneQuests[questID] = true end
		end
	end
	ItemLensDB.chars[key] = {
		class = class,
		t = time(),
		bags = (IL.ScanContainers(IL.BagIDs())),
		equipped = scanEquipped(),
		currencies = IL.ScanCurrencies(),
		classQuests = doneQuests,
	}
end

-- Many events in a row become a single snapshot. / Muchos eventos seguidos, una sola copia.
local snapshotPending = false
local function scheduleSnapshot()
	if snapshotPending then return end
	snapshotPending = true
	C_Timer.After(2, function()
		snapshotPending = false
		Chars:Snapshot()
	end)
end

function Chars:Init()
	ItemLensDB.chars = ItemLensDB.chars or {}
	IL.OnEvents({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "CURRENCY_DISPLAY_UPDATE",
		"QUEST_TURNED_IN", "PLAYER_LOGOUT" }, function(event)
		if event == "PLAYER_LOGOUT" then
			Chars:Snapshot() -- last copy before WoW writes to disk / última copia antes de guardar
		else
			scheduleSnapshot()
		end
	end)
	scheduleSnapshot()
end

-- Who has an item or currency: { { name, total, bags, bank, equipped, class, isMe }, … } or nil.
-- ItemLens' own data comes first; Syndicator only adds characters ItemLens does not know.
-- Quién tiene un objeto o moneda. Primero los datos propios; Syndicator solo agrega
-- personajes que ItemLens no conoce.
function Chars:GetOwners(key)
	local out, seen = {}, {}
	local me = IL.PlayerKey()

	local names = {}
	for name in pairs(ItemLensDB.chars or {}) do names[name] = true end
	for name in pairs(ItemLensDB.bank or {}) do names[name] = true end
	for name in pairs(names) do
		local c = ItemLensDB.chars[name] or {}
		local b = ItemLensDB.bank[name]
		local bags = (c.bags and c.bags[key] or 0) + (c.currencies and c.currencies[key] or 0)
		local bank = b and b.items and b.items[key] or 0
		local equipped = c.equipped and c.equipped[key] or 0
		local total = bags + bank + equipped
		if total > 0 then
			out[#out + 1] = { name = IL.ShortName(name), total = total, bags = bags, bank = bank,
				equipped = equipped, class = c.class, isMe = name == me }
		end
		seen[name] = true
	end

	local w = ItemLensDB.warband
	local inWarband = w and w.items and w.items[key]
	if inWarband and inWarband > 0 then
		out[#out + 1] = { name = L.BANK_WARBAND, total = inWarband, bank = inWarband, warband = true }
	end

	for _, o in ipairs(IL.Int:GetSyndicatorOwners(key) or {}) do
		if o.full and not seen[o.full] and not o.warband then
			out[#out + 1] = { name = IL.ShortName(o.full), total = o.total, bags = o.bags, bank = o.bank,
				equipped = o.equipped, class = o.class, fromSyndicator = true }
		end
	end

	table.sort(out, function(a, b) return a.total > b.total end)
	return #out > 0 and out or nil
end
