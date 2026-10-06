--[[
	ItemLens · Locales/esMX.lua
	Base strings (Spanish). Loaded first; enUS.lua overrides them on non-Spanish clients.
	Textos base (español). Se carga primero; enUS.lua los reemplaza en clientes que no son en español.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...

IL.LOCALE = GetLocale and GetLocale() or "esMX"
IL.SPANISH = IL.LOCALE == "esMX" or IL.LOCALE == "esES"

IL.L = {
	TITLE              = "ItemLens",

	-- Main window / Ventana principal
	TAB_BAG            = "Mochila",
	TAB_DICT           = "Diccionario",
	TAB_FAV            = "Favoritos",
	TAB_COLL           = "Colecciones",
	SEARCH             = "Buscar objeto o token…",
	NO_RESULTS         = "Sin resultados",
	EMPTY_FAVS_TITLE   = "Aún no tienes favoritos",
	EMPTY_FAVS_TEXT    = "Marca un objeto con la estrella y aparecerá aquí y en su tooltip.",
	PICK_ONE           = "Elige un objeto de la lista",
	FAV_ON             = "Favorito",
	FAV_OFF            = "Agregar",
	DICT_FOOTER        = "%d de %d objetos",
	DICT_LOADING       = "Cargando nombres… %d de %d",
	CLICK_HINT         = "Mayús+clic en un objeto: lo busca aquí si el cursor está en el buscador",
	N_ITEMS            = "%d |4objeto:objetos;",
	N_ITEMS_M_VENDORS  = "%d |4objeto:objetos; con %d |4vendedor:vendedores;",
	N_EXCH_M_VENDORS   = "%d |4canje:canjes; · %d |4vendedor:vendedores;",

	-- Detail header / Encabezado del detalle
	EXPANSION          = "Expansión",
	UNKNOWN_EXP        = "Desconocida",
	EXCHANGES          = "Se canjea",
	OBTAINED           = "Se obtiene",
	OBTAINED_WITH      = "Se obtiene con",
	PURPOSE            = "Sirve para",
	DRESSUP            = "Probador",
	DRESSUP_TIP        = "Ver en el probador.\nTambién: Ctrl+clic sobre cualquier objeto en ItemLens.",

	-- Detail sections / Secciones del detalle
	PURPOSE_SECTION    = "PARA QUÉ SIRVE",
	NEEDED_FOR         = "SE NECESITA PARA",
	WHERE              = "DÓNDE CANJEARLO",
	SOURCES            = "CÓMO SE OBTIENE",
	CRAFTS_SECTION     = "SE USA PARA FABRICAR",
	OWNERS             = "LO TIENEN",
	MORE_CRAFTS        = "+ %d objetos más",
	NO_USES            = "No se conoce ningún logro, invocación, evento o misión que lo pida.",
	NO_EXCHANGE        = "Sin datos de canje para este objeto.",
	PIN                = "Marcar en el mapa",
	PIN_SET            = "Punto marcado: %s (%s, %s)",
	PIN_FAIL           = "No se puede marcar en ese mapa.",

	-- What it's for / Para qué sirve
	USE_SUMMON         = "Invoca a %s",
	USE_WITH_NPC       = "Se usa con %s",
	USE_OBJECT         = "Se usa en: %s",
	USE_QUEST          = "Se entrega en la misión: %s",
	USE_QUEST_START    = "Inicia la misión: %s",
	USE_ACHIEVEMENT    = "Se necesita para el logro: %s",
	USE_MORE           = " (+%d)",
	TAG = {
		rare = "raro", worldboss = "jefe mundial", treasure = "tesoro",
		secret = "secreto", event = "evento",
	},
	BUYS               = "Moneda para comprar: %s",
	REAGENT            = "Material de profesión%s · se usa en %d |4receta:recetas;",
	CAT = {
		mount      = "%d |4montura:monturas;",
		pet        = "%d |4mascota:mascotas;",
		toy        = "%d |4juguete:juguetes;",
		recipe     = "%d |4receta:recetas;",
		gear       = "%d |4pieza de equipo:piezas de equipo;",
		consumable = "%d |4consumible:consumibles;",
		material   = "%d |4material:materiales;",
		other      = "%d |4otro:otros;",
	},

	-- How to get it / Cómo se obtiene
	SRC_BOSS           = "Botín de jefe",
	SRC_RARE           = "Botín de raro",
	SRC_WORLDBOSS      = "Jefe mundial",
	SRC_NPC            = "Botín de NPC",
	SRC_VENDOR         = "Vendedor",
	SRC_TREASURE       = "Tesoro",
	SRC_QUEST          = "Recompensa de misión",
	SRC_ACHIEVEMENT    = "Logro",
	SRC_CRAFTED        = "Fabricación",
	SRC_INSTANCE       = "Botín de instancia",
	SRC_CONTAINER      = "Sale de",
	SRC_ZONE           = "En la zona",
	SRC_REP            = "Reputación",
	SRC_CAT = {
		w = "Botín del mundo", j = "JcJ", x = "Función de expansión", k = "Personaje",
		e = "Evento", s = "Tienda del juego", m = "Promoción", t = "Puesto comercial",
		f = "Buscador de grupos", v = "Profundidades", i = "Instancia", c = "Fabricación",
		p = "Profesión", r = "Secreto", h = "Hogar", b = "Mercado negro", u = "Otro", z = "Zona",
	},

	-- Places / Lugares
	PLACE_RAID         = "Banda",
	PLACE_DUNGEON      = "Calabozo",
	PLACE_INSTANCE     = "Instancia",
	PLACE_ZONE         = "Zona",
	PLACE_FMT          = "%s · %s",
	TRADING_POST       = "Puesto comercial",
	CAPITALS           = "Capitales",

	-- Fallback names / Nombres de respaldo
	ITEM_N             = "Objeto #%d",
	CURRENCY_N         = "Moneda #%d",
	NPC_N              = "NPC #%d",
	MAP_N              = "Mapa #%d",
	OBJECT_N           = "Objeto del mundo #%d",
	QUEST_N            = "Misión #%d",
	INSTANCE_N         = "Instancia #%d",
	BOSS_N             = "Jefe #%d",
	ACHIEVEMENT_N      = "Logro #%d",
	PROFESSION_N       = "Profesión #%d",
	FACTION_N          = "Facción #%d",
	CLASS_N            = "Clase #%d",
	ITEM_UNAVAILABLE   = "Objeto #%d (no disponible en el juego)",
	QUEST_UNAVAILABLE  = "Misión #%d (no disponible en el juego)",

	-- Bank / Banco
	BANK_BTN           = "Banco »",
	BANK_BTN_OPEN      = "Banco «",
	BANK_TITLE         = "Banco",
	BANK_CHAR          = "Personaje",
	BANK_WARBAND       = "Banda guerrera",
	BANK_TAB_N         = "Pestaña %d",
	BANK_EMPTY         = "Todavía no hay datos. Abre el banco una vez y aparecerá aquí.",
	BANK_SRC_OWN       = "%d |4objeto:objetos; · visto el %s",
	BANK_SRC_SYN       = "%d |4objeto:objetos; · datos de Syndicator",

	-- Who has it / Lo tienen
	OWN_BAGS           = "bolsas %d",
	OWN_BANK           = "banco %d",
	OWN_EQUIPPED       = "equipado %d",
	TT_TOTAL           = "Total",

	-- Collections / Colecciones
	COLL_SETS = {
		mm     = "Manuscritos de dracoequitación",
		class  = "Desbloqueos de clase",
		other  = "Otros desbloqueos",
		quests = "Misiones de clase",
		art    = "Armas artefacto",
	},
	COLL_SET           = "Conjunto: %s",
	COLL_EXP           = "Exp.: %s",
	COLL_CLASS         = "Clase: %s",
	COLL_ALL           = "Todas",
	COLL_ALL_CLASSES   = "Todas",
	COLL_CLASS_NA      = "Este conjunto no depende de la clase: todos sus objetos sirven para cualquier clase.",
	COLL_REWARD_ONLY   = "Con recompensa",
	COLL_REWARD_TIP    = "Mostrar solo las misiones que dan un objeto de recompensa. Algunas sin recompensa son necesarias para desbloquear las siguientes.",
	COLL_HAVE          = "Aprendido",
	COLL_MISSING       = "Te falta",
	COLL_OTHERCLASS    = "Otra clase",
	COLL_OTHER         = "Otros",
	COLL_FOOTER        = "Aprendidos: %d de %d",
	STATE_ALL          = "Todos",
	STATE_MISSING      = "Faltan",
	STATE_HAVE         = "Tengo",
	STATE_DONE         = "Hechas",

	-- Class quests / Misiones de clase
	Q_DONE             = "Hecha",
	Q_PENDING          = "Pendiente",
	Q_CLASS            = "Clase",
	Q_REWARDS          = "Recompensas",
	Q_PLACE            = "Lugar",
	Q_SECTION_PLACE    = "UBICACIÓN",
	Q_SECTION_REWARDS  = "RECOMPENSAS",
	Q_SECTION_CHARS    = "TUS PERSONAJES DE ESTA CLASE",
	Q_PENDING_FOR      = "Le falta a",
	Q_DONE_BY          = "Ya la hizo",
	Q_NO_CHARS         = "Ningún personaje de esta clase registrado (entra una vez con él).",

	-- Artifact weapons / Armas artefacto
	ART_APPEARANCE     = "Apariencia",
	ART_N              = "Apariencia de artefacto #%d",
	ART_WEAPON         = "Arma",
	ART_SET            = "Conjunto",
	ART_SECTION_HOW    = "CÓMO SE CONSIGUE",
	ART_SET_ONLY       = "Se consigue por su conjunto: %s",

	-- Learning / Aprendizaje
	LEARNED_TIP        = "Aprendido por ItemLens mientras juegas (no viene en los datos importados).",
	LEARN_SEEN         = "visto %d veces",
	LEARN_STATUS       = "Aprendido: %d |4vendedor:vendedores; · %d |4objeto:objetos; con botín · %d |4misión:misiones; · %d |4receta:recetas;",
	LEARN_CLEARED      = "Datos aprendidos borrados.",

	-- Tooltip
	TT_HEADER          = "ItemLens",
	TT_PURPOSE         = "Sirve para: %s",
	TT_OBTAIN          = "Se obtiene: %s",
	TT_EXCH            = "Se canjea: %d |4objeto:objetos; · %d |4vendedor:vendedores;",
	TT_NEAREST         = "Más cercano: %s · %s",
	TT_OBTAINED        = "Se obtiene con: %s ×%d",
	TT_CLICK           = "Mayús+clic: abrir en ItemLens",

	-- Options and commands / Opciones y comandos
	OPT_TOOLTIP        = "Tooltip de favoritos",
	OPT_OWNERS         = "Personajes en el tooltip",
	OPT_CLICK          = "Mayús+clic (sin cursor) abre ItemLens",
	OPT_LEARN          = "Aprender mientras juegas",
	TOGGLED            = "%s: %s",
	ON                 = "activado",
	OFF                = "desactivado",
	RESET_DONE         = "Ventana centrada.",
	BINDING_TOGGLE     = "Abrir/cerrar ItemLens",
	COMPARTMENT_TIP    = "Clic: abrir/cerrar la ventana",
	HELP = {
		"|cffc8a765ItemLens|r %s — comandos:",
		"  /il — abrir/cerrar la ventana",
		"  /il <link de objeto> — abrir ese objeto",
		"  /il tooltip — activar/desactivar el bloque en el tooltip de favoritos",
		"  /il personajes — activar/desactivar los personajes que lo tienen en el tooltip",
		"  /il clic — activar/desactivar que Mayús+clic (sin cursor en un campo) abra ItemLens",
		"  /il aprender — activar/desactivar el aprendizaje (y ver cuánto lleva)",
		"  /il aprender borrar — borrar todo lo aprendido",
		"  /il reset — volver a centrar la ventana",
		"  /il creditos — créditos y licencias",
	},
	CREDITS = {
		"|cffc8a765ItemLens|r %s (build %s) — © 2026 TavoD_Gus_KrG · Licencia MIT",
		"  |cffc8a765AllTheThings|r — base de datos de vendedores, orígenes y colecciones (MIT, © 2026 AllTheThings WoW Addon). ¡Gracias a su comunidad!",
		"  |cffc8a765Syndicator|r (plusmouse) y |cffc8a765TomTom|r (Cladhaire, Ludovicus) — compatibilidad opcional.",
		"  World of Warcraft® es marca de Blizzard Entertainment, Inc. ItemLens no está afiliado a Blizzard.",
	},
}
