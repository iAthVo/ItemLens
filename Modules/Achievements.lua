--[[
	ItemLens · Modules/Achievements.lua
	Achievements tab (D-56): which achievements are listed, their groups, filters, progress,
	requirements, reputation and locations. Names, criteria, progress and icons come live from
	the game client; Data/iLs_Achievements.lua adds what the client does not give.
	Pestaña Logros (D-56): qué logros se listan, sus grupos, filtros, progreso, requisitos,
	reputación y ubicaciones. Nombres, criterios, progreso e íconos vienen en vivo del cliente;
	Data/iLs_Achievements.lua agrega lo que el cliente no da.
	© 2026 iAthVo_Kr · MIT License
]]

local _, IL = ...
local L = IL.L

-- Guides generated from LogrosDoc (D-76) replace the hand-written ones with the same ID. Each
-- client loads only its language (D-86): Data/iLs_Guides.lua on es clients, Data/iLs_Guides_enUS.lua
-- on every other one, so IL.GUIDES is already the right one here.
-- Las guías generadas del LogrosDoc (D-76) reemplazan a las escritas a mano con el mismo ID. Cada
-- cliente carga solo su idioma (D-86): Data/iLs_Guides.lua en español, Data/iLs_Guides_enUS.lua en
-- todos los demás, así que aquí IL.GUIDES ya es la correcta.
function IL.MergeGuides(G)
	if not G then return 0, 0 end
	L.ACH_GUIDES, L.ACH_CRIT_TIPS = L.ACH_GUIDES or {}, L.ACH_CRIT_TIPS or {}
	local a, c = 0, 0
	for id, steps in pairs(G.ach or {}) do L.ACH_GUIDES[id] = steps; a = a + 1 end
	for id, tip in pairs(G.crit or {}) do L.ACH_CRIT_TIPS[id] = tip; c = c + 1 end
	-- By the criterion's text too (D-80): the game's criteria IDs are not the web export's.
	-- También por el texto del criterio (D-80): los IDs del juego no son los de la exportación web.
	L.ACH_CRIT_TEXT = L.ACH_CRIT_TEXT or {}
	for id, list in pairs(G.critText or {}) do L.ACH_CRIT_TEXT[id] = list end
	return a, c
end
IL.MergeGuides(IL.GUIDES)

local Ach = {}
IL.Ach = Ach

---------------------------------------------------------------------------
-- Rules / Reglas
---------------------------------------------------------------------------
-- Root categories (game IDs). Every achievement of the client is listed (D-72).
-- Categorías raíz (IDs del juego). Se listan todos los logros del cliente (D-72).
local CHARACTER, QUESTS, EXPLORATION, PVP, DUNGEONS = 92, 96, 97, 95, 168
local PROFESSIONS, REPUTATION, EVENTS, PETS, COLLECTIONS = 169, 201, 155, 15117, 15246
local FEATURES, FEATS, LEGACY, GUILD, DELVES, HOUSING = 15301, 81, 15234, 15076, 15522, 15606
local MOUNTS, TOYS = 15248, 15247 -- Collections › Mounts / Toy Box

-- The list goes by expansion (D-78): General, Midnight … Classic, No expansion; inside each one
-- the sections in this order. "dungeons"/"raids" split Dungeons & Raids; the old expansions the
-- game does not split stay together (DUNGEONS).
-- La lista va por expansión (D-78): General, Midnight … Clásico, Sin expansión; dentro de cada una
-- las secciones en este orden. "dungeons"/"raids" separan Calabozos y bandas; las expansiones
-- viejas que el juego no separa quedan juntas (DUNGEONS).
local SECTION_ORDER = { EXPLORATION, QUESTS, PVP, "dungeons", "raids", DUNGEONS, PROFESSIONS, REPUTATION, EVENTS,
	PETS, COLLECTIONS, FEATURES, DELVES, HOUSING, FEATS, LEGACY }
local GENERAL = { [CHARACTER] = true, [GUILD] = true } -- not of any expansion / de ninguna expansión
-- Roots whose sub-categories are topics (a profession, a holiday…), not expansions: one more level.
-- Raíces cuyas subcategorías son temas (una profesión, una festividad…), no expansiones: un nivel más.
local SUBDIVIDED = { [PVP] = true, [PROFESSIONS] = true, [EVENTS] = true, [PETS] = true, [COLLECTIONS] = true,
	[FEATURES] = true, [FEATS] = true, [LEGACY] = true }
