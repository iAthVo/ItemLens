"""
ItemLens · generador de Data/iLs_Achievements.lua (solo desarrollo, fuera del juego). D-56.

Junta lo que el cliente del juego NO da sobre los logros:
  - Qué logros de Misiones entran (solo los que son criterio de otro logro incluido) y cuáles
    de Exploración (solo tesoros). El resto de las reglas se aplica en el juego por categoría.
  - "Es parte de": qué logros piden a cuál (índice inverso de criterios).
  - Disponibilidad de proezas y logros (campo u de AllTheThings).
  - Coordenadas, NPC y objetos de cada criterio (AllTheThings).
  - Misiones repetibles y entregas que suben cada reputación (AllTheThings).
  - Los 50 logros famosos y los borradores de guía.

Fuentes:
  - Logros de la API de Blizzard (Blizzard_API/export/logros_es_MX.json, de export_logros.py).
  - tools/att_achievements.lua → JSON con los datos de ATT (MIT, con crédito: D-12, D-43).

Uso (desde la carpeta ItemLens):
  lua tools\\att_achievements.lua ..\\AllTheThings tools\\att_achievements.json
  python tools\\ach_extract.py <ruta a logros_es_MX.json> [tools\\att_achievements.json]
"""
import collections
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "Data", "iLs_Achievements.lua")

if len(sys.argv) < 2:
    sys.exit("Uso: python tools\\ach_extract.py <logros_es_MX.json> [att_achievements.json]")
api = json.load(open(sys.argv[1], encoding="utf-8"))
att = json.load(open(sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "att_achievements.json"), encoding="utf-8"))
A, CATS = api["achievements"], api["categories"]
ATT_CRIT, ATT_ACH, ATT_REP = att["crit"], att["ach"] or {}, att["rep"]
if isinstance(ATT_ACH, list): ATT_ACH = {}

# Categorías raíz (IDs del juego, iguales en la API). Mismas reglas que Modules/Achievements.lua.
QUESTS, EXPLORATION, FEATS, LEGACY = 96, 97, 81, 15234
EXCLUDED = {92, 95, 15117, 15076}       # Personajes (nivel/equipo), JcJ, duelos de mascotas, hermandad
EXCLUDED_LEGACY_SUBS = {"Jugador contra Jugador", "Personaje"}

def cat(cid): return CATS.get(str(cid)) or {}
def root_of(cid): return cat(cid).get("parent") or cid

# Famosos y difíciles (IDs verificados en la API). Orden = número de guía.
FAMOUS = [2336, 2144, 7520, 2136, 2137, 4602, 13687, 40232, 12866, 942, 762, 948, 10672, 12947, 2536, 8302,
          9673, 12996, 5755, 9838, 10770, 11162, 4923, 4859, 306, 150, 2096, 1836, 1837, 2094, 16298, 8726,
          10348, 871, 15941, 2051, 1683, 3456, 2798, 1793, 3478, 1693, 1691, 1288, 13994, 14760, 19458, 20501,
          2187, 4625]
FAMOUS = [f for f in FAMOUS if str(f) in A][:50]

def is_treasure(a):
    return "tesoro" in ((a["name"] or "") + " " + (a["description"] or "")).lower()

def base_included(a):
    r = root_of(a["category"])
    if r in EXCLUDED or r == QUESTS: return False
    if r == LEGACY and cat(a["category"]).get("name") in EXCLUDED_LEGACY_SUBS: return False
    if r == EXPLORATION: return is_treasure(a)
    return True

# Quién pide a quién
required_by = collections.defaultdict(set)
for a in A.values():
    def walk(n, owner=a["id"]):
        if not n: return
        if n.get("achievement"): required_by[n["achievement"]].add(owner)
        for ch in n.get("children") or []: walk(ch, owner)
    walk(a["criteria"])

included = {int(i) for i, a in A.items() if base_included(a)} | set(FAMOUS)
quests = set()
changed = True
while changed:  # misiones: criterio de un logro incluido (cierre transitivo)
    changed = False
    for i, a in A.items():
        i = int(i)
        if i in included or root_of(a["category"]) != QUESTS: continue
        if required_by.get(i, set()) & included:
            included.add(i); quests.add(i); changed = True
treasures = {int(i) for i, a in A.items() if root_of(a["category"]) == EXPLORATION and is_treasure(a)}

