--[[
	ItemLens · Core/Util.lua
	Shared helpers: keys, secret values, character names, events, chat links and container scans.
	Utilidades compartidas: claves, valores secretos, nombres de personaje, eventos, enlaces y bolsas.
	© 2026 TavoD_Gus_KrG · MIT License

	Comment style: English first, Spanish second.
	Estilo de comentarios: primero inglés, luego español.
]]

local _, IL = ...

---------------------------------------------------------------------------
-- Keys / Claves
---------------------------------------------------------------------------
-- Every entry is a key: "i<itemID>", "c<currencyID>", "q<questID>" or "f<artifact appearanceID>".
-- Cada entrada es una clave: "i<itemID>", "c<monedaID>", "q<misiónID>" o "f<apariencia de artefacto>".
function IL.SplitKey(key)
	return key:sub(1, 1), tonumber(key:sub(2))
end

---------------------------------------------------------------------------
-- Secret values / Valores secretos
---------------------------------------------------------------------------
-- Midnight may hand out "secret values" (mostly in combat or instances): they cannot be
-- compared, indexed or used in math. Check anything that comes from the game first.
-- Midnight puede entregar "valores secretos" (sobre todo en combate o instancias): no se pueden
-- comparar, indexar ni operar. Revisa primero todo lo que venga del juego.
function IL.IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) and true or false
end

---------------------------------------------------------------------------
-- Characters / Personajes
---------------------------------------------------------------------------
-- "Name-Realm" of the current character, or nil while the realm is not available yet.
-- "Nombre-Reino" del personaje actual, o nil mientras el reino todavía no está disponible.
function IL.PlayerKey()
	local name, realm = UnitFullName("player")
	if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
	if not name or name == "" or not realm or realm == "" then return nil end
	return name .. "-" .. realm
end

-- "Name" for characters on your realm, "Name-Realm" for the rest.
-- "Nombre" para personajes de tu reino, "Nombre-Reino" para los demás.
function IL.ShortName(fullName)
	local name, realm = fullName:match("^(.-)%-(.*)$")
	if not name then return fullName end
	local myRealm = GetNormalizedRealmName and GetNormalizedRealmName()
	return realm == myRealm and name or fullName
end

---------------------------------------------------------------------------
-- Output / Salida
---------------------------------------------------------------------------
function IL:Print(msg, ...)
	print("|cffc8a765ItemLens|r " .. (select("#", ...) > 0 and msg:format(...) or msg))
end

-- Inserts an item link into the active chat box.
-- Inserta un enlace de objeto en la caja de chat activa.
function IL.InsertLink(link)
	if not link then return end
	if ChatFrameUtil and ChatFrameUtil.InsertLink then
		ChatFrameUtil.InsertLink(link)
	elseif ChatEdit_InsertLink then
		ChatEdit_InsertLink(link)
	end
end

---------------------------------------------------------------------------
-- Events / Eventos
---------------------------------------------------------------------------
-- Creates a frame listening to the given events. Unknown events are skipped silently.
-- Crea un marco que escucha los eventos dados. Los eventos que no existen se ignoran.
function IL.OnEvents(events, handler)
	local frame = CreateFrame("Frame")
	for _, event in ipairs(events) do pcall(frame.RegisterEvent, frame, event) end
	frame:SetScript("OnEvent", function(_, ...) handler(...) end)
	return frame
end

---------------------------------------------------------------------------
-- Containers / Contenedores
---------------------------------------------------------------------------
-- Backpack plus equipped bags. / Mochila más bolsas equipadas.
function IL.BagIDs()
	local ids = {}
	for bag = 0, NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5 do ids[#ids + 1] = bag end
	return ids
end

-- Reads containers into { [key] = count }. Also returns the total slot count, so callers can
-- tell "empty" apart from "could not be read" (bank tabs are only readable while open).
-- Lee contenedores en { [clave] = cantidad }. También devuelve el total de espacios, para
-- distinguir "vacío" de "no se pudo leer" (el banco solo se lee mientras está abierto).
function IL.ScanContainers(bagIDs)
	local items, slots = {}, 0
	for _, bag in ipairs(bagIDs) do
		local n = C_Container.GetContainerNumSlots(bag) or 0
		slots = slots + n
		for slot = 1, n do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				local key = "i" .. info.itemID
				items[key] = (items[key] or 0) + (info.stackCount or 1)
			end
		end
	end
	return items, slots
end

-- Currencies you own that are exchange tokens: { [key] = amount }.
-- Monedas que tienes y que sirven para canjear: { [clave] = cantidad }.
function IL.ScanCurrencies()
	local out = {}
	for _, key in ipairs(IL.Data:GetTokenKeys()) do
		local kind, id = IL.SplitKey(key)
		if kind == "c" then
			local info = C_CurrencyInfo.GetCurrencyInfo(id)
			if info and (info.quantity or 0) > 0 then out[key] = info.quantity end
		end
	end
	return out
end
