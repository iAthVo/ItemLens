--[[
	ItemLens · Modules/GameData.lua
	Fills the gap while AllTheThings catches up with a new patch: reads the game's own Encounter
	Journal (raid and dungeon loot of the newest tiers) and Appearance Sets of the current expansion
	(tier, PvP and other sets). Only items without imported origins are kept, once per game build,
	in ItemLensDB.game; nothing is sent anywhere.
	Cubre el hueco mientras AllTheThings se pone al día con un parche nuevo: lee el Diario de
	encuentros del juego (botín de bandas y calabozos de los niveles más nuevos) y los Conjuntos de
	apariencias de la expansión actual (de banda, JcJ y otros). Solo se guardan los objetos sin
	origen importado, una vez por versión del juego, en ItemLensDB.game; no se envía nada.
	© 2026 iAthVo_Kr · MIT License

	ItemLensDB.game = { v = 1, build = "12.1.5.70961 esMX", items = { [itemID] = "b<encounter>,<instance>;t<setID>" } }
	(same origin format as IL.DB.sources; "t" = appearance set / mismo formato; "t" = conjunto)
]]

local _, IL = ...

local Game = {}
IL.Game = Game

local TIERS = 2          -- newest Encounter Journal tiers to read (current season + expansion)

local function buildKey()
	local version, build = GetBuildInfo()
	return (version or "?") .. "." .. (build or "?") .. " " .. (GetLocale and GetLocale() or "")
end

local function db()
	local d = ItemLensDB and ItemLensDB.game
	if type(d) ~= "table" or d.v ~= 1 then
		d = { v = 1, items = {} }
		if ItemLensDB then ItemLensDB.game = d end
	end
	return d
end

-- Origins of an item in the same shape as Data:GetObtain (parsed by Data). / Orígenes crudos.
function Game:GetRaw(itemID)
	local d = ItemLensDB and ItemLensDB.game
	return d and d.items and d.items[itemID] or nil
end

