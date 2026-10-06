--[[
	ItemLens · Modules/Learn.lua
	Learns while you play: vendors, loot, quest rewards and recipes. It is added to the bundled
	data without duplicates and stays on your PC (ItemLensDB.learned); nothing is sent anywhere.
	Aprende mientras juegas: vendedores, botín, recompensas de misión y recetas. Se suma a los
	datos incluidos sin duplicar y se queda en tu PC (ItemLensDB.learned); no se envía nada.
	© 2026 TavoD_Gus_KrG · MIT License

	ItemLensDB.learned:
	  vendors[npcID]    = { map, x, y, t, items = { [itemID] = { p = copper, n = stack, c = { { "i"|"c", id, qty }, … } } } }
	  loot[itemID]      = { ["n<npcID>" | "o<objectID>"] = { n = times, map, x, y, t } }
	  quests[questID]   = { k = "n"|"o", id = giver, map, x, y, r = { itemID… }, ch = { itemID… }, t }
	  recipes[recipeID] = { o = crafted itemID, q = qty, p = skillLine, r = { { itemID, qty }, … }, t }
]]

local _, IL = ...

local Learn = {}
IL.Learn = Learn

local secret = IL.IsSecret

local function db()
	local d = ItemLensDB and ItemLensDB.learned
	if type(d) ~= "table" or d.v ~= 1 then
		d = { v = 1, vendors = {}, loot = {}, quests = {}, recipes = {} }
		if ItemLensDB then ItemLensDB.learned = d end
	end
	return d
end

local function enabled()
	return ItemLensDB and ItemLensDB.options and ItemLensDB.options.learn ~= false
end

local function now() return time and time() or 0 end

-- Tells Data what changed so it only rebuilds that part.
-- Avisa a Data qué cambió para que solo rehaga esa parte.
local function changed(what, itemIDs)
	if IL.Data and IL.Data.OnLearned then IL.Data:OnLearned(what, itemIDs) end
	IL:RequestRefresh()
end

---------------------------------------------------------------------------
-- Helpers / Utilidades
---------------------------------------------------------------------------
-- "Creature-0-…-<npcID>-…" → npcID, "n"   ·   "GameObject-…-<objectID>-…" → objectID, "o"
function Learn.FromGUID(guid)
	if not guid or secret(guid) or type(guid) ~= "string" then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	id = tonumber(id)
	if not id then return nil end
	if kind == "Creature" or kind == "Vehicle" then return id, "n" end
	if kind == "GameObject" then return id, "o" end
	return nil
end

local function round1(v) return math.floor(v * 1000 + 0.5) / 10 end

-- Player map and coordinates (0–100, one decimal). Inside instances only the map is known.
-- Mapa y coordenadas del jugador (0–100, un decimal). Dentro de instancias solo se sabe el mapa.
function Learn.PlayerPos()
	local map = C_Map.GetBestMapForUnit("player")
	if not map or secret(map) then return nil end
	local ok, pos = pcall(C_Map.GetPlayerMapPosition, map, "player")
	if not ok or not pos or secret(pos) then return map end
	local x, y = pos:GetXY()
	if not x or secret(x) or secret(y) or (x == 0 and y == 0) then return map end
	return map, round1(x), round1(y)
end

local function linkID(link, kind)
	if not link or secret(link) then return nil end
	return tonumber(link:match("|H" .. kind .. ":(%d+)"))
end

