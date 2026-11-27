--[[
	ItemLens · Core/LoadWork.lua
	Heavy one-time work runs while a loading screen is up (D-85): logging in, /reload and every
	zone change with a loading screen. Nothing of it runs while you play, so the game does not
	stutter a few seconds after the screen goes away. What does not fit in one loading screen goes
	on in the next one (or right away, if a window needs it before).
	El trabajo pesado de una sola vez corre mientras está la pantalla de carga (D-85): al entrar,
	con /reload y en cada cambio de zona con pantalla de carga. Nada de eso corre mientras juegas,
	así que el juego no se traba unos segundos después de que se quita la pantalla. Lo que no cabe
	en una pantalla de carga sigue en la siguiente (o en el momento, si una ventana lo necesita antes).
	© 2026 iAthVo_Kr · MIT License
]]

local _, IL = ...

local LoadWork = { jobs = {} }
IL.LoadWork = LoadWork

-- Milliseconds of work per loading screen: more when entering (the screen is up longer anyway).
-- Milisegundos de trabajo por pantalla de carga: más al entrar (la pantalla dura más de todos modos).
LoadWork.FIRST_MS, LoadWork.ZONE_MS = 1500, 300

function LoadWork.Clock()
	if debugprofilestop then return debugprofilestop() end
	return 0 -- no clock (tests): never out of time / sin reloj (pruebas): nunca se acaba el tiempo
end

-- step(deadline) does a part and returns true when it is finished; it checks Clock() < deadline.
-- step(deadline) hace una parte y devuelve true cuando terminó; revisa Clock() < deadline.
function LoadWork:Add(name, step)
	self.jobs[#self.jobs + 1] = { name = name, step = step }
end

function LoadWork:Pending() return #self.jobs end

function LoadWork:Run(ms)
	local deadline = self.Clock() + (ms or self.ZONE_MS)
	local i = 1
	while self.jobs[i] do
		local job = self.jobs[i]
		local ok, done = pcall(job.step, deadline)
		if not ok or done then table.remove(self.jobs, i) else i = i + 1 end
		if self.Clock() >= deadline then break end
	end
	return #self.jobs == 0
end

-- PLAYER_ENTERING_WORLD arrives while the screen is still up (it goes away right after), and
-- LOADING_SCREEN_ENABLED when the next one appears.
-- PLAYER_ENTERING_WORLD llega con la pantalla todavía puesta (se quita justo después), y
-- LOADING_SCREEN_ENABLED cuando aparece la siguiente.
local first = true
IL.OnEvents({ "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_ENABLED" }, function(event)
	if #LoadWork.jobs == 0 then return end
	LoadWork:Run(first and event == "PLAYER_ENTERING_WORLD" and LoadWork.FIRST_MS or LoadWork.ZONE_MS)
	if event == "PLAYER_ENTERING_WORLD" then first = false end
end)
