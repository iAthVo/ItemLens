-- Prueba de lógica fuera del juego (Lua 5.1) con la API de WoW simulada.
-- Uso (desde la carpeta ItemLens):  lua tools\smoke_test.lua
local stub
stub = setmetatable({}, { __index = function() return function() return stub end end, __call = function() return stub end })

-- API simulada ---------------------------------------------------------
CreateFrame = function() return stub end
C_Timer = { After = function() end }
C_AddOns = { GetAddOnMetadata = function() return "test" end }
C_Map = { GetBestMapForUnit = function() return 2215 end, GetMapInfo = function(id) return { name = "Mapa" .. id } end }
C_Item = {
	GetItemInfo = function(id)
		if id == 206350 then return "Remanente radiante", "|Hitem:206350|h", 1, 0, 0, "Moneda", 0, 0, 0, 0, 0, 0, 0, 0, 10 end
		return nil
	end,
	RequestLoadItemDataByID = function() end,
	GetItemIconByID = function() return 1 end,
	-- itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID
	GetItemInfoInstant = function(id)
		if id == 212664 then return id, "Material de profesión", "Cuero", "", 1, 7, 6 end
		return id, "Misceláneo", "Basura", "", 1, 15, 0
	end,
}
C_ToyBox = { GetToyInfo = function() return nil end }
C_QuestLog = { GetTitleForQuestID = function(id) return id == 70199 and "Pesca de prueba" or nil end, RequestLoadQuestByID = function() end }
ItemLensDB = { npcNames = {} }
C_CurrencyInfo = { GetCurrencyInfo = function(id) return { name = "Moneda" .. id, iconFileID = 2, quality = 1, quantity = 0 } end }
C_TooltipInfo = { GetItemByID = function() return { lines = { { leftText = "X" }, { leftText = "Uso: algo" }, { leftText = "\"cita\"" } } } end }
ITEM_SPELL_TRIGGER_ONUSE = "Uso:"
EXPANSION_NAME10 = "The War Within"

local IL = {}
local function load(path) assert(loadfile(path))("ItemLens", IL) end
-- Mismo orden que ItemLens.toc
load("Locales\\esMX.lua")
load("Locales\\enUS.lua")
SlashCmdList = {} -- global de WoW que usa Core/Commands.lua
load("Core\\Util.lua")
load("Core\\Init.lua")
load("Core\\Commands.lua")
IL.RequestRefresh = function() end
load("Data\\iLs_Import.lua")
load("Modules\\Data.lua")
load("Modules\\Integrations.lua")
IL.Data:Init()

local D = IL.Data
local function check(cond, msg) print((cond and "OK   " or "FAIL ") .. msg); if not cond then FAILED = true end end