# Expansión (D-71): por la subcategoría con nombre de expansión (Exploración › Midnight…);
# si la categoría no lo dice, la de ATT. 1 Clásico … 12 Midnight (mismo número que ATT).
EXP_BY_NAME = {
    "World of Warcraft": 1, "Clásico": 1, "Reinos del Este": 1, "Kalimdor": 1,
    "The Burning Crusade": 2, "Terrallende": 2,
    "Wrath of the Lich King": 3, "Rasganorte": 3, "Lich King: Calabozo": 3, "Lich King: Banda": 3,
    "Cataclysm": 4, "Pandaria": 5, "Draenor": 6, "Legion": 7, "Battle for Azeroth": 8,
    "Shadowlands": 9, "Dragonflight": 10, "War Within": 11, "The War Within": 11, "Midnight": 12,
}
def exp_of_cat(cid):
    seen = 0
    while cid and seen < 6:
        c = cat(cid)
        if c.get("name") in EXP_BY_NAME: return EXP_BY_NAME[c["name"]]
        cid, seen = c.get("parent"), seen + 1
    return None
exp_cat = {}
for sid in CATS:
    e = exp_of_cat(int(sid))
    if e: exp_cat[int(sid)] = e
exp_ach = {}
for sid, a in A.items():
    if exp_of_cat(a["category"]): continue
    e = (ATT_ACH.get(sid) or {}).get("exp") if isinstance(ATT_ACH.get(sid), dict) else None
    if isinstance(e, (int, float)) and 1 <= e <= 12: exp_ach[int(sid)] = int(e)

# Disponibilidad: u de ATT; 0 = ATT lo conoce sin restricción (sirve para "Disponible" en proezas)
avail = {}
for sid, info in ATT_ACH.items():
    aid = int(sid)
    if aid not in included: continue
    if info.get("u"): avail[aid] = info["u"]
    elif root_of((A.get(sid) or {}).get("category")) == FEATS: avail[aid] = 0

# Retirado en el parche (D-82): rwp de ATT (120200 = 12.2.0). En el juego se compara con la versión
# del cliente: ya pasó → retirado; todavía no → por tiempo limitado (hasta ese parche).
rwp = {int(sid): int(info["rwp"]) for sid, info in ATT_ACH.items()
       if isinstance(info, dict) and isinstance(info.get("rwp"), (int, float)) and int(sid) in included}

# Faction: 1 Horde, 2 Alliance (only one-faction achievements) / Facción (D-59)
faction = {int(sid): info["fac"] for sid, info in ATT_ACH.items()
           if isinstance(info, dict) and info.get("fac") in (1, 2) and int(sid) in included}

def num(v): return ("%.1f" % v).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)
def lstr(s): return json.dumps(s, ensure_ascii=False)

# Criterios ubicados: { [índice] = {map, x, y, npc, item, "nota en inglés"} }
crit_lines = []
for sid in sorted(ATT_CRIT, key=int):
    aid = int(sid)
    if aid not in included: continue
    rows = []
    entries = ATT_CRIT[sid] if isinstance(ATT_CRIT[sid], dict) else {}  # una tabla vacía de Lua llega como []
    for k in sorted(entries, key=lambda k: int(k[1:])):
        e = entries[k]
        if not isinstance(e, dict) or e.get("x") is None: continue
        npc = (e.get("npcs") or [None])[0] or (e["id"] if e.get("kind") == "NPC" else None)
        item = ((e.get("items") or [[None]])[0])[0]
        tip = (e.get("desc") or "")[:200]
        fields = [num(e["map"]), num(e["x"]), num(e["y"]), num(npc) if npc else "nil", num(item) if item else "nil"]
        if e.get("kind") == "Object" and e.get("id"): fields.append(num(e["id"]))
        elif tip: fields.append("nil")
        if tip: fields.append(lstr(tip))
        rows.append(f"[{k[1:]}]={{{','.join(fields)}}}")
    if rows: crit_lines.append(f"\t\t[{aid}]={{{','.join(rows)}}},")

# Objetos que pide cada logro (todos los de ATT, también materiales de cada criterio): el
# buscador los encuentra y el detalle dice "Se necesita para: <logro>".
needs = {}
for sid, entries in ATT_CRIT.items():
    if not isinstance(entries, dict): continue
    aid = int(sid)
    for e in entries.values():
        if not isinstance(e, dict): continue
        ids = [it[0] for it in (e.get("items") or []) if it and it[0]]
        if e.get("kind") == "Item" and e.get("id"): ids.append(e["id"])
        for i in ids:
            needs.setdefault(int(i), set()).add(aid)
needs_lines = [f"[{i}]={{{','.join(map(str, sorted(a)))}}}" for i, a in sorted(needs.items())]

# Reputación: misiones repetibles o con entrega. {quest, map, x, y, npc, item, cantidad, tope}
rep_lines = []
for sid in sorted(ATT_REP, key=int):
    rows = []
    for q in ATT_REP[sid]:
        if not (q.get("repeatable") or q.get("cost")): continue
        item, n = (q.get("cost") or [[None, None]])[0]
        npc = (q.get("qgs") or [None])[0]
        fields = [num(q["quest"]), num(q["map"]) if q.get("map") else "nil", num(q["x"]) if q.get("x") is not None else "nil",
                  num(q["y"]) if q.get("y") is not None else "nil", num(npc) if npc else "nil", num(item) if item else "nil",
                  num(n) if n else "nil", num(q["max"]) if q.get("max") else "nil", "true" if q.get("repeatable") else "nil"]
        rows.append("{" + ",".join(fields) + "}")
    if rows: rep_lines.append(f"\t\t[{sid}]={{{','.join(rows[:8])}}},")