function Game:GetItemIDs()
	local out = {}
	for id in pairs(db().items) do out[#out + 1] = id end
	return out
end

function Game:Count()
	local n = 0
	for _ in pairs(db().items) do n = n + 1 end
	return n
end

---------------------------------------------------------------------------
-- Scan / Lectura
---------------------------------------------------------------------------
local function imported(itemID)
	return IL.DB and IL.DB.sources and IL.DB.sources[itemID] ~= nil
end

local function addOrigin(items, itemID, origin)
	if not itemID or imported(itemID) then return end
	local cur = items[itemID]
	if not cur then items[itemID] = origin return end
	for part in cur:gmatch("[^;]+") do if part == origin then return end end
	items[itemID] = cur .. ";" .. origin
end

-- Encounter Journal: every encounter of the newest tiers, all classes and slots. The player's own
-- journal filters and selection are put back afterwards.
-- Diario de encuentros: cada encuentro de los niveles más nuevos, todas las clases y espacios. Los
-- filtros y la selección del jugador se restauran al terminar.
local function journalJobs()
	local jobs = {}
	if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex) then return jobs end
	local numTiers = EJ_GetNumTiers() or 0
	for tier = numTiers, math.max(1, numTiers - TIERS + 1), -1 do
		EJ_SelectTier(tier)
		for _, isRaid in ipairs({ true, false }) do
			local i = 1
			while true do
				local instID = EJ_GetInstanceByIndex(i, isRaid)
				if not instID then break end
				jobs[#jobs + 1] = { tier = tier, inst = instID }
				i = i + 1
			end
		end
	end
	return jobs
end

local function readInstance(items, job)
	EJ_SelectTier(job.tier)
	EJ_SelectInstance(job.inst)
	local e = 1
	while true do
		local _, _, encID = EJ_GetEncounterInfoByIndex(e, job.inst)
		if not encID then break end
		EJ_SelectEncounter(encID)
		local n = EJ_GetNumLoot and EJ_GetNumLoot() or 0
		for l = 1, n do
			local info = C_EncounterJournal and C_EncounterJournal.GetLootInfoByIndex and C_EncounterJournal.GetLootInfoByIndex(l)
			if info and info.itemID then addOrigin(items, info.itemID, "b" .. encID .. "," .. job.inst) end
		end
		e = e + 1
	end
end

-- Appearance sets of the current expansion (tier, PvP, others), every class.
-- Conjuntos de apariencias de la expansión actual (de banda, JcJ, otros), todas las clases.
local function setJobs()
	local out = {}
	if not (C_TransmogSets and C_TransmogSets.GetAllSets) then return out end
	local current = (GetServerExpansionLevel and GetServerExpansionLevel()) or LE_EXPANSION_LEVEL_CURRENT
	for _, s in ipairs(C_TransmogSets.GetAllSets() or {}) do
		if s.setID and s.expansionID == current then out[#out + 1] = s.setID end
	end
	return out
end

local function readSet(items, setID)
	local sources = C_TransmogSets.GetAllSourceIDs and C_TransmogSets.GetAllSourceIDs(setID) or {}
	for _, src in ipairs(sources) do
		local info = C_TransmogCollection.GetSourceInfo and C_TransmogCollection.GetSourceInfo(src)
		if info and info.itemID then addOrigin(items, info.itemID, "t" .. setID) end
	end
end

local running = false
local scan -- the scan in progress / la lectura en curso

local function blocked()
	return (InCombatLockdown and InCombatLockdown()) or (EncounterJournal and EncounterJournal:IsShown())
end

local function newScan(force)
	return { items = {}, j = 1, s = 1, force = force }
end

-- Reads until it is finished or `deadline` (LoadWork.Clock) arrives, putting the player's journal
-- filters back. Returns true when finished.
-- Lee hasta terminar o hasta `deadline` (LoadWork.Clock), y vuelve a poner los filtros del diario
-- del jugador. Devuelve true al terminar.
local function scanChunk(st, deadline)
	if not EJ_GetNumTiers and C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal") end
	local clock = IL.LoadWork.Clock
	local savedClass, savedSpec = EJ_GetLootFilter and EJ_GetLootFilter()
	local savedSlot = C_EncounterJournal and C_EncounterJournal.GetSlotFilter and C_EncounterJournal.GetSlotFilter()
	local savedTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
	if EJ_SetLootFilter then EJ_SetLootFilter(0, 0) end
	if C_EncounterJournal and C_EncounterJournal.SetSlotFilter and Enum and Enum.ItemSlotFilterType then
		C_EncounterJournal.SetSlotFilter(Enum.ItemSlotFilterType.NoFilter)
	end
	if not st.jobs then st.jobs = journalJobs() end
	while st.jobs[st.j] and clock() < deadline do
		pcall(readInstance, st.items, st.jobs[st.j])
		st.j = st.j + 1
	end
	if not st.jobs[st.j] then
		if not st.sets then st.sets = setJobs() end
		while st.sets[st.s] and clock() < deadline do
			pcall(readSet, st.items, st.sets[st.s])
			st.s = st.s + 1
		end
	end
	if EJ_SetLootFilter and savedClass then EJ_SetLootFilter(savedClass, savedSpec or 0) end
	if savedSlot and C_EncounterJournal.SetSlotFilter then C_EncounterJournal.SetSlotFilter(savedSlot) end
	if savedTier and EJ_SelectTier then EJ_SelectTier(savedTier) end
	return not st.jobs[st.j] and st.sets ~= nil and not st.sets[st.s]
end

local function finish(st)
	local d = db()
	d.items, d.build, d.at = st.items, buildKey(), time and time() or 0
	running, scan = false, nil
	local ids = Game:GetItemIDs()
	if IL.Data and IL.Data.OnGameData then IL.Data:OnGameData(ids) end
	IL:RequestRefresh()
	if st.force then IL:Print(IL.L.GAME_SCANNED, Game:Count()) end
end

-- On demand (/il juego): a few milliseconds per frame, out of combat and with the journal closed.
-- A pedido (/il juego): unos milisegundos por cuadro, fuera de combate y con el diario cerrado.
function Game:Scan(force)
	if running and not force then return end
	if not force and db().build == buildKey() then return end
	running = true
	scan = scan or newScan(force)
	scan.force = scan.force or force
	local st = scan
	local function step()
		if scan ~= st then return end
		if blocked() then return C_Timer.After(3, step) end
		if scanChunk(st, IL.LoadWork.Clock() + 8) then finish(st) else C_Timer.After(0.1, step) end
	end
	step()
end

-- During loading screens (D-85): nothing at all when this build is already read (the journal is
-- not even loaded); otherwise as much as fits, and the rest in the next loading screen.
-- En pantallas de carga (D-85): nada si esta versión ya se leyó (ni siquiera se carga el diario);
-- si no, lo que quepa, y el resto en la siguiente pantalla de carga.
function Game:LoadStep(deadline)
	if not scan and db().build == buildKey() then return true end
	if scan and scan.force then return true end -- /il juego is reading it / lo está leyendo /il juego
	if blocked() then return false end
	running = true
	scan = scan or newScan(false)
	local st = scan
	if scanChunk(st, deadline) then finish(st) return true end
	return false
end

function Game:IsRunning() return running end

function Game:Init()
	db()
	-- Once per game build or language, only while a loading screen is up (D-85).
	-- Una vez por versión del juego o idioma, solo con la pantalla de carga puesta (D-85).
	IL.LoadWork:Add("game", function(deadline) return Game:LoadStep(deadline) end)
end
