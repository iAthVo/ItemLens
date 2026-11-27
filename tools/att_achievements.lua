-- ItemLens · extractor de datos de logros de AllTheThings (solo desarrollo, fuera del juego).
-- Datos de ATT bajo su licencia MIT, con crédito (D-12, D-43): licenses/AllTheThings-MIT.txt.
-- © 2026 iAthVo_Kr · MIT License
--
-- Uso:
--   lua att_achievements.lua <ruta AllTheThings> <salida.json>
--
-- Extrae lo que el cliente del juego no da sobre los logros:
--   crit[achID]["i"..índice] = {map, x, y, kind, id, desc, npcs, items}   criterios con ubicación
--   ach[achID]               = {u, rwp, map, x, y, desc, items}            disponibilidad y ubicación
--   rep[factionID]           = { {quest, map, x, y, qgs, cost, repeatable, max}, ... }
-- tools/ach_extract.py convierte esto en Data/iLs_Achievements.lua.

local attRoot = assert(arg[1], "falta ruta a AllTheThings")
local outPath = assert(arg[2], "falta archivo de salida")

---------------------------------------------------------------------------
-- Entorno aislado (igual que att_extract.lua)
---------------------------------------------------------------------------
local stub
stub = setmetatable({}, { __index = function() return stub end, __call = function() return stub end })
setmetatable(_G, { __index = function() return stub end })
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

local files = { "Instances", "Zones", "ExpansionFeatures", "Holidays", "WorldEvents", "PVP",
	"Professions", "Craftables", "Delves", "Character", "GroupFinder", "Promotions", "Unsorted",
	"WorldDrops", "Housing", "TradingPost", "BlackMarket", "Sourceless", "Secrets", "InGameShop",
	"NeverImplemented", "HiddenAchievementTriggers" }
local categories = {}
for _i, name in ipairs(files) do
	local fh = io.open(attRoot .. "\\db\\Standard\\Categories\\" .. name .. ".lua", "rb")
	if fh then
		local src = fh:read("*a"); fh:close()
		if src:sub(1, 3) == "\239\187\191" then src = src:sub(4) end
		local chunk, err = loadstring(src, "=" .. name)
		if chunk then
			local ok, e = pcall(chunk, "AllTheThings", ATT)
			if not ok then io.stderr:write(name, ": ", tostring(e), "\n") end
		else io.stderr:write(name, ": ", err, "\n") end
	end
end
for _i, h in ipairs(handlers) do
	if h.ev == "OnBuildDataCache" then pcall(h.fn, categories) end
end

---------------------------------------------------------------------------
-- Recorrido
---------------------------------------------------------------------------
local function firstCoord(coords)
	if type(coords) ~= "table" then return end
	for mapID, list in pairs(coords) do
		if type(mapID) == "number" and type(list) == "table" and type(list[1]) == "table" then
			return mapID, list[1][1], list[1][2]
		end
	end
	local c = coords[1]
	if type(c) == "table" and type(c[3]) == "number" then return c[3], c[1], c[2] end
end
local function where(node, ctx)
	local m, x, y = firstCoord(node.coords)
	if not m and type(node.coord) == "table" then m, x, y = node.coord[3], node.coord[1], node.coord[2] end
	if m then return m, x, y end
	return ctx.map
