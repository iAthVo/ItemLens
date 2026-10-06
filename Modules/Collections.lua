--[[
	ItemLens · Modules/Collections.lua
	Whether something is already learned, and the full collection sets for the Collections tab:
	Skyriding manuscripts, class unlocks, other unlocks, class quests and artifact appearances.
	Mounts, pets, toys and appearances use the game's own collection APIs.
	Si algo ya se aprendió, y los conjuntos completos de la pestaña Colecciones: manuscritos,
	desbloqueos de clase, otros desbloqueos, misiones de clase y apariencias de artefacto.
	Monturas, mascotas, juguetes y apariencias usan las funciones de colección del juego.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...
local L = IL.L

local Coll = {}
IL.Coll = Coll

Coll.SETS = { "mm", "class", "other", "quests", "art" }

---------------------------------------------------------------------------
-- Learned state / Estado aprendido
---------------------------------------------------------------------------
local function questDone(questID)
	if not questID then return false end
	if C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) then return true end
	if C_QuestLog.IsQuestFlaggedCompletedOnAccount and C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID) then return true end
	return false
end

local function spellKnown(spellID)
	if not spellID then return false end
	if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then return true end
	if IsSpellKnown and IsSpellKnown(spellID) then return true end
	if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
	return false
end

local function myClassID()
	return (select(3, UnitClass("player")))
end

-- Shared rule for class-bound entries. / Regla común para entradas ligadas a una clase.
local function classState(learned, classID)
	if learned then return "have" end
	if classID and classID ~= myClassID() then return "otherclass" end
	return "missing"
end

-- "have" | "missing" | "otherclass" | nil (not collectible / no es coleccionable)
function Coll:GetState(key)
	local kind, id = IL.SplitKey(key)
	if kind == "q" then
		local q = IL.Data:GetClassQuest(id)
		return q and classState(questDone(id), q.class) or nil
	end
	if kind == "f" then
		local a = IL.Data:GetArtifact(id)
		if not a then return nil end
		local has = a.source and C_TransmogCollection and C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance
			and C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(a.source)
		return classState(has, a.class)
	end
	if kind ~= "i" then return nil end

	local C = IL.DB.collections
	if C then
		local m = C.mm and C.mm[id]
		if m then return questDone(m[1]) and "have" or "missing" end
		local q = C.cq and C.cq[id]
		if q then return classState(questDone(q[1]), q[2]) end
		local s = C.cs and C.cs[id]
		if s then return classState(spellKnown(s[1]), s[2]) end
	end

	if C_MountJournal and C_MountJournal.GetMountFromItem then
		local mountID = C_MountJournal.GetMountFromItem(id)
		if mountID then
			local isCollected = select(11, C_MountJournal.GetMountInfoByID(mountID))
			return isCollected and "have" or "missing"
		end
	end
	if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
		local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(id))
		if speciesID then
			return (C_PetJournal.GetNumCollectedInfo(speciesID) or 0) > 0 and "have" or "missing"
		end
	end
	if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(id) then
		return PlayerHasToy(id) and "have" or "missing"
	end
	if C_TransmogCollection and C_TransmogCollection.GetItemInfo and C_TransmogCollection.GetItemInfo(id) then
		return C_TransmogCollection.PlayerHasTransmog(id) and "have" or "missing"
	end
	return nil
end

---------------------------------------------------------------------------
-- Sets / Conjuntos
---------------------------------------------------------------------------
local entriesCache = {}