req_lines = []
for aid in sorted(included):
    rb = sorted(x for x in required_by.get(aid, ()) if x in included)
    if rb: req_lines.append(f"[{aid}]={{{','.join(map(str, rb[:8]))}}}")

def setline(ids): return ",".join(f"[{i}]=true" for i in sorted(ids))

out = f"""--[[
	ItemLens · Data/iLs_Achievements.lua
	Generated by tools/ach_extract.py — do not edit by hand. / Generado por tools/ach_extract.py — no editar a mano.
	What the game client does not give about achievements (D-56): which Quests/Exploration
	achievements are listed, "part of", availability, criteria locations and reputation quests.
	Lo que el cliente no da sobre los logros (D-56): qué logros de Misiones/Exploración se listan,
	"es parte de", disponibilidad, ubicación de criterios y misiones de reputación.
	Data from AllTheThings (MIT): availability, locations, reputation quests. / Datos de AllTheThings (MIT).
	© 2026 iAthVo_Kr · MIT License
]]

local _, IL = ...

IL.ACH = {{
	-- Famous and hard achievements, in guide order / Famosos y difíciles, en orden de guía
	famous = {{{",".join(map(str, FAMOUS))}}},
	-- Quests achievements that are a criterion of another listed one / Misiones que son criterio de otro logro
	quests = {{{setline(quests)}}},
	-- Exploration: treasures only / Exploración: solo tesoros
	treasures = {{{setline(treasures)}}},
	-- [achID] = {{ achievements that ask for it }} / logros que lo piden
	requiredBy = {{{",".join(req_lines)}}},
	-- [achID] = ATT "u": 0 available, 1 never implemented, 2 removed, 3 promotion, 4 legacy, 9 black market…
	avail = {{{",".join(f"[{k}]={v}" for k, v in sorted(avail.items()))}}},
	-- [achID] = ATT "removed with patch" (120200 = 12.2.0) / retirado en el parche · D-82
	rwp = {{{",".join(f"[{k}]={v}" for k, v in sorted(rwp.items()))}}},
	-- Expansion (D-71): [categoryID] = n by category name; [achID] = n from ATT when the category doesn't say
	-- Expansión (D-71): por nombre de categoría; por logro (ATT) cuando la categoría no lo dice
	expCat = {{{",".join(f"[{k}]={v}" for k, v in sorted(exp_cat.items()))}}},
	expAch = {{{",".join(f"[{k}]={v}" for k, v in sorted(exp_ach.items()))}}},
	-- [achID] = 1 Horde · 2 Alliance (only one-faction ones) / solo los de una facción · D-59
	faction = {{{",".join(f"[{k}]={v}" for k, v in sorted(faction.items()))}}},
	-- [achID] = {{ [criteria index] = {{ map, x, y, npcID, itemID, objectID, "ATT note (English)" }} }}
	crit = {{
{chr(10).join(crit_lines)}
	}},
	-- [itemID] = {{ achievements that need it (ATT, materials included) }} / logros que lo piden (D-66)
	needs = {{{",".join(needs_lines)}}},
	-- [factionID] = {{ {{ quest, map, x, y, npcID, itemID, count, max rep, repeatable }} }}
	rep = {{
{chr(10).join(rep_lines)}
	}},
	-- Insane in the Membrane: no criteria in the client. {{ factionID, standing (FACTION_STANDING_LABEL index) }}
	-- Demente supereminente: sin criterios en el cliente. {{ facción, nivel (índice de FACTION_STANDING_LABEL) }}
	insane = {{ {{ 87, 6 }}, {{ 21, 8 }}, {{ 577, 8 }}, {{ 369, 8 }}, {{ 470, 8 }}, {{ 909, 8 }}, {{ 349, 8 }} }},
}}
"""
open(OUT, "w", encoding="utf-8", newline="\n").write(out)
print(f"Listo: {OUT}")
print(f"  famosos {len(FAMOUS)} · misiones {len(quests)} · tesoros {len(treasures)} · es parte de {len(req_lines)}"
      f" · disponibilidad {len(avail)} · con parche de retiro {len(rwp)} · con ubicaciones {len(crit_lines)} · facciones {len(rep_lines)}"
      f" · de una facción {len(faction)} · objetos que piden logros {len(needs_lines)}"
      f" · expansión: {len(exp_cat)} categorías + {len(exp_ach)} logros (ATT)"
      f" · {round(os.path.getsize(OUT) / 1024)} KB")
