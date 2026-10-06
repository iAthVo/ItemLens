-- ItemLens · extractor de datos de AllTheThings (solo desarrollo, fuera del juego).
-- Datos de ATT bajo su licencia MIT, con crédito (D-12, D-43): licenses/AllTheThings-MIT.txt.
--
-- Uso:
--   lua att_extract.lua <ruta AllTheThings> <archivo salida> [expansiones, ej. 10,11,12 | all]
--
-- Carga db\Standard\Categories\*.lua en un entorno aislado (los constructores de ATT se
-- reemplazan por funciones que solo arman tablas), recorre el árbol y extrae:
--   vendedor (npcID + coordenadas) · objeto que vende · costo en objetos/monedas.
-- El costo en oro se ignora: solo interesan canjes de tokens y monedas.

local attRoot = assert(arg[1], "falta ruta a AllTheThings")
local outPath = assert(arg[2], "falta archivo de salida")
local expArg  = arg[3] or "10,11,12"

local wantExp
if expArg ~= "all" then
	wantExp = {}
	for n in expArg:gmatch("%d+") do wantExp[tonumber(n)] = true end
end

---------------------------------------------------------------------------
-- Entorno aislado
---------------------------------------------------------------------------
local stub
stub = setmetatable({}, { __index = function() return stub end, __call = function() return stub end })
setmetatable(_G, { __index = function() return stub end }) -- globales de WoW (GetCVar, etc.)

