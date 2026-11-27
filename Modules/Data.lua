--[[
	ItemLens · Modules/Data.lua
	Read access to the bundled database (IL.DB) merged with what ItemLens learns in game,
	plus item information from the client: names, icons, expansions, sources, uses, crafts.
	Acceso a la base de datos incluida (IL.DB) unida a lo que ItemLens aprende en el juego,
	más la información del cliente: nombres, íconos, expansiones, orígenes, usos y recetas.
	© 2026 iAthVo_Kr · MIT License

	IL.DB layout (Data/iLs_Import.lua) / Formato de IL.DB:
	  vendors[npcID]  = { mapID, x, y, expansion }        (expansion: ATT numbering = Blizzard + 1)
	  offers[key]     = { { npcID, itemID received, cost }, … }   key = "i<id>" | "c<id>"
	  sources[itemID] = "origin;origin;…"                 (compact, see parseOrigin)
	  uses[key]       = { { kind, id, mapID, x, y, tag, qty }, … }
	  reagents[itemID]= { { crafted itemID, qty }, … }
	Expansions are handled with Blizzard IDs: 0 = Classic … 9 = DF, 10 = TWW, 11 = Midnight.
	Las expansiones se manejan con el ID de Blizzard: 0 = Clásico … 9 = DF, 10 = TWW, 11 = Midnight.
]]

local _, IL = ...
local L = IL.L

local Data = {}
IL.Data = Data

local DB = IL.DB

-- Item IDs the server confirmed do not exist. / Objetos que el servidor confirmó que no existen.
Data.unavailable = {}

-- State and caches (rebuilt on demand) / Estado y cachés (se rehacen al pedirlos)
local tokenList, tokenStats = {}, {} -- exchange tokens / tokens con canje
local offersAll       -- imported + learned exchanges / canjes importados + aprendidos
local rewards         -- reverse index: itemID → tokens that buy it / índice inverso
local dictKeys        -- Catalog tab keys / claves del Catálogo
local breakdownCache = {}
local obtainCache, craftsCache = {}, {}