-- Dungeons & Raids sub-categories → { expansion, "d" dungeon | "r" raid | nil both }.
-- Subcategorías de Calabozos y bandas → { expansión, "d" calabozo | "r" banda | nil ambos }.
local DUNGEON_CATS = { [14808] = { 1 }, [14805] = { 2 }, [14806] = { 3, "d" }, [14922] = { 3, "r" },
	[15067] = { 4, "d" }, [15068] = { 4, "r" }, [15106] = { 5, "d" }, [15107] = { 5, "r" }, [15228] = { 6, "d" },
	[15231] = { 6, "r" }, [15254] = { 7, "d" }, [15255] = { 7, "r" }, [15285] = { 8, "d" }, [15286] = { 8, "r" },
	[15428] = { 9, "d" }, [15438] = { 9, "r" }, [15467] = { 10, "d" }, [15468] = { 10, "r" }, [15524] = { 11, "d" },
	[15526] = { 11, "r" }, [15541] = { 12, "d" }, [15566] = { 12, "r" } }
local EXP_CAT_EXTRA = { [15465] = 10 } -- Exploration › Dragon Isles / Exploración › Islas Dragón

-- Order of the roots in the list. / Orden de las raíces en la lista.
-- Same order as the game's achievement window (D-72). / El mismo orden que la ventana del juego (D-72).
local ROOT_ORDER = { CHARACTER, QUESTS, EXPLORATION, PVP, DUNGEONS, PROFESSIONS, REPUTATION, EVENTS, PETS,
	COLLECTIONS, FEATURES, DELVES, HOUSING, LEGACY, FEATS, GUILD }

-- Excluded content that an included achievement may ask for → requirement text.
-- Contenido excluido que un logro incluido puede pedir → texto de requisito.
local CONTENT_NOTE = { [PVP] = "ACH_NEEDS_PVP", [EXPLORATION] = "ACH_NEEDS_EXPLORE", [PETS] = "ACH_NEEDS_PETS",
	[CHARACTER] = "ACH_NEEDS_CHAR" }

local CRITERIA_ACHIEVEMENT, CRITERIA_REPUTATION = 8, 46
-- Criteria whose asset is an item: own, use, loot, equip (D-74). / Criterios cuyo dato es un objeto.
local CRITERIA_ITEM = { [36] = true, [41] = true, [42] = true, [57] = true }
local ACCOUNT_FLAG = 0x20000 -- ACHIEVEMENT_FLAGS_ACCOUNT

-- Reputation tier sizes by standing (1 Hated … 8 Exalted). / Tamaño de cada nivel de reputación.
local TIER = { 36000, 3000, 3000, 3000, 6000, 12000, 21000, 0 }

---------------------------------------------------------------------------
-- Categories / Categorías
---------------------------------------------------------------------------
local catInfo = {} -- [catID] = { name, parent, root }

local function rootOf(cat)
	local seen = 0
	while cat and seen < 8 do
		local info = catInfo[cat]
		if not info then
			local name, parent = GetCategoryInfo(cat)
			info = { name = name, parent = (parent and parent > 0) and parent or nil }
			catInfo[cat] = info
		end
		if not info.parent then return cat end
		cat, seen = info.parent, seen + 1
	end
	return cat
end

local function catName(cat)
	rootOf(cat)
	return catInfo[cat] and catInfo[cat].name or "?"
end

-- "Reputation · Legion", or just "Reputation" for the root itself.
-- "Reputación · Legion", o solo "Reputación" para la raíz misma.
local function groupLabel(cat, root)
	if cat == root then return catName(root) end
	return catName(root) .. " · " .. catName(cat)
end

-- Everything is listed (D-72); the search box narrows it. / Todo se lista (D-72); el buscador acota.
local function isListed(id, cat)
	return id ~= nil and cat ~= nil
end

---------------------------------------------------------------------------
-- Index / Índice
---------------------------------------------------------------------------
-- Built once, when the tab is first opened. Only ids, categories and groups are kept here; names,
-- progress and criteria are read from the client when shown (they change while you play).
-- Se arma una vez, al abrir la pestaña. Aquí solo se guardan ids, categorías y grupos; nombres,
-- progreso y criterios se leen del cliente al mostrarse (cambian mientras juegas).
local index -- { groups = { { id, text, root, cat, keys } }, byID = { [id] = { cat, root, group, name, done, low } }, total }
local famousRank = {}
local building -- index being built in the background / índice que se arma en segundo plano

-- The index is built a few categories per frame, right after logging in, so opening the tab
-- does not freeze the game. Opening it before that finishes the rest at once.
-- El índice se arma unas cuantas categorías por cuadro, al entrar al juego, para que abrir la
-- pestaña no congele el juego. Si se abre antes, se termina de una vez.
local CATS_PER_STEP = 4

local function newBuild()
	local D = IL.ACH
	for i, id in ipairs(D.famous) do famousRank[id] = i end
	return { cats = GetCategoryList() or {}, i = 1, byID = {}, groups = {}, byCat = {} }
end