local function union(a, b)
	local seen, out = {}, {}
	for _, list in ipairs({ a or {}, b or {} }) do
		for _, v in ipairs(list) do if not seen[v] then seen[v] = true; out[#out + 1] = v end end
	end
	return out
end

---------------------------------------------------------------------------
-- 1. Vendors / Vendedores
---------------------------------------------------------------------------
local function merchantItem(i)
	if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
		local d = C_MerchantFrame.GetItemInfo(i)
		if d then return d.price, d.stackCount, d.hasExtendedCost end
	end
	if GetMerchantItemInfo then
		local _, _, price, stack, _, _, _, ext = GetMerchantItemInfo(i)
		return price, stack, ext
	end
end

local function merchantCosts(i)
	local costs = {}
	for j = 1, GetMerchantItemCostInfo(i) or 0 do
		local _, value, link = GetMerchantItemCostItem(i, j)
		local currencyID = linkID(link, "currency")
		local itemID = not currencyID and linkID(link, "item")
		if currencyID then costs[#costs + 1] = { "c", currencyID, value or 1 }
		elseif itemID then costs[#costs + 1] = { "i", itemID, value or 1 } end
	end
	return #costs > 0 and costs or nil
end

-- Items are added or updated, never removed: class filters and rotations hide some items.
-- Los objetos se agregan o actualizan, nunca se borran: filtros y rotaciones ocultan algunos.
function Learn:ScanMerchant()
	if not enabled() then return end
	local npc, kind = Learn.FromGUID(UnitGUID("npc"))
	if not npc or kind ~= "n" then return end
	local count = GetMerchantNumItems and GetMerchantNumItems() or 0
	if count == 0 then return end
	local d = db()
	local v = d.vendors[npc] or { items = {} }
	local map, x, y = Learn.PlayerPos()
	v.map, v.x, v.y, v.t = map or v.map, x or v.x, y or v.y, now()
	local touched = {}
	for i = 1, count do
		local itemID = GetMerchantItemID and GetMerchantItemID(i)
		if itemID and not secret(itemID) then
			local price, stack, extended = merchantItem(i)
			local e = { p = (price and price > 0) and price or nil, n = (stack and stack > 1) and stack or nil }
			if extended and GetMerchantItemCostInfo then e.c = merchantCosts(i) end
			if e.p or e.c then v.items[itemID] = e; touched[#touched + 1] = itemID end
		end
	end
	d.vendors[npc] = v
	changed("vendors", touched)
end

---------------------------------------------------------------------------
-- 2. Loot / Botín
---------------------------------------------------------------------------
-- GUID + item already counted this session (reopening a corpse does not add up).
-- GUID + objeto ya contado en esta sesión (volver a abrir un cadáver no suma).
local lootSeen = {}

function Learn:ScanLoot()
	if not enabled() or not GetNumLootItems then return end
	local d = db()
	local map, x, y = Learn.PlayerPos()
	local touched = {}
	for slot = 1, GetNumLootItems() do
		local isItem = not GetLootSlotType or GetLootSlotType(slot) == 1
		local itemID = isItem and linkID(GetLootSlotLink(slot), "item")
		if itemID then
			local sources = { GetLootSourceInfo(slot) } -- guid, qty, guid, qty…
			for s = 1, #sources, 2 do
				local guid = sources[s]
				local id, kind = Learn.FromGUID(guid)
				local seenKey = id and (guid .. ":" .. itemID)
				if id and not lootSeen[seenKey] then
					lootSeen[seenKey] = true
					local byItem = d.loot[itemID] or {}
					local rec = byItem[kind .. id] or { n = 0 }
					rec.n = rec.n + 1
					rec.map, rec.x, rec.y, rec.t = map or rec.map, x or rec.x, y or rec.y, now()
					byItem[kind .. id] = rec
					d.loot[itemID] = byItem
					touched[#touched + 1] = itemID
				end
			end
		end
	end
	if #touched > 0 then changed("origins", touched) end
end

---------------------------------------------------------------------------
-- 3. Quests (when offered and when turned in) / Misiones (al verla y al entregarla)
---------------------------------------------------------------------------
local function questItems(kind, count)
	local list = {}
	for i = 1, count or 0 do
		local id = linkID(GetQuestItemLink(kind, i), "item")
		if id then list[#list + 1] = id end
	end
	return list
end

function Learn:ScanQuest()
	if not enabled() or not GetQuestID then return end
	local questID = GetQuestID()
	if not questID or secret(questID) or questID == 0 then return end
	local rewards = questItems("reward", GetNumQuestRewards and GetNumQuestRewards())
	local choices = questItems("choice", GetNumQuestChoices and GetNumQuestChoices())
	local d = db()
	local q = d.quests[questID] or {}
	local id, kind = Learn.FromGUID(UnitGUID("questnpc") or UnitGUID("npc"))
	if id then q.id, q.k = id, kind end
	local map, x, y = Learn.PlayerPos()
	q.map, q.x, q.y, q.t = map or q.map, x or q.x, y or q.y, now()
	q.r, q.ch = union(q.r, rewards), union(q.ch, choices)
	d.quests[questID] = q
	changed("origins", union(rewards, choices))
end

---------------------------------------------------------------------------
-- 4. Professions (in small batches, so the game never stalls)
-- 4. Profesiones (en bloques pequeños, para no trabar el juego)
---------------------------------------------------------------------------
local scanning, scannedThisSession = false, {}

function Learn:ScanProfession()
	if not enabled() or scanning or not C_TradeSkillUI then return end
	if C_TradeSkillUI.IsTradeSkillReady and not C_TradeSkillUI.IsTradeSkillReady() then return end
	local base = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
	local profession = base and base.professionID
	local ids = C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetAllRecipeIDs() or {}
	if not profession or #ids == 0 or scannedThisSession[profession] == #ids then return end
	scannedThisSession[profession] = #ids
	scanning = true
	-- Only required reagents count. / Solo cuentan los materiales obligatorios.
	local BASIC = Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic or 1
	local d, i, touched = db(), 1, {}
	local function step()
		for _ = 1, 40 do
			local recipeID = ids[i]
			if not recipeID then break end
			local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
			if ok and s and s.outputItemID and not secret(s.outputItemID) then
				local reagents = {}
				for _, slot in ipairs(s.reagentSlotSchematics or {}) do
					if slot.reagentType == BASIC then
						for _, r in ipairs(slot.reagents or {}) do
							if r.itemID then reagents[#reagents + 1] = { r.itemID, slot.quantityRequired or 1 } end
						end
					end
				end
				d.recipes[recipeID] = { o = s.outputItemID, q = s.quantityMin or 1, p = profession, r = reagents, t = now() }
				touched[#touched + 1] = s.outputItemID
				for _, r in ipairs(reagents) do touched[#touched + 1] = r[1] end
			end
			i = i + 1
		end
		if ids[i] then C_Timer.After(0.05, step)
		else scanning = false; changed("recipes", touched) end
	end
	step()
end

---------------------------------------------------------------------------
-- Reading (used by Data.lua) / Lectura (la usa Data.lua)
---------------------------------------------------------------------------
function Learn:GetVendor(npc)
	local v = ItemLensDB and ItemLensDB.learned and ItemLensDB.learned.vendors[npc]
	if not v then return nil end
	return { npc = npc, map = v.map, x = v.x, y = v.y, learned = true }
end

-- Learned exchanges: { [tokenKey] = { { npcID, itemID, cost }, … } }
-- Canjes aprendidos: { [token] = { { npcID, itemID, costo }, … } }
function Learn:GetOffers()
	local out = {}
	for npc, v in pairs(db().vendors) do
		for itemID, e in pairs(v.items or {}) do
			for _, c in ipairs(e.c or {}) do
				local key = c[1] .. c[2]
				out[key] = out[key] or {}
				table.insert(out[key], { npc, itemID, c[3] })
			end
		end
	end
	return out
end

-- Learned origins in the same shape as Data:GetObtain, flagged learned = true.
-- Orígenes aprendidos con el mismo formato que Data:GetObtain, marcados learned = true.
function Learn:GetOrigins(itemID)
	local d, out = db(), {}
	for npc, v in pairs(d.vendors) do
		local e = v.items and v.items[itemID]
		if e and e.p and not e.c then
			out[#out + 1] = { k = "v", id = npc, map = v.map, x = v.x, y = v.y, price = e.p, learned = true }
		end
	end
	for key, rec in pairs(d.loot[itemID] or {}) do
		out[#out + 1] = { k = key:sub(1, 1), id = tonumber(key:sub(2)), map = rec.map, x = rec.x, y = rec.y,
			count = rec.n, learned = true }
	end
	for questID, q in pairs(d.quests) do
		for _, list in ipairs({ q.r or {}, q.ch or {} }) do
			local found = false
			for _, id in ipairs(list) do if id == itemID then found = true break end end
			if found then
				out[#out + 1] = { k = "q", id = questID, map = q.map, x = q.x, y = q.y, learned = true }
				break
			end
		end
	end
	for _, r in pairs(d.recipes) do
		if r.o == itemID then out[#out + 1] = { k = "p", id = r.p, learned = true } break end
	end
	return out
end

-- Items crafted with this reagent: { { itemID, qty, true }, … }
-- Objetos que se fabrican con este material: { { itemID, cantidad, true }, … }
function Learn:GetCrafts(itemID)
	local out, seen = {}, {}
	for _, r in pairs(db().recipes) do
		for _, x in ipairs(r.r or {}) do
			if x[1] == itemID and not seen[r.o] then
				seen[r.o] = true
				out[#out + 1] = { r.o, x[2], true }
			end
		end
	end
	return out
end

function Learn:Counts()
	local d = db()
	local function n(t) local c = 0 for _ in pairs(t) do c = c + 1 end return c end
	return n(d.vendors), n(d.loot), n(d.quests), n(d.recipes)
end

function Learn:Clear()
	if ItemLensDB then ItemLensDB.learned = nil end
	db()
	lootSeen, scannedThisSession = {}, {}
	changed("all")
end

---------------------------------------------------------------------------
-- Events / Eventos
---------------------------------------------------------------------------
function Learn:Init()
	db()
	local pending = {}
	local function later(scan, delay)
		if pending[scan] then return end
		pending[scan] = true
		C_Timer.After(delay, function() pending[scan] = nil; pcall(scan, Learn) end)
	end
	IL.OnEvents({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "LOOT_READY", "QUEST_DETAIL", "QUEST_COMPLETE",
		"TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE" }, function(event)
		if not enabled() then return end
		if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
			later(Learn.ScanMerchant, 0.3)
		elseif event == "LOOT_READY" then
			pcall(Learn.ScanLoot, Learn) -- right away, before the window closes / ya, antes de que se cierre
		elseif event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" then
			pcall(Learn.ScanQuest, Learn)
		else
			later(Learn.ScanProfession, 0.5)
		end
	end)
end