-- Entries of a set: { { key, group, exp, class, reward }, … } (exp = Blizzard ID).
-- Entradas de un conjunto (exp = ID de Blizzard).
function Coll:GetEntries(set)
	if entriesCache[set] then return entriesCache[set] end
	local C = IL.DB.collections or {}
	local list = {}
	local function exp(attExp) return attExp and (attExp - 1) or nil end
	if set == "mm" then
		-- Grouped by dragon (mount item). / Agrupados por dragón (objeto de montura).
		for item, v in pairs(C.mm or {}) do list[#list + 1] = { key = "i" .. item, group = v[2] or 0, exp = exp(v[3]) } end
	elseif set == "art" then
		-- Grouped by weapon. / Agrupados por arma.
		for appearanceID in pairs(IL.DB.artifacts or {}) do
			local a = IL.Data:GetArtifact(appearanceID)
			if a and a.weapon then
				list[#list + 1] = { key = "f" .. appearanceID, group = a.weapon, exp = 6, class = a.class }
			end
		end
	elseif set == "quests" then
		-- Group = class × 100 + expansion (99 = unknown). / Grupo = clase × 100 + expansión (99 = desconocida).
		for questID in pairs(IL.DB.classQuests or {}) do
			local q = IL.Data:GetClassQuest(questID)
			if q and q.class then
				list[#list + 1] = { key = "q" .. questID, group = q.class * 100 + (q.exp or 99), exp = q.exp,
					class = q.class, reward = #q.rewards > 0 }
			end
		end
	else
		-- "class": unlocks bound to a class · "other": the rest, grouped by expansion.
		-- "class": desbloqueos de una clase · "other": el resto, agrupado por expansión.
		local wantClass = set == "class"
		for _, src in ipairs({ C.cq or {}, C.cs or {} }) do
			for item, v in pairs(src) do
				if (v[2] ~= nil) == wantClass then
					local e = exp(v[3])
					list[#list + 1] = { key = "i" .. item, group = wantClass and v[2] or (e or -1), exp = e, class = v[2] }
				end
			end
		end
	end
	entriesCache[set] = list
	return list
end

function Coll:GroupName(set, group)
	if set == "mm" then
		return group == 0 and L.COLL_OTHER or IL.Data:GetDisplayName("i" .. group)
	elseif set == "class" then
		return (GetClassInfo and GetClassInfo(group)) or L.CLASS_N:format(group)
	elseif set == "art" then
		local classID
		for _, e in ipairs(self:GetEntries("art")) do if e.group == group then classID = e.class break end end
		local className = classID and GetClassInfo and GetClassInfo(classID) or "?"
		return L.PLACE_FMT:format(className, IL.Data:GetDisplayName("i" .. group))
	elseif set == "quests" then
		local classID, exp = math.floor(group / 100), group % 100
		local className = (GetClassInfo and GetClassInfo(classID)) or L.CLASS_N:format(classID)
		return L.PLACE_FMT:format(className, exp == 99 and L.UNKNOWN_EXP or IL.Data:ExpansionName(exp))
	end
	if group == -1 then return L.UNKNOWN_EXP end
	return IL.Data:ExpansionName(group)
end

-- Group order: class by ID, expansions newest first, dragons by name.
-- Orden de grupos: clase por ID, expansiones de la más nueva a la más vieja, dragones por nombre.
local function compareGroups(set)
	return function(a, b)
		if set == "class" then return a.id < b.id end
		if set == "art" then return a.name < b.name end -- "Class · Weapon"
		if set == "quests" then
			local ca, cb = math.floor(a.id / 100), math.floor(b.id / 100)
			if ca ~= cb then return ca < cb end
			local ea, eb = a.id % 100, b.id % 100
			if ea == 99 or eb == 99 then return eb == 99 and ea ~= 99 end
			return ea > eb
		end
		if set == "other" then return a.id > b.id end
		if (a.id == 0) ~= (b.id == 0) then return b.id == 0 end -- "Others" last / "Otros" al final
		return a.name < b.name
	end
end

-- List for the tab: group headers with progress, then keys.
-- filters = { set, exp, class, state ("all" | "missing" | "have"), query, rewardOnly }
-- Returns elements, learned, total (counting expansion and class filters, not the state one).
-- The class filter only drops entries of ANOTHER class; class-free entries always pass.
-- Lista para la pestaña: encabezados de grupo con progreso y luego claves.
-- Devuelve elementos, aprendidos y total (con los filtros de expansión y clase, sin el de estado).
-- El filtro de clase solo descarta entradas de OTRA clase; las que no dependen de clase siempre pasan.
function Coll:BuildList(filters)
	local set = filters.set or "mm"
	local query = filters.query or ""
	local groups, order = {}, {}
	local have, total = 0, 0
	for _, e in ipairs(self:GetEntries(set)) do
		local passExp = filters.exp == "all" or filters.exp == nil or e.exp == filters.exp
		local passClass = filters.class == "all" or filters.class == nil or e.class == nil or e.class == filters.class
		local passReward = not (filters.rewardOnly and set == "quests") or e.reward
		if passExp and passClass and passReward then
			local learned = self:GetState(e.key) == "have"
			total = total + 1
			if learned then have = have + 1 end
			local g = groups[e.group]
			if not g then
				g = { id = e.group, items = {}, have = 0, total = 0 }
				groups[e.group] = g
				order[#order + 1] = g
			end
			g.total = g.total + 1
			if learned then g.have = g.have + 1 end
			local passState = filters.state == "all" or filters.state == nil
				or (filters.state == "have" and learned) or (filters.state == "missing" and not learned)
			local name = IL.Data:GetDisplayName(e.key)
			if passState and (query == "" or strlower(name):find(query, 1, true)) then
				g.items[#g.items + 1] = { key = e.key, name = name }
			end
		end
	end
	for _, g in ipairs(order) do g.name = self:GroupName(set, g.id) end
	table.sort(order, compareGroups(set))
	local out = {}
	for _, g in ipairs(order) do
		if #g.items > 0 then
			out[#out + 1] = { header = true, id = g.id, text = g.name, have = g.have, total = g.total }
			table.sort(g.items, function(a, b) return a.name < b.name end)
			for _, it in ipairs(g.items) do out[#out + 1] = it.key end
		end
	end
	return out, have, total
end

---------------------------------------------------------------------------
-- Filter options / Opciones de los filtros
---------------------------------------------------------------------------
-- Classes present in a set. Empty = the set does not depend on class.
-- Clases presentes en un conjunto. Vacío = el conjunto no depende de la clase.
function Coll:GetClasses(set)
	local seen, list = {}, {}
	for _, e in ipairs(self:GetEntries(set)) do
		if e.class and not seen[e.class] then seen[e.class] = true; list[#list + 1] = e.class end
	end
	table.sort(list)
	return list
end

-- Every class with its entry count in the set: { { id, count }, … } by class ID.
-- Todas las clases con cuántas entradas tienen en el conjunto, por ID de clase.
function Coll:GetClassCounts(set)
	local counts = {}
	for _, e in ipairs(self:GetEntries(set)) do
		if e.class then counts[e.class] = (counts[e.class] or 0) + 1 end
	end
	local list = {}
	for id = 1, (GetNumClasses and GetNumClasses()) or 13 do list[#list + 1] = { id = id, count = counts[id] or 0 } end
	return list
end

-- Expansions present in a set, newest first. / Expansiones del conjunto, la más nueva primero.
function Coll:GetExpansions(set)
	local seen, list = {}, {}
	for _, e in ipairs(self:GetEntries(set)) do
		if e.exp and not seen[e.exp] then seen[e.exp] = true; list[#list + 1] = e.exp end
	end
	table.sort(list, function(a, b) return a > b end)
	return list
end

---------------------------------------------------------------------------
-- Class quests per character / Misiones de clase por personaje
---------------------------------------------------------------------------
function Coll:GetClassQuestIDs(classID)
	local ids = {}
	for questID in pairs(IL.DB.classQuests or {}) do
		local q = IL.Data:GetClassQuest(questID)
		if q and q.class == classID then ids[#ids + 1] = questID end
	end
	return ids
end

-- Account characters of the quest's class and whether each one already did it.
-- Personajes de la cuenta de la clase de la misión y si cada uno ya la hizo.
function Coll:GetQuestChars(questID)
	local q = IL.Data:GetClassQuest(questID)
	if not q or not q.class then return {} end
	local _, classFile = GetClassInfo(q.class)
	local me = IL.PlayerKey()
	local out = {}
	for fullName, c in pairs(ItemLensDB.chars or {}) do
		if c.class == classFile then
			local done
			if fullName == me then done = questDone(questID)
			else done = c.classQuests and c.classQuests[questID] == true end
			out[#out + 1] = { name = IL.ShortName(fullName), done = done, class = classFile }
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

function Coll:Init()
	IL.OnEvents({ "QUEST_TURNED_IN", "NEW_MOUNT_ADDED", "NEW_PET_ADDED", "TOYS_UPDATED",
		"TRANSMOG_COLLECTION_UPDATED", "LEARNED_SPELL_IN_SKILL_LINE" }, function() IL:RequestRefresh() end)
end