local function add(b, id, cat, name, done)
	if b.byID[id] or not cat or cat <= 0 then return end
	if not isListed(id, cat) then return end
	local root = rootOf(cat)
	local g = b.byCat[cat]
	if not g then
		g = { id = "a" .. cat, text = groupLabel(cat, root), root = root, cat = cat, keys = {} }
		b.byCat[cat] = g
		b.groups[#b.groups + 1] = g
	end
	g.keys[#g.keys + 1] = "a" .. id
	b.byID[id] = { cat = cat, root = root, group = g, name = name, done = done and true or false }
end

-- Feats of Strength and famous ones the category scan does not list (unearned hidden ones), then
-- the order: roots as agreed; inside a root, its own group first, then the client's order.
-- Proezas y famosos que el recorrido no lista (ocultos sin conseguir) y luego el orden: raíces
-- como se acordó; dentro de cada raíz, primero su propio grupo y luego el orden del cliente.
local function finish(b)
	local D = IL.ACH
	local extra = {}
	for id in pairs(D.avail) do extra[#extra + 1] = id end
	for _, id in ipairs(D.famous) do extra[#extra + 1] = id end
	for id in pairs(L.ACH_GUIDES or {}) do extra[#extra + 1] = id end -- D-71
	table.sort(extra)
	for _, id in ipairs(extra) do
		if not b.byID[id] then
			local _, name, _, done = GetAchievementInfo(id)
			if name then add(b, id, GetAchievementCategory(id), name, done) end
		end
	end
	local rank = {}
	for i, r in ipairs(ROOT_ORDER) do rank[r] = i end
	for i, g in ipairs(b.groups) do g.order = i end
	table.sort(b.groups, function(x, y)
		local rx, ry = rank[x.root] or 99, rank[y.root] or 99
		if rx ~= ry then return rx < ry end
		local sx, sy = x.cat == x.root and 0 or 1, y.cat == y.root and 0 or 1
		if sx ~= sy then return sx < sy end
		return x.order < y.order
	end)
	local total = 0
	for _, g in ipairs(b.groups) do total = total + #g.keys end
	return { groups = b.groups, byID = b.byID, total = total }
end

-- Processes up to `maxCats` categories; returns true when every category is done.
-- Procesa hasta `maxCats` categorías; devuelve true cuando ya no quedan.
local function step(b, maxCats)
	local n = 0
	while b.i <= #b.cats and n < maxCats do
		local cat = b.cats[b.i]
		local count = GetCategoryNumAchievements(cat, true) or 0
		for i = 1, count do
			local id, name, _, done = GetAchievementInfo(cat, i)
			if id then add(b, id, cat, name, done) end
		end
		b.i, n = b.i + 1, n + 1
	end
	return b.i > #b.cats
end

function Ach:Ensure()
	if index then return index end
	local b = building or newBuild()
	building = nil
	step(b, math.huge)
	index = finish(b)
	return index
end

-- Background build after logging in (paused in combat). / Armado en segundo plano (se pausa en combate).
function Ach:Preload()
	if index or building then return end
	building = newBuild()
	local function tick()
		if index or not building then return end
		if InCombatLockdown and InCombatLockdown() then return C_Timer.After(1, tick) end
		if step(building, CATS_PER_STEP) then
			index = finish(building)
			building = nil
		else
			C_Timer.After(0, tick)
		end
	end
	tick()
end

-- During loading screens (D-85): categories until `deadline`, and the rest in the next one.
-- Opening the tab first builds what is missing at that moment (Ensure).
-- En pantallas de carga (D-85): categorías hasta `deadline` y el resto en la siguiente. Si abres
-- la pestaña antes, se arma en ese momento lo que falte (Ensure).
function Ach:LoadStep(deadline)
	if index then return true end
	building = building or newBuild()
	local clock = IL.LoadWork.Clock
	repeat
		if step(building, 1) then
			index = finish(building)
			building = nil
			return true
		end
	until clock() >= deadline
	return false
end

function Ach:Reset() index, building = nil, nil end -- for tests / para pruebas

---------------------------------------------------------------------------
-- One achievement / Un logro
---------------------------------------------------------------------------
local function idOf(key) return tonumber(key:sub(2)) end

-- GetAchievementInfo → table. / GetAchievementInfo → tabla.
function Ach:Info(key)
	local id = type(key) == "number" and key or idOf(key)
	local _, name, points, completed, month, day, year, desc, flags, icon, reward, _, wasEarnedByMe = GetAchievementInfo(id)
	if not name then return nil end
	return {
		id = id, name = name, points = points or 0, completed = completed and true or false,
		date = (completed and month) and ("%02d/%02d/%02d"):format(day, month, year) or nil, -- dd/mm/aa
		desc = desc or "", icon = icon, reward = (reward and reward ~= "") and reward or nil,
		account = bit.band(flags or 0, ACCOUNT_FLAG) ~= 0, mine = wasEarnedByMe and true or false,
	}
end

-- Name and state are read once (index) and kept up to date by ACHIEVEMENT_EARNED.
-- Nombre y estado se leen una vez (índice) y se actualizan con ACHIEVEMENT_EARNED.
function Ach:GetName(key)
	local e = index and index.byID[idOf(key)]
	if e and e.name then return e.name end
	local _, name = GetAchievementInfo(idOf(key))
	return name or L.ACHIEVEMENT_N:format(idOf(key))
end

local function lowerName(key)
	local e = index and index.byID[idOf(key)]
	if not e then return strlower(Ach:GetName(key)) end
	if not e.low then e.low = strlower(e.name or Ach:GetName(key)) end
	return e.low
end

-- Achievements by name for the global search (D-67). / Logros por nombre para la búsqueda global.
function Ach:Search(query, exclude, limit)
	if query == "" then return {}, false end
	local idx = self:Ensure()
	local found = {}
	for id, e in pairs(idx.byID) do
		local key = "a" .. id
		if not (exclude and exclude[key]) and lowerName(key):find(query, 1, true) then
			found[#found + 1] = { key, e.name or "" }
		end
	end
	table.sort(found, function(a, b) return a[2] < b[2] end)
	local out, cut = {}, #found > limit
	for i = 1, math.min(#found, limit) do out[i] = found[i][1] end
	return out, cut
end

-- Items an achievement needs (reverse of IL.ACH.needs, built once). D-67
-- Objetos que pide un logro (inverso de IL.ACH.needs, se arma una vez). D-67
local itemsByAch
function Ach:NeededItems(key)
	if not itemsByAch then
		itemsByAch = {}
		for item, achs in pairs(IL.ACH.needs or {}) do
			for _, a in ipairs(achs) do
				local list = itemsByAch[a]
				if not list then list = {}; itemsByAch[a] = list end
				list[#list + 1] = item
			end
		end
		for _, list in pairs(itemsByAch) do table.sort(list) end
	end
	return itemsByAch[idOf(key)]
end

function Ach:GetIcon(key) return select(10, GetAchievementInfo(idOf(key))) end

function Ach:IsCompleted(key)
	local e = index and index.byID[idOf(key)]
	if e then return e.done end
	return select(4, GetAchievementInfo(idOf(key))) and true or false
end

function Ach:FamousRank(key) return famousRank[idOf(key)] end

-- Feat of Strength? (separate list, D-70) / ¿Es una proeza? (lista aparte, D-70)
function Ach:IsFeat(key)
	local e = index and index.byID[idOf(key)]
	if e then return e.root == FEATS end
	local cat = GetAchievementCategory(idOf(key))
	return cat ~= nil and cat > 0 and rootOf(cat) == FEATS
end

-- 1 Horde only, 2 Alliance only, nil both (AllTheThings). / Facción del logro (D-59).
function Ach:Faction(key)
	local f = IL.ACH.faction
	return f and f[idOf(key)] or nil
end

-- The client version the way ATT writes patches (12.1.5 → 120105); 0 when unknown.
-- La versión del cliente como ATT escribe los parches (12.1.5 → 120105); 0 si no se sabe.
local function clientPatch()
	if not GetBuildInfo then return 0 end
	return tonumber((select(4, GetBuildInfo()))) or 0
end
Ach.ClientPatch = clientPatch

-- 120200 → "12.2.0"
function Ach:PatchText(n)
	return ("%d.%d.%d"):format(math.floor(n / 10000), math.floor(n / 100) % 100, n % 100)
end

-- Patch where ATT says it goes away (D-82), or nil. / Parche en que ATT dice que se quita (D-82), o nil.
function Ach:RemovedPatch(key)
	local r = IL.ACH.rwp
	return r and r[idOf(key)] or nil
end

-- "until patch 12.2.0 · <date when known>" (D-82). / "hasta el parche 12.2.0 · <fecha si se sabe>".
function Ach:UntilText(patch)
	local when = L.ACH_PATCH_WHEN and L.ACH_PATCH_WHEN[patch]
	return L.ACH_UNTIL:format(self:PatchText(patch)) .. (when and (" · " .. when) or "")
end

-- Availability → "yes" / "no" / "timed" / "limited" / "unknown" / nil, and the reason.
-- "timed" (D-82): ATT knows the patch that removes it and it has not arrived yet.
-- Disponibilidad → "yes" / "no" / "timed" / "limited" / "unknown" / nil, y el motivo.
-- "timed" (D-82): ATT sabe el parche que lo quita y todavía no llega.
function Ach:Status(key)
	local id = idOf(key)
	local u = IL.ACH.avail[id]
	local where = index and index.byID[id]
	local root = where and where.root
	if u == 1 then return "no", L.ACH_U[1] end
	local rwp, now = self:RemovedPatch(key), clientPatch()
	if rwp and now > 0 then
		if rwp <= now then return "no", L.ACH_REMOVED_IN:format(self:PatchText(rwp)) end
		return "timed", self:UntilText(rwp)
	end
	if u == 2 then return "no", L.ACH_U[2] end
	if u and u > 0 then return "limited", L.ACH_U[u] or L.ACH_U.limited end
	if root == LEGACY then return "no", L.ACH_U[4] end
	if root == FEATS then return u == 0 and "yes" or "unknown", nil end
	-- A regular achievement with no ATT note is still in the game (D-72).
	-- Un logro normal sin nota de ATT sigue en el juego (D-72).
	if root then return "yes", nil end
	return nil, nil
end

-- Expansion number (1 Classic … 12 Midnight) or nil: by category, else ATT (D-71, D-78).
-- Número de expansión (1 Clásico … 12 Midnight) o nil: por categoría, si no, ATT (D-71, D-78).
function Ach:Expansion(key)
	local id = idOf(key)
	local e = index and index.byID[id]
	local cat = e and e.cat or GetAchievementCategory(id)
	local D, dc = IL.ACH, cat and DUNGEON_CATS[cat]
	return (dc and dc[1]) or (cat and (EXP_CAT_EXTRA[cat] or (D.expCat and D.expCat[cat])))
		or (D.expAch and D.expAch[id]) or nil
end

local function sectionOf(e)
	if e.root == DUNGEONS then
		local dc = DUNGEON_CATS[e.cat]
		if dc and dc[2] == "d" then return "dungeons" elseif dc and dc[2] == "r" then return "raids" end
	end
	return e.root
end

local function sectionText(sec)
	if sec == "dungeons" then return L.ACH_DUNGEONS elseif sec == "raids" then return L.ACH_RAIDS end
	return catName(sec)
end

function Ach:CategoryText(key)
	local where = index and index.byID[idOf(key)]
	return where and where.group.text or ""
end

-- Standing reached by accumulated reputation from Neutral (how criteria count it: 42000 = Exalted).
-- Nivel según la reputación acumulada desde Neutral (como la cuentan los criterios: 42000 = Exaltado).
local function standingOf(acc)
	local tier, base = 4, 0
	while tier < 8 and acc >= base + TIER[tier] do
		base = base + TIER[tier]
		tier = tier + 1
	end
	return tier, acc - base
end

local function label(standing) return _G["FACTION_STANDING_LABEL" .. standing] or tostring(standing) end
local function num(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

-- "You have: Honored 3,200/12,000 · 18,600 to go" from a criterion's accumulated value.
-- "Tienes: Honorable 3,200/12,000 · te faltan 18,600" desde el valor acumulado de un criterio.
local function repNoteAcc(acc, target)
	local tier, inTier = standingOf(acc or 0)
	local now = label(tier) .. (tier < 8 and (" " .. num(inTier) .. "/" .. num(TIER[tier])) or "")
	local left = math.max(0, target - (acc or 0))
	if left == 0 then return L.ACH_REP_HAVE:format(now) end
	return L.ACH_REP_HAVE:format(now) .. " · " .. L.ACH_REP_LEFT:format(num(left))
end

-- Same from the faction data (for Insane in the Membrane, which has no criteria in the client).
-- Lo mismo desde los datos de la facción (para Demente supereminente, sin criterios en el cliente).
function Ach:RepStatus(factionID, target)
	local d = C_Reputation and C_Reputation.GetFactionDataByID and C_Reputation.GetFactionDataByID(factionID)
	if not d or not d.reaction then return false, L.ACH_REP_NONE end
	local r = d.reaction
	local cur = (d.currentStanding or 0) - (d.currentReactionThreshold or 0)
	local size = (d.nextReactionThreshold or 0) - (d.currentReactionThreshold or 0)
	local now = label(r) .. (size > 0 and (" " .. num(cur) .. "/" .. num(size)) or "")
	if r >= target then return true, L.ACH_REP_HAVE:format(now) end
	local left = math.max(0, size - cur)
	for t = r + 1, target - 1 do left = left + TIER[t] end
	return false, L.ACH_REP_HAVE:format(now) .. " · " .. L.ACH_REP_LEFT:format(num(left))
end

-- Criteria of an achievement with progress, rep notes and locations.
-- Criterios de un logro con progreso, notas de reputación y ubicaciones.
--   { text, done, have, need, ach, faction, note, map, x, y, npc, item, object, tip }
function Ach:Criteria(key)
	local id = idOf(key)
	local D = IL.ACH
	local pins = D.crit[id] or {}
	local out = {}
	if id == 2336 then -- Insane in the Membrane / Demente supereminente
		for _, f in ipairs(D.insane) do
			local done, note = self:RepStatus(f[1], f[2])
			out[#out + 1] = { text = IL.Int:GetFactionName(f[1]) .. " — " .. label(f[2]), done = done, note = note, faction = f[1] }
		end
		return out
	end
	local n = GetAchievementNumCriteria(id) or 0
	for i = 1, n do
		local text, ctype, done, have, need, _, _, asset, qtyText, critID = GetAchievementCriteriaInfo(id, i)
		local c = { n = i, text = (text and text ~= "") and text or L.ACH_CRITERION_N:format(i), done = done and true or false }
		if need and need > 1 then c.have, c.need, c.qtyText = have or 0, need, qtyText end
		if ctype == CRITERIA_ACHIEVEMENT and asset and asset > 0 then
			c.ach = asset
			if c.text == L.ACH_CRITERION_N:format(i) then c.text = self:GetName("a" .. asset) end
		elseif ctype == CRITERIA_REPUTATION and asset and asset > 0 then
			c.faction = asset
			if not c.done and need then c.note = repNoteAcc(have, need) end
			c.have, c.need = nil, nil
		end
		local p = pins[i]
		if p then
			c.map, c.x, c.y, c.npc, c.item, c.object, c.tip = p[1], p[2], p[3], p[4], p[5], p[6], p[7]
		end
		-- Collections and others: the item of the criterion, clickable to its detail (D-74).
		-- Colecciones y otros: el objeto del criterio, con clic a su detalle (D-74).
		if not c.item and CRITERIA_ITEM[ctype] and asset and asset > 0 then c.item = asset end
		-- Our own suggestion for this criterion (LogrosDoc, D-70), by criteria ID: text or
		-- { text, map, x, y }; its place is used only when ATT has none.
		-- Sugerencia propia del criterio (LogrosDoc, D-70), por ID: texto o { texto, mapa, x, y };
		-- su lugar solo se usa si ATT no trae uno.
		local hint = critID and L.ACH_CRIT_TIPS and L.ACH_CRIT_TIPS[critID]
		if not hint and text and L.ACH_CRIT_TEXT and L.ACH_CRIT_TEXT[id] then hint = L.ACH_CRIT_TEXT[id][text] end -- D-80
		if type(hint) == "table" then
			c.hint = hint[1]
			if not c.map and hint[2] then c.map, c.x, c.y = hint[2], hint[3], hint[4] end
		elseif hint then
			c.hint = hint
		end
		out[#out + 1] = c
	end
	return out
end

-- Every place of an achievement (D-79): its criteria and its guide steps with coordinates, done or
-- not (onlyMissing: just the criteria still missing). Same place only once. { map, x, y, title }
-- Todos los lugares de un logro (D-79): sus criterios y los pasos de la guía con coordenadas, hechos
-- o no (onlyMissing: solo los criterios que faltan). El mismo lugar una sola vez. { map, x, y, title }
function Ach:Places(key, onlyMissing, criteria)
	local out, seen = {}, {}
	local function put(map, x, y, title)
		if not (map and x and y) then return end
		local k = map .. ":" .. ("%.1f:%.1f"):format(x, y)
		if seen[k] then return end
		seen[k] = true
		out[#out + 1] = { map = map, x = x, y = y, title = title }
	end
	local name = self:GetName(key) or ""
	for _, c in ipairs(criteria or self:Criteria(key)) do
		if not (onlyMissing and c.done) then put(c.map, c.x, c.y, name .. ": " .. (c.text or "")) end
	end
	if not onlyMissing then
		for i, step in ipairs(L.ACH_GUIDES and L.ACH_GUIDES[idOf(key)] or {}) do
			if type(step) == "table" then
				local text = step[1] or ""
				if #text > 60 then text = text:sub(1, 57):gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", "") .. "…" end
				put(step[2], step[3], step[4], name .. " · " .. i .. ". " .. text)
			end
		end
	end
	return out
end

-- Progress: done, total. One criterion with a quantity uses the quantity.
-- Progreso: hechos, total. Un solo criterio con cantidad usa la cantidad.
function Ach:Progress(key, criteria)
	local info = self:Info(key)
	criteria = criteria or self:Criteria(key)
	local n = #criteria
	if info and info.completed then return math.max(n, 1), math.max(n, 1) end
	if n == 1 and criteria[1].need then return criteria[1].have, criteria[1].need end
	if n == 0 then return 0, 1 end
	local done = 0
	for _, c in ipairs(criteria) do if c.done then done = done + 1 end end
	return done, n
end

-- Requirements: account/character, availability, previous one, content, items, "part of".
-- Requisitos: cuenta/personaje, disponibilidad, el anterior, contenido, objetos, "es parte de".
--   { { text, ach = id? } }
function Ach:Requirements(key, criteria)
	local id = idOf(key)
	local info = self:Info(key) or {}
	local out = {}
	out[#out + 1] = { text = info.account and L.ACH_ACCOUNT_LONG or L.ACH_CHAR_LONG }
	local status, reason = self:Status(key)
	if status == "no" then out[#out + 1] = { text = L.ACH_UNAVAILABLE_LONG .. (reason and (" " .. L.ACH_REASON:format(reason)) or "") } end
	if status == "limited" then out[#out + 1] = { text = L.ACH_LIMITED_LONG .. (reason and (" " .. L.ACH_REASON:format(reason)) or "") } end
	if status == "timed" then out[#out + 1] = { text = L.ACH_TIMED_LONG:format(reason) } end -- D-82
	if status == "yes" then out[#out + 1] = { text = L.ACH_AVAILABLE_LONG } end
	local prev = GetPreviousAchievement and GetPreviousAchievement(id)
	if prev then out[#out + 1] = { text = L.ACH_BEFORE:format(self:GetName("a" .. prev)), ach = prev } end
	local where = index and index.byID[id]
	if where and where.root == DUNGEONS and where.cat ~= where.root then
		out[#out + 1] = { text = L.ACH_GROUP_CONTENT:format(catName(where.cat)) }
	end
	for _, c in ipairs(criteria or self:Criteria(key)) do
		if c.ach and not (index and index.byID[c.ach]) then
			local cat = GetAchievementCategory(c.ach)
			local note = cat and CONTENT_NOTE[rootOf(cat)]
			if note then out[#out + 1] = { text = L[note]:format(self:GetName("a" .. c.ach)) } end
		end
	end
	for _, other in ipairs(IL.ACH.requiredBy[id] or {}) do
		out[#out + 1] = { text = L.ACH_PART_OF:format(self:GetName("a" .. other)), ach = other }
	end
	return out
end

-- Ways to raise a reputation (ATT): repeatable quests and turn-ins, with NPC and place.
-- Formas de subir una reputación (ATT): misiones repetibles y entregas, con NPC y lugar.
--   { { quest, map, x, y, npc, item, count, max, repeatable } }
function Ach:RepWays(factionID)
	local out = {}
	for _, q in ipairs(IL.ACH.rep[factionID] or {}) do
		out[#out + 1] = { quest = q[1], map = q[2], x = q[3], y = q[4], npc = q[5], item = q[6], count = q[7],
			max = q[8], repeatable = q[9] }
	end
	return out
end

-- Mount and Toy Box achievements: what is still missing. / Monturas y juguetes: lo que falta.
function Ach:CollectionKind(key)
	local where = index and index.byID[idOf(key)]
	if not where then return nil end
	if where.cat == MOUNTS then return "mounts" end
	if where.cat == TOYS then return "toys" end
	return nil
end

-- Mounts not collected that this character can get, by source. / Monturas que faltan, por origen.
--   { { source = text, items = { { name, icon, id } } } }
function Ach:MissingMounts()
	local bySource, order = {}, {}
	if not (C_MountJournal and C_MountJournal.GetMountIDs) then return order end
	for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
		local name, _, icon, _, _, sourceType, _, _, _, hideOnChar, collected = C_MountJournal.GetMountInfoByID(mountID)
		if name and not collected and not hideOnChar then
			local src = (sourceType and _G["BATTLE_PET_SOURCE_" .. sourceType]) or L.ACH_SOURCE_OTHER
			if not bySource[src] then
				bySource[src] = { source = src, items = {} }
				order[#order + 1] = bySource[src]
			end
			local list = bySource[src].items
			list[#list + 1] = { name = name, icon = icon, id = mountID }
		end
	end
	for _, g in ipairs(order) do table.sort(g.items, function(a, b) return a.name < b.name end) end
	table.sort(order, function(a, b) return #a.items > #b.items end)
	return order
end

---------------------------------------------------------------------------
-- List / Lista
---------------------------------------------------------------------------
-- Filters (D-72): all · missing · have. Returns groups (copied keys).
-- Filtros (D-72): todos · faltan · tengo. Devuelve grupos (claves copiadas).

-- By expansion (D-78): expansion › section › topic (a profession, a collection…). Feats of Strength
-- and Legacy are one more section of each expansion. Returns groups for the list's fold (parent ids).
-- Por expansión (D-78): expansión › sección › tema (una profesión, una colección…). Proezas y Legado
-- son una sección más de cada expansión. Devuelve grupos para el plegado de la lista (ids de padre).
-- avail (D-82): "all" · "yes" (available, also special ways) · "timed" · "no" (retired).
-- avail (D-82): "all" · "yes" (disponibles, también vías especiales) · "timed" · "no" (retirados).
local AVAIL_PASS = {
	yes = { yes = true, limited = true }, timed = { timed = true }, no = { no = true },
}
function Ach:AvailPass(key, avail)
	local want = AVAIL_PASS[avail]
	if not want then return true end
	return want[self:Status(key) or ""] == true
end

function Ach:BuildGroups(filter, query, avail)
	local idx = self:Ensure()
	local qID = query ~= "" and query:match("^%d+$")
	local secRank, rootRank = {}, {}
	for i, s in ipairs(SECTION_ORDER) do secRank[s] = i end
	for i, r in ipairs(ROOT_ORDER) do rootRank[r] = i end
	local blocks, shown, have = {}, 0, 0
	for _, g in ipairs(idx.groups) do
		for _, key in ipairs(g.keys) do
			local e = idx.byID[idOf(key)]
			local ok = e ~= nil
			if ok and query ~= "" then
				ok = (qID and key:sub(2) == qID) or lowerName(key):find(query, 1, true) ~= nil
			end
			if ok and filter == "missing" then ok = not self:IsCompleted(key) and self:Status(key) ~= "no"
			elseif ok and filter == "have" then ok = self:IsCompleted(key) end
			if ok then ok = IL:FactionPass(key) end
			if ok and avail and avail ~= "all" then ok = self:AvailPass(key, avail) end
			if ok then
				local bid = GENERAL[e.root] and "gen" or self:Expansion(key) or 0
				local b = blocks[bid]
				if not b then b = { secs = {}, secList = {} }; blocks[bid] = b end
				local sec = sectionOf(e)
				local s = b.secs[sec]
				if not s then
					s = { keys = {}, subs = {}, subList = {} }
					b.secs[sec], b.secList[#b.secList + 1] = s, sec
				end
				local into = s.keys
				if SUBDIVIDED[e.root] and e.cat ~= e.root then
					into = s.subs[e.cat]
					if not into then into = {}; s.subs[e.cat], s.subList[#s.subList + 1] = into, e.cat end
				end
				into[#into + 1] = key
				shown = shown + 1
				if self:IsCompleted(key) then have = have + 1 end
			end
		end
	end
	local out = {}
	local function group(id, text, keys, parent)
		local done = 0
		for _, key in ipairs(keys) do if self:IsCompleted(key) then done = done + 1 end end
		out[#out + 1] = { id = id, text = text, keys = keys, have = done, total = #keys, parent = parent, defaultFolded = true }
		return out[#out]
	end
	local newest = 0
	for bid in pairs(blocks) do if type(bid) == "number" and bid > newest then newest = bid end end
	local order = { "gen" }
	for x = newest, 1, -1 do order[#order + 1] = x end
	order[#order + 1] = 0
	local function secKey(s) return secRank[s] or (100 + (rootRank[s] or 99)) end
	for _, bid in ipairs(order) do
		local b = blocks[bid]
		if b then
			local bgid = "x" .. bid
			local text = (bid == "gen" and L.ACH_GENERAL) or (bid == 0 and L.ACH_NO_EXP)
				or (IL.Data and IL.Data.ExpansionName and IL.Data:ExpansionName(bid - 1)) or ("#" .. bid)
			-- The newest expansion starts open. / La expansión más nueva empieza abierta.
			out[#out + 1] = { id = bgid, text = text, keys = {}, isParent = true, defaultFolded = bid ~= newest }
			table.sort(b.secList, function(x, y)
				local rx, ry = secKey(x), secKey(y)
				if rx ~= ry then return rx < ry end
				return tostring(x) < tostring(y)
			end)
			for _, sec in ipairs(b.secList) do
				local s, sid = b.secs[sec], bgid .. ":" .. sec
				local g = group(sid, sectionText(sec), s.keys, bgid)
				if #s.subList > 0 then
					g.isParent = true
					for _, cat in ipairs(s.subList) do group(sid .. ":" .. cat, catName(cat), s.subs[cat], sid) end
				end
			end
		end
	end
	return out, shown, have
end

-- Earning an achievement updates its state and redraws the list. Progress on a criterion (very
-- frequent) only redraws the detail, at most once a second.
-- Ganar un logro actualiza su estado y redibuja la lista. Avanzar un criterio (muy seguido)
-- solo redibuja el detalle, como mucho una vez por segundo.
function Ach:Init()
	IL.OnEvents({ "ACHIEVEMENT_EARNED" }, function(_, id)
		local e = index and id and index.byID[id]
		if e then e.done = true end
		if IL.UI and IL.UI:IsShown() and IL.UI.tab == "ach" then IL:RequestRefresh() end
	end)
	local pending = false
	IL.OnEvents({ "CRITERIA_UPDATE", "UPDATE_FACTION" }, function()
		if pending or not (IL.UI and IL.UI:IsShown() and IL.UI.tab == "ach") then return end
		pending = true
		C_Timer.After(1, function()
			pending = false
			if IL.UI and IL.UI:IsShown() and IL.UI.tab == "ach" then IL.UI.achDetail:Refresh(true) end
		end)
	end)
end
