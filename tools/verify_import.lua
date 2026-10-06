-- Verifica que Data/iLs_Import.lua cargue como lo haría WoW y que sea consistente.
-- Uso: lua verify_import.lua ..\Data\iLs_Import.lua
local path = assert(arg[1], "falta ruta")
local IL = {}
local chunk = assert(loadfile(path))
chunk("ItemLens", IL)
assert(type(IL.DB) == "table", "IL.DB no existe")
local v, o = IL.DB.vendors, IL.DB.offers
local nV, nT, nO, orphan = 0, 0, 0, 0
for _ in pairs(v) do nV = nV + 1 end
for key, list in pairs(o) do
	nT = nT + 1
	assert(key:match("^[ic]%d+$"), "clave inválida: " .. key)
	for _, off in ipairs(list) do
		nO = nO + 1
		if not v[off[1]] then orphan = orphan + 1 end
	end
end
print(("OK · meta ATT %s (%s) · vendedores %d · tokens %d · canjes %d · canjes sin vendedor registrado %d")
	:format(IL.DB.meta.attVersion, IL.DB.meta.generated, nV, nT, nO, orphan))
