--[[
	ItemLens · Modules/Integrations.lua
	Names from the game client (NPCs, quests, instances, factions…) and the optional add-ons
	TomTom (waypoints) and Syndicator (extra characters). Everything works without them.
	Nombres del cliente del juego (NPC, misiones, instancias, facciones…) y los addons opcionales
	TomTom (puntos de ruta) y Syndicator (más personajes). Todo funciona sin ellos.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...
local L = IL.L

local Int = {}
IL.Int = Int

local TRADING_POST = -230 -- pseudo-vendor for the Trading Post / pseudo-vendedor del Puesto comercial

---------------------------------------------------------------------------
-- NPCs, world objects and quests / NPC, objetos del mundo y misiones
---------------------------------------------------------------------------
-- NPC names are read from the client through a unit hyperlink and cached. A secret name is
-- neither compared nor stored: "NPC #id" is shown and it is retried later.
-- Los nombres de NPC se leen del cliente con un hyperlink de unidad y se guardan. Un nombre
-- secreto no se compara ni se guarda: se muestra "NPC #id" y se reintenta después.
function Int:GetNPCName(npc)
	if npc == TRADING_POST then return L.TRADING_POST end
	local cache = ItemLensDB.npcNames
	if cache[npc] then return cache[npc] end
	local ok, name = pcall(function()
		local data = C_TooltipInfo.GetHyperlink(("unit:Creature-0-0-0-0-%d-0000000000"):format(npc))
		if not data or IL.IsSecret(data) or IL.IsSecret(data.lines) then return nil end
		local line = data.lines and data.lines[1]
		local text = line and line.leftText
		if IL.IsSecret(text) or type(text) ~= "string" then return nil end
		if text == "" or text == UNKNOWN then return nil end
		return text
	end)
	if ok and name then
		cache[npc] = name
		return name
	end
	return L.NPC_N:format(npc)
end

-- World objects: bundled name, in Spanish on Spanish clients.
-- Objetos del mundo: nombre incluido, en español en clientes en español.
function Int:GetObjectName(id)
	local DB = IL.DB
	local name = (IL.SPANISH and DB.objectsES and DB.objectsES[id]) or (DB.objects and DB.objects[id])
	return name or L.OBJECT_N:format(id)
end

-- Quest title from the client; if it is not cached yet it is requested and the UI refreshes
-- when it arrives.
-- Título de la misión del cliente; si todavía no está, se pide y la ventana se refresca al llegar.
local questEvents
local questUnavailable = {}
Int.questUnavailable = questUnavailable

function Int:GetQuestTitle(id)
	local title = C_QuestLog.GetTitleForQuestID(id)
	if title and title ~= "" then return title end
	if questUnavailable[id] then return L.QUEST_UNAVAILABLE:format(id) end
	if not questEvents then
		questEvents = IL.OnEvents({ "QUEST_DATA_LOAD_RESULT" }, function(_, questID, success)
			if not success and questID then questUnavailable[questID] = true end
			IL:RequestRefresh()
		end)
	end
	if C_QuestLog.RequestLoadQuestByID then C_QuestLog.RequestLoadQuestByID(id) end
	return L.QUEST_N:format(id)
end

---------------------------------------------------------------------------
-- Instances and places / Instancias y lugares
---------------------------------------------------------------------------
function Int:GetEncounterName(id)
	local name = EJ_GetEncounterInfo and EJ_GetEncounterInfo(id)
	return name or L.BOSS_N:format(id)
end

function Int:GetInstanceName(id)
	if not id then return nil end
	return EJ_GetInstanceInfo and EJ_GetInstanceInfo(id) or nil
end

function Int:GetDifficultyName(id)
	if not id then return nil end
	return GetDifficultyInfo and GetDifficultyInfo(id) or nil
end

-- Raid? From the Encounter Journal (12th value = isRaid) or else from the difficulty.
-- Returns true (raid), false (dungeon) or nil (unknown).
-- ¿Banda? Del Diario de encuentros (12.º valor = isRaid) o, si no, de la dificultad.
-- Devuelve true (banda), false (calabozo) o nil (no se sabe).
function Int:IsRaid(instID, diffID)
	if instID and EJ_GetInstanceInfo then
		local isRaid = select(12, EJ_GetInstanceInfo(instID))
		if isRaid ~= nil then return isRaid and true or false end
	end
	if diffID and GetDifficultyInfo then
		local _, groupType = GetDifficultyInfo(diffID)
		if groupType == "raid" then return true end
		if groupType == "party" then return false end
	end
	return nil
end

-- "Raid" / "Dungeon" / "Instance"
function Int:InstanceKind(instID, diffID)
	local raid = self:IsRaid(instID, diffID)
	if raid == true then return L.PLACE_RAID end
	if raid == false then return L.PLACE_DUNGEON end
	return L.PLACE_INSTANCE
end

-- "Zone", or "Instance" when the map is inside an instance.
-- "Zona", o "Instancia" si el mapa es el interior de una instancia.
function Int:MapKind(mapID)
	local info = mapID and C_Map.GetMapInfo(mapID)
	if info and Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Dungeon then return L.PLACE_INSTANCE end
	return L.PLACE_ZONE
end

function Int:GetZoneName(mapID, npc)
	if npc == TRADING_POST then return L.CAPITALS end
	if not mapID then return "" end
	local info = C_Map.GetMapInfo(mapID)
	return info and info.name or L.MAP_N:format(mapID)
end

function Int:FormatCoords(x, y)
	if not x or not y then return "" end
	return ("%.1f, %.1f"):format(x, y)
end

-- Category headers: text, or "=CONSTANT" for a WoW global string (already localized).
-- Encabezados de categoría: texto, o "=CONSTANTE" para un texto global de WoW (ya traducido).
function Int:GetHeaderName(id)
	local DB = IL.DB
	local v = id and ((IL.SPANISH and DB.headersES and DB.headersES[id]) or (DB.headers and DB.headers[id]))
	if not v then return nil end
	if v:sub(1, 1) == "=" then
		local g = _G[v:sub(2)]
		return type(g) == "string" and g or nil
	end
	return v
end

---------------------------------------------------------------------------
-- Achievements, professions and reputation / Logros, profesiones y reputación
---------------------------------------------------------------------------
function Int:GetAchievementName(id)
	if not GetAchievementInfo then return L.ACHIEVEMENT_N:format(id) end
	local _, name = GetAchievementInfo(id) -- the name is the 2nd value / el nombre es el 2.º valor
	return name or L.ACHIEVEMENT_N:format(id)
end

-- Fallback profession names by skill line. / Nombres de respaldo por línea de habilidad.
local PROFESSIONS_ES = {
	[171] = "Alquimia", [164] = "Herrería", [333] = "Encantamiento", [202] = "Ingeniería",
	[182] = "Herboristería", [773] = "Inscripción", [755] = "Joyería", [165] = "Peletería",
	[186] = "Minería", [393] = "Desuello", [197] = "Sastrería", [185] = "Cocina",
	[356] = "Pesca", [794] = "Arqueología",
}
local PROFESSIONS_EN = {
	[171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering",
	[182] = "Herbalism", [773] = "Inscription", [755] = "Jewelcrafting", [165] = "Leatherworking",
	[186] = "Mining", [393] = "Skinning", [197] = "Tailoring", [185] = "Cooking",
	[356] = "Fishing", [794] = "Archaeology",
}

function Int:GetProfessionName(id)
	local ok, name = pcall(function()
		return C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName and C_TradeSkillUI.GetTradeSkillDisplayName(id)
	end)
	if ok and type(name) == "string" and name ~= "" then return name end
	local fallback = IL.SPANISH and PROFESSIONS_ES or PROFESSIONS_EN
	return fallback[id] or L.PROFESSION_N:format(id)
end

function Int:GetFactionName(id)
	local name
	if C_Reputation and C_Reputation.GetFactionDataByID then
		local d = C_Reputation.GetFactionDataByID(id)
		name = d and d.name
	end
	if not name and GetFactionInfoByID then name = GetFactionInfoByID(id) end
	return name or L.FACTION_N:format(id)
end

-- Renown factions (Dragonflight onward) use small levels (1–40) instead of reputation points.
-- Las facciones de renombre (Dragonflight en adelante) usan niveles chicos (1–40), no puntos.
local function isRenown(value, factionID)
	if factionID and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
		local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
		if ok and data then return true end
	end
	return value > 0 and value < 100
end

-- Reputation value → "Renown 5", or the standing name from the client (Neutral 0, Friendly 3000,
-- Honored 9000, Revered 21000, Exalted 42000).
-- Valor de reputación → "Renombre 5", o el nivel con el texto del cliente (Neutral 0, Amistoso 3000,
-- Honorable 9000, Reverenciado 21000, Exaltado 42000).
function Int:StandingName(value, factionID)
	value = value or 0
	if isRenown(value, factionID) then return L.RENOWN_N:format(value) end
	local idx = (value >= 42000 and 8) or (value >= 21000 and 7) or (value >= 9000 and 6) or (value >= 3000 and 5) or 4
	return _G["FACTION_STANDING_LABEL" .. idx] or tostring(value)
end

---------------------------------------------------------------------------
-- Waypoints: TomTom (optional) or the native map pin
-- Puntos de ruta: TomTom (opcional) o el pin nativo del mapa
---------------------------------------------------------------------------
function Int:CanWaypoint(v)
	return v and v.map and v.x and v.y and true or false
end

function Int:SetWaypoint(v)
	if not self:CanWaypoint(v) then return end
	local title = v.title or (v.npc and self:GetNPCName(v.npc)) or L.TITLE
	local x, y = v.x / 100, v.y / 100
	if TomTom and TomTom.AddWaypoint then
		TomTom:AddWaypoint(v.map, x, y, { title = title, from = "ItemLens" })
	elseif C_Map.CanSetUserWaypointOnMap(v.map) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(v.map, x, y))
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	else
		IL:Print(L.PIN_FAIL)
		return
	end
	IL:Print(L.PIN_SET, title, ("%.1f"):format(v.x), ("%.1f"):format(v.y))
end

---------------------------------------------------------------------------
-- Syndicator (optional): characters ItemLens has not seen yet
-- Syndicator (opcional): personajes que ItemLens todavía no ha visto
---------------------------------------------------------------------------
function Int:HasSyndicator()
	return Syndicator and Syndicator.API and Syndicator.API.IsReady and Syndicator.API.IsReady()
end

-- { { full = "Name-Realm", total, bags, bank, equipped, class }, … } or nil
function Int:GetSyndicatorOwners(key)
	if not self:HasSyndicator() then return nil end
	local kind, id = IL.SplitKey(key)
	local out = {}
	if kind == "i" then
		local ok, info = pcall(Syndicator.API.GetInventoryInfoByItemID, id, false, false)
		if not ok or not info then return nil end
		for _, c in ipairs(info.characters or {}) do
			local bags = (c.bags or 0) + (c.mail or 0) + (c.void or 0) + (c.auctions or 0)
			local total = bags + (c.bank or 0) + (c.equipped or 0)
			if total > 0 and c.character then
				out[#out + 1] = { full = c.character .. "-" .. (c.realmNormalized or ""), total = total,
					bags = bags, bank = c.bank or 0, equipped = c.equipped or 0, class = c.className }
			end
		end
	else
		local ok, list = pcall(Syndicator.API.GetCurrencyInfo, id, false, false)
		if not ok or not list then return nil end
		for _, c in ipairs(list) do
			if c.character then
				out[#out + 1] = { full = c.character .. "-" .. (c.realmNormalized or ""), total = c.quantity,
					bags = c.quantity, bank = 0, equipped = 0, class = c.className }
			end
		end
	end
	return #out > 0 and out or nil
end
