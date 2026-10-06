--[[
	ItemLens · Modules/Data.lua
	Read access to the bundled database (IL.DB) merged with what ItemLens learns in game,
	plus item information from the client: names, icons, expansions, sources, uses, crafts.
	Acceso a la base de datos incluida (IL.DB) unida a lo que ItemLens aprende en el juego,
	más la información del cliente: nombres, íconos, expansiones, orígenes, usos y recetas.
	© 2026 TavoD_Gus_KrG · MIT License

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
		IL:RequestRefresh()
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
		else loader.running = false; IL:RequestRefresh() end
	end
	step()
end

function Data:GetLoaderProgress()
	return loader.running, loader.total - loader.pending, loader.total
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
--   q quest,map,x,y[,w|d,faction,reputation]   a achievement   p skillLine   c container item   z map
--   d instance,difficulty   r faction,value   g categoryCode,header
local ORIGIN_ORDER = { b = 1, d = 2, n = 3, v = 4, o = 5, q = 6, a = 7, r = 8, p = 9, c = 10, z = 11, g = 12 }
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
		return { k = "q", id = n(1), map = n(2), x = n(3), y = n(4),
			repeats = (f[5] == "w" and "weekly") or (f[5] == "d" and "daily") or nil, repFaction = n(6), repValue = n(7) }
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
		return L.SRC_TREASURE, Int:GetObjectName(o.id), zoneWhere(o.map)
	elseif o.k == "q" then
		-- Weekly/daily label, and the reputation it requires next to the place.
		-- Etiqueta semanal/diaria, y la reputación que pide junto al lugar.
		local label = (o.repeats == "weekly" and L.SRC_QUEST_WEEKLY) or (o.repeats == "daily" and L.SRC_QUEST_DAILY) or L.SRC_QUEST
		local where = zoneWhere(o.map)
		if o.repFaction then
			local rep = L.REQUIRES:format(Int:GetFactionName(o.repFaction) .. " — " .. Int:StandingName(o.repValue, o.repFaction))
			where = where and (where .. " · " .. rep) or rep
		end
		return label, Int:GetQuestTitle(o.id), where
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

function Data:GetUses(key)
	if usesSorted[key] ~= nil then return usesSorted[key] or nil end
	local raw = DB.uses and DB.uses[key]
	if not raw then usesSorted[key] = false return nil end
	local list = {}
	for i, u in ipairs(raw) do list[i] = u end
	table.sort(list, function(a, b)
		local pa, pb = usePriority(a), usePriority(b)
		if pa ~= pb then return pa < pb end
		return (a[2] or 0) < (b[2] or 0)
	end)
	usesSorted[key] = list
	return list
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