local nOffers = 0 for _ in pairs(IL.DB.offers) do nOffers = nOffers + 1 end
check(#D:GetTokenKeys() == nOffers and nOffers > 0, "Tokens indexados = tokens importados (" .. #D:GetTokenKeys() .. ")")
local decimals = 0 for k in pairs(IL.DB.offers) do if k:find(".", 1, true) then decimals = decimals + 1 end end
check(decimals == 0, "Ninguna clave con itemID.modID")
local st = D:GetTokenStats("i206350")
check(st and st.offers == 19 and st.vendors == 7, "Remanente radiante: 19 canjes / 7 vendedores")
check(st.exp == 10, "Remanente radiante: expansión ATT 11 → Blizzard 10 (TWW)")
check(D:GetExpansion("i206350") == 10, "GetExpansion desde el cliente = 10")
check(D:ExpansionName(10) == "The War Within", "ExpansionName(10)")
check(D:ExpansionShort(9) == "DF" and D:ExpansionShort(11) == "MN", "Etiquetas cortas DF / MN")

local offers = D:GetOffers("i206350")
check(#offers == 7, "GetOffers agrupa 7 vendedores")
check(offers[1].map == 2215, "Primero los vendedores de tu zona (2215)")
local total = 0 for _, v in ipairs(offers) do total = total + #v.items end
check(total == 19, "Los 7 vendedores suman 19 objetos")

local src = D:GetSources("i207591")
check(src and src[1][1] == "i206350" and src[1][2] == 206150, "Índice inverso: 207591 se obtiene con Remanente radiante en NPC 206150")
check(D:GetExpansion("i207591") == 10, "Expansión de una recompensa sin caché: la toma del vendedor (TWW)")
check(D:GetSources("c3008") == nil, "Una moneda no tiene fuentes")

local desc = D:GetDescription("i206350")
check(desc and #desc == 2 and desc[1] == "Uso: algo", "Descripción: línea 'Uso:' + cita")

check(D:GetDisplayName("i999999") == "Objeto #999999", "Nombre de respaldo para objetos sin caché")
check(D:GetOffers("i1") == nil, "Objeto sin canjes → nil")

-- Pseudo-vendedor del Puesto comercial
local tp = IL.DB.vendors[-230]
check(tp ~= nil and tp[1] == nil, "Puesto comercial (-230) existe y no tiene coordenadas")

-- Para qué sirve (v2.0.0) -------------------------------------------------
local sum, lines = D:GetPurpose("i194701") -- Caracola ominosa
check(sum and sum:find("^Invoca a NPC #%d+ %(raro%)") and #D:GetUses("i194701") >= 9,
	"Uso: lo primero es invocar un raro (" .. #D:GetUses("i194701") .. " usos, incluidos logros) → " .. tostring(sum))
sum = D:GetPurpose("i260531") -- Fragmento de resina cristalizada
check(sum == "Se usa en: Caldero peculiar (tesoro)", "Uso: objeto del mundo con nombre en español → " .. tostring(sum))
sum = D:GetPurpose("i194730") -- Macarela panzaescamosa
check(sum == "Se entrega en la misión: Pesca de prueba", "Uso: se entrega en misión → " .. tostring(sum))
sum = D:GetPurpose("i212664") -- Cuero tormentoso
check(sum and sum:find("Material de profesión (Cuero)", 1, true) and sum:find("50", 1, true), "Material: se usa en 50 recetas → " .. tostring(sum))
check(#D:GetCrafts("i212664") == 50, "GetCrafts devuelve 50 objetos fabricables")
sum = D:GetPurpose("i206350") -- Remanente radiante (token)
check(sum and sum:find("Moneda para comprar:", 1, true) == 1, "Token: desglose de lo que compra → " .. tostring(sum))
sum, lines = D:GetPurpose("i999999")
check(sum == "Misceláneo · Basura", "Sin datos: tipo · subtipo del cliente → " .. tostring(sum))
check(IL.Int:GetObjectName(1) == "Objeto del mundo #1", "Objeto sin nombre → respaldo")

-- Banco (v3.0.0) ------------------------------------------------------------
UnitFullName = function() return "Krg", "Ragnaros" end
GetNormalizedRealmName = function() return "Ragnaros" end
Enum = { BagIndex = { Backpack = 0, CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, AccountBankTab_1 = 12 } }
load("Modules\\Inventory.lua") -- Mochila, banco y personajes
ItemLensDB.bank = {}
IL.Bank:Init()
check(IL.Bank:Get("bank") == nil, "Banco sin datos → nil (muestra 'abre el banco')")
ItemLensDB.bank["Krg-Ragnaros"] = { t = 1, items = { i206350 = 12 } }
local items, src = IL.Bank:Get("bank")
check(items and items.i206350 == 12 and src == "own", "Banco: copia propia del personaje")
-- Syndicator simulado para la banda guerrera
Syndicator = { API = {
	IsReady = function() return true end,
	GetWarband = function() return { bank = { { slots = { { itemID = 199211, itemCount = 3 }, { itemLink = "|cff|Hitem:199211::|h[x]|h|r", itemCount = 2 }, {} } } } } end,
	GetCurrentCharacter = function() return "Krg-Ragnaros" end,
	GetCharacter = function() return {} end,
} }
items, src = IL.Bank:Get("warband")
check(items and items.i199211 == 5 and src == "syndicator", "Banda guerrera desde Syndicator (itemID o itemLink) = 5")
ItemLensDB.warband = { t = 2, items = { i1 = 1 } }
items, src = IL.Bank:Get("warband")
check(src == "own", "La copia propia tiene prioridad sobre Syndicator")

-- Stubs generales (antes vivían en la sección de subastas, quitada en v11.0.0)
IL.Print = function() end
time, date = os.time, os.date -- en WoW son globales
C_Item.GetItemInfo = function(id)
	if id == 1 then return "BoP", nil, 1, 0, 0, "", "", 1, "", 1, 0, 0, 0, 1 end
	if id == 2 then return "BoE", nil, 1, 0, 0, "", "", 1, "", 1, 0, 0, 0, 2 end
	return nil
end

check(IL.Auction == nil, "v11.0.0: ya no existe el módulo de subastas")

-- Lo tienen, sin Syndicator (v5.0.0) ---------------------------------------
UnitClass = function() return "Cazador", "HUNTER" end
GetInventoryItemID = function(_, slot) return slot == 16 and 777 or nil end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = {
	GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
	GetContainerItemInfo = function(_, slot)
		if slot == 1 then return { itemID = 190396, stackCount = 12 } end
		if slot == 2 then return { itemID = 190396, stackCount = 3 } end
	end,
}
C_CurrencyInfo.GetCurrencyInfo = function(id) return { name = "M", quantity = id == 3008 and 40 or 0 } end
Syndicator = nil
ItemLensDB.chars = {}
ItemLensDB.bank = { ["Krg-Ragnaros"] = { t = 1, items = { i190396 = 28 } },
	["Alt-Ragnaros"] = { t = 1, items = { i190396 = 5 } } }
ItemLensDB.warband = { t = 1, items = { i190396 = 7 } }
IL.Chars:Snapshot()
local me = ItemLensDB.chars["Krg-Ragnaros"]
check(me and me.class == "HUNTER" and me.bags.i190396 == 15, "Copia del personaje: clase + bolsas (12+3)")
check(me.equipped.i777 == 1, "Copia del personaje: equipo puesto")
local hasC = false for k, v in pairs(me.currencies) do if v == 40 then hasC = true end end
check(hasC or IL.DB.offers.c3008 == nil, "Copia del personaje: monedas que se canjean")
local owners = IL.Chars:GetOwners("i190396")
check(owners and #owners == 3, "Lo tienen: yo + alt (solo banco) + banda guerrera = 3 filas")
check(owners[1].isMe and owners[1].total == 43 and owners[1].bags == 15 and owners[1].bank == 28,
	"Yo primero: 15 bolsas + 28 banco = 43")
check(owners[1].name == "Krg", "Nombre corto si es del mismo reino")
-- Syndicator solo completa personajes que ItemLens no conoce
Syndicator = { API = {
	IsReady = function() return true end,
	GetInventoryInfoByItemID = function() return { characters = {
		{ character = "Krg", realmNormalized = "Ragnaros", bags = 99, bank = 0, equipped = 0 },
		{ character = "Nuevo", realmNormalized = "Ragnaros", bags = 4, bank = 0, equipped = 0, className = "MAGE" },
	}, warband = { 0 } } end,
} }
owners = IL.Chars:GetOwners("i190396")
local n, krg = 0, nil
for _, o in ipairs(owners) do if o.fromSyndicator then n = n + 1 end; if o.name == "Krg" then krg = o end end
check(n == 1 and krg.total == 43, "Syndicator solo agrega 'Nuevo'; Krg conserva los datos propios")
Syndicator = nil

-- Tooltip: personajes en cualquier objeto + bloque de favoritos (v5.1.0) ----
load("UI\\Style.lua")

-- Colores de expansión (v6.1.0): uno distinto para cada expansión 0–11
local seenColor, allColored = {}, true
for e = 0, 11 do
	local c = IL.Style.EXP[e]
	if not c then allColored = false else
		local k = string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3])
		if seenColor[k] then allColored = false end
		seenColor[k] = true
		-- Claridad mínima para leerse sobre el panel #111217
		if (0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]) < 0.35 then allColored = false end
	end
end
check(allColored, "Cada expansión (0–11) tiene su propio color, claro y distinto")
load("Modules\\Tooltip.lua")
RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 } }
local function fakeTooltip()
	local t = { lines = {} }
	function t:AddLine(s) self.lines[#self.lines + 1] = s end
	function t:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. " | " .. b end
	return t
end
local function has(t, pat) for _, l in ipairs(t.lines) do if l:find(pat, 1, true) then return true end end return false end
local function count(t, pat) local n = 0 for _, l in ipairs(t.lines) do if l:find(pat, 1, true) then n = n + 1 end end return n end
ItemLensDB.options = { tooltip = true, ownersTooltip = true, bagClick = true }
ItemLensDB.favorites = {}
IL.IsFavorite = function(_, key) return ItemLensDB.favorites[key] == true end

local tt = fakeTooltip()
IL.Tooltip.AddAll(tt, "i190396")
check(has(tt, "Krg |") and has(tt, "43"), "Tooltip (no favorito): muestra mis 43")
check(not has(tt, "(tú)"), "Tooltip: solo el nombre del personaje, sin (tú)")
check(has(tt, "Banda guerrera") and has(tt, "Total | 55"), "Tooltip: banda guerrera y total 43+5+7 = 55")
check(not has(tt, "FavoritesIcon"), "Tooltip (no favorito): sin bloque de favoritos")
check(count(tt, "Mayús+clic") == 0, "Tooltip: sin la leyenda de Mayús+clic")

ItemLensDB.favorites.i190396 = true
tt = fakeTooltip()
IL.Tooltip.AddAll(tt, "i190396")
check(has(tt, "Krg |") and has(tt, "FavoritesIcon"), "Tooltip (favorito): personajes + bloque de favoritos")
check(count(tt, "Mayús+clic") == 0, "Tooltip (favorito): sin la leyenda de Mayús+clic")

tt = fakeTooltip()
IL.Tooltip.AddAll(tt, "i424242")
check(#tt.lines == 0, "Objeto que nadie tiene y no es favorito: el tooltip no cambia")

ItemLensDB.options.ownersTooltip = false
ItemLensDB.favorites = {}
tt = fakeTooltip()
IL.Tooltip.AddAll(tt, "i190396")
check(#tt.lines == 0, "/il personajes apagado: el tooltip no cambia")

-- Cómo se obtiene (v7.0.0) ----------------------------------------------------
EJ_GetEncounterInfo = function(id) return id == 1 and "Jefe de prueba" or nil end
EJ_GetInstanceInfo = function(id) return id == 2 and "Mazmorra de prueba" or nil end
GetDifficultyInfo = function(id) return id == 14 and "Normal" or nil end
GetAchievementInfo = function(id) return id, "Logro de prueba" end
IL.DB.sources[990001] = "b1,2,14;q70199;p165;n197411,2022,24.7,56.8,r;o614483,2215,33.2,55.3;v200,2112,58.1,35.2,150000"
local ob = D:GetObtain("i990001")
check(ob and #ob == 6, "GetObtain interpreta 6 orígenes del texto compacto")
check(ob[1].k == "b" and ob[2].k == "n" and ob[3].k == "v" and ob[4].k == "o" and ob[5].k == "q" and ob[6].k == "p",
	"Orden: jefe, NPC, vendedor, tesoro, misión, fabricación")
local lb, nm, wh = D.ObtainLine(ob[1])
check(lb == "Botín de jefe" and nm == "Jefe de prueba" and wh == "Instancia: Mazmorra de prueba (Normal)", "Botín de jefe: nombre + tipo de lugar: mazmorra (dificultad)")
lb, nm = D.ObtainLine(ob[2])
check(lb == "Botín de raro" and ob[2].x == 24.7 and ob[2].map == 2022, "Raro: etiqueta + coordenadas")
lb, nm = D.ObtainLine(ob[6])
check(lb == "Fabricación" and nm == "Peletería", "Fabricación: nombre de la profesión (respaldo en español)")
check(D:GetObtainSummary("i990001") == "Botín de jefe: Jefe de prueba (+5)", "Resumen del encabezado: " .. tostring(D:GetObtainSummary("i990001")))
check(D:GetObtain("i990002") == nil and D:GetObtain("c3008") == nil, "Sin orígenes → nil")
check(IL.DB.sources[15138] and IL.DB.sources[15138]:find("p165", 1, true), "Dato real: Capa de escamas de Onyxia incluye Peletería")

-- Orígenes nuevos (v7.1.0): instancia sin jefe, contenedor, zona, categoría ----
IL.DB.headers[-9001] = "Temporada de prueba"
IL.DB.headers[-9002] = "=RAID_BOSSES"
RAID_BOSSES = "Jefes de banda"
IL.DB.sources[990003] = "gj,-9001;d2,14;c990004;z2022;gw,"
ob = D:GetObtain("i990003")
check(ob and #ob == 5 and ob[1].k == "d" and ob[5].k == "g", "Orden con los nuevos: instancia … categoría al final")
lb, nm = D.ObtainLine(ob[1])
check(lb == "Botín de instancia" and nm == "Mazmorra de prueba (Normal)", "Botín de instancia sin jefe")
lb, nm = D.ObtainLine(ob[2])
check(lb == "Sale de" and nm == "Objeto #990004", "Sale de otro objeto (contenedor)")
lb, nm = D.ObtainLine(ob[3])
check(lb == "En la zona" and nm == "Mapa2022", "En la zona")
lb, nm = D.ObtainLine(ob[4])
check(lb == "JcJ" and nm == "Temporada de prueba", "Categoría JcJ con subtítulo en español")
lb, nm = D.ObtainLine(ob[5])
check(lb == "Botín del mundo" and nm == "", "Categoría sin subtítulo")
check(IL.Int:GetHeaderName(-9002) == "Jefes de banda", "Encabezado '=CONST' se resuelve con la constante del juego")
check(D:GetObtainSummary("i990003") == "Botín de instancia: Mazmorra de prueba (Normal) (+4)", "Resumen con instancia")
local pep = IL.DB.sources[200080]
check(pep and pep:find("o377938", 1, true) and pep:find("n197596", 1, true), "Dato real: Pepita de draconio = bancos de peces + NPC")
local hasNever = false
for _, v in pairs(IL.DB.sources) do if v:find("gN", 1, true) then hasNever = true break end end
check(not hasNever, "NeverImplemented no genera orígenes")

-- Misiones con lugar + objetos/misiones no disponibles (v7.2.0) --------------
IL.DB.sources[990005] = "q70199,2022,47.1,82.6"
ob = D:GetObtain("i990005")
lb, nm, wh = D.ObtainLine(ob[1])
check(lb == "Recompensa de misión" and nm == "Pesca de prueba" and wh == "Zona: Mapa2022", "Misión: título + Zona: <zona>")
check(ob[1].x == 47.1 and ob[1].y == 82.6 and IL.Int:CanWaypoint(ob[1]), "Misión con coordenadas → se puede marcar en el mapa")
local realQ = 0 for _, s in pairs(IL.DB.sources) do if s:find("q%d+,%d+") then realQ = realQ + 1 end end
check(realQ > 1000, "Datos reales: miles de misiones con zona (" .. realQ .. " objetos)")
D.unavailable[555555] = true
check(D:GetDisplayName("i555555") == "Objeto #555555 (no disponible en el juego)", "Objeto que no existe: lo indica")
check(D:GetDisplayName("i555556") == "Objeto #555556", "Objeto que todavía no carga: solo el número")
IL.Int.questUnavailable[123456] = true
check(IL.Int:GetQuestTitle(123456) == "Misión #123456 (título no disponible)", "Misión sin título del servidor: lo dice sin afirmar que no existe")
-- Misiones semanales con reputación (build 14.5.0)
IL.DB.sources[990020] = "q70906,,,,w,2503,5"
IL.DB.sources[990021] = "q12345,2022,10,20,d,1234,42000"
local qo = D:GetObtain("i990020")[1]
check(qo.repeats == "weekly" and qo.repFaction == 2503 and qo.repValue == 5, "Origen de misión: semanal + facción + nivel")
local lbl, _, wh = D.ObtainLine(qo)
check(lbl == "Misión semanal" and wh and wh:find("Requiere:", 1, true) and wh:find("Renombre 5", 1, true),
	"Línea: 'Misión semanal' · 'Requiere: <facción> — Renombre 5' → " .. tostring(wh))
FACTION_STANDING_LABEL8 = "Exaltado"
lbl, _, wh = D.ObtainLine(D:GetObtain("i990021")[1])
check(lbl == "Misión diaria" and wh:find("Zona", 1, true) and wh:find("Exaltado", 1, true), "Diaria con zona y reputación clásica (Exaltado)")
-- Valores secretos de Midnight (v10.1.1) -----------------------------------------
do
	local SECRET = setmetatable({}, { __eq = function() error("comparar un valor secreto") end })
	issecretvalue = function(v) return v == SECRET or rawequal(v, SECRET) end
	issecretvalue = function(v) return rawequal(v, SECRET) end
	local realGH = C_TooltipInfo.GetHyperlink
	C_TooltipInfo.GetHyperlink = function() return { lines = { { leftText = SECRET } } } end
	ItemLensDB.npcNames[424242] = nil
	local ok, res = pcall(IL.Int.GetNPCName, IL.Int, 424242)
	check(ok and res == "NPC #424242" and ItemLensDB.npcNames[424242] == nil, "Nombre de NPC secreto: no truena, muestra 'NPC #id' y no lo guarda")
	local realGIB = C_TooltipInfo.GetItemByID
	C_TooltipInfo.GetItemByID = function() return { lines = { { leftText = "x" }, { leftText = SECRET }, { leftText = "Uso: algo" } } } end
	ok, res = pcall(D.GetDescription, D, "i12345")
	check(ok and res and res[1] == "Uso: algo", "Descripción con una línea secreta: la salta sin tronar")
	C_TooltipInfo.GetHyperlink, C_TooltipInfo.GetItemByID = realGH, realGIB
	issecretvalue = nil
end

-- Reino vacío al entrar (v7.1.1) ---------------------------------------------
do
	local realUFN, realGNRN = UnitFullName, GetNormalizedRealmName
	UnitFullName = function() return "Krhona", nil end
	GetNormalizedRealmName = function() return nil end
	local before = 0 for _ in pairs(ItemLensDB.chars) do before = before + 1 end
	IL.Chars:Snapshot()
	local after, bad = 0, false
	for k in pairs(ItemLensDB.chars) do after = after + 1; if k:sub(-1) == "-" then bad = true end end
	check(after == before and not bad, "Sin reino disponible: no guarda 'Krhona-' (reintenta después)")
	UnitFullName = function() return "Krhona", nil end
	GetNormalizedRealmName = function() return "QuelThalas" end
	check(IL.PlayerKey() == "Krhona-QuelThalas", "Reino vacío en UnitFullName → usa GetNormalizedRealmName")
	UnitFullName, GetNormalizedRealmName = realUFN, realGNRN
end

-- Probador (v6.2.0) ---------------------------------------------------------
load("Core\\Init.lua") -- define IL:CanDressUp / IL:DressUp / IL:HandleDressUpClick
C_Item.IsDressableItemByID = function(id) return id == 1001 end
C_MountJournal = { GetMountFromItem = function(id) return id == 1002 and 55 or nil end }
C_PetJournal = { GetPetInfoByItemID = function(id) if id == 1003 then return "Mascota" end end }
check(IL:CanDressUp("i1001") and IL:CanDressUp("i1002") and IL:CanDressUp("i1003"), "Probador: ropa, montura y mascota se pueden probar")
check(not IL:CanDressUp("i1004") and not IL:CanDressUp("c3008"), "Probador: un material o una moneda no")
local dressed
DressUpLink = function(link) dressed = link; return true end
IL.Data.GetLink = function(_, key) return "|Hitem:" .. key:sub(2) .. "|h[x]|h" end
IsModifiedClick = function(what) return what == "DRESSUP" end
check(IL:HandleDressUpClick("i1001") and dressed and dressed:find("item:1001", 1, true), "Ctrl+clic abre el probador nativo con el objeto")
IsModifiedClick = function() return false end
dressed = nil
check(not IL:HandleDressUpClick("i1001") and dressed == nil, "Clic normal no abre el probador")

-- Colecciones (v8.0.0) --------------------------------------------------------
load("Modules\\Collections.lua")
local doneQuests = { [69326] = true }
C_QuestLog.IsQuestFlaggedCompleted = function(q) return doneQuests[q] == true end
UnitClass = function() return "Brujo", "WARLOCK", 9 end
GetClassInfo = function(id) return ({ [9] = "Brujo", [3] = "Cazador" })[id] end
C_MountJournal.GetMountInfoByID = function(id) return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, id == 55 end
local CO = IL.DB.collections
check(CO and CO.mm[197125] and CO.mm[197125][1] == 69326, "Datos: manuscrito 197125 con su misión oculta 69326")
check(IL.Coll:GetState("i197125") == "have", "Manuscrito con misión completada → Aprendido")
check(IL.Coll:GetState("i197149") == "missing", "Manuscrito sin completar → Te falta")
check(IL.Coll:GetState("i207178") == "missing", "Tomo de brujo siendo brujo → Te falta")
local otherClassItem
for item, v in pairs(CO.cq) do if v[2] and v[2] ~= 9 then otherClassItem = item break end end
check(otherClassItem and IL.Coll:GetState("i" .. otherClassItem) == "otherclass", "Desbloqueo de otra clase → Otra clase")
check(IL.Coll:GetState("i1002") == "have", "Montura (nativo): coleccionada")
check(IL.Coll:GetState("i190396") == nil, "Un material no es coleccionable → sin insignia")

local els, have, total = IL.Coll:BuildList({ set = "mm", exp = "all", state = "all", query = "" })
check(total == 428 and have == 1, "Manuscritos: 428 en total, 1 aprendido (" .. have .. "/" .. total .. ")")
check(type(els[1]) == "table" and els[1].header and els[1].total > 0, "La lista empieza con un encabezado de grupo con progreso")
local nHeaders = 0 for _, e in ipairs(els) do if type(e) == "table" then nHeaders = nHeaders + 1 end end
check(nHeaders == 8, "Manuscritos agrupados en 7 dragones + Otros (" .. nHeaders .. ")")
check(type(els[#els - 1]) ~= "table" and els[#els] ~= nil, "Cada grupo tiene sus objetos debajo")
local lastHeader for _, e in ipairs(els) do if type(e) == "table" then lastHeader = e end end
check(lastHeader.text == "Otros", "'Otros' va al final")
els = IL.Coll:BuildList({ set = "mm", exp = "all", state = "have", query = "" })
local nItems = 0 for _, e in ipairs(els) do if type(e) ~= "table" then nItems = nItems + 1 end end
check(nItems == 1, "Filtro Tengo: solo el aprendido")
els, have, total = IL.Coll:BuildList({ set = "mm", exp = "all", state = "missing", query = "" })
nItems = 0 for _, e in ipairs(els) do if type(e) ~= "table" then nItems = nItems + 1 end end
check(nItems == 427 and total == 428, "Filtro Faltan: 427 (el progreso sigue contando todo)")
local _, _, totalDF = IL.Coll:BuildList({ set = "mm", exp = 9, state = "all", query = "" })
local _, _, totalTWW = IL.Coll:BuildList({ set = "mm", exp = 10, state = "all", query = "" })
check(totalDF > 0 and totalDF + totalTWW <= 428, "Filtro por expansión: DF " .. totalDF .. " · TWW " .. totalTWW)
local _, _, totalClass = IL.Coll:BuildList({ set = "class", exp = "all", state = "all", query = "" })
local _, _, totalOther = IL.Coll:BuildList({ set = "other", exp = "all", state = "all", query = "" })
check(totalClass == 118 and totalOther == 363, "Clase " .. totalClass .. " · Otros " .. totalOther)
check(IL.Coll:GroupName("class", 9) == "Brujo", "Grupo de clase con nombre del juego")
check(#IL.Coll:GetExpansions("other") >= 5, "El filtro de expansión ofrece solo las expansiones del conjunto")

-- Filtro por clase (v8.1.0)
check(#IL.Coll:GetClasses("class") >= 5 and #IL.Coll:GetClasses("mm") == 0 and #IL.Coll:GetClasses("other") == 0,
	"Clases disponibles solo en 'Desbloqueos de clase'")
local elsW, _, totW = IL.Coll:BuildList({ set = "class", exp = "all", class = 9, state = "all", query = "" })
local onlyWarlock, nW = true, 0
for _, e in ipairs(elsW) do
	if type(e) == "table" then onlyWarlock = onlyWarlock and e.text == "Brujo"
	else nW = nW + 1 end
end
check(onlyWarlock and nW == totW and totW > 0 and totW < 118, "Clase Brujo: solo el grupo Brujo (" .. totW .. " objetos)")
local _, _, totMM = IL.Coll:BuildList({ set = "mm", exp = "all", class = 9, state = "all", query = "" })
check(totMM == 428, "En manuscritos el filtro de clase no quita nada (sirven para todas)")

-- Todas las clases en el menú (v8.2.1)
GetNumClasses = function() return 13 end
local cc = IL.Coll:GetClassCounts("class")
local byId = {} for _, c in ipairs(cc) do byId[c.id] = c.count end
check(#cc == 13, "El menú de clase tiene las 13 clases")
check(byId[9] == 35 and byId[12] == 0 and byId[13] == 0, "Brujo 35 · Cazador de demonios 0 · Evocador 0 (sin datos en ATT)")

-- Misiones de clase (v9.0.0) ----------------------------------------------------
do
	local nQ = 0 for _ in pairs(IL.DB.classQuests) do nQ = nQ + 1 end
	check(nQ > 1500, "Datos: " .. nQ .. " misiones de clase vigentes")
	-- Una misión de evocador cualquiera de los datos reales
	local evokerQ
	for qid in pairs(IL.DB.classQuests) do
		local q = D:GetClassQuest(qid)
		if q.class == 13 then evokerQ = q break end
	end
	check(evokerQ and evokerQ.exp == 9, "Hay misiones de Evocador (Dragonflight)")
	local _, _, tEv = IL.Coll:BuildList({ set = "quests", exp = "all", class = 13, state = "all", query = "" })
	local _, _, tDH = IL.Coll:BuildList({ set = "quests", exp = "all", class = 12, state = "all", query = "" })
	check(tEv == 60 and tDH > 100, "Evocador " .. tEv .. " · Cazador de demonios " .. tDH)
	local _, _, tEvR = IL.Coll:BuildList({ set = "quests", exp = "all", class = 13, state = "all", query = "", rewardOnly = true })
	check(tEvR > 0 and tEvR < tEv, "Con recompensa (Evocador): " .. tEvR)
	GetClassInfo = function(id) return ({ [9] = "Brujo", [13] = "Evocador", [3] = "Cazador" })[id], ({ [9] = "WARLOCK", [13] = "EVOKER" })[id] end
	EXPANSION_NAME9 = "Dragonflight" -- en el juego es global
	local els = IL.Coll:BuildList({ set = "quests", exp = "all", class = 13, state = "all", query = "" })
	local hdrs = {}
	for _, e in ipairs(els) do if type(e) == "table" then hdrs[#hdrs + 1] = e.text end end
	check(hdrs[1] == "Evocador · The War Within" and hdrs[2] == "Evocador · Dragonflight",
		"Grupos 'Clase · Expansión', de la más nueva a la más vieja: " .. table.concat(hdrs, " / "))
	check(type(els[2]) == "string" and els[2]:sub(1, 1) == "q", "Las entradas son misiones (q<id>)")
	-- Estado y personajes
	local qid = evokerQ.id
	doneQuests[qid] = nil
	UnitClass = function() return "Evocador", "EVOKER", 13 end
	check(IL.Coll:GetState("q" .. qid) == "missing", "Misión de mi clase sin hacer → Pendiente")
	UnitClass = function() return "Brujo", "WARLOCK", 9 end
	check(IL.Coll:GetState("q" .. qid) == "otherclass", "Misión de otra clase → Otra clase")
	doneQuests[qid] = true
	check(IL.Coll:GetState("q" .. qid) == "have", "Misión hecha → Hecha")
	GetClassInfo = function(id) return ({ [9] = "Brujo", [13] = "Evocador", [3] = "Cazador" })[id], ({ [9] = "WARLOCK", [13] = "EVOKER" })[id] end
	ItemLensDB.chars["Dracky-Ragnaros"] = { class = "EVOKER", classQuests = { [qid] = true } }
	ItemLensDB.chars["Otro-Ragnaros"] = { class = "EVOKER", classQuests = {} }
	local qc = IL.Coll:GetQuestChars(qid)
	check(#qc == 2 and qc[1].name == "Dracky" and qc[1].done and not qc[2].done, "Personajes de la clase: Dracky la hizo, a Otro le falta")
	-- Copia del personaje: guarda sus misiones de clase hechas
	UnitClass = function() return "Evocador", "EVOKER", 13 end
	IL.Chars:Snapshot()
	local mine = ItemLensDB.chars[IL.PlayerKey()]
	check(mine and mine.classQuests and mine.classQuests[qid] == true, "La copia del personaje guarda sus misiones de clase hechas")
	-- Lugar y nombre
	check(D:GetDisplayName("q" .. qid):find("Misión #", 1, true) == 1, "Título de misión sin caché → 'Misión #id'")
	if evokerQ.map then check(D:GetPlace("q" .. qid) ~= nil, "Lugar de la misión: " .. tostring(D:GetPlace("q" .. qid))) end
	UnitClass = function() return "Brujo", "WARLOCK", 9 end
end

-- Diccionario completo + caché de nombres (v10.1.0) ------------------------------
do
	GetLocale = function() return "esMX" end
	GetTime = function() return 1000 end
	local keys = D:GetDictionaryKeys()
	local has = {}
	for _, k in ipairs(keys) do has[k] = true end
	check(#keys > 8000, "Diccionario: " .. #keys .. " objetos (no solo los 1,294 tokens)")
	check(has["i194701"], "La Caracola ominosa está en el diccionario (tiene usos)")
	check(has["i212664"] and has["i197125"], "Materiales y manuscritos también están")
	-- Caché de nombres: se guarda y sirve aunque el juego todavía no tenga el objeto
	local realGII = C_Item.GetItemInfo
	C_Item.GetItemInfo = function(id) if id == 194701 then return "Caracola ominosa" end end
	check(D:GetName("i194701") == "Caracola ominosa", "Nombre desde el juego")
	C_Item.GetItemInfo = function() return nil end
	check(D:GetName("i194701") == "Caracola ominosa", "Nombre desde la caché guardada (el juego aún no lo tiene)")
	check(ItemLensDB.names[194701] == "Caracola ominosa" and ItemLensDB.namesLocale == "esMX", "La caché queda en los datos guardados, por idioma")
	GetLocale = function() return "enUS" end
	check(D:GetName("i194701") == nil, "Si cambia el idioma del cliente, la caché se reinicia")
	GetLocale = function() return "esMX" end
	-- Cargador en segundo plano
	local requested = 0
	C_Item.RequestLoadItemDataByID = function() requested = requested + 1 end
	D:StartNameLoader()
	local running, done, total = D:GetLoaderProgress()
	check(running and total > 8000 and requested == 100, "Cargador: pide 100 nombres por paso (" .. requested .. " de " .. total .. ")")
	C_Item.GetItemInfo = realGII
end

-- Armas artefacto + "Se necesita para" logros (v10.0.0) -------------------------
do
	local nA = 0 for _ in pairs(IL.DB.artifacts) do nA = nA + 1 end
	check(nA == 873, "Datos: 873 apariencias de artefacto (" .. nA .. ")")
	local a = D:GetArtifact(295)
	check(a and a.class == 1 and a.weapon == 128910 and a.source == 76539 and a.set == -133, "Apariencia 295: guerrero, arma 128910, conjunto base")
	check(a.origins[1] and a.origins[1].k == "o", "Apariencia 295: se consigue en un objeto del mundo (misión de clase)")
	local rep = D:GetArtifact(224)
	local hasRep = false
	for _, o in ipairs(rep.origins) do if o.k == "r" and o.id == 1900 and o.value == 21000 then hasRep = true end end
	check(hasRep, "Apariencia 224: requiere reputación 1900 en Reverenciado")
	FACTION_STANDING_LABEL7 = "Reverenciado"
	C_Reputation = { GetFactionDataByID = function(id) return { name = id == 1900 and "Corte de Farondis" or nil } end }
	local lb, nm = D.ObtainLine({ k = "r", id = 1900, value = 21000 })
	check(lb == "Reputación" and nm == "Corte de Farondis — Reverenciado", "Origen de reputación: " .. tostring(nm))
	check(D:GetExpansion("f295") == 6 and D:GetQuality("f295") == 6, "Apariencia: Legion y calidad artefacto")
	check(D:GetDisplayName("f295"):find("Apariencia base", 1, true), "Nombre: <arma> · Apariencia base N → " .. D:GetDisplayName("f295"))
	-- Estado por colección de transfiguración
	C_TransmogCollection = C_TransmogCollection or {}
	local owned = { [76539] = true }
	C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance = function(s) return owned[s] == true end
	UnitClass = function() return "Guerrero", "WARRIOR", 1 end
	check(IL.Coll:GetState("f295") == "have", "Apariencia en la colección → Tengo")
	check(IL.Coll:GetState("f797") == "missing", "Apariencia de mi clase que no tengo → Te falta")
	check(IL.Coll:GetState("f224") == "otherclass", "Apariencia de otra clase → Otra clase")
	GetClassInfo = function(id) return ({ [1] = "Guerrero", [3] = "Cazador", [9] = "Brujo", [13] = "Evocador" })[id], ({ [1] = "WARRIOR" })[id] end
	local els, have, total = IL.Coll:BuildList({ set = "art", exp = "all", class = 1, state = "all", query = "" })
	local hdrs = 0 for _, e in ipairs(els) do if type(e) == "table" then hdrs = hdrs + 1 end end
	check(total > 50 and have == 1 and hdrs >= 3, "Guerrero: " .. total .. " apariencias en " .. hdrs .. " armas, 1 en la colección")
	-- Logros que piden un objeto
	local achItem
	for key, list in pairs(IL.DB.uses) do for _, u in ipairs(list) do if u[1] == "a" then achItem = key break end end if achItem then break end end
	check(achItem ~= nil, "Hay objetos que se necesitan para un logro (" .. tostring(achItem) .. ")")
	local u1
	for _, u in ipairs(IL.DB.uses[achItem]) do if u[1] == "a" then u1 = u break end end
	check(D.UseLine(u1):find("Se necesita para el logro: Logro de prueba", 1, true) == 1, "Línea: 'Se necesita para el logro: …'")
	UnitClass = function() return "Brujo", "WARLOCK", 9 end
end

-- Tipo de lugar: banda / calabozo / zona (v8.2.0) ------------------------------
EJ_GetInstanceInfo = function(id)
	if id == 2 then return "Mazmorra de prueba" end
	if id == 63 then return "Guarida de prueba", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, true end
	if id == 64 then return "Calabozo de prueba", nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, false end
end
GetDifficultyInfo = function(id) if id == 14 then return "Normal", "raid" end end
check(IL.Int:InstanceKind(63) == "Banda" and IL.Int:InstanceKind(64) == "Calabozo", "Diario de encuentros: banda / calabozo")
check(IL.Int:InstanceKind(2, 14) == "Banda", "Sin dato del diario: la dificultad decide (Normal de banda)")
check(IL.Int:InstanceKind(99) == "Instancia", "Sin datos: 'Instancia'")
Enum.UIMapType = { Dungeon = 4, Zone = 3 }
local realGMI = C_Map.GetMapInfo
C_Map.GetMapInfo = function(id) return { name = "Mapa" .. id, mapType = id == 777 and 4 or 3 } end
check(IL.Int:MapKind(2022) == "Zona" and IL.Int:MapKind(777) == "Instancia", "Tipo de mapa: zona / interior de instancia")
IL.DB.sources[990010] = "b1,63,14"
IL.DB.sources[990011] = "d64,1"
IL.DB.sources[990012] = "n197411,2022,24.7,56.8,r"
IL.DB.sources[990013] = "gj,-9001"
check(D:GetPlace("i990010") == "Banda · Guarida de prueba", "Lugar: Banda · <instancia> → " .. tostring(D:GetPlace("i990010")))
check(D:GetPlace("i990011") == "Calabozo · Calabozo de prueba", "Lugar: Calabozo · <instancia>")
check(D:GetPlace("i990012") == "Zona · Mapa2022", "Lugar: Zona · <zona>")
check(D:GetPlace("i990013") == "JcJ · Temporada de prueba", "Lugar: categoría (JcJ · temporada)")
local _, _, whB = D.ObtainLine(D:GetObtain("i990010")[1])
check(whB == "Banda: Guarida de prueba (Normal)", "Detalle: 'Banda: <instancia> (dificultad)'")
C_Map.GetMapInfo = realGMI

-- Aprendizaje mientras juegas (v14.0.0, D-44) ---------------------------------
do
	strsplit = function(sep, s)
		local out = {}
		for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
		return unpack(out)
	end
	CopyTable = function(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
	ItemLensDB.options = ItemLensDB.options or {}
	ItemLensDB.options.learn = true
	ItemLensDB.learned = nil
	load("Modules\\Learn.lua")
	local Lr = IL.Learn
	check(select(1, Lr.FromGUID("Creature-0-1-2-3-555001-000")) == 555001 and select(2, Lr.FromGUID("GameObject-0-1-2-3-777001-0")) == "o",
		"GUID → NPC / objeto del mundo")
	check(Lr.FromGUID("Player-1-ABC") == nil, "GUID de jugador → nada")
	issecretvalue = function(v) return v == "SECRETO" end
	check(Lr.FromGUID("SECRETO") == nil, "GUID secreto (Midnight) → se ignora")
	issecretvalue = nil

	-- Posición del jugador
	C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.4567, 0.1234 end } end
	-- 1. Vendedor: NPC nuevo que vende por oro y por una moneda
	UnitGUID = function(u) if u == "npc" then return "Creature-0-1-2-3-555001-000" end end
	GetMerchantNumItems = function() return 2 end
	GetMerchantItemID = function(i) return i == 1 and 880001 or 880002 end
	C_MerchantFrame = { GetItemInfo = function(i)
		if i == 1 then return { price = 25000, stackCount = 1, hasExtendedCost = false } end
		return { price = 0, stackCount = 1, hasExtendedCost = true }
	end }
	GetMerchantItemCostInfo = function() return 1 end
	GetMerchantItemCostItem = function() return 1, 150, "|cff|Hcurrency:999001:0|h[x]|h|r" end
	Lr:ScanMerchant()
	local v = D:GetVendor(555001)
	check(v and v.learned and v.map == 2215 and v.x == 45.7 and v.y == 12.3, "Vendedor aprendido con mapa y coordenadas (45.7, 12.3)")
	local o1 = D:GetObtain("i880001")
	check(o1 and o1[1].k == "v" and o1[1].price == 25000 and o1[1].learned, "Objeto por oro → origen 'Vendedor' aprendido")
	local off = D:GetOffers("c999001")
	local found = false
	for _, g in ipairs(off or {}) do if g.npc == 555001 and g.learned then found = true end end
	check(found, "Objeto por moneda → canje aprendido de la moneda 999001")
	local s880 = D:GetSources("i880002")
	check(s880 and s880[1][1] == "c999001" and s880[1][3] == 150 and s880[1][4], "Índice inverso con el canje aprendido (150 de la moneda)")
	check(D:IsToken("c999001"), "La moneda pasa a ser token aunque no estuviera importada")

	-- 2. Botín: el mismo cadáver dos veces cuenta una
	GetNumLootItems = function() return 1 end
	GetLootSlotType = function() return 1 end
	GetLootSlotLink = function() return "|cff|Hitem:880003::|h[x]|h|r" end
	GetLootSourceInfo = function() return "Creature-0-1-2-3-555002-AAA", 1 end
	Lr:ScanLoot(); Lr:ScanLoot()
	GetLootSourceInfo = function() return "Creature-0-1-2-3-555002-BBB", 1 end
	Lr:ScanLoot()
	local o3 = D:GetObtain("i880003")
	check(o3 and o3[1].k == "n" and o3[1].id == 555002 and o3[1].count == 2 and o3[1].learned, "Botín aprendido: NPC 555002, visto 2 veces (no cuenta doble)")

	-- 3. Misión con recompensa fija y a elegir
	GetQuestID = function() return 990777 end
	GetNumQuestRewards = function() return 1 end
	GetNumQuestChoices = function() return 1 end
	GetQuestItemLink = function(kind) return kind == "reward" and "|Hitem:880004:|h" or "|Hitem:880005:|h" end
	UnitGUID = function(u) if u == "questnpc" then return "Creature-0-1-2-3-555003-000" end end
	Lr:ScanQuest()
	local o4, o5 = D:GetObtain("i880004"), D:GetObtain("i880005")
	check(o4 and o4[1].k == "q" and o4[1].id == 990777 and o5 and o5[1].id == 990777, "Misión aprendida: recompensa fija y a elegir")

	-- 4. Profesión: receta con dos materiales
	Enum.CraftingReagentType = { Basic = 1 }
	C_TradeSkillUI = {
		IsTradeSkillReady = function() return true end,
		GetBaseProfessionInfo = function() return { professionID = 171 } end,
		GetAllRecipeIDs = function() return { 4001 } end,
		GetRecipeSchematic = function() return { outputItemID = 880006, quantityMin = 1, reagentSlotSchematics = {
			{ reagentType = 1, quantityRequired = 3, reagents = { { itemID = 880007 } } },
			{ reagentType = 0, quantityRequired = 1, reagents = { { itemID = 880008 } } }, -- opcional: no cuenta
		} } end,
	}
	Lr:ScanProfession()
	local c7 = D:GetCrafts("i880007")
	check(c7 and c7[1][1] == 880006 and c7[1][2] == 3 and c7[1][3], "Receta aprendida: el material se usa para fabricar 880006 (×3)")
	check(D:GetCrafts("i880008") == nil, "Los materiales opcionales no cuentan")
	local o6 = D:GetObtain("i880006")
	check(o6 and o6[1].k == "p" and o6[1].id == 171, "El resultado se obtiene por Fabricación (Alquimia)")

	-- No duplica lo que ya está importado
	ItemLensDB.learned.loot[194701] = { n197411 = { n = 1, map = 2022 } }
	IL.Data:OnLearned("origins", { 194701 })
	local dup = 0
	for _, o in ipairs(D:GetObtain("i194701") or {}) do if o.k == "n" and o.id == 197411 then dup = dup + 1 end end
	check(dup <= 1, "Si el origen ya viene importado, no se repite")

	local nv, nl, nq, nr = Lr:Counts()
	check(nv == 1 and nl == 2 and nq == 1 and nr == 1, "Cuenta: 1 vendedor · 2 objetos con botín · 1 misión · 1 receta")
	ItemLensDB.options.learn = false
	Lr:ScanLoot()
	check(select(2, Lr:Counts()) == 2, "/il aprender apagado: no aprende")
	Lr:Clear()
	check(select(1, Lr:Counts()) == 0 and D:GetObtain("i880003") == nil and not D:IsToken("c999001"), "/il aprender borrar: limpia todo y los índices")
end

-- Interfaz en inglés (v14.0.0, D-45) --------------------------------------------
do
	local realLocale = GetLocale
	local function loadLocales(t)
		assert(loadfile("Locales\\esMX.lua"))("ItemLens", t)
		assert(loadfile("Locales\\enUS.lua"))("ItemLens", t)
	end
	GetLocale = function() return "enUS" end
	local EN = {}
	loadLocales(EN)
	check(not EN.SPANISH and EN.L.TAB_BAG == "Bags" and EN.L.SRC_CAT.j == "PvP", "Cliente en inglés: textos en inglés")
	check(EN.L.HELP[1]:find("commands", 1, true) ~= nil, "Ayuda de /il en inglés")
	GetLocale = function() return "deDE" end
	local DE = {}
	loadLocales(DE)
	check(DE.L.TAB_COLL == "Collections", "Otros idiomas (alemán) → inglés")
	GetLocale = function() return "esES" end
	local ES = {}
	loadLocales(ES)
	check(ES.SPANISH and ES.L.TAB_BAG == "Mochila", "esES → español")
	-- Nombres importados: inglés como base, español aparte
	IL.SPANISH = false
	check(IL.Int:GetObjectName(211684) == "Volatile Blooms", "Objeto del mundo en inglés")
	IL.SPANISH = true
	check(IL.Int:GetObjectName(211684) == "Flores volátiles", "Objeto del mundo en español")
	GetLocale = realLocale
end

-- Banco por pestañas (build 14.2.0) ---------------------------------------------
do
	local realContainer, realBank = C_Container, C_Bank
	-- Pestaña 6: 2 objetos · pestaña 7: 1 objeto · pestaña 8: sin comprar (0 espacios)
	local BAGS = {
		[6] = { { itemID = 190396, stackCount = 10 }, { itemID = 212664, stackCount = 4 } },
		[7] = { { itemID = 190396, stackCount = 5 } },
	}
	C_Container = {
		GetContainerNumSlots = function(bag) return BAGS[bag] and 4 or 0 end,
		GetContainerItemInfo = function(bag, slot) return BAGS[bag] and BAGS[bag][slot] end,
	}
	C_Bank = { FetchPurchasedBankTabData = function() return { { ID = 6, name = "Materiales", icon = 4549 } } end }
	local copy = IL.Bank.BuildCopy({ 6, 7, 8 }, 0)
	check(copy and #copy.tabs == 2 and copy.items.i190396 == 15, "Copia por pestaña: 2 pestañas leídas y el total junto (10+5)")
	check(copy.tabs[1].name == "Materiales" and copy.tabs[1].icon == 4549 and copy.tabs[1].items.i212664 == 4,
		"Pestaña con su nombre e ícono del juego")
	check(copy.tabs[2].name == nil and copy.tabs[2].index == 2, "Pestaña sin nombre: guarda su número")
	check(IL.Bank.BuildCopy({ 8 }, 0) == nil, "Nada legible (banco cerrado) → no hay copia")

	strlower, strupper = strlower or string.lower, strupper or string.upper -- globales de WoW
	load("UI\\BankPanel.lua")
	local build = IL.BankPanelBuildElements
	local realName = D.GetDisplayName
	local els, n = build(copy.items, copy.tabs, "")
	check(els[1].header and els[1].text == "Materiales" and els[1].count == 2 and n == 3,
		"Panel: encabezado 'Materiales' con 2 objetos; 3 objetos en total")
	check(els[4].header and els[4].text == "Pestaña 2", "Panel: pestaña sin nombre → 'Pestaña 2'")
	D.GetDisplayName = function(_, key) return key == "i212664" and "Cuero tormentoso" or "Otro" end
	els, n = build(copy.items, copy.tabs, "cuero")
	check(#els == 2 and n == 1 and els[1].text == "Materiales", "Búsqueda: solo la pestaña con coincidencias")
	els, n = build(copy.items, nil, "")
	check(not els[1].header and n == 2, "Copia vieja sin pestañas: lista plana como antes")
	els, n = build(copy.items, copy.tabs, "", { [1] = true })
	check(#els == 3 and els[1].collapsed and els[2].header and n == 3,
		"Pestaña plegada: solo su encabezado (con la cantidad); las demás siguen abiertas")
	els = build(copy.items, copy.tabs, "cuero", { [1] = true })
	check(#els == 2 and not els[1].collapsed, "Al buscar, las pestañas plegadas muestran sus coincidencias")
	D.GetDisplayName = realName

	ItemLensDB.bank["Krg-Ragnaros"] = copy
	local _, src, _, tabs = IL.Bank:Get("bank")
	check(src == "own" and tabs and #tabs == 2, "Bank:Get devuelve también las pestañas")
	C_Container, C_Bank = realContainer, realBank
end

-- Grupos plegables en la lista (build 14.4.0) -----------------------------------
do
	load("UI\\MainFrame.lua")
	local G = IL.ListGroups
	check(G.FirstLetter("Árbol") == "A" and G.FirstLetter("ébano") == "E" and G.FirstLetter("ñame") == "Ñ"
		and G.FirstLetter("zafiro") == "Z" and G.FirstLetter("[Viejo]") == "#" and G.FirstLetter("7 llaves") == "#",
		"Letra inicial: acentos con su letra, Ñ propia, símbolos y números en #")
	local names = { k1 = "Árbol", k2 = "Ñandú", k3 = "Nube", k4 = "Oro", k5 = "#raro" }
	local groups = G.GroupByLetter({ "k1", "k3", "k2", "k4", "k5" }, names)
	local order = {}
	for _, g in ipairs(groups) do order[#order + 1] = g.id end
	check(table.concat(order, ",") == "A,N,Ñ,O,#", "Orden de letras: … N, Ñ, O … y # al final → " .. table.concat(order, ","))
	local folded = function(id) return id ~= "N" end
	local els, n = G.Fold(groups, folded, false)
	check(#els == 6 and n == 5 and els[2].header and els[3] == "k3", "Plegado: solo 'N' abierta muestra su objeto; 5 en total")
	check(els[1].folded and els[1].count == 1 and els[1].text == "A", "Encabezado plegado con su cantidad")
	els = G.Fold(groups, folded, true)
	check(#els == 10, "Al buscar, nada se pliega (5 encabezados + 5 objetos)")
	check(#G.Fold({ { id = "x", text = "X", keys = {} } }, folded, false) == 0, "Grupos vacíos no aparecen")

	-- Mochila por bolsa
	local realContainer = C_Container
	local BAGS = { [0] = { { itemID = 190396, stackCount = 3 } }, [1] = { { itemID = 212664, stackCount = 2 }, { itemID = 190396, stackCount = 1 } } }
	C_Container = {
		GetContainerNumSlots = function(bag) return BAGS[bag] and 2 or 0 end,
		GetContainerItemInfo = function(bag, slot) return BAGS[bag] and BAGS[bag][slot] end,
		GetBagName = function(bag) return bag == 1 and "Bolsa de seda" or nil end,
		ContainerIDToInventoryID = function(bag) return 30 + bag end,
	}
	GetInventoryItemTexture = function() return 1234 end
	NUM_TOTAL_EQUIPPED_BAG_SLOTS = 1
	IL.OnEvents({}, function() end) -- no-op
	local bg = IL.Scanner:GetBagGroups()
	check(bg[1].text == "Mochila" and bg[2].text == "Bolsa de seda" and bg[2].icon == 1234 and #bg[2].keys == 2,
		"Mochila agrupada: 'Mochila' y la bolsa equipada con su nombre e ícono")
	check(#IL.Scanner:GetBagKeys() >= 2, "La lista plana de la mochila sigue disponible")
	C_Container = realContainer
end

print(FAILED and "\nHAY FALLAS" or "\nTodo bien")