---------------------------------------------------------------------------
-- Exchanges / Canjes
---------------------------------------------------------------------------
-- Imported exchanges plus the ones learned at vendors: { npcID, itemID, cost, learned }.
-- Canjes importados más los aprendidos en vendedores: { npcID, itemID, costo, aprendido }.
local function allOffers()
	if offersAll then return offersAll end
	offersAll = {}
	for key, list in pairs(DB.offers) do offersAll[key] = list end
	if IL.Learn then
		for key, learned in pairs(IL.Learn:GetOffers()) do
			local base, seen, merged = offersAll[key] or {}, {}, {}
			for i, o in ipairs(base) do merged[i] = o; seen[o[1] .. ":" .. o[2]] = true end
			for _, o in ipairs(learned) do
				if not seen[o[1] .. ":" .. o[2]] then merged[#merged + 1] = { o[1], o[2], o[3], true } end
			end
			offersAll[key] = merged
		end
	end
	return offersAll
end

local function buildTokens()
	tokenList, tokenStats = {}, {}
	for key, list in pairs(allOffers()) do
		tokenList[#tokenList + 1] = key
		local seen, vendors, exp = {}, 0, nil
		for _, o in ipairs(list) do
			if not seen[o[1]] then
				seen[o[1]] = true
				vendors = vendors + 1
				local v = DB.vendors[o[1]]
				if v and v[4] and (not exp or v[4] > exp) then exp = v[4] end
			end
		end
		tokenStats[key] = { offers = #list, vendors = vendors, exp = exp and (exp - 1) or nil }
	end
end

function Data:GetTokenKeys() return tokenList end
function Data:IsToken(key) return tokenStats[key] ~= nil end
function Data:GetTokenStats(key) return tokenStats[key] end

-- Vendor from the database or, failing that, learned in game.
-- Vendedor de la base de datos o, si no está, aprendido en el juego.
function Data:GetVendor(npc)
	local v = DB.vendors[npc]
	if v then return { npc = npc, map = v[1], x = v[2], y = v[3] } end
	return IL.Learn and IL.Learn:GetVendor(npc) or nil
end

-- Vendors that accept this token, grouped by NPC. Vendors in your current zone come first.
-- Vendedores que aceptan este token, agrupados por NPC. Primero los de tu zona actual.
function Data:GetOffers(key)
	local list = allOffers()[key]
	if not list then return nil end
	local byNpc, order = {}, {}
	for _, o in ipairs(list) do
		local g = byNpc[o[1]]
		if not g then
			local v = self:GetVendor(o[1]) or {}
			g = { npc = o[1], map = v.map, x = v.x, y = v.y, items = {}, learned = true }
			byNpc[o[1]] = g
			order[#order + 1] = g
		end
		g.items[#g.items + 1] = { o[2], o[3], o[4] }
		if not o[4] then g.learned = nil end -- learned only if all of it is / aprendido solo si todo lo es
	end
	local here = C_Map.GetBestMapForUnit("player")
	table.sort(order, function(a, b)
		local ah, bh = a.map == here, b.map == here
		if ah ~= bh then return ah end
		if #a.items ~= #b.items then return #a.items > #b.items end
		return a.npc < b.npc
	end)
	return order
end

-- Tokens that buy this item: { { tokenKey, npcID, cost, learned }, … }.
-- Tokens con los que se obtiene este objeto: { { token, npcID, costo, aprendido }, … }.
function Data:GetSources(key)
	local kind, id = IL.SplitKey(key)
	if kind ~= "i" then return nil end
	if not rewards then
		rewards = {}
		for token, list in pairs(allOffers()) do
			for _, o in ipairs(list) do
				local r = rewards[o[2]]
				if not r then r = {}; rewards[o[2]] = r end
				r[#r + 1] = { token, o[1], o[3], o[4] }
			end
		end
	end
	return rewards[id]
end

local function rewardCategory(itemID)
	if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID) then return "toy" end
	local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
	if classID == 15 and subClassID == 5 then return "mount" end
	if (classID == 15 and subClassID == 2) or classID == 17 then return "pet" end
	if classID == 9 then return "recipe" end
	if classID == 2 or classID == 4 then return "gear" end
	if classID == 0 then return "consumable" end
	if classID == 7 then return "material" end
	return "other"
end

local CAT_ORDER = { "mount", "pet", "toy", "recipe", "gear", "consumable", "material", "other" }

-- What a token buys: "6 recipes · 3 toys · 1 mount". / Lo que compra un token.
function Data:GetRewardBreakdown(key)
	if breakdownCache[key] then return breakdownCache[key] end
	local list = allOffers()[key]
	if not list then return nil end
	local counts, seen = {}, {}
	for _, o in ipairs(list) do
		if not seen[o[2]] then
			seen[o[2]] = true
			local cat = rewardCategory(o[2])
			counts[cat] = (counts[cat] or 0) + 1
		end
	end
	local parts = {}
	for _, cat in ipairs(CAT_ORDER) do
		if counts[cat] then parts[#parts + 1] = L.CAT[cat]:format(counts[cat]) end
		if #parts >= 4 then break end
	end
	breakdownCache[key] = table.concat(parts, " · ")
	return breakdownCache[key]
end

---------------------------------------------------------------------------
-- Learning hook / Aviso del aprendizaje
---------------------------------------------------------------------------
-- Called by Learn.lua: rebuilds only what changed.
-- Lo llama Learn.lua: rehace solo lo que cambió.
function Data:OnLearned(what, itemIDs)
	if what == "vendors" or what == "all" then
		offersAll, rewards, dictKeys = nil, nil, nil
		breakdownCache = {}
		buildTokens()
	end
	Data._facCache = {} -- faction depends on sources / la facción depende de los orígenes
	if what == "all" then
		obtainCache, craftsCache = {}, {}
	else
		for _, id in ipairs(itemIDs or {}) do obtainCache[id] = nil; craftsCache[id] = nil end
	end
end

---------------------------------------------------------------------------
-- Start-up / Arranque
---------------------------------------------------------------------------
local nameCache -- defined below / definida más abajo

function Data:Init()
	buildTokens()
	IL.OnEvents({ "ITEM_DATA_LOAD_RESULT" }, function(_, itemID, success)
		if success then
			Data.unavailable[itemID] = nil
			local cache = itemID and nameCache()
			if cache then
				local name = C_Item.GetItemInfo(itemID)
				if name then cache[itemID] = name end
			end
		elseif itemID then
			Data.unavailable[itemID] = true -- removed or never implemented / retirado o nunca implementado
		end
		-- While every name is loading, the loader redraws now and then instead of per item.
		-- Mientras cargan todos los nombres, la carga redibuja de vez en cuando y no por objeto.
		if not Data:IsFullLoadRunning() and not Data:GetLoaderProgress() then IL:RequestRefresh() end
	end)
end

---------------------------------------------------------------------------
-- Catalog / Catálogo
---------------------------------------------------------------------------
-- Everything with something to say: tokens, items with uses, reagents and collectibles.
-- Todo lo que tiene algo que decir: tokens, objetos con usos, materiales y coleccionables.
function Data:GetDictionaryKeys()
	if dictKeys then return dictKeys end
	local seen, list = {}, {}
	local function add(key) if not seen[key] then seen[key] = true; list[#list + 1] = key end end
	for _, key in ipairs(tokenList) do add(key) end
	for key in pairs(DB.uses or {}) do add(key) end
	for id in pairs(DB.reagents or {}) do add("i" .. id) end
	for id in pairs(IL.ACH and IL.ACH.needs or {}) do add("i" .. id) end -- D-66
	local C = DB.collections or {}
	for _, set in ipairs({ "mm", "cq", "cs" }) do
		for id in pairs(C[set] or {}) do add("i" .. id) end
	end
	dictKeys = list
	return list
end

-- Saved name cache, so searching by name does not depend on the client having every item
-- loaded. It resets when the client language changes.
-- Caché de nombres guardada, para que buscar por nombre no dependa de que el cliente ya tenga
-- cada objeto cargado. Se reinicia si cambia el idioma del cliente.
nameCache = function()
	local db = ItemLensDB
	if not db then return nil end
	local loc = GetLocale and GetLocale() or "?"
	if db.namesLocale ~= loc then db.names = {}; db.namesLocale = loc end
	db.names = db.names or {}
	return db.names
end

-- Background name loader: 100 items every 0.2 s, at most one pass every 30 s.
-- Carga de nombres en segundo plano: 100 objetos cada 0.2 s, como mucho una pasada cada 30 s.
local loader = { running = false, pending = 0, total = 0 }

function Data:StartNameLoader()
	if loader.running then return end
	local now = GetTime and GetTime() or 0
	if loader.lastRun and now - loader.lastRun < 30 then return end
	loader.lastRun = now
	local cache = nameCache()
	if not cache then return end
	local queue = {}
	for _, key in ipairs(self:GetDictionaryKeys()) do
		local kind, id = IL.SplitKey(key)
		if kind == "i" and not cache[id] and not Data.unavailable[id] then queue[#queue + 1] = id end
	end
	loader.total, loader.pending = #queue, #queue
	if #queue == 0 then return end
	loader.running = true
	local i = 1
	local function step()
		for _ = 1, 100 do
			local id = queue[i]
			if not id then break end
			local name = C_Item.GetItemInfo(id)
			if name then cache[id] = name else C_Item.RequestLoadItemDataByID(id) end
			i = i + 1
		end
		loader.pending = math.max(0, #queue - i + 1)
		if queue[i] then C_Timer.After(0.2, step)
		else
			loader.running = false
			Data.namesVersion = (Data.namesVersion or 0) + 1 -- the Catalog sorts again / el Catálogo se reordena
			IL:RequestRefresh()
		end
	end
	step()
end

function Data:GetLoaderProgress()
	return loader.running, loader.total - loader.pending, loader.total
end

---------------------------------------------------------------------------
-- Search everything / Buscar en todo
---------------------------------------------------------------------------
-- Searching by name reaches every item ItemLens knows (the Catalog plus every item with a known
-- source), not only the tab's list. Names come from the client and are saved (nameCache); the
-- first search loads the missing ones in the background.
-- Buscar por nombre llega a todo objeto que ItemLens conoce (el Catálogo y todo objeto con
-- origen), no solo a la lista de la pestaña. Los nombres vienen del cliente y se guardan
-- (nameCache); la primera búsqueda carga en segundo plano los que faltan.
local allIDs          -- every known itemID / todos los itemID conocidos
local lowerNames = {} -- [itemID] = lower-case name / nombre en minúsculas
local full = { running = false, done = 0, total = 0 }
-- Per step: up to 25 requests to the server (names the client already has are read without
-- asking, up to 500 per step), every 0.25 s → at most 100 requests/s. Each answer is a game event
-- that other add-ons also handle, so asking faster stutters the game. Paused in combat.
-- Por paso: hasta 25 pedidos al servidor (los nombres que el cliente ya tiene se leen sin pedir,
-- hasta 500 por paso), cada 0.25 s → como mucho 100 pedidos por segundo. Cada respuesta es un
-- evento del juego que otros addons también atienden; pedir más rápido traba el juego. En
-- combate se pausa.
local FULL_REQUESTS, FULL_READS, FULL_DELAY, FULL_REDRAW = 25, 500, 0.25, 24 -- redraw every ~6 s / redibuja cada ~6 s

local function allItemIDs()
	if allIDs then return allIDs end
	local seen, list = {}, {}
	local function add(id)
		id = tonumber(id)
		if id and not seen[id] then seen[id] = true; list[#list + 1] = id end
	end
	for id in pairs(DB.sources or {}) do add(id) end
	for _, id in ipairs(IL.Game and IL.Game:GetItemIDs() or {}) do add(id) end -- D-73
	for _, key in ipairs(Data:GetDictionaryKeys()) do
		local kind, id = IL.SplitKey(key)
		if kind == "i" then add(id) end
	end
	allIDs = list
	return list
end

function Data:IsFullLoadRunning() return full.running end

function Data:GetFullLoadProgress() return full.running, full.done, full.total end

-- Loads every missing name once (saved afterwards). / Carga una vez cada nombre que falta.
function Data:StartFullNameLoader()
	if full.running or full.finished then return end
	local cache = nameCache()
	if not cache then return end
	local queue = {}
	for _, id in ipairs(allItemIDs()) do
		if not cache[id] and not Data.unavailable[id] then queue[#queue + 1] = id end
	end
	full.total, full.done = #queue, 0
	if #queue == 0 then full.finished = true return end
	full.running = true
	local i, batches = 1, 0
	local function step()
		if InCombatLockdown and InCombatLockdown() then return C_Timer.After(2, step) end
		local requests, reads = 0, 0
		while requests < FULL_REQUESTS and reads < FULL_READS do
			local id = queue[i]
			if not id then break end
			if not cache[id] then
				local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
				if name then cache[id] = name
				else
					C_Item.RequestLoadItemDataByID(id)
					requests = requests + 1
				end
			end
			reads = reads + 1
			i = i + 1
		end
		full.done = i - 1
		batches = batches + 1
		if queue[i] then
			-- Redraw only when it can show something new. / Redibuja solo si hay algo nuevo que mostrar.
			local ui = IL.UI
			if batches % FULL_REDRAW == 0 and ui and ui:IsShown() and ui.query ~= "" and ui.tab ~= "ach" then
				IL:RequestRefresh()
			end
			C_Timer.After(FULL_DELAY, step)
		else
			full.running, full.finished = false, true
			IL:RequestRefresh()
		end
	end
	step()
end

-- New items read from the game (D-73): searchable, with their names asked for once.
-- Objetos nuevos leídos del juego (D-73): se pueden buscar y sus nombres se piden una vez.
function Data:OnGameData(itemIDs)
	allIDs = nil
	Data._facCache = {}
	local cache = nameCache()
	local queue = {}
	for _, id in ipairs(itemIDs or {}) do
		obtainCache[id] = nil
		if cache and not cache[id] then queue[#queue + 1] = id end
	end
	local i = 1
	local function step()
		if InCombatLockdown and InCombatLockdown() then return C_Timer.After(2, step) end
		for _ = 1, FULL_REQUESTS do
			local id = queue[i]
			if not id then break end
			local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
			if name then cache[id] = name else C_Item.RequestLoadItemDataByID(id) end
			i = i + 1
		end
		if queue[i] then C_Timer.After(FULL_DELAY, step) end
	end
	if #queue > 0 then step() end
end

-- Items whose name contains the query, sorted by name, skipping `exclude`.
-- Returns the keys and whether the limit cut the list.
-- Objetos cuyo nombre contiene el texto, ordenados por nombre, sin los de `exclude`.
-- Devuelve las claves y si el límite cortó la lista.
function Data:SearchAll(query, exclude, limit)
	local cache = nameCache()
	if not cache or query == "" then return {}, false end
	local found = {}
	for _, id in ipairs(allItemIDs()) do
		local name = cache[id]
		if name then
			local low = lowerNames[id]
			if not low then low = strlower(name); lowerNames[id] = low end
			if low:find(query, 1, true) then
				local key = "i" .. id
				if not (exclude and exclude[key]) then found[#found + 1] = { key, name } end
			end
		end
	end
	table.sort(found, function(a, b) return a[2] < b[2] end)
	local out, cut = {}, #found > limit
	for i = 1, math.min(#found, limit) do out[i] = found[i][1] end
	return out, cut
end

-- Currencies by name (global search, D-67). / Monedas por nombre (búsqueda global, D-67).
function Data:SearchCurrencies(query, exclude, limit)
	if query == "" then return {}, false end
	local found = {}
	for _, key in ipairs(self:GetDictionaryKeys()) do
		if key:sub(1, 1) == "c" and not (exclude and exclude[key]) then
			local name = self:GetDisplayName(key)
			if name and strlower(name):find(query, 1, true) then found[#found + 1] = { key, name } end
		end
	end
	table.sort(found, function(a, b) return a[2] < b[2] end)
	local out, cut = {}, #found > limit
	for i = 1, math.min(#found, limit) do out[i] = found[i][1] end
	return out, cut
end

---------------------------------------------------------------------------
-- Item information / Información de objetos
---------------------------------------------------------------------------
local QUEST_ICON = "Interface\\GossipFrame\\AvailableQuestIcon"

local function itemInfo(id)
	local name, link, quality, _, _, itemType, _, _, _, _, _, _, _, _, expacID = C_Item.GetItemInfo(id)
	if not name then C_Item.RequestLoadItemDataByID(id) end
	return name, link, quality, itemType, expacID
end

local function currencyInfo(id)
	return C_CurrencyInfo.GetCurrencyInfo(id)
end

-- Name, or nil while it is still loading. / Nombre, o nil mientras todavía carga.
function Data:GetName(key)
	local kind, id = IL.SplitKey(key)
	if kind == "i" then
		local cache = nameCache()
		if cache and cache[id] then return cache[id] end
		local name = itemInfo(id)
		if name and cache then cache[id] = name end
		return name
	elseif kind == "q" then
		local title = C_QuestLog.GetTitleForQuestID(id)
		if not title or title == "" then IL.Int:GetQuestTitle(id) return nil end -- requests it / la pide
		return title
	elseif kind == "f" then
		local a = self:GetArtifact(id)
		if not a then return nil end
		local name, loaded = Data.ArtifactName(a)
		return loaded and name or nil
	end
	local info = currencyInfo(id)
	return info and info.name
end

-- Name with a readable fallback ("Item #123"). / Nombre con respaldo legible ("Objeto #123").
function Data:GetDisplayName(key)
	local name = self:GetName(key)
	if name then return name end
	local kind, id = IL.SplitKey(key)
	if kind == "q" then return IL.Int:GetQuestTitle(id) end
	if kind == "f" then local a = self:GetArtifact(id); return a and (Data.ArtifactName(a)) or L.ART_N:format(id) end
	if kind == "i" and Data.unavailable[id] then return L.ITEM_UNAVAILABLE:format(id) end
	return (kind == "i" and L.ITEM_N or L.CURRENCY_N):format(id)
end

function Data:GetIcon(key)
	local kind, id = IL.SplitKey(key)
	if kind == "i" then return C_Item.GetItemIconByID(id) or 134400 end
	if kind == "q" then return QUEST_ICON end
	if kind == "f" then
		local a = self:GetArtifact(id)
		return a and a.weapon and C_Item.GetItemIconByID(a.weapon) or 134400
	end
	local info = currencyInfo(id)
	return info and info.iconFileID or 134400
end

function Data:GetQuality(key)
	local kind, id = IL.SplitKey(key)
	if kind == "i" then return (select(3, itemInfo(id))) end
	if kind == "q" then return nil end
	if kind == "f" then return 6 end -- artifact quality / calidad de artefacto
	local info = currencyInfo(id)
	return info and info.quality
end

function Data:GetLink(key)
	local kind, id = IL.SplitKey(key)
	if kind == "i" then return (select(2, itemInfo(id))) end
	if kind == "q" then return GetQuestLink and GetQuestLink(id) or nil end
	if kind == "f" then
		local a = self:GetArtifact(id)
		return a and a.weapon and select(2, itemInfo(a.weapon)) or nil
	end
	return C_CurrencyInfo.GetCurrencyLink(id, 0)
end

function Data:GetItemType(key)
	local kind, id = IL.SplitKey(key)
	if kind ~= "i" then return nil end
	return (select(4, itemInfo(id)))
end

-- Blizzard expansion ID: from the client first, otherwise from the vendor in the database.
-- ID de expansión de Blizzard: primero del cliente; si no, del vendedor en la base de datos.
function Data:GetExpansion(key)
	local kind, id = IL.SplitKey(key)
	if kind == "q" then
		local q = self:GetClassQuest(id)
		return q and q.exp
	elseif kind == "f" then
		return self:GetArtifact(id) and 6 or nil -- Legion
	end
	if kind == "i" then
		local expacID = select(5, itemInfo(id))
		if type(expacID) == "number" and expacID >= 0 and expacID < 30 then return expacID end
	end
	local stats = tokenStats[key]
	if stats and stats.exp then return stats.exp end
	local src = self:GetSources(key)
	if src and src[1] then
		local v = DB.vendors[src[1][2]]
		if v and v[4] then return v[4] - 1 end
	end
	return nil
end

---------------------------------------------------------------------------
-- Class quests / Misiones de clase
---------------------------------------------------------------------------
-- DB.classQuests[questID] = "class,expansion,mapID,x,y;reward,reward…"
local questCache = {}

function Data:GetClassQuest(id)
	if questCache[id] ~= nil then return questCache[id] or nil end
	local raw = DB.classQuests and DB.classQuests[id]
	if not raw then questCache[id] = false return nil end
	local head, rew = raw:match("^([^;]*);?(.*)$")
	local f = {}
	for v in (head .. ","):gmatch("([^,]*),") do f[#f + 1] = tonumber(v) end
	local rewardIDs = {}
	for r in (rew or ""):gmatch("%d+") do rewardIDs[#rewardIDs + 1] = tonumber(r) end
	local q = { id = id, class = f[1], exp = f[2] and (f[2] - 1) or nil, map = f[3], x = f[4], y = f[5], rewards = rewardIDs }
	questCache[id] = q
	return q
end

---------------------------------------------------------------------------
-- Origins / Orígenes
---------------------------------------------------------------------------
-- Compact origin format (one letter + comma-separated fields):
-- Formato compacto de un origen (una letra + campos separados por coma):
--   b encounter,instance,difficulty   n npc,map,x,y,tag   v npc,map,x,y,copper   o object,map,x,y
--   q quest,map,x,y[,w|d,faction,reputation,eventHeader]   a achievement   p skillLine   c container   z map
--   d instance,difficulty   r faction,value   g categoryCode,header   t appearance set (read from the game, D-73)
local ORIGIN_ORDER = { b = 1, d = 2, n = 3, v = 4, o = 5, q = 6, a = 7, r = 8, p = 9, c = 10, z = 11, g = 12, t = 13 }
local TAG_DECODE = { r = "rare", w = "worldboss", t = "treasure", s = "secret", e = "event" }

local function parseOrigin(s)
	local k, rest = s:sub(1, 1), s:sub(2)
	local f = {}
	for v in (rest .. ","):gmatch("([^,]*),") do f[#f + 1] = v end
	local n = function(i) return tonumber(f[i]) end
	if k == "b" then return { k = "b", id = n(1), inst = n(2), diff = n(3) } end
	if k == "n" then return { k = "n", id = n(1), map = n(2), x = n(3), y = n(4), tag = TAG_DECODE[f[5]] } end
	if k == "v" then return { k = "v", id = n(1), map = n(2), x = n(3), y = n(4), price = n(5) } end
	if k == "o" then return { k = "o", id = n(1), map = n(2), x = n(3), y = n(4) } end
	if k == "q" then
		local event = n(8)
		local zones
		if event and DB.eventZones and DB.eventZones[event] then
			zones = {}
			for z in DB.eventZones[event]:gmatch("%d+") do zones[#zones + 1] = tonumber(z) end
		end
		return { k = "q", id = n(1), map = n(2), x = n(3), y = n(4),
			repeats = (f[5] == "w" and "weekly") or (f[5] == "d" and "daily") or nil,
			repFaction = n(6), repValue = n(7), event = event, zones = zones }
	end
	if k == "d" then return { k = "d", id = n(1), diff = n(2) } end
	if k == "r" then return { k = "r", id = n(1), value = n(2) } end
	if k == "g" then return { k = "g", id = 0, cat = f[1], hdr = n(2) } end
	return { k = k, id = n(1) } -- a, p, c, z
end

local function sortOrigins(list)
	table.sort(list, function(a, b)
		local oa, ob = ORIGIN_ORDER[a.k] or 99, ORIGIN_ORDER[b.k] or 99
		if oa ~= ob then return oa < ob end
		return (a.learned and 1 or 0) < (b.learned and 1 or 0) -- imported first / importados primero
	end)
	return list
end

local function parseOriginList(raw)
	local list = {}
	for part in (raw or ""):gmatch("[^;]+") do
		local o = parseOrigin(part)
		if o.id then list[#list + 1] = o end
	end
	return sortOrigins(list)
end

-- DB.artifacts[appearanceID] = "class,weapon,sourceID,set|origins"
local artCache, artIndex = {}, nil

function Data:GetArtifact(id)
	if artCache[id] ~= nil then return artCache[id] or nil end
	local raw = DB.artifacts and DB.artifacts[id]
	if not raw then artCache[id] = false return nil end
	local head, origins = raw:match("^([^|]*)|?(.*)$")
	local f = {}
	for v in (head .. ","):gmatch("([^,]*),") do f[#f + 1] = tonumber(v) end
	-- Variant number within its weapon and set (1, 2, 3…), by ID.
	-- Número de variante dentro de su arma y conjunto (1, 2, 3…), por ID.
	if not artIndex then
		artIndex = {}
		local groups = {}
		for aid, r in pairs(DB.artifacts) do
			local w, s = r:match("^[^,]*,([^,]*),[^,]*,([^|]*)")
			local g = (w or "") .. ":" .. (s or "")
			groups[g] = groups[g] or {}
			table.insert(groups[g], aid)
		end
		for _, ids in pairs(groups) do
			table.sort(ids)
			for i, aid in ipairs(ids) do artIndex[aid] = i end
		end
	end
	local a = { id = id, class = f[1], weapon = f[2], source = f[3], set = f[4], index = artIndex[id] or 1,
		origins = parseOriginList(origins) }
	artCache[id] = a
	return a
end

-- "Ulthalesh · Base appearance 2". Second value: whether the weapon name is loaded.
-- "Ulthalesh · Apariencia base 2". Segundo valor: si el nombre del arma ya cargó.
function Data.ArtifactName(a)
	local weapon = a.weapon and Data:GetName("i" .. a.weapon) or nil
	local set = IL.Int:GetHeaderName(a.set) or L.ART_APPEARANCE
	return (weapon or L.ITEM_N:format(a.weapon or 0)) .. " · " .. set .. " " .. a.index, weapon ~= nil
end

-- Every way to get an item, imported and learned, sorted: boss, NPC, vendor, treasure, quest…
-- Todas las formas de conseguir un objeto, importadas y aprendidas, ordenadas.
function Data:GetObtain(key)
	local kind, id = IL.SplitKey(key)
	if kind == "f" then
		local a = self:GetArtifact(id)
		return a and #a.origins > 0 and a.origins or nil
	end
	if kind ~= "i" then return nil end
	if obtainCache[id] ~= nil then return obtainCache[id] or nil end
	local list, seen = {}, {}
	for part in (DB.sources and DB.sources[id] or ""):gmatch("[^;]+") do
		local o = parseOrigin(part)
		if o.id then list[#list + 1] = o; seen[o.k .. o.id] = true end
	end
	for _, o in ipairs(IL.Learn and IL.Learn:GetOrigins(id) or {}) do
		if o.id and not seen[o.k .. o.id] then list[#list + 1] = o; seen[o.k .. o.id] = true end
	end
	-- Read from the game's journal and sets while ATT catches up (D-73).
	-- Leído del diario y los conjuntos del juego mientras ATT se pone al día (D-73).
	for part in (IL.Game and IL.Game:GetRaw(id) or ""):gmatch("[^;]+") do
		local o = parseOrigin(part)
		if o.id and not seen[o.k .. o.id] then o.game = true; list[#list + 1] = o; seen[o.k .. o.id] = true end
	end
	sortOrigins(list)
	obtainCache[id] = #list > 0 and list or false
	return obtainCache[id] or nil
end

-- "Zone: Nagrand", "Instance: …"
local function zoneWhere(map)
	if not map then return nil end
	return IL.Int:MapKind(map) .. ": " .. IL.Int:GetZoneName(map)
end

-- One origin as text: label ("Boss drop"), name and place.
-- Un origen como texto: etiqueta ("Botín de jefe"), nombre y lugar.
function Data.ObtainLine(o)
	local Int = IL.Int
	if o.k == "b" then
		local where = Int:GetInstanceName(o.inst)
		local diff = Int:GetDifficultyName(o.diff)
		if where and diff then where = where .. " (" .. diff .. ")" end
		if where then where = Int:InstanceKind(o.inst, o.diff) .. ": " .. where end
		return L.SRC_BOSS, Int:GetEncounterName(o.id), where
	elseif o.k == "n" then
		local label = (o.tag == "rare" and L.SRC_RARE) or (o.tag == "worldboss" and L.SRC_WORLDBOSS)
			or (o.tag == "treasure" and L.SRC_TREASURE) or L.SRC_NPC
		return label, Int:GetNPCName(o.id), zoneWhere(o.map)
	elseif o.k == "v" then
		local name = Int:GetNPCName(o.id)
		if o.price and GetMoneyString then name = name .. "  " .. GetMoneyString(o.price, true) end
		return L.SRC_VENDOR, name, zoneWhere(o.map)
	elseif o.k == "o" then
		return L.SRC_TREASURE, Int:GetObjectName(o.id), zoneWhere(o.map), Data:OpenersLine(o.id)
	elseif o.k == "q" then
		-- "Weekly quest: <event>" (the event says more than a quest number), then the requirement
		-- and, for events that move around, their zones.
		-- "Misión semanal: <evento>" (el evento dice más que un número de misión), luego el requisito
		-- y, en eventos que cambian de lugar, sus zonas.
		local label = (o.repeats == "weekly" and L.SRC_QUEST_WEEKLY) or (o.repeats == "daily" and L.SRC_QUEST_DAILY) or L.SRC_QUEST
		local name = (o.event and Int:GetHeaderName(o.event)) or Int:GetQuestTitle(o.id)
		local where = zoneWhere(o.map)
		if o.repFaction then
			local rep = L.REQUIRES:format(L.REP_WITH:format(Int:StandingName(o.repValue, o.repFaction), Int:GetFactionName(o.repFaction)))
			where = where and (where .. " · " .. rep) or rep
		end
		local zones
		if o.zones and #o.zones > 0 then
			local names = {}
			for _, map in ipairs(o.zones) do names[#names + 1] = Int:GetZoneName(map) end
			zones = L.EVENT_ZONES:format(table.concat(names, " · "))
		end
		return label, name, where, zones
	elseif o.k == "a" then
		return L.SRC_ACHIEVEMENT, Int:GetAchievementName(o.id), nil
	elseif o.k == "p" then
		return L.SRC_CRAFTED, Int:GetProfessionName(o.id), nil
	elseif o.k == "d" then
		local name = Int:GetInstanceName(o.id) or L.INSTANCE_N:format(o.id)
		local diff = Int:GetDifficultyName(o.diff)
		return L.SRC_INSTANCE, diff and (name .. " (" .. diff .. ")") or name, Int:InstanceKind(o.id, o.diff)
	elseif o.k == "r" then
		return L.SRC_REP, Int:GetFactionName(o.id) .. " — " .. Int:StandingName(o.value, o.id), nil
	elseif o.k == "c" then
		return L.SRC_CONTAINER, Data:GetDisplayName("i" .. o.id), nil
	elseif o.k == "z" then
		return L.SRC_ZONE, Int:GetZoneName(o.id), nil
	elseif o.k == "g" then
		return L.SRC_CAT[o.cat] or L.SRC_CAT.u, Int:GetHeaderName(o.hdr) or "", nil
	elseif o.k == "t" then
		-- Appearance set (D-73): "Set: <name> (<label>)", and its description ("PvP Season 2"…).
		-- Conjunto de apariencias (D-73): "Conjunto: <nombre> (<etiqueta>)" y su descripción.
		local s = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(o.id)
		if not s then return L.SRC_SET, L.SET_N:format(o.id), nil end
		local name = s.name or L.SET_N:format(o.id)
		if s.label and s.label ~= "" and s.label ~= name then name = name .. " (" .. s.label .. ")" end
		return L.SRC_SET, name, (s.description and s.description ~= "") and s.description or nil
	end
	return "?", "?", nil
end

-- One-line summary: "Boss drop: Onyxia (+2)". / Resumen de una línea.
function Data:GetObtainSummary(key)
	local list = self:GetObtain(key)
	if not list then return nil end
	local label, name = Data.ObtainLine(list[1])
	local s = (name and name ~= "") and (label .. ": " .. name) or label
	if #list > 1 then s = s .. L.USE_MORE:format(#list - 1) end
	return s
end

-- Main place of an entry: "Raid · Onyxia's Lair", "Zone · …", "PvP · Season 2"…
-- Lugar principal de una entrada: "Banda · Guarida de Onyxia", "Zona · …", "JcJ · Temporada 2"…
function Data:GetPlace(key)
	local Int = IL.Int
	local kind, id = IL.SplitKey(key)
	if kind == "q" then
		local q = self:GetClassQuest(id)
		if q and q.map then return L.PLACE_FMT:format(Int:MapKind(q.map), Int:GetZoneName(q.map)) end
		return nil
	end
	for _, o in ipairs(self:GetObtain(key) or {}) do
		if o.k == "b" or o.k == "d" then
			local inst = o.k == "b" and o.inst or o.id
			local name = Int:GetInstanceName(inst)
			if name then return L.PLACE_FMT:format(Int:InstanceKind(inst, o.diff), name) end
		elseif (o.k == "n" or o.k == "v" or o.k == "o" or o.k == "q") and o.map then
			return L.PLACE_FMT:format(Int:MapKind(o.map), Int:GetZoneName(o.map))
		elseif o.k == "z" then
			return L.PLACE_FMT:format(Int:MapKind(o.id), Int:GetZoneName(o.id))
		elseif o.k == "t" then
			local _, name, where = Data.ObtainLine(o)
			return where and L.PLACE_FMT:format(L.SRC_SET, where) or L.PLACE_FMT:format(L.SRC_SET, name)
		elseif o.k == "g" then
			local hdr = Int:GetHeaderName(o.hdr)
			local cat = L.SRC_CAT[o.cat] or L.SRC_CAT.u
			return hdr and hdr ~= "" and L.PLACE_FMT:format(cat, hdr) or cat
		end
	end
	-- Artifact without its own origin: its set. / Artefacto sin origen propio: su conjunto.
	if kind == "f" then
		local a = self:GetArtifact(id)
		return a and Int:GetHeaderName(a.set) or nil
	end
	-- Bought with a token: the vendor's zone. / Se compra con token: la zona del vendedor.
	local src = self:GetSources(key)
	if src and src[1] then
		local v = self:GetVendor(src[1][2])
		if v and v.map then return L.PLACE_FMT:format(Int:MapKind(v.map), Int:GetZoneName(v.map, v.npc)) end
	end
	return nil
end

---------------------------------------------------------------------------
-- Uses and crafting / Usos y fabricación
---------------------------------------------------------------------------
-- Uses sorted by usefulness: summon rare/boss/event, world object, starts a quest,
-- used with an NPC, achievement, quest turn-in.
-- Usos ordenados por utilidad: invocar raro/jefe/evento, objeto del mundo, inicia misión,
-- se usa con un NPC, logro, se entrega en misión.
local usesSorted = {}

local function usePriority(u)
	local kind, tag = u[1], u[6]
	if kind == "n" and (tag == "rare" or tag == "worldboss" or tag == "event") then return 1 end
	if kind == "o" then return 2 end
	if kind == "qs" then return 3 end
	if kind == "n" then return 4 end
	if kind == "a" then return 5 end
	return 6
end

-- Achievements that need the item (IL.ACH.needs, D-66): the materials of each criterion too.
-- Logros que piden el objeto (IL.ACH.needs, D-66): también los materiales de cada criterio.
local function achNeeds(key)
	local kind, id = IL.SplitKey(key)
	local needs = kind == "i" and IL.ACH and IL.ACH.needs
	return needs and needs[id]
end

function Data:GetUses(key)
	if usesSorted[key] ~= nil then return usesSorted[key] or nil end
	local raw = DB.uses and DB.uses[key]
	local extra = achNeeds(key)
	if not raw and not extra then usesSorted[key] = false return nil end
	local list, seenAch = {}, {}
	for i, u in ipairs(raw or {}) do
		list[i] = u
		if u[1] == "a" then seenAch[u[2]] = true end
	end
	for _, ach in ipairs(extra or {}) do
		if not seenAch[ach] then list[#list + 1] = { "a", ach, nil, nil, nil, nil, 1 } end
	end
	table.sort(list, function(a, b)
		local pa, pb = usePriority(a), usePriority(b)
		if pa ~= pb then return pa < pb end
		return (a[2] or 0) < (b[2] or 0)
	end)
	usesSorted[key] = list
	return list
end

-- Our own note on how to get an item that ATT has no source for, from the achievement that
-- needs it (fountain coins, Brew of the Month…). / Nota propia de cómo conseguir un objeto sin
-- origen en ATT, según el logro que lo pide (monedas de la fuente, cerveza del mes…). D-66
function Data:GetAchObtainNotes(key)
	local achs = achNeeds(key)
	if not achs then return nil end
	local out, seen = {}, {}
	for _, ach in ipairs(achs) do
		local note = L.ACH_ITEM_NOTE and L.ACH_ITEM_NOTE[ach]
		if note and not seen[note] then seen[note] = true; out[#out + 1] = note end
	end
	return #out > 0 and out or nil
end

-- Items a world object asks for (key, offering…): reverse of the "o" uses, built once. D-68
-- Objetos que pide un objeto del mundo (llave, ofrenda…): inverso de los usos "o", se arma una vez. D-68
local openers
function Data:GetOpeners(objectID)
	if not openers then
		openers = {}
		for key, list in pairs(DB.uses or {}) do
			for _, u in ipairs(list) do
				if u[1] == "o" then
					local l = openers[u[2]]
					if not l then l = {}; openers[u[2]] = l end
					l[#l + 1] = { key, u[7] or 1 }
				end
			end
		end
		for _, l in pairs(openers) do table.sort(l, function(a, b) return a[1] < b[1] end) end
	end
	return openers[objectID]
end

-- "Opens with: Corroded Key" / "Se abre con: Llave corroída"
function Data:OpenersLine(objectID)
	local list = self:GetOpeners(objectID)
	if not list then return nil end
	local names = {}
	for i, e in ipairs(list) do
		if i > 3 then names[#names + 1] = "…"; break end
		names[#names + 1] = self:GetDisplayName(e[1]) .. (e[2] > 1 and (" × " .. e[2]) or "")
	end
	return L.OPENS_WITH:format(table.concat(names, ", "))
end

-- What a world object that asks for an item gives (reverse of the "o" sources), only for the
-- objects in GetOpeners, built once. D-68
-- Lo que da un objeto del mundo que pide un objeto (inverso de los orígenes "o"), solo para los
-- objetos de GetOpeners, se arma una vez. D-68
local objectLoot
function Data:GetObjectLoot(objectID)
	if not objectLoot then
		objectLoot = {}
		self:GetOpeners(0) -- builds the openers index / arma el índice de openers
		for itemID, raw in pairs(DB.sources or {}) do
			for oid in raw:gmatch("o(%d+),") do
				oid = tonumber(oid)
				if openers[oid] then
					local l = objectLoot[oid]
					if not l then l = {}; objectLoot[oid] = l end
					l[#l + 1] = "i" .. itemID
				end
			end
		end
		for _, l in pairs(objectLoot) do table.sort(l) end
	end
	return objectLoot[objectID]
end

-- Third line of a "starts a quest" use: where it is turned in and the upgrade it unlocks. D-68
-- Tercera línea de "inicia la misión": dónde se entrega y la mejora que desbloquea. D-68
function Data.UseExtra(u)
	if u[1] == "o" then
		-- A treasure that asks for this item: what it gives, clickable. D-68
		-- Un tesoro que pide este objeto: lo que da, clicable. D-68
		local loot = Data:GetObjectLoot(u[2])
		if not loot then return nil end
		local names = {}
		for i, key in ipairs(loot) do
			if i > 3 then names[#names + 1] = "…"; break end
			names[#names + 1] = Data:GetDisplayName(key)
		end
		return L.OBJECT_GIVES:format(table.concat(names, ", "))
	end
	if u[1] ~= "qs" then return nil end
	local parts = {}
	if u[9] then parts[#parts + 1] = L.USE_TURN_IN:format(IL.Int:GetNPCName(u[9])) end
	if u[8] then
		local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(u[8])
		if name and name ~= "" then parts[#parts + 1] = L.USE_UNLOCKS:format(name) end
	end
	return #parts > 0 and table.concat(parts, " · ") or nil
end

local function useLine(u)
	local Int = IL.Int
	local kind, id, tag = u[1], u[2], u[6]
	local suffix = tag and L.TAG[tag] and (" (" .. L.TAG[tag] .. ")") or ""
	if kind == "n" then
		local fmt = (tag == "rare" or tag == "worldboss" or tag == "event") and L.USE_SUMMON or L.USE_WITH_NPC
		return fmt:format(Int:GetNPCName(id)) .. suffix
	elseif kind == "o" then
		return L.USE_OBJECT:format(Int:GetObjectName(id)) .. suffix
	elseif kind == "qs" then
		return L.USE_QUEST_START:format(Int:GetQuestTitle(id))
	elseif kind == "a" then
		return L.USE_ACHIEVEMENT:format(Int:GetAchievementName(id))
	end
	return L.USE_QUEST:format(Int:GetQuestTitle(id))
end
Data.UseLine = useLine

-- Items crafted with this reagent, imported and learned: { { itemID, qty, learned }, … }.
-- Objetos que se fabrican con este material, importados y aprendidos.
function Data:GetCrafts(key)
	local kind, id = IL.SplitKey(key)
	if kind ~= "i" then return nil end
	if craftsCache[id] ~= nil then return craftsCache[id] or nil end
	local list, seen = {}, {}
	for _, x in ipairs(DB.reagents and DB.reagents[id] or {}) do list[#list + 1] = x; seen[x[1]] = true end
	for _, x in ipairs(IL.Learn and IL.Learn:GetCrafts(id) or {}) do
		if not seen[x[1]] then list[#list + 1] = x; seen[x[1]] = true end
	end
	craftsCache[id] = #list > 0 and list or false
	return craftsCache[id] or nil
end

-- Tooltip description lines from the client: "Use: …" and the flavor text in quotes.
-- Líneas de descripción del cliente: "Uso: …" y el texto entre comillas.
function Data:GetDescription(key)
	local kind, id = IL.SplitKey(key)
	if kind == "q" or kind == "f" then return nil end
	if kind == "c" then
		local info = currencyInfo(id)
		if info and info.description and info.description ~= "" then return { info.description } end
		return nil
	end
	local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
	if not ok or not data or IL.IsSecret(data) or not data.lines or IL.IsSecret(data.lines) then return nil end
	local out = {}
	local useText = ITEM_SPELL_TRIGGER_ONUSE or "Uso:"
	pcall(function()
		for i = 2, #data.lines do
			local text = data.lines[i].leftText
			if not IL.IsSecret(text) and type(text) == "string" and text ~= "" then
				if text:find(useText, 1, true) == 1 or text:sub(1, 1) == "\"" then
					out[#out + 1] = text
					if #out >= 3 then break end
				end
			end
		end
	end)
	return #out > 0 and out or nil
end

-- What an item is for: a one-line summary and every line for the detail panel. Sources:
-- known uses, what a token buys, reagent count, and the client's type as a last resort.
-- Para qué sirve un objeto: resumen de una línea y todas las líneas del detalle. Fuentes:
-- usos conocidos, lo que compra un token, recetas que lo usan y, al final, el tipo del cliente.
function Data:GetPurpose(key)
	local lines = {}

	local uses = self:GetUses(key)
	if uses then
		local first = useLine(uses[1])
		lines[#lines + 1] = #uses > 1 and (first .. L.USE_MORE:format(#uses - 1)) or first
	end

	local breakdown = self:GetRewardBreakdown(key)
	if breakdown and breakdown ~= "" then
		lines[#lines + 1] = L.BUYS:format(breakdown)
	end

	local crafts = self:GetCrafts(key)
	if crafts then
		local _, id = IL.SplitKey(key)
		local _, _, subType = C_Item.GetItemInfoInstant(id)
		local sub = subType and subType ~= "" and (" (" .. subType .. ")") or ""
		lines[#lines + 1] = L.REAGENT:format(sub, #crafts)
	end

	if #lines == 0 then
		local kind, id = IL.SplitKey(key)
		if kind == "i" then
			local _, itemType, subType = C_Item.GetItemInfoInstant(id)
			if itemType then
				lines[#lines + 1] = (subType and subType ~= "" and subType ~= itemType) and (itemType .. " · " .. subType) or itemType
			end
		end
	end

	return lines[1], lines
end

---------------------------------------------------------------------------
-- Expansion labels / Etiquetas de expansión
---------------------------------------------------------------------------
local EXP_SHORT = { [0] = "CL", "TBC", "WLK", "CTM", "MOP", "WOD", "LEG", "BFA", "SL", "DF", "TWW", "MN" }

function Data:ExpansionShort(exp)
	return exp and EXP_SHORT[exp] or nil
end

function Data:ExpansionName(exp)
	if not exp then return L.UNKNOWN_EXP end
	return _G["EXPANSION_NAME" .. exp] or EXP_SHORT[exp] or L.UNKNOWN_EXP
end

---------------------------------------------------------------------------
-- Faction (D-59) / Facción (D-59)
---------------------------------------------------------------------------
-- 1 = Horde only, 2 = Alliance only, nil = both (or not known). NPCs, quests and marked items
-- come from AllTheThings; an item is one faction's only when every source it has is.
-- 1 = solo Horda, 2 = solo Alianza, nil = ambas (o no se sabe). NPC, misiones y objetos marcados
-- vienen de AllTheThings; un objeto es de una facción solo si todos sus orígenes lo son.
Data.HORDE, Data.ALLIANCE = 1, 2
Data._facCache = {}

local function factions() return DB.factions or { n = {}, q = {}, i = {} } end

function Data:NpcFaction(npc) return npc and factions().n[npc] or nil end

-- Faction of one source of "How to get it". / Facción de un origen de "Cómo se obtiene".
function Data:OriginFaction(o)
	if not o then return nil end
	local F = factions()
	if o.k == "n" or o.k == "v" then return F.n[o.id] end
	if o.k == "q" then return F.q[o.id] end
	if o.k == "a" then return IL.ACH and IL.ACH.faction and IL.ACH.faction[o.id] or nil end
	return nil
end

function Data:GetFaction(key)
	local cached = self._facCache[key]
	if cached ~= nil then return cached or nil end
	local kind, id = IL.SplitKey(key)
	local F = factions()
	local f
	if kind == "q" then
		f = F.q[id]
	elseif kind == "i" then
		f = F.i[id]
		if not f then
			local seen, all, any = nil, true, false
			local function take(x)
				any = true
				if not x then all = false
				elseif seen == nil then seen = x
				elseif seen ~= x then all = false end
			end
			for _, o in ipairs(self:GetObtain(key) or {}) do take(self:OriginFaction(o)) end
			for _, src in ipairs(self:GetSources(key) or {}) do take(F.n[src[2]]) end
			if any and all then f = seen end
		end
	end
	self._facCache[key] = f or false
	return f
end