end
local function numList(t)
	if type(t) ~= "table" then return nil end
	local out = {}
	for _i, v in ipairs(t) do if type(v) == "number" then out[#out + 1] = v end end
	return #out > 0 and out or nil
end
-- providers {{"i", id}, {"n", id}, {"o", id}} y cost {{"i", id, n}}
local function typed(t, kind)
	if type(t) ~= "table" then return nil end
	local out = {}
	for _i, v in ipairs(t) do
		if type(v) == "table" and v[1] == kind and type(v[2]) == "number" then out[#out + 1] = { v[2], v[3] or 1 } end
	end
	return #out > 0 and out or nil
end

local crit, ach, rep = {}, {}, {}
local function walk(node, ctx)
	if type(node) ~= "table" then return end
	local kind = node.__kind
	local c = ctx
	local mapHere = (kind == "Map" and type(node.__id) == "number") and node.__id or nil
	local fac = (node.r == 1 or node.r == 2) and node.r or nil -- 1 Horde · 2 Alliance (D-59)
	-- Expansion (D-71): Expansion node, or "added with patch" (awp = 120001 → 12).
	-- Expansión (D-71): nodo Expansion, o "agregado en el parche" (awp = 120001 → 12).
	local expHere = (kind == "Expansion" and type(node.__id) == "number" and node.__id)
		or (type(node.awp) == "number" and math.floor(node.awp / 10000)) or nil
	-- Removed with patch (D-82): ATT's rwp (120200 = 12.2.0), inherited from the nearest header.
	-- Retirado en el parche (D-82): rwp de ATT (120200 = 12.2.0), heredado del encabezado más cercano.
	local rwpHere = type(node.rwp) == "number" and node.rwp or nil
	if mapHere or kind == "Achievement" or kind == "Instance" or fac or expHere or rwpHere then
		c = setmetatable({}, { __index = ctx })
		if expHere then c.exp = expHere end
		if rwpHere then c.rwp = rwpHere end
		if fac then c.fac = fac end
		if mapHere then c.map = mapHere end
		if kind == "Instance" then c.instance = node.__id end
		if kind == "Achievement" then c.ach = node.__id end
	end
	if kind == "Achievement" and type(node.__id) == "number" then
		local a = ach[node.__id] or {}
		ach[node.__id] = a
		if node.u and not a.u then a.u = node.u end
		local m, x, y = where(node, c)
		if m and not a.map then a.map, a.x, a.y = m, x, y end
		if type(node.description) == "string" and not a.desc then a.desc = node.description end
		a.items = a.items or typed(node.providers, "i")
		a.seen = true
		if c.exp and not a.exp then a.exp = c.exp end -- D-71
		if c.rwp and not a.rwp then a.rwp = c.rwp end -- D-82
		-- Faction: nearest mark; seen with both → 0 / Facción: marca más cercana; con ambas → 0
		local f = c.fac or 0
		if a.fac == nil then a.fac = f elseif a.fac ~= f then a.fac = 0 end
	end
	-- Criterio: dentro de un objeto/misión/NPC con coordenadas, o como hijo directo del logro
	if kind == "AchievementCriteria" or kind == "Criteria" then
		local aid = node.achID or ctx.ach
		local idx = node.id or node.criteriaID
		if type(aid) == "number" and type(idx) == "number" then
			crit[aid] = crit[aid] or {}
			local holder = ctx.holder
			local e = crit[aid][idx] or {}
			crit[aid][idx] = e
			local m, x, y = where(node, c)
			if (not x) and holder then m, x, y = where(holder.node, c) end
			if x and not e.x then e.map, e.x, e.y = m, x, y elseif m and not e.map then e.map = m end
			if holder and not e.kind then e.kind, e.id = holder.node.__kind, holder.node.__id end
			local d = node.description or (holder and holder.node.description)
			if type(d) == "string" and not e.desc then e.desc = d end
			e.npcs = e.npcs or numList(node.crs) or numList(node.qgs) or (holder and holder.node.__kind == "NPC" and { holder.node.__id }) or nil
			e.items = e.items or typed(node.providers, "i") or typed(node.cost, "i")
		end
	end
	-- Misiones que suben reputación (maxReputation = {facción, tope})
	if kind == "Quest" and type(node.maxReputation) == "table" and type(node.maxReputation[1]) == "number" then
		local fid = node.maxReputation[1]
		rep[fid] = rep[fid] or {}
		local m, x, y = where(node, c)
		rep[fid][#rep[fid] + 1] = { quest = node.__id, map = m, x = x, y = y, qgs = numList(node.qgs),
			cost = typed(node.cost, "i"), repeatable = node.repeatable and true or nil, max = node.maxReputation[2] }
	end
	local cc = c
	if kind == "Object" or kind == "Quest" or kind == "NPC" or kind == "Item" then
		cc = setmetatable({ holder = { node = node } }, { __index = c })
	end
	-- Hijos: en g o en la parte de arreglo del propio nodo (encabezados de ATT)
	if type(node.g) == "table" then for _i, ch in ipairs(node.g) do walk(ch, cc) end end
	for _i, ch in ipairs(node) do walk(ch, cc) end
end
for _name, cat in pairs(categories) do
	if type(cat) == "table" then
		if cat.__kind then walk(cat, {}) else for _i, n in ipairs(cat) do walk(n, {}) end end
	end
end

---------------------------------------------------------------------------
-- JSON
---------------------------------------------------------------------------
local function enc(v)
	local t = type(v)
	if t == "nil" then return "null"
	elseif t == "boolean" then return tostring(v)
	elseif t == "number" then return (v == math.floor(v)) and string.format("%d", v) or string.format("%.2f", v)
	elseif t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(ch)
			if ch == "\n" then return "\\n" elseif ch == '"' then return '\\"' elseif ch == "\\" then return "\\\\" end
			return string.format("\\u%04x", ch:byte())
		end) .. '"'
	elseif t == "table" then
		local n = 0
		for _k in pairs(v) do n = n + 1 end
		if n == #v then
			local out = {}
			for i = 1, #v do out[i] = enc(v[i]) end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local out = {}
		for k, x in pairs(v) do
			if type(k) ~= "string" or k:sub(1, 2) ~= "__" then out[#out + 1] = enc(tostring(k)) .. ":" .. enc(x) end
		end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "null"
end
-- Índices de criterios como objeto (pueden tener huecos)
local critOut = {}
for aid, list in pairs(crit) do
	local o = {}
	for idx, e in pairs(list) do o["i" .. idx] = e end
	critOut[aid] = o
end
local fh = assert(io.open(outPath, "wb"))
fh:write(enc({ crit = critOut, ach = ach, rep = rep }))
fh:close()
local n1, n2, n3 = 0, 0, 0
for _ in pairs(crit) do n1 = n1 + 1 end
for _ in pairs(ach) do n2 = n2 + 1 end
for _ in pairs(rep) do n3 = n3 + 1 end
print(string.format("Logros con criterios ubicados: %d · logros en ATT: %d · facciones con misiones de reputación: %d", n1, n2, n3))