local handlers = {}
local ATT = setmetatable({}, { __index = function(t, k)
	if type(k) == "string" and k:sub(1, 6) == "Create" then
		local kind = k:sub(7)
		local f = function(id, a2, a3)
			local data
			if type(id) == "table" and a2 == nil then data, id = id, nil
			elseif type(a2) == "table" then data = a2
			else data = (type(a3) == "table" and a3) or {}; data.__arg2 = a2 end
			data.__kind, data.__id = kind, id
			return data
		end
		rawset(t, k, f)
		return f
	end
	return stub
end })
ATT.AddEventHandler = function(ev, fn) handlers[#handlers + 1] = { ev = ev, fn = fn } end
ATT.WOWAPI = setmetatable({}, { __index = function() return function() return 0 end end })

local function readVersion()
	local fh = io.open(attRoot .. "\\AllTheThings.toc", "rb")
	if not fh then return "?" end
	local s = fh:read("*a"); fh:close()
	return s:match("## Version:%s*([^\r\n]+)") or "?"
end

local files = { "Instances", "Zones", "ExpansionFeatures", "Holidays", "WorldEvents", "PVP",
	"Professions", "Craftables", "Delves", "Character", "GroupFinder", "Promotions", "Unsorted",
	"WorldDrops", "Housing", "TradingPost", "BlackMarket", "Sourceless", "Secrets", "InGameShop",
	"NeverImplemented" }

local categories, loadErrors = {}, {}
for _i, name in ipairs(files) do
	local path = attRoot .. "\\db\\Standard\\Categories\\" .. name .. ".lua"
	local fh = io.open(path, "rb")
	if fh then
		local src = fh:read("*a"); fh:close()
		if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end -- BOM UTF-8
		local chunk, err = loadstring(src, "=" .. name)
		if not chunk then loadErrors[#loadErrors + 1] = name .. ": " .. err
		else
			local ok, e = pcall(chunk, "AllTheThings", ATT)
			if not ok then loadErrors[#loadErrors + 1] = name .. ": " .. tostring(e) end
		end
	end
end
for _i, h in ipairs(handlers) do
	if h.ev == "OnBuildDataCache" then
		local ok, e = pcall(h.fn, categories)
		if not ok then loadErrors[#loadErrors + 1] = "handler: " .. tostring(e) end
	end
end

---------------------------------------------------------------------------
-- Recorrido
---------------------------------------------------------------------------
-- MountMod = manuscritos de dracoequitación: su __id es el itemID (v8.0.0)
local ITEM_KINDS = { Item = true, Toy = true, Heirloom = true, MountMod = true }
-- Encabezado "Trading Post" de ATT. Se guarda como pseudo-vendedor con ID -230
-- (no tiene NPC ni coordenadas fijas; está en las capitales).
TRADING_POST = -230

-- ATT usa a veces itemID.modID (183888.003): se normaliza al itemID entero.
local function itemIDOf(node)
	local id
	if node.itemID then id = node.itemID
	elseif node.__kind == "ItemSource" then id = node.__arg2
	elseif ITEM_KINDS[node.__kind] then id = node.__id end
	return type(id) == "number" and math.floor(id) or nil
end

local function firstCoord(coords)
	if type(coords) ~= "table" then return end
	-- formato compacto: { [mapID] = { {x, y}, ... } }
	for mapID, list in pairs(coords) do
		if type(mapID) == "number" and type(list) == "table" and type(list[1]) == "table" then
			return mapID, list[1][1], list[1][2]
		end
	end
	-- formato clásico: { {x, y, mapID}, ... }
	local c = coords[1]
	if type(c) == "table" and type(c[3]) == "number" then return c[3], c[1], c[2] end
end

-- Encabezados de ATT que clasifican lo que se invoca o activa
TAGS = {
	[-46] = "rare", [-61] = "worldboss", [-56] = "treasure", [-50] = "secret",
	[-29] = "event", [-83] = "event", [-470] = "event", [-681] = "event", [-723] = "event", [-741] = "event",
}
-- Tipo de nodo → tipo de uso: n = invoca NPC, o = objeto del mundo, q = se entrega en misión
USE_KINDS = { NPC = "n", Object = "o", Quest = "q" }

-- Origen de cada objeto (v7.0.0): tipo de nodo de ATT → letra
--   b = botín de jefe (Encounter), n = NPC/raro, q = misión, a = logro, o = objeto del mundo, p = profesión
SRC_KINDS = { Encounter = "b", NPC = "n", Quest = "q", Achievement = "a", Object = "o", Profession = "p" }
MAX_SOURCES = 12 -- tope por objeto (algunos aparecen en decenas de lugares)

local vendors, offers = {}, {}
local uses, seenUse, objectIDs = {}, {}, {}
local sources, seenSrc, zoneOf, catOf = {}, {}, {}, {}
local collections = { mm = {}, cq = {}, cs = {} } -- v8.0.0
unlockNoItem = {} -- diagnóstico: desbloqueos sin objeto, por clase
glyphCandidates, glyphSample = {}, {} -- diagnóstico: glifos de Inscripción por clase
classQuests = {} -- diagnóstico: misiones exclusivas por clase
classQuestData = {} -- v9.0.0: [questID] = {classID, expATT, mapID, x, y, {recompensas}}
artifacts = {} -- v10.0.0: [appearanceID] = {cls, weapon, source, set, origins}
local seen = {}
local stats = { offers = 0, skippedExp = 0, noExp = 0, noVendor = 0, goldOnly = 0, uses = 0, sources = 0,
	extra = { providers = 0, container = 0, crs = 0, skill = 0, zone = 0, instance = 0, category = 0 } }

-- Categorías de ATT → código de una letra para el respaldo "g" (v7.1.0)
CATEGORY_CODE = {
	WorldDrops = "w", PVP = "j", ExpansionFeatures = "x", Character = "k", WorldEvents = "e",
	Holidays = "e", InGameShop = "s", Promotions = "m", TradingPost = "t", GroupFinder = "f",
	Delves = "v", Instances = "i", Craftables = "c", Professions = "p", Secrets = "r",
	Housing = "h", BlackMarket = "b", Sourceless = "u", Unsorted = "u", Zones = "z",
}
-- Categorías que no se recorren: objetos que nunca llegaron al juego
SKIP_CATEGORY = { NeverImplemented = true }
local usedHeaders = {}
local expCount = {}

local function expOf(ctx)
	if ctx.exp then return ctx.exp end
	if ctx.awp then return math.floor(ctx.awp / 10000) end
end

-- Diagnóstico: ITEMLENS_DEBUG=1 agrupa por ruta los objetos de exp >= 10 que tienen
-- costo pero no tienen vendedor.
TRACE = tonumber(os.getenv("ITEMLENS_TRACE") or "")
TRACE_ART = tonumber(os.getenv("ITEMLENS_TRACE_ART") or "")
DEBUG = os.getenv("ITEMLENS_DEBUG") == "1" or TRACE ~= nil or TRACE_ART ~= nil
PATH, noVendorPaths = {}, {}

local walk
local function walkInner(node, ctx)
	local kind = node.__kind

	-- Vendedor indicado por campo en lugar de nodo NPC padre
	local fieldNpc
	if type(node.crs) == "table" and type(node.crs[1]) == "number" then fieldNpc = node.crs[1] end
	if not fieldNpc and type(node.providers) == "table" then
		for _i, p in ipairs(node.providers) do
			if p[1] == "n" and type(p[2]) == "number" then fieldNpc = p[2]; break end
		end
	end
	local isTradingPost = kind == "CustomHeader" and node.__id == TRADING_POST
	local tag = kind == "CustomHeader" and TAGS[node.__id]

	-- Origen (v7.0.0): el nodo "fuente" más cercano (jefe, NPC, misión, logro, objeto, profesión)
	local srcKind = SRC_KINDS[kind]
	local validId = type(node.__id) == "number" and node.__id > 0
	local isInstance = (kind == "Instance" or kind == "Difficulty") and validId
	local isMap = kind == "Map" and validId
	local reqSkill = type(node.requireSkill) == "number" and node.requireSkill or nil
	-- Encabezados: el primero es la raíz de la categoría; el segundo, el subtítulo (v7.1.0)
	local isHeader = (kind == "CustomHeader" or kind == "Header") and type(node.__id) == "number"
	local newRoot = isHeader and not ctx.hdrRoot
	local newHdr1 = isHeader and ctx.hdrRoot and not ctx.hdr1

	-- Conjuntos de colección (v8.0.0): clase y encabezado positivo (montura de los manuscritos)
	local isClass = kind == "CharacterClass" and validId
	local isMMRoot = kind == "CustomHeader" and node.__id == -185 -- "Drakewatcher Manuscript"
	local isPosHeader = kind == "Header" and validId and ctx.mmRoot -- montura, solo dentro de -185
	-- Armas artefacto (v10.0.0): catálogo "-214 › clase › arma (Header = itemID) › conjunto"
	local isArtRoot = kind == "CustomHeader" and node.__id == -214
	local isArtWeapon = kind == "Header" and validId and ctx.artRoot and not ctx.artWeapon
	local isArtSet = kind == "CustomHeader" and type(node.__id) == "number" and node.__id < 0 and ctx.artWeapon and not ctx.artSet

	-- Contexto heredado
	local c = ctx
	if kind == "Expansion" or type(node.awp) == "number" or (kind == "NPC" and type(node.__id) == "number" and node.__id > 0) or node.coords or node.coord or fieldNpc or isTradingPost or tag or (srcKind and validId) or isInstance or isMap or reqSkill or newRoot or newHdr1 or isClass or isPosHeader or isMMRoot or (kind == "CustomHeader" and type(node.__id) == "number" and node.__id < 0) or isArtRoot or isArtWeapon then
		c = setmetatable({}, { __index = ctx })
		if isArtRoot then c.artRoot = true end
		if isArtWeapon then c.artWeapon = node.__id end
		if isArtSet then c.artSet = node.__id end
		if isClass then c.class = node.__id end
		if isMMRoot then c.mmRoot = true end
		if kind == "CustomHeader" and type(node.__id) == "number" and node.__id < 0 then c.hdrNear = node.__id end
		if isPosHeader then c.posHdr = node.__id end
		if tag then c.tag = tag end
		if newRoot then c.hdrRoot = node.__id end
		if newHdr1 then c.hdr1 = node.__id end
		if isMap then c.zmap = node.__id end           -- zona más cercana (v7.1.0)
		if reqSkill then c.reqSkill = reqSkill end     -- profesión requerida (v7.1.0)
		if srcKind and validId then
			c.src, c.srcId = srcKind, node.__id
			-- Lugar del nodo fuente (v7.2.0): coordenadas propias o, si no, la zona donde está
			local sm, sx, sy = firstCoord(node.coords)
			if sm then c.srcM, c.srcX, c.srcY = sm, sx, sy
			else c.srcM, c.srcX, c.srcY = ctx.zmap, nil, nil end
			-- Quests: weekly/daily and the reputation they require, so ItemLens can explain them
			-- even when the server won't send the title.
			-- Misiones: semanal/diaria y la reputación que piden, para explicarlas aunque el
			-- servidor no dé el título.
			if srcKind == "q" then
				c.srcFlag = (node.isWeekly and "w") or (node.isDaily and "d") or false
				local rep = node.minReputation
				c.srcRep = (type(rep) == "table" and type(rep[1]) == "number") and rep or false
			end
		end
		if kind == "Instance" and validId then c.inst = node.__id end
		if kind == "Difficulty" and validId then c.diff = node.__id end
		if isTradingPost then c.npc = TRADING_POST; c.npcM, c.npcX, c.npcY = nil, nil, nil end
		if fieldNpc and not ctx.npc then
			c.npc = fieldNpc
			local m, x, y = firstCoord(node.coords)
			c.npcM, c.npcX, c.npcY = m or ctx.m, x or ctx.x, y or ctx.y
		end
		if kind == "Expansion" and type(node.__id) == "number" then c.exp = node.__id end
		if type(node.awp) == "number" then c.awp = node.awp end
		local m, x, y = firstCoord(node.coords)
		if not m and type(node.coord) == "table" then m, x, y = node.coord[3], node.coord[1], node.coord[2] end
		if m then c.m, c.x, c.y = m, x, y end
		if kind == "NPC" and type(node.__id) == "number" and node.__id > 0 then
			c.npc = node.__id
			c.npcM, c.npcX, c.npcY = c.m, c.x, c.y
		end
	end

	-- ¿Se compra con un token o una moneda?
	if type(node.cost) == "table" then
		local iid = itemIDOf(node)
		local npc = c.npc
		if iid and not npc then
			stats.noVendor = stats.noVendor + 1
			if DEBUG then
				local e = expOf(c) or 0
				if e >= 10 then
					local key = table.concat(PATH, " > ", 1, math.min(#PATH, 4))
					noVendorPaths[key] = (noVendorPaths[key] or 0) + 1
				end
			end
		end
		if iid and npc then
			local e = expOf(c)
			if not e then stats.noExp = stats.noExp + 1 end
			if wantExp and not (e and wantExp[e]) then
				stats.skippedExp = stats.skippedExp + 1
			else
				local any = false
				for _i, cost in ipairs(node.cost) do
					local t, id, qty = cost[1], cost[2], cost[3]
					if type(id) == "number" then id = math.floor(id) end -- ATT usa itemID.modID (183888.003)
					if (t == "i" or t == "c") and type(id) == "number" then
						any = true
						local key = t .. id
						local dedupe = key .. ":" .. npc .. ":" .. iid
						if not seen[dedupe] then
							seen[dedupe] = true
							offers[key] = offers[key] or {}
							table.insert(offers[key], { npc, iid, qty or 1 })
							stats.offers = stats.offers + 1
							if e then expCount[e] = (expCount[e] or 0) + 1 end
						end
					end
				end
				if any then
					local v = vendors[npc]
					if not v then
						-- El Puesto comercial abarca todas las expansiones: sin expansión propia
						vendors[npc] = { m = c.npcM, x = c.npcX, y = c.npcY, e = npc ~= TRADING_POST and e or nil }
					elseif not v.m and c.npcM then
						v.m, v.x, v.y = c.npcM, c.npcX, c.npcY
					end
				else
					stats.goldOnly = stats.goldOnly + 1
				end
			end
		end
	end

	-- ¿De dónde sale este objeto? (v7.0.0)
	-- Los canjes con tokens ya están en `offers`; aquí van los demás orígenes.
	local srcItem = itemIDOf(node)
	-- Diagnóstico: ITEMLENS_TRACE_ART=<appearanceID> imprime la ruta de una apariencia de artefacto
	if TRACE_ART and kind == "Artifact" and node.__id == TRACE_ART then
		print("TRACEART " .. node.__id .. " | ruta: " .. table.concat(PATH, " > ") .. " | src=" .. tostring(c.src) .. ":" .. tostring(c.srcId)
			.. " rep=" .. tostring(node.minReputation and "sí" or "no") .. " skill=" .. tostring(node.requireSkill or c.reqSkill))
	end
	-- Diagnóstico: ITEMLENS_TRACE=<itemID> imprime la ruta de ese objeto en el árbol de ATT
	if TRACE and srcItem == TRACE then
		local function fields(t)
			local out = {}
			for _i, k in ipairs({ "description", "requireSkill", "crs", "providers", "maps", "mapID", "cost", "coords" }) do
				if t[k] ~= nil then out[#out + 1] = k .. "=" .. (type(t[k]) == "table" and "{...}" or tostring(t[k]):sub(1, 90)) end
			end
			return table.concat(out, " ")
		end
		print("TRACE " .. srcItem .. " | ruta: " .. table.concat(PATH, " > "))
		print("      nodo: " .. fields(node) .. " | src=" .. tostring(c.src) .. ":" .. tostring(c.srcId) .. " m=" .. tostring(c.m))
	end
	if srcItem and (not wantExp or (expOf(c) and wantExp[expOf(c)])) then
		local key = "i" .. srcItem
		local function addSrc(entry)
			if not entry or type(entry[2]) ~= "number" then return end
			entry[2] = math.floor(entry[2])
			local dedupe = key .. ":" .. entry[1] .. ":" .. entry[2] .. ":" .. tostring(entry[1] == "b" and entry[4] or "")
			local list = sources[key]
			if seenSrc[dedupe] or (list and #list >= MAX_SOURCES) then return end
			seenSrc[dedupe] = true
			if entry[1] == "o" then objectIDs[entry[2]] = true end
			sources[key] = list or {}
			table.insert(sources[key], entry)
			stats.sources = stats.sources + 1
		end

		-- 1. Nodo padre (v7.0.0)
		if type(node.cost) == "number" and c.npc and c.npc > 0 then
			addSrc({ "v", c.npc, c.npcM, c.npcX, c.npcY, node.cost }) -- vendedor con oro
		elseif type(node.cost) ~= "table" and c.src then
			local s, id = c.src, c.srcId
			if s == "b" then addSrc({ "b", id, c.inst, c.diff })
			elseif s == "n" then addSrc({ "n", id, c.npcM or c.m, c.npcX or c.x, c.npcY or c.y, c.tag })
			elseif s == "o" then addSrc({ "o", id, c.m, c.x, c.y })
			elseif s == "q" then
				local rep = c.srcRep or nil
				addSrc({ "q", id, c.srcM, c.srcX, c.srcY, c.srcFlag or nil, rep and rep[1], rep and rep[2] })
			else addSrc({ s, id }) end -- a, p
		end

		-- 2. Campos del propio objeto (v7.1.0): providers (objeto del mundo, NPC, contenedor) y crs
		if type(node.providers) == "table" then
			for _i, p in ipairs(node.providers) do
				if type(p) == "table" and type(p[2]) == "number" then
					if p[1] == "o" then addSrc({ "o", p[2], c.m, c.x, c.y }); stats.extra.providers = stats.extra.providers + 1
					elseif p[1] == "n" then addSrc({ "n", p[2], c.m, c.x, c.y, c.tag }); stats.extra.providers = stats.extra.providers + 1
					elseif p[1] == "i" then addSrc({ "c", p[2] }); stats.extra.container = stats.extra.container + 1 end
				end
			end
		end
		if type(node.crs) == "table" then
			for _i, npc in ipairs(node.crs) do
				if type(npc) == "number" then addSrc({ "n", npc, c.m, c.x, c.y, c.tag }); stats.extra.crs = stats.extra.crs + 1 end
			end
		end

		-- 3. Profesión requerida en el objeto o en un padre (pesca, minería…) (v7.1.0)
		local skill = (type(node.requireSkill) == "number" and node.requireSkill) or c.reqSkill
		if skill then addSrc({ "p", skill }); stats.extra.skill = stats.extra.skill + 1 end

		-- 4. Botín de instancia sin jefe: dentro de una mazmorra/banda, sin otro origen (v7.1.0)
		if c.inst and not sources[key] then
			addSrc({ "d", c.inst, c.diff }); stats.extra.instance = stats.extra.instance + 1
		end

		-- 5. Respaldos (se aplican al final, solo si no hubo nada más): zona y categoría de ATT
		if c.zmap and not zoneOf[key] then zoneOf[key] = c.zmap end
		if c.cat and not catOf[key] then catOf[key] = { c.cat, c.hdr1 } end
	end

	-- Conjuntos de colección (v8.0.0)
	--   mm: manuscritos (itemID → misión oculta, montura a la que pertenecen)
	--   cq: desbloqueos de clase por misión oculta (tomos, glifos…)
	--   cs: desbloqueos de clase por hechizo (tomos de doma…)
	do
		local e = expOf(c)
		-- Clase: la del nodo CharacterClass padre o, si no, la restricción del propio objeto
		-- (campo `c` de ATT = lista de classID; solo si es una sola clase)
		local cls = c.class
		if not cls and type(node.c) == "table" and #node.c == 1 and type(node.c[1]) == "number" then cls = node.c[1] end
		if kind == "Artifact" and validId and not node.isOffHand then
			-- Apariencia de arma artefacto (v10.0.0). El catálogo (-214) da clase/arma/conjunto;
			-- las demás apariciones en el árbol dan cómo se consigue.
			local a = artifacts[node.__id]
			if not a then a = { origins = {}, seenO = {} }; artifacts[node.__id] = a end
			a.cls = a.cls or cls
			a.weapon = a.weapon or c.artWeapon
			a.source = a.source or (type(node.sourceID) == "number" and node.sourceID or nil)
			if c.artSet and not a.set then a.set = c.artSet; usedHeaders[c.artSet] = true end
			if not c.artRoot then
				local function addO(entry)
					if not entry or type(entry[2]) ~= "number" then return end
					local d = entry[1] .. ":" .. entry[2]
					if a.seenO[d] or #a.origins >= 8 then return end
					a.seenO[d] = true
					if entry[1] == "o" then objectIDs[entry[2]] = true end
					a.origins[#a.origins + 1] = entry
				end
				local s, id = c.src, c.srcId
				if s == "b" then addO({ "b", id, c.inst, c.diff })
				elseif s == "n" then addO({ "n", id, c.npcM or c.m, c.npcX or c.x, c.npcY or c.y, c.tag })
				elseif s == "o" then addO({ "o", id, c.m, c.x, c.y })
				elseif s == "q" then addO({ "q", id, c.srcM, c.srcX, c.srcY })
				elseif s then addO({ s, id }) end -- a, p
				-- Reputación requerida: {facción, valor}
				if type(node.minReputation) == "table" and type(node.minReputation[1]) == "number" then
					addO({ "r", node.minReputation[1], node.minReputation[2] })
				end
				local skill = (type(node.requireSkill) == "number" and node.requireSkill) or c.reqSkill
				if skill then addO({ "p", skill }) end
			end
		elseif kind == "MountMod" and validId then
			local group = c.mmRoot and c.posHdr or nil
			local cur = collections.mm[node.__id]
			if not cur then
				collections.mm[node.__id] = { node.questID, group, e }
			elseif not cur[2] and group then
				cur[2] = group -- preferir la ruta que trae la montura
			end
		elseif kind == "Quest" and validId and cls then
			-- Diagnóstico: misiones exclusivas de una clase (y si dan recompensas)
			local d = classQuests[cls] or { n = 0, withReward = 0, byExp = {}, active = 0, activeReward = 0 }
			classQuests[cls] = d
			if not d.seen then d.seen = {} end
			if not d.seen[node.__id] then
				d.seen[node.__id] = true
				d.n = d.n + 1
				local hasReward = false
				for _i, ch in ipairs(type(node.g) == "table" and node.g or node) do
					if type(ch) == "table" and itemIDOf(ch) then hasReward = true break end
				end
				if hasReward then d.withReward = d.withReward + 1 end
				-- Vigente: ATT no la marca retirada (rwp = retirada en un parche; u = no disponible)
				local retired = node.rwp ~= nil or (type(node.u) == "number" and node.u <= 2)
				if not retired then
					d.active = d.active + 1
					if hasReward then d.activeReward = d.activeReward + 1 end
					-- Misiones de clase (v9.0.0): clase, expansión, lugar y recompensas
					local m, x, y = firstCoord(node.coords)
					if not m then m = c.zmap end
					local rewards = {}
					for _i, ch in ipairs(type(node.g) == "table" and node.g or node) do
						local rid = type(ch) == "table" and itemIDOf(ch)
						if rid and #rewards < 8 then rewards[#rewards + 1] = rid end
					end
					classQuestData[node.__id] = { cls, e, m, x, y, rewards }
				end
				local ex = e or 0
				d.byExp[ex] = (d.byExp[ex] or 0) + 1
			end
		elseif (kind == "Item" or kind == "ItemSource") and cls and type(node.spellID) == "number"
			and (c.reqSkill == 773 or (c.src == "p" and c.srcId == 773)) then
			-- Diagnóstico: posibles glifos de Inscripción con clase (objeto que enseña un hechizo)
			glyphCandidates[cls] = (glyphCandidates[cls] or 0) + 1
			local id = itemIDOf(node)
			if id and not glyphSample[cls] then glyphSample[cls] = id .. ":" .. node.spellID end
		elseif (kind == "CharacterUnlockQuest" or kind == "CharacterUnlockSpell") and validId and type(node.itemID) ~= "number" then
			-- Diagnóstico: desbloqueos que no vienen de un objeto (no entran en la colección)
			unlockNoItem[cls or 0] = (unlockNoItem[cls or 0] or 0) + 1
		elseif (kind == "CharacterUnlockQuest" or kind == "CharacterUnlockSpell") and validId and type(node.itemID) == "number" then
			-- Lo que no es de una clase se agrupa por expansión en el juego
			local set = kind == "CharacterUnlockQuest" and collections.cq or collections.cs
			local item = math.floor(node.itemID)
			local cur = set[item]
			if not cur then set[item] = { node.__id, cls, e }
			elseif not cur[2] and cls then cur[2] = cls end
		end
	end

	-- ¿Para qué se usa un objeto? Invocar un NPC, activar un objeto del mundo,
	-- entregarse en una misión (cost) o iniciar una misión (providers).
	local useKind = USE_KINDS[kind]
	if useKind and type(node.__id) == "number" and node.__id > 0 then
		local e = expOf(c)
		if not wantExp or (e and wantExp[e]) then
			local m, x, y = firstCoord(node.coords)
			if not m then m, x, y = c.m, c.x, c.y end
			if not m then m = c.zmap end -- v7.2.0: al menos la zona
			local function addUse(itemID, k, qty)
				itemID = math.floor(itemID)
				local key = "i" .. itemID
				local dedupe = key .. ":" .. k .. ":" .. node.__id
				if seenUse[dedupe] then return end
				seenUse[dedupe] = true
				uses[key] = uses[key] or {}
				table.insert(uses[key], { k, node.__id, m, x, y, c.tag, qty or 1 })
				stats.uses = stats.uses + 1
				if k == "o" then objectIDs[node.__id] = true end
			end
			if type(node.cost) == "table" then
				for _i, cost in ipairs(node.cost) do
					if cost[1] == "i" and type(cost[2]) == "number" then addUse(cost[2], useKind, cost[3]) end
				end
			end
			if kind == "Quest" then
				for _i, p in ipairs(type(node.providers) == "table" and node.providers or {}) do
					if p[1] == "i" and type(p[2]) == "number" then addUse(p[2], "qs", 1) end
				end
				if type(node.provider) == "table" and node.provider[1] == "i" and type(node.provider[2]) == "number" then
					addUse(node.provider[2], "qs", 1)
				end
			end
		end
	end

	-- Logros que piden un objeto (v10.0.0): criterio con providers {"i", id}
	--   → uso {"a", achievementID}: "Se necesita para el logro: …"
	if kind == "AchievementCriteria" and type(node.achID) == "number" and type(node.providers) == "table" then
		for _i, p in ipairs(node.providers) do
			if type(p) == "table" and p[1] == "i" and type(p[2]) == "number" then
				local key = "i" .. math.floor(p[2])
				local dedupe = key .. ":a:" .. node.achID
				if not seenUse[dedupe] then
					seenUse[dedupe] = true
					uses[key] = uses[key] or {}
					table.insert(uses[key], { "a", node.achID, nil, nil, nil, nil, 1 })
					stats.uses = stats.uses + 1
					stats.achUses = (stats.achUses or 0) + 1
				end
			end
		end
	end

	-- Hijos: en `g` o, en la forma compacta de ATT, directo en la parte de arreglo
	-- de la tabla: h(-12, { hijo1, hijo2, ... }).
	if type(node.g) == "table" then
		for _i, child in ipairs(node.g) do walk(child, c) end
	end
	for _i, child in ipairs(node) do
		if type(child) == "table" and child.__kind then walk(child, c) end
	end
end

walk = function(node, ctx)
	if type(node) ~= "table" then return end
	if DEBUG then PATH[#PATH + 1] = tostring(node.__kind) .. ":" .. tostring(node.__id) end
	walkInner(node, ctx)
	if DEBUG then PATH[#PATH] = nil end
end

for name, cat in pairs(categories) do
	if type(cat) == "table" and not SKIP_CATEGORY[name] then
		local root = { cat = name }
		if cat.__kind then walk(cat, root) else for _i, n in ipairs(cat) do walk(n, root) end end
	end
end

-- Respaldos (v7.1.0), solo para objetos sin ningún otro origen ni canje:
--   1. la zona donde ATT lo ubica  →  {"z", mapID}
--   2. la categoría de ATT         →  {"g", código, encabezado}
local rewardItems = {}
for _k, list in pairs(offers) do for _i, o in ipairs(list) do rewardItems["i" .. o[2]] = true end end
for key, map in pairs(zoneOf) do
	if not sources[key] and not rewardItems[key] then
		sources[key] = { { "z", map } }
		stats.sources = stats.sources + 1
		stats.extra.zone = stats.extra.zone + 1
	end
end
for key, info in pairs(catOf) do
	local code = CATEGORY_CODE[info[1]]
	if code and not sources[key] and not rewardItems[key] then
		local hdr = info[2]
		if hdr and hdr < 0 then usedHeaders[hdr] = true else hdr = nil end -- solo encabezados con nombre
		sources[key] = { { "g", code, hdr } }
		stats.sources = stats.sources + 1
		stats.extra.category = stats.extra.category + 1
	end
end

-- Objetos de ATT que siguen sin origen (para revisarlos): tools/sin_origen.txt
local allItems, itemCat = {}, {}
local function collectItems(node, catName, path)
	if type(node) ~= "table" then return end
	local id = itemIDOf(node)
	if id then
		allItems["i" .. id] = true
		itemCat["i" .. id] = itemCat["i" .. id] or (catName .. (path ~= "" and (" > " .. path) or ""))
	end
	local sub = path
	if node.__kind == "CustomHeader" or node.__kind == "Header" or node.__kind == "Filter" then
		local depth = select(2, path:gsub(">", "")) + (path ~= "" and 1 or 0)
		if depth < 2 then sub = (path ~= "" and (path .. " > ") or "") .. node.__kind:sub(1, 1) .. tostring(node.__id) end
	end
	if type(node.g) == "table" then for _i, ch in ipairs(node.g) do collectItems(ch, catName, sub) end end
	for _i, ch in ipairs(node) do if type(ch) == "table" and ch.__kind then collectItems(ch, catName, sub) end end
end
for name, cat in pairs(categories) do
	if type(cat) == "table" and not SKIP_CATEGORY[name] then
		if cat.__kind then collectItems(cat, name, "") else for _i, n in ipairs(cat) do collectItems(n, name, "") end end
	end
end
ITEM_CATEGORY = itemCat
local noSource = {}
for key in pairs(allItems) do
	if not sources[key] and not rewardItems[key] then noSource[#noSource + 1] = tonumber(key:sub(2)) end
end
table.sort(noSource)
stats.allItems, stats.noSource = 0, #noSource
for _ in pairs(allItems) do stats.allItems = stats.allItems + 1 end
do
	local dir = outPath:match("^(.*)[\\/][^\\/]*$") or "."
	local fh = io.open(dir .. "\\..\\tools\\sin_origen.txt", "wb")
	if fh then
		fh:write("# Objetos de ATT sin origen conocido (", #noSource, "). Generado por att_extract.lua\n")
		for _i, id in ipairs(noSource) do fh:write(id, "\n") end
		fh:close()
	end
end

---------------------------------------------------------------------------
-- Materiales de profesión: ReferenceDB.ReagentsDB
--   [reagentItemID] = { [recipeSpellID] = { craftedItemID, cantidad }, ... }
-- Filtro: solo lo que fabrica objetos con ID >= el mínimo de la expansión más antigua
-- pedida (heurística por rangos de itemID; las expansiones se traslapan un poco).
---------------------------------------------------------------------------
local MIN_ITEM_ID = { [7] = 121000, [8] = 152000, [9] = 171000, [10] = 190000, [11] = 210000, [12] = 235000 }
local REAGENT_MIN_CRAFTED = 190000
if wantExp then
	local lowest
	for e in pairs(wantExp) do if not lowest or e < lowest then lowest = e end end
	REAGENT_MIN_CRAFTED = MIN_ITEM_ID[lowest] or 0
end
local reagents, nReagentLinks = {}, 0
do
	local fh = io.open(attRoot .. "\\db\\Standard\\ReferenceDB.lua", "rb")
	if fh then
		local src = fh:read("*a"); fh:close()
		if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
		local chunk, err = loadstring(src, "=ReferenceDB")
		if not chunk then loadErrors[#loadErrors + 1] = "ReferenceDB: " .. err
		else
			local ok, e = pcall(chunk, "AllTheThings", ATT)
			if not ok then loadErrors[#loadErrors + 1] = "ReferenceDB: " .. tostring(e) end
		end
	end
	local R = rawget(ATT, "ReagentsDB") or {}
	for reagent, recipes in pairs(R) do
		local list
		for _spell, v in pairs(recipes) do
			if type(v) == "table" and type(v[1]) == "number" and (expArg == "all" or v[1] >= REAGENT_MIN_CRAFTED) then
				list = list or {}
				list[#list + 1] = { v[1], v[2] or 1 }
			end
		end
		if list then
			table.sort(list, function(a, b) return a[1] < b[1] end)
			-- quitar duplicados (varias recetas pueden fabricar el mismo objeto)
			local out, last = {}, nil
			for _i, x in ipairs(list) do
				if x[1] ~= last then out[#out + 1] = x; last = x[1] end
			end
			reagents[reagent] = out
			nReagentLinks = nReagentLinks + #out
		end
	end
end

---------------------------------------------------------------------------
-- Nombres de objetos del mundo (LocalizationDB.ObjectNames): mx > es > inglés.
-- Se leen como texto; no se ejecuta el archivo.
---------------------------------------------------------------------------
local objects, headers, objectsES, headersES = {}, {}, {}, {}
do
	local fh = io.open(attRoot .. "\\db\\Standard\\LocalizationDB.lua", "rb")
	local lines = {}
	if fh then
		for line in fh:lines() do lines[#lines + 1] = line end
		fh:close()
	end
	-- markers: líneas que abren el bloque. Valores aceptados: "texto" o una constante global
	-- de WoW (RAID_BOSSES…), que se guarda como "=NOMBRE" y ItemLens resuelve en el juego.
	local function parse(from, to, into, markers, allowGlobals)
		local inBlock = false
		for i = from, to do
			local line = lines[i]
			if not inBlock then
				for _i, m in ipairs(markers) do
					if line:find(m, 1, true) then inBlock = true break end
				end
			else
				if line:match("^}") then inBlock = false
				else
					local id, name = line:match('^%s*%[(%-?%d+)%]%s*=%s*"(.-)",?%s*$')
					if id then into[tonumber(id)] = name
					elseif allowGlobals then
						local gid, global = line:match('^%s*%[(%-?%d+)%]%s*=%s*([A-Z][A-Z0-9_]+),?%s*$')
						if gid then into[tonumber(gid)] = "=" .. global end
					end
				end
			end
		end
	end
	local OBJ = { "localize(ObjectNames, {", "local ObjectNames = {" }
	local HDR = { "localize(L.HEADER_NAMES, {" }
	local esStart, mxStart, mxEnd
	for i, line in ipairs(lines) do
		if line:find('simplifiedLocale == "es"', 1, true) then esStart = i
		elseif line:find('sub(3,4):lower() == "mx"', 1, true) then mxStart = i
		elseif mxStart and not mxEnd and i > mxStart and line:match("^if ") then mxEnd = i - 1 end
	end
	-- El bloque base termina donde empieza el primer idioma (de)
	local firstLocale
	for i, line in ipairs(lines) do
		if line:find("simplifiedLocale = GetLocale", 1, true) then firstLocale = i break end
	end
	local baseEnd = (firstLocale or esStart or #lines) - 1
	local base, es, mx = {}, {}, {}
	parse(1, baseEnd, base, OBJ)
	if esStart then parse(esStart, (mxStart or #lines) - 1, es, OBJ) end
	if mxStart then parse(mxStart, mxEnd or #lines, mx, OBJ) end
	-- v14.0.0 (bilingüe): inglés como base; el español (mx > es) aparte, solo si es distinto.
	-- Si el inglés falta, el español ocupa la base para no perder el nombre.
	for id in pairs(objectIDs) do
		local spa = mx[id] or es[id]
		objects[id] = base[id] or spa
		if spa and spa ~= objects[id] then objectsES[id] = spa end
	end
	-- Nombres de encabezado (v7.1.0): constantes globales como "=NOMBRE" (el juego ya las traduce)
	local hb, he, hm = {}, {}, {}
	parse(1, baseEnd, hb, HDR, true)
	if esStart then parse(esStart, (mxStart or #lines) - 1, he, HDR, true) end
	if mxStart then parse(mxStart, mxEnd or #lines, hm, HDR, true) end
	for id in pairs(usedHeaders) do
		local spa = hm[id] or he[id]
		headers[id] = hb[id] or spa
		if spa and spa ~= headers[id] then headersES[id] = spa end
	end
end

---------------------------------------------------------------------------
-- Salida
---------------------------------------------------------------------------
local function sortedKeys(t, cmp)
	local ks = {}
	for k in pairs(t) do ks[#ks + 1] = k end
	table.sort(ks, cmp)
	return ks
end

local function num(v)
	if v == nil then return "nil" end
	if v == math.floor(v) then return string.format("%d", v) end
	return string.format("%.1f", v)
end

local out = assert(io.open(outPath, "wb"))
local w = function(...) out:write(...) end
local version = readVersion()
w("-- ItemLens · datos importados de AllTheThings v", version, "\n")
w("-- GENERADO por tools/att_extract.lua — NO editar a mano (se sobrescribe).\n")
w("-- Datos derivados de AllTheThings (https://github.com/ATTWoWAddon/AllTheThings),\n")
w("-- (c) 2026 AllTheThings WoW Addon, licencia MIT: ver licenses/AllTheThings-MIT.txt y CREDITS.md.\n")
w("-- Fecha: ", os.date("%Y-%m-%d"), " · Expansiones: ", expArg, "\n")
w("local _, IL = ...\n")
w("IL.DB = {\n")
w("\tmeta = { attVersion = \"", version, "\", generated = \"", os.date("%Y-%m-%d"), "\", scope = \"", expArg, "\" },\n")
w("\t-- vendors[npcID] = { mapID, x, y, expansión }\n")
w("\tvendors = {\n")
for _i, npc in ipairs(sortedKeys(vendors)) do
	local v = vendors[npc]
	w("\t\t[", npc, "]={", num(v.m), ",", num(v.x), ",", num(v.y), ",", num(v.e), "},\n")
end
w("\t},\n")
w("\t-- offers[\"i<itemID>\" | \"c<currencyID>\"] = { {npcID, itemID que se obtiene, cantidad}, ... }\n")
w("\toffers = {\n")
local function tokenCmp(a, b)
	local ta, tb = a:sub(1, 1), b:sub(1, 1)
	if ta ~= tb then return ta < tb end
	return tonumber(a:sub(2)) < tonumber(b:sub(2))
end
for _i, key in ipairs(sortedKeys(offers, tokenCmp)) do
	local list = offers[key]
	table.sort(list, function(a, b) if a[1] ~= b[1] then return a[1] < b[1] end return a[2] < b[2] end)
	local parts = {}
	for _j, o in ipairs(list) do parts[#parts + 1] = "{" .. o[1] .. "," .. o[2] .. "," .. num(o[3]) .. "}" end
	w("\t\t", key, "={", table.concat(parts, ","), "},\n")
end
w("\t},\n")

local function lstr(s) return string.format("%q", s) end
local function tagStr(t) return t and lstr(t) or "nil" end

w("\t-- uses[\"i<itemID>\"] = { {tipo, id, mapID, x, y, etiqueta, cantidad}, ... }\n")
w("\t--   tipo: n = NPC (invoca/se usa con), o = objeto del mundo, q = se entrega en misión, qs = inicia misión\n")
w("\t--   etiqueta: rare | worldboss | treasure | secret | event | nil\n")
w("\tuses = {\n")
for _i, key in ipairs(sortedKeys(uses, tokenCmp)) do
	local parts = {}
	for _j, u in ipairs(uses[key]) do
		parts[#parts + 1] = "{" .. lstr(u[1]) .. "," .. u[2] .. "," .. num(u[3]) .. "," .. num(u[4]) .. "," .. num(u[5]) .. "," .. tagStr(u[6]) .. "," .. num(u[7]) .. "}"
	end
	w("\t\t", key, "={", table.concat(parts, ","), "},\n")
end
w("\t},\n")

-- Formato compacto (un texto por objeto) para ahorrar memoria: ~98k objetos.
-- ItemLens lo interpreta solo al abrir el objeto (Data:GetObtain).
w("\t-- sources[itemID] = \"origen;origen;...\" (v7.0.0). Cada origen: letra + campos separados por coma\n")
w("\t--   b<encounterID>,<instanceID>,<difficultyID>   botín de jefe\n")
w("\t--   n<npcID>,<mapID>,<x>,<y>,<etiqueta>          botín de NPC / raro (etiqueta: r w t s e)\n")
w("\t--   v<npcID>,<mapID>,<x>,<y>,<cobre>             vendedor con oro\n")
w("\t--   o<objectID>,<mapID>,<x>,<y>                  tesoro / objeto del mundo\n")
w("\t--   q<questID>,<mapID>,<x>,<y>[,<w|d>,<factionID>,<rep>] (semanal/diaria y reputación)   a<achievementID>   p<skillLineID>\n")
w("\t--   c<itemID> sale de otro objeto (bolsa, caja)   z<mapID> en la zona (respaldo)   (v7.1.0)\n")
w("\t--   d<instanceID>,<difficultyID> botín de instancia sin jefe   g<código>,<encabezado> categoría de ATT (respaldo)\n")
w("\t--   códigos: w mundo, j JcJ, x función de expansión, k personaje, e evento, s tienda, m promoción,\n")
w("\t--            t puesto comercial, f buscador de grupos, v profundidades, i instancia, c/p fabricación…\n")
w("\t--   Campo vacío = sin dato.\n")
w("\tsources = {\n")
local TAG_CODE = { rare = "r", worldboss = "w", treasure = "t", secret = "s", event = "e" }
local function f(v)
	if v == nil then return "" end
	if type(v) == "string" then return TAG_CODE[v] or "" end
	return num(v)
end
-- Codifica una lista de orígenes al formato compacto (también la usan los artefactos)
local function encodeOrigins(list)
	local parts = {}
	for _j, s in ipairs(list) do
		local k = s[1]
		if k == "b" then parts[#parts + 1] = "b" .. s[2] .. "," .. f(s[3]) .. "," .. f(s[4])
		elseif k == "n" or k == "v" then parts[#parts + 1] = k .. s[2] .. "," .. f(s[3]) .. "," .. f(s[4]) .. "," .. f(s[5]) .. "," .. f(s[6])
		elseif k == "o" then parts[#parts + 1] = "o" .. s[2] .. "," .. f(s[3]) .. "," .. f(s[4]) .. "," .. f(s[5])
		elseif k == "q" then
			local q = "q" .. s[2] .. "," .. f(s[3]) .. "," .. f(s[4]) .. "," .. f(s[5])
			-- Optional: ,<w|d>,<factionID>,<reputation> / Opcional: semanal/diaria y reputación
			if s[6] or s[7] then q = q .. "," .. (s[6] or "") .. "," .. f(s[7]) .. "," .. f(s[8]) end
			parts[#parts + 1] = q
		elseif k == "d" then parts[#parts + 1] = "d" .. s[2] .. "," .. f(s[3])
		elseif k == "g" then parts[#parts + 1] = "g" .. s[2] .. "," .. (s[3] and num(s[3]) or "")
		elseif k == "r" then parts[#parts + 1] = "r" .. s[2] .. "," .. f(s[3]) -- reputación (v10.0.0)
		else parts[#parts + 1] = k .. s[2] end
	end
	return table.concat(parts, ";")
end
for _i, key in ipairs(sortedKeys(sources, tokenCmp)) do
	w("\t\t[", key:sub(2), "]=\"", encodeOrigins(sources[key]), "\",\n")
end
w("\t},\n")

-- Armas artefacto (v10.0.0)
w("\t-- artifacts[appearanceID] = \"clase,arma(itemID),sourceID,conjunto(encabezado)|orígenes\"\n")
w("\t--   orígenes: mismo formato que sources, más r<facción>,<valor> = reputación requerida\n")
w("\tartifacts = {\n")
for _i, id in ipairs(sortedKeys(artifacts)) do
	local a = artifacts[id]
	if a.weapon then -- solo las que están en el catálogo de armas artefacto
		w("\t\t[", id, "]=\"", f(a.cls), ",", f(a.weapon), ",", f(a.source), ",", (a.set and num(a.set) or ""), "|", encodeOrigins(a.origins), "\",\n")
	end
end
w("\t},\n")

w("\t-- reagents[itemID] = { {itemID que se fabrica, cantidad del material}, ... }\n")
w("\treagents = {\n")
for _i, id in ipairs(sortedKeys(reagents)) do
	local parts = {}
	for _j, x in ipairs(reagents[id]) do parts[#parts + 1] = "{" .. x[1] .. "," .. num(x[2]) .. "}" end
	w("\t\t[", id, "]={", table.concat(parts, ","), "},\n")
end
w("\t},\n")

w("\t-- collections (v8.0.0): conjuntos coleccionables y cómo saber si ya se aprendieron\n")
w("\t--   mm[itemID] = {misión oculta, itemID de la montura, expansiónATT}   manuscritos\n")
w("\t--   cq[itemID] = {misión oculta, classID o nil, expansiónATT}          desbloqueo por misión\n")
w("\t--   cs[itemID] = {spellID, classID o nil, expansiónATT}                desbloqueo por hechizo\n")
w("\tcollections = {\n")
for _i, set in ipairs({ "mm", "cq", "cs" }) do
	w("\t\t", set, " = {\n")
	for _j, item in ipairs(sortedKeys(collections[set])) do
		local v = collections[set][item]
		w("\t\t\t[", item, "]={", num(v[1]), ",", num(v[2]), ",", num(v[3]), "},\n")
	end
	w("\t\t},\n")
end
w("\t},\n")

w("\t-- classQuests[questID] = \"clase,expATT,mapID,x,y;recompensa,recompensa…\" (v9.0.0, solo vigentes)\n")
w("\tclassQuests = {\n")
for _i, qid in ipairs(sortedKeys(classQuestData)) do
	local v = classQuestData[qid]
	local function f2(n) return n and num(n) or "" end
	local rew = {}
	for _j, r in ipairs(v[6]) do rew[#rew + 1] = tostring(r) end
	w("\t\t[", qid, "]=\"", f2(v[1]), ",", f2(v[2]), ",", f2(v[3]), ",", f2(v[4]), ",", f2(v[5]), ";", table.concat(rew, ","), "\",\n")
end
w("\t},\n")

local function writeNames(name, t)
	w("\t", name, " = {\n")
	for _i, id in ipairs(sortedKeys(t)) do
		w("\t\t[", id, "]=", lstr(t[id]), ",\n")
	end
	w("\t},\n")
end
-- v14.0.0 (bilingüe): base en inglés + español aparte (solo lo que cambia)
w("\t-- headers[id] = nombre del encabezado (inglés); \"=CONST\" = constante global de WoW (v7.1.0)\n")
writeNames("headers", headers)
w("\t-- headersES[id] = nombre en español, solo si es distinto (v14.0.0)\n")
writeNames("headersES", headersES)
w("\t-- objects[objectID] = nombre del objeto del mundo (inglés)\n")
writeNames("objects", objects)
w("\t-- objectsES[objectID] = nombre en español, solo si es distinto (v14.0.0)\n")
writeNames("objectsES", objectsES)
w("}\n")
out:close()

---------------------------------------------------------------------------
-- Resumen
---------------------------------------------------------------------------
local nV, nT = 0, 0
for _ in pairs(vendors) do nV = nV + 1 end
for _ in pairs(offers) do nT = nT + 1 end
print("ATT versión:        " .. version)
print("Expansiones:        " .. expArg)
print("Vendedores:         " .. nV)
print("Tokens/monedas:     " .. nT)
print("Canjes (ofertas):   " .. stats.offers)
print("Fuera de alcance:   " .. stats.skippedExp)
print("Sin expansión:      " .. stats.noExp)
print("Sin vendedor:       " .. stats.noVendor .. " (costo sin NPC padre: misiones, objetos, etc.)")
print("Solo oro:           " .. stats.goldOnly)
local nUseItems, nObj, nObjNamed, nReag = 0, 0, 0, 0
for _ in pairs(uses) do nUseItems = nUseItems + 1 end
for id in pairs(objectIDs) do nObj = nObj + 1; if objects[id] then nObjNamed = nObjNamed + 1 end end
for _ in pairs(reagents) do nReag = nReag + 1 end
print("Usos (invoca, etc.): " .. stats.uses .. " en " .. nUseItems .. " objetos")
local nSrcItems, bySrc = 0, {}
for _, list in pairs(sources) do
	nSrcItems = nSrcItems + 1
	for _, s in ipairs(list) do bySrc[s[1]] = (bySrc[s[1]] or 0) + 1 end
end
local srcParts = {}
for _, k in ipairs({ "b", "d", "n", "v", "q", "a", "o", "p", "c", "z", "g" }) do srcParts[#srcParts + 1] = k .. "=" .. (bySrc[k] or 0) end
print("Orígenes:           " .. stats.sources .. " en " .. nSrcItems .. " objetos (" .. table.concat(srcParts, " ") .. ")")
local e = stats.extra
local nHdr, nHdrNamed = 0, 0
for id in pairs(usedHeaders) do nHdr = nHdr + 1; if headers[id] then nHdrNamed = nHdrNamed + 1 end end
print(string.format("  señales v7.1.0:   providers %d · contenedor %d · crs %d · profesión %d · instancia %d · zona %d · categoría %d",
	e.providers, e.container, e.crs, e.skill, e.instance, e.zone, e.category))
print(string.format("  encabezados:      %d usados, %d con nombre", nHdr, nHdrNamed))
local function cnt(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local mmGroups, mmNoQuest = {}, 0
for _, v in pairs(collections.mm) do
	if v[2] then mmGroups[v[2]] = (mmGroups[v[2]] or 0) + 1 end
	if not v[1] then mmNoQuest = mmNoQuest + 1 end
end
print(string.format("Colecciones:        manuscritos %d (%d monturas, %d sin misión) · clase por misión %d · clase por hechizo %d",
	cnt(collections.mm), cnt(mmGroups), mmNoQuest, cnt(collections.cq), cnt(collections.cs)))
do
	local byClass, noItem = {}, {}
	for _i, set in ipairs({ "cq", "cs" }) do
		for _, v in pairs(collections[set]) do if v[2] then byClass[v[2]] = (byClass[v[2]] or 0) + 1 end end
	end
	local parts = {}
	for cid = 1, 13 do parts[#parts + 1] = cid .. "=" .. (byClass[cid] or 0) .. "(+" .. (unlockNoItem[cid] or 0) .. " sin objeto)" end
	print("  por clase:        " .. table.concat(parts, " "))
	local nArt, nArtW, nArtO, weapons = 0, 0, 0, {}
	for _, a in pairs(artifacts) do
		if a.weapon then
			nArtW = nArtW + 1
			weapons[a.weapon] = true
			if #a.origins > 0 then nArtO = nArtO + 1 end
		end
		nArt = nArt + 1
	end
	print(string.format("  artefactos:       %d apariencias en catálogo (de %d) · %d armas · %d con origen · logros que piden objeto: %d",
		nArtW, nArt, cnt(weapons), nArtO, stats.achUses or 0))
	local gp = {}
	for cid = 1, 13 do gp[#gp + 1] = cid .. "=" .. (glyphCandidates[cid] or 0) .. (glyphSample[cid] and (" [" .. glyphSample[cid] .. "]") or "") end
	print("  glifos Inscripción: " .. table.concat(gp, " "))
	print("  misiones de clase (total · con recompensa · por expansión ATT):")
	for cid = 1, 13 do
		local d = classQuests[cid]
		if d then
			local ex = {}
			for k = 0, 12 do if d.byExp[k] then ex[#ex + 1] = k .. ":" .. d.byExp[k] end end
			print(string.format("    clase %2d: %4d · %4d · vigentes %4d (con recompensa %3d) · %s",
				cid, d.n, d.withReward, d.active, d.activeReward, table.concat(ex, " ")))
		else
			print(string.format("    clase %2d: 0", cid))
		end
	end
end
print(string.format("  objetos en ATT:   %d · sin origen ni canje: %d (lista en tools/sin_origen.txt)", stats.allItems, stats.noSource))
if DEBUG then
	local groups = {}
	for key in pairs(allItems) do
		if not sources[key] and not rewardItems[key] then
			local g = ITEM_CATEGORY[key] or "?"
			groups[g] = (groups[g] or 0) + 1
		end
	end
	print("SIN ORIGEN, por categoría de ATT:")
	local ks = sortedKeys(groups, function(a, b) return groups[a] > groups[b] end)
	for i = 1, math.min(30, #ks) do print(string.format("  %6d  %s", groups[ks[i]], ks[i])) end
end
print("Objetos del mundo:  " .. nObj .. " (" .. nObjNamed .. " con nombre)")
print("Materiales:         " .. nReag .. " con " .. nReagentLinks .. " objetos fabricables")
for _i, e in ipairs(sortedKeys(expCount)) do print(string.format("  exp %2d: %d canjes", e, expCount[e])) end
if DEBUG then
	print("SIN VENDEDOR (exp >= 10), por ruta:")
	local ks = sortedKeys(noVendorPaths, function(a, b) return noVendorPaths[a] > noVendorPaths[b] end)
	for i = 1, math.min(25, #ks) do print(string.format("  %5d  %s", noVendorPaths[ks[i]], ks[i])) end
end
if #loadErrors > 0 then
	print("ERRORES DE CARGA:")
	for _i, e in ipairs(loadErrors) do print("  " .. e) end
end
