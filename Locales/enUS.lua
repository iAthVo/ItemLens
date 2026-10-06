--[[
	ItemLens · Locales/enUS.lua
	English strings, applied over the Spanish base on every non-Spanish client.
	Textos en inglés; se aplican sobre la base en español en cualquier cliente que no sea en español.
	© 2026 TavoD_Gus_KrG · MIT License
]]

local _, IL = ...

local EN = {
	-- Main window / Ventana principal
	TAB_BAG            = "Bags",
	TAB_DICT           = "Catalog",
	TAB_FAV            = "Favorites",
	TAB_COLL           = "Collections",
	SEARCH             = "Search item or token…",
	NO_RESULTS         = "No results",
	EMPTY_FAVS_TITLE   = "No favorites yet",
	EMPTY_FAVS_TEXT    = "Star an item and it will show up here and in its tooltip.",
	PICK_ONE           = "Pick an item from the list",
	FAV_ON             = "Favorite",
	FAV_OFF            = "Add",
	DICT_FOOTER        = "%d of %d items",
	DICT_LOADING       = "Loading names… %d of %d",
	N_ITEMS            = "%d |4item:items;",
	N_ITEMS_M_VENDORS  = "%d |4item:items; from %d |4vendor:vendors;",
	N_EXCH_M_VENDORS   = "%d |4exchange:exchanges; · %d |4vendor:vendors;",

	-- Detail header / Encabezado del detalle
	EXPANSION          = "Expansion",
	UNKNOWN_EXP        = "Unknown",
	EXCHANGES          = "Exchanges",
	OBTAINED           = "Obtained",
	OBTAINED_WITH      = "Obtained with",
	PURPOSE            = "Used for",
	DRESSUP            = "Dressing room",
	DRESSUP_TIP        = "Preview in the dressing room.\nAlso: Ctrl+click any item in ItemLens.",

	-- Detail sections / Secciones del detalle
	PURPOSE_SECTION    = "WHAT IT'S FOR",
	NEEDED_FOR         = "NEEDED FOR",
	WHERE              = "WHERE TO EXCHANGE IT",
	SOURCES            = "HOW TO GET IT",
	CRAFTS_SECTION     = "USED TO CRAFT",
	OWNERS             = "WHO HAS IT",
	MORE_CRAFTS        = "+ %d more items",
	NO_USES            = "No known achievement, summon, event or quest requires it.",
	NO_EXCHANGE        = "No exchange data for this item.",
	PIN                = "Pin on the map",
	PIN_SET            = "Waypoint set: %s (%s, %s)",
	PIN_FAIL           = "Can't place a waypoint on that map.",

	-- What it's for / Para qué sirve
	USE_SUMMON         = "Summons %s",
	USE_WITH_NPC       = "Used with %s",
	USE_OBJECT         = "Used at: %s",
	USE_QUEST          = "Turned in for the quest: %s",
	USE_QUEST_START    = "Starts the quest: %s",
	USE_ACHIEVEMENT    = "Needed for the achievement: %s",
	TAG = {
		rare = "rare", worldboss = "world boss", treasure = "treasure",
		secret = "secret", event = "event",
	},
	BUYS               = "Currency to buy: %s",
	REAGENT            = "Crafting reagent%s · used in %d |4recipe:recipes;",
	CAT = {
		mount      = "%d |4mount:mounts;",
		pet        = "%d |4pet:pets;",
		toy        = "%d |4toy:toys;",
		recipe     = "%d |4recipe:recipes;",
		gear       = "%d |4piece of gear:pieces of gear;",
		consumable = "%d |4consumable:consumables;",
		material   = "%d |4material:materials;",
		other      = "%d |4other:others;",
	},

	-- How to get it / Cómo se obtiene
	SRC_BOSS           = "Boss drop",
	SRC_RARE           = "Rare drop",
	SRC_WORLDBOSS      = "World boss",
	SRC_NPC            = "NPC drop",
	SRC_VENDOR         = "Vendor",
	SRC_TREASURE       = "Treasure",
	SRC_QUEST          = "Quest reward",
	SRC_QUEST_WEEKLY   = "Weekly quest",
	SRC_QUEST_DAILY    = "Daily quest",
	REQUIRES           = "Requirement: %s",
	REP_WITH           = "%s with %s",
	EVENT_ZONES        = "Zones: %s",
	RENOWN_N           = "Renown %d",
	SOURCE_UNKNOWN     = "Unknown",
	NO_SOURCE_YET      = "ItemLens doesn't know where to get this yet. Once you see it at a vendor or in loot, it will learn it on its own.",
	SRC_ACHIEVEMENT    = "Achievement",
	SRC_CRAFTED        = "Crafted",
	SRC_INSTANCE       = "Instance drop",
	SRC_CONTAINER      = "Comes from",
	SRC_ZONE           = "In zone",
	SRC_REP            = "Reputation",
	SRC_CAT = {
		w = "World drop", j = "PvP", x = "Expansion feature", k = "Character",
		e = "Event", s = "In-game Shop", m = "Promotion", t = "Trading Post",
		f = "Group Finder", v = "Delves", i = "Instance", c = "Crafted",
		p = "Profession", r = "Secret", h = "Housing", b = "Black Market", u = "Other", z = "Zone",
	},

	-- Places / Lugares
	PLACE_RAID         = "Raid",
	PLACE_DUNGEON      = "Dungeon",
	PLACE_INSTANCE     = "Instance",
	PLACE_ZONE         = "Zone",
	TRADING_POST       = "Trading Post",
	CAPITALS           = "Capital cities",

	-- Fallback names / Nombres de respaldo
	ITEM_N             = "Item #%d",
	CURRENCY_N         = "Currency #%d",
	MAP_N              = "Map #%d",
	OBJECT_N           = "World object #%d",
	QUEST_N            = "Quest #%d",
	INSTANCE_N         = "Instance #%d",
	BOSS_N             = "Boss #%d",
	ACHIEVEMENT_N      = "Achievement #%d",
	PROFESSION_N       = "Profession #%d",
	FACTION_N          = "Faction #%d",
	CLASS_N            = "Class #%d",
	ITEM_UNAVAILABLE   = "Item #%d (not available in game)",
	QUEST_UNAVAILABLE  = "Quest #%d (title unavailable)",

	-- Bank / Banco
	BANK_BTN           = "Bank »",
	BANK_BTN_OPEN      = "Bank «",
	BANK_TITLE         = "Bank",
	BANK_CHAR          = "Character",
	BANK_WARBAND       = "Warband",
	BANK_TAB_N         = "Tab %d",
	BAG_BACKPACK       = "Backpack",
	BAG_N              = "Bag %d",
	BAG_CURRENCIES     = "Currencies",
	BANK_EMPTY         = "No data yet. Open your bank once and it will show up here.",
	BANK_SRC_OWN       = "%d |4item:items; · seen on %s",
	BANK_SRC_SYN       = "%d |4item:items; · data from Syndicator",

	-- Who has it / Lo tienen
	OWN_BAGS           = "bags %d",
	OWN_BANK           = "bank %d",
	OWN_EQUIPPED       = "equipped %d",

	-- Collections / Colecciones
	COLL_SETS = {
		mm     = "Skyriding manuscripts",
		class  = "Class unlocks",
		other  = "Other unlocks",
		quests = "Class quests",
		art    = "Artifact weapons",
	},
	COLL_SET           = "Set: %s",
	COLL_EXP           = "Exp.: %s",
	COLL_CLASS         = "Class: %s",
	COLL_ALL           = "All",
	COLL_ALL_CLASSES   = "All",
	COLL_CLASS_NA      = "This set doesn't depend on class: every item works for any class.",
	COLL_REWARD_ONLY   = "With reward",
	COLL_REWARD_TIP    = "Show only quests that give an item reward. Some quests without a reward are needed to unlock the next ones.",
	COLL_HAVE          = "Learned",
	COLL_MISSING       = "Missing",
	COLL_OTHERCLASS    = "Other class",
	COLL_OTHER         = "Others",
	COLL_FOOTER        = "Learned: %d of %d",
	STATE_ALL          = "All",
	STATE_MISSING      = "Missing",
	STATE_HAVE         = "Owned",
	STATE_DONE         = "Done",

	-- Class quests / Misiones de clase
	Q_DONE             = "Done",
	Q_PENDING          = "Pending",
	Q_CLASS            = "Class",
	Q_REWARDS          = "Rewards",
	Q_PLACE            = "Location",
	Q_SECTION_PLACE    = "LOCATION",
	Q_SECTION_REWARDS  = "REWARDS",
	Q_SECTION_CHARS    = "YOUR CHARACTERS OF THIS CLASS",
	Q_PENDING_FOR      = "Still needed by",
	Q_DONE_BY          = "Already done by",
	Q_NO_CHARS         = "No character of this class recorded yet (log in with it once).",

	-- Artifact weapons / Armas artefacto
	ART_APPEARANCE     = "Appearance",
	ART_N              = "Artifact appearance #%d",
	ART_WEAPON         = "Weapon",
	ART_SET            = "Set",
	ART_SECTION_HOW    = "HOW TO UNLOCK IT",
	ART_SET_ONLY       = "Unlocked through its set: %s",

	-- Learning / Aprendizaje
	LEARNED_TIP        = "Learned by ItemLens while you play (not in the imported data).",
	LEARN_SEEN         = "seen %d times",
	LEARN_STATUS       = "Learned: %d |4vendor:vendors; · %d |4item:items; with drops · %d |4quest:quests; · %d |4recipe:recipes;",
	LEARN_CLEARED      = "Learned data cleared.",

	-- Tooltip
	TT_PURPOSE         = "Used for: %s",
	TT_OBTAIN          = "Obtained: %s",
	TT_EXCH            = "Exchanges: %d |4item:items; · %d |4vendor:vendors;",
	TT_NEAREST         = "Nearest: %s · %s",
	TT_OBTAINED        = "Obtained with: %s ×%d",

	-- Options and commands / Opciones y comandos
	OPT_TOOLTIP        = "Favorites tooltip",
	OPT_OWNERS         = "Characters in tooltip",
	OPT_CLICK          = "Shift+click (no cursor) opens ItemLens",
	OPT_LEARN          = "Learn while you play",
	ON                 = "on",
	OFF                = "off",
	RESET_DONE         = "Window centered.",
	BINDING_TOGGLE     = "Open/close ItemLens",
	COMPARTMENT_TIP    = "Click: open/close the window",
	HELP = {
		"|cffc8a765ItemLens|r %s — commands:",
		"  /il — open/close the window",
		"  /il <item link> — open that item",
		"  /il tooltip — toggle the favorites block in tooltips",
		"  /il characters — toggle the characters that own it in tooltips",
		"  /il click — toggle Shift+click (no text box focused) opening ItemLens",
		"  /il learn — toggle learning while you play (and see how much it has learned)",
		"  /il learn clear — clear everything learned",
		"  /il reset — re-center the window",
		"  /il credits — credits and licenses",
	},
	CREDITS = {
		"|cffc8a765ItemLens|r %s (build %s) — © 2026 TavoD_Gus_KrG · MIT License",
		"  |cffc8a765AllTheThings|r — vendor, source and collection data (MIT, © 2026 AllTheThings WoW Addon). Thanks to their community!",
		"  |cffc8a765Syndicator|r (plusmouse) and |cffc8a765TomTom|r (Cladhaire, Ludovicus) — optional compatibility.",
		"  World of Warcraft® is a trademark of Blizzard Entertainment, Inc. ItemLens is not affiliated with Blizzard.",
	},
}

IL.L_EN = EN

if not IL.SPANISH then
	for key, text in pairs(EN) do IL.L[key] = text end
end
