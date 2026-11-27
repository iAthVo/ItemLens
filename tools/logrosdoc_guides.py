# ItemLens · tools/logrosdoc_guides.py
# Converts the LogrosDoc guide (one Markdown file per section) into Data/iLs_Guides.lua:
#   IL.GUIDES.ach[achID]   = { step, … }   step = "text" or { "text", mapID, x, y }
#   IL.GUIDES.crit[critID] = "text" or { "text", mapID, x, y }
# Achievement and criterion IDs come from the Blizzard API export (es_MX names).
# Convierte la guía LogrosDoc (un Markdown por sección) en Data/iLs_Guides.lua.
# Los IDs de logros y criterios salen de la exportación de la API de Blizzard (nombres es_MX).
# Nothing personal is copied: no status marks, no "your progress", no character names.
# No se copia nada personal: ni estados, ni "tu avance", ni nombres de personajes.
#
# Uso: python -I tools/logrosdoc_guides.py <carpeta LogrosDoc> <logros_es_MX.json> [nombres,privados]
import json, os, re, sys, unicodedata, glob

sys.stdout.reconfigure(encoding="utf-8")
DOC, EXPORT = sys.argv[1], sys.argv[2]
PRIVATE = [n.strip().lower() for n in (sys.argv[3] if len(sys.argv) > 3 else "").split(",") if n.strip()]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Data", "iLs_Guides.lua")
SKIP_FILES = {"LogrosDoc.md", "EstadoGuias.md", "Pendientes.md"}
MAX_STEP = 420
MIN_ID = 41000  # Midnight-era IDs only / solo IDs de la era de Midnight

data = json.load(open(EXPORT, encoding="utf-8"))
ACH = data["achievements"]

def norm(s):
    s = unicodedata.normalize("NFKD", s or "").lower()
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    s = re.sub(r"[^a-z0-9' ]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()

by_name = {}
for sid, a in ACH.items():
    by_name.setdefault(norm(a["name"]), []).append(int(sid))

def crit_list(a):
    out = []
    def walk(n):
        if not n: return
        for ch in n.get("children") or []:
            if ch.get("description"): out.append((ch["id"], ch["description"]))
            walk(ch)
    walk(a.get("criteria"))
    return out

def pick(ids):
    # Newest one (Midnight) when a name repeats. / El más nuevo si el nombre se repite.
    return max(ids) if ids else None

EMOJI = {"🟡": "(por confirmar)", "⚠️": "Ojo:", "⚠": "Ojo:"}
def clean(s):
    for k, v in EMOJI.items(): s = s.replace(k, v)
    s = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", s)          # links → text
    s = s.replace("**", "").replace("`", "")
    s = re.sub(r"(?<![\w*])\*([^*]+)\*(?![\w*])", r"\1", s)  # *italic*
    s = "".join(c for c in s if ord(c) < 0x2190 or c in "→←·…—–")  # no emoji / sin emoji
    s = re.sub(r"\s+", " ", s).strip(" ·-|")
    return sources(s)

# No other addons or sites in the addon (D-83): LogrosDoc keeps its sources (Method, Wowhead…),
# the generated guide speaks in ItemLens' own voice. Only ATT is credited (in the credits).
# Sin otros addons ni sitios en el addon (D-83): LogrosDoc conserva sus fuentes; la guía generada
# habla con la voz de ItemLens. Solo ATT lleva crédito (en los créditos).
SOURCE_FIX = [
    (r"Pega cada bloque en el chat con /ttpaste \(TomTom\) para cargar todos los puntos del grupo\.?",
     "Usa Marcar todo (arriba, junto a la barra de progreso) para poner todos los puntos en el mapa."),
    (r"Coordenadas de la Warcraft Wiki; Wowhead da unas ligeramente distintas \(ej\. ([^)]*)\)\. Con TomTom estando en la zona: /way ([\d.]+ [\d.]+) (\w+)\.?",
     r"Las coordenadas pueden variar un poco (ej. \1). \3: \2."),
    (r"^:?\s*y \(por confirmar\) el quinto: Method dice, Icy Veins dice", "(por confirmar) el quinto punto"),
    (r"^:?\s*y \(por confirmar\) el quinto: Icy Veins dice ?\(Method da una coordenada en otro mapa que parece error\)",
     "(por confirmar) el quinto punto"),
    (r"Fuentes: [^.]*\. Las coordenadas de los pasos (\d+ y \d+) vienen de una sola guía;",
     r"Las coordenadas de los pasos \1 todavía no están confirmadas;"),
    (r"\(Gamerpillar lo llama ([^)]*)\)", r"(también la llaman \1)"),
    (r"^Video: YouTube\.?$", ""),
    (r"^Addons? útil(?:es)?: .*$", ""),
    (r"\s*El addon [\w-]+ [^.]*\.", ""),
    # First-person notes of the research (D-84) / Notas en primera persona de la investigación
    (r"^Los nombres en inglés de la guía que traduje a los oficiales: .*$", ""),
    (r"\s*\(?(?:\(por confirmar\) )?Si alguno no cuadra en el juego, avísame\.?\)?", ""),
    (r"Un reporte del foro menciona que ", "Al parecer, "),
    (r"\s*\(por confirmar\) Para verlos en video con el mapa: YouTube: [^.]*\.?", ""),
    (r"Coordenadas de la Warcraft Wiki \(mapa de ([^,)]*), #\d+\)\.", r"Coordenadas del mapa de \1."),
    (r"Coordenadas de Wowhead \(mapa de ([^)]*)\):", r"Ubicaciones (mapa de \1):"),
    (r"Coordenadas de Wowhead:", "Ubicaciones:"),
    (r"Según comentarios de Wowhead, hay", "Hay"),
    (r"Según Icy Veins, la", "la"),
    (r"Según Wowhead News y otras guías, Blizzard", "Blizzard"),
    (r"Icy Veins calcula unos", "Se calculan unos"),
    (r"Icy Veins dice que lo quitaron del logro \(([^)]*)\), pero la exportación de Blizzard todavía lo lista",
     r"Parece que lo quitaron del logro (\1), pero el juego todavía lo lista"),
    (r"\(Method no dice cuál de cada uno\)", "(no se sabe cuál de cada uno)"),
    (r"\s*\(unas (\d+) semanas en total según Method\)", r" (unas \1 semanas en total)"),
    (r"\s*\(según Method\)", ""),
    (r"\s*\(Wowhead solo trae un crédito de PNJ\)", ""),
    (r"Ninguna guía publica coordenadas; estas son las ubicaciones descritas \(Gamerpillar\),",
     "Sin coordenadas exactas; estas son las ubicaciones descritas,"),
    (r"\s*\(Gamerpillar\)", ""),
    (r"; nombres traducidos por mí\)", ")"),
    (r"son traducción mía", "son traducción no oficial (pueden cambiar en el juego)"),
    # Commenters, site sections and the research's own notes (D-86) / Comentaristas, secciones de
    # sitios y notas de la propia investigación
    (r"\s*\(AlterTime\)", ""),
    (r"\s*Fuente: AlterTime\.?", ""),
    (r"Según Reins of Pain, algunos", "Según reportes de jugadores, algunos"),
    (r"Revisa cuándo está activa en Today in WoW\.", "Revisa en el calendario del juego cuándo está activa."),
    (r"^Los dos estaban hechos en tu exportación[^.]*\.$", ""),
]
SOURCE_FIX = [(re.compile(a), b) for a, b in SOURCE_FIX]
# Anything left is reported, so a new LogrosDoc note does not slip into the addon.
# Lo que quede se avisa, para que una nota nueva de LogrosDoc no se cuele en el addon.
FORBIDDEN = re.compile(r"method|wowhead|icy ?veins|youtube|warcraft ?wiki|tomtom|/ttpaste|gamerpillar|reddit|"
                       r"mmo-?champion|wowpedia|zygor|data ?for ?azeroth|simple ?armory|por mí\b|traducción mía|\baddons?\b|\btraduje\b|avísame|curseforge|wago|github|alter ?time|today in wow|reins of pain|tu exportación", re.I)
leftovers = set()
def sources(s):
    for rx, rep in SOURCE_FIX:
        s = rx.sub(rep if callable(rep) else (lambda m, r=rep: m.expand(r)), s)
    s = re.sub(r"\s+", " ", s).strip(" ·-|")
    if FORBIDDEN.search(s): leftovers.add(s)
    return s

WAY = re.compile(r"/way\s+#(\d+)\s+([\d.]+)[ ,]+([\d.]+)")
def coords(s):
    m = WAY.search(s or "")
    return (int(m.group(1)), float(m.group(2)), float(m.group(3))) if m else None
def strip_way(s):
    s = (s or "").replace("`", "")
    s = re.sub(r"\(?\s*/way\s+#\d+\s+[\d.]+[ ,]+[\d.]+\s*\)?", "", s)
    return re.sub(r"\(\s*\)", "", s)

def private(s):
    low = s.lower()
    return any(p in low for p in PRIVATE) or "tu avance" in low or "capturas" in low

def slug(h):
    s = h.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s, flags=re.UNICODE)
    return re.sub(r"\s", "-", s)

def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]

guides, crits, crit_text, unmatched, stats = {}, {}, {}, [], {"files": 0, "sections": 0}
crit_text_cid = {}  # (achID, criterion text) → criterion ID / ID del criterio

def step_of(text, where=None):
    text = clean(strip_way(text))
    if not text or private(text): return None
    if text.startswith('"'): return None
    if text.endswith(":") and len(text) < 40: return None  # a lone label / una etiqueta suelta
    text = re.sub(r"\s+([.,;])", r"\1", text)
    if len(text) > MAX_STEP: text = text[:MAX_STEP - 1].rsplit(" ", 1)[0] + "…"
    return [text, where[0], where[1], where[2]] if where else text

def match_ach(name):
    n = re.sub(r"\((meta|proeza|por personaje|por confirmar)\)", "", name or "", flags=re.I)
    ids = [i for i in by_name.get(norm(n), []) if i >= MIN_ID]
    return pick(ids)

def ids_for_title(title, anchors):
    names = anchors.get(slug(title)) or []
    if not names:
        t = re.sub(r"^[\d.]+\s*", "", title)
        t = re.sub(r"\s*·.*$", "", t)
        names = [t, re.sub(r"\s*\([^)]*\)\s*$", "", t)]
        m = re.match(r"^(.*?:\s*)(.+) y (.+)$", t)
        if m: names += [m.group(1) + m.group(2), m.group(1) + m.group(3)]
    ids = []
    for n in names:
        aid = match_ach(n)
        if aid and aid not in ids: ids.append(aid)
    return ids

# Second, looser key (no non-ASCII letters), in case a name is written with other accents or symbols.
# Segunda clave más floja (sin letras no ASCII), por si un nombre viene con otros acentos o símbolos.
def loose(s):
    return norm("".join(c for c in (s or "") if ord(c) < 128))

def crit_map(ids):
    out = {}
    for aid in ids:
        for cid, desc in crit_list(ACH[str(aid)]):
            out.setdefault(norm(desc), (cid, aid, desc))
            out.setdefault("~" + loose(desc), (cid, aid, desc))
    return out

def add_steps(ids, st):
    if not st: return
    text = st[0] if isinstance(st, list) else st
    for aid in ids:
        if norm(text) == norm(ACH[str(aid)]["name"]): continue  # just its own name / solo su nombre
        g = guides.setdefault(aid, [])
        if st not in g: g.append(st)

for path in sorted(glob.glob(os.path.join(DOC, "*.md"))):
    if os.path.basename(path) in SKIP_FILES: continue
    stats["files"] += 1
    lines = open(path, encoding="utf-8").read().splitlines()
    anchors = {}
    for ln in lines:
        if ln.startswith("## "): break
        for name, anc in re.findall(r"\[([^\]]+)\]\(#([^)]+)\)", ln):
            anchors.setdefault(anc, []).append(name)
    ids2, ids3, head = [], [], None
    topic_tips, topic_achs = [], []
    def flush_topic():
        for aid in topic_achs:
            for st in topic_tips: guides.setdefault(aid, []).append(st)
    for ln in lines:
        s = ln.strip()
        if s.startswith("#"):
            level = len(s) - len(s.lstrip("#"))
            title = s[level:].strip()
            if level <= 2:
                flush_topic()
                topic_tips, topic_achs = [], []
                ids2, ids3 = ids_for_title(title, anchors), []
                if ids2: stats["sections"] += 1
                elif level == 2 and not title.lower().startswith("fuentes"): unmatched.append(os.path.basename(path) + " · " + title)
            else:
                ids3 = ids_for_title(title, anchors)
                if ids3: stats["sections"] += 1
            head = None
            continue
        cur = ids3 or ids2
        if not s or s == "---": continue
        if s.startswith("|"):
            c = cells(s)
            if all(re.fullmatch(r":?-+:?", x or "-") for x in c): continue
            if head is None:
                head = [norm(x) or x.strip().lower() for x in c]
                continue
            keep, name, where = [], None, None
            for i, v0 in enumerate(c):
                h = head[i] if i < len(head) else ""
                if h in ("estado", "#", "pts", "puntos") or h.startswith("pts"): continue
                w = coords(v0)
                if w and not where: where = w
                v = clean(strip_way(v0))
                if not v or v in ("—", "-"): continue
                if name is None: name = v; continue
                keep.append(v)
            if not name or private(name): continue
            text = " · ".join(k for k in keep if not private(k))
            # 1) a criterion of the current achievement / un criterio del logro actual
            bare = re.sub(r"\s*\(por confirmar\)", "", name).strip()
            cm = crit_map(cur) if cur else {}
            hit = cm.get(norm(bare)) or cm.get("~" + loose(bare))
            if hit:
                cid, caid, desc = hit
                tip = clean(text) or name
                tip = [tip, where[0], where[1], where[2]] if where else tip
                crits[cid] = tip
                # Also by the criterion's text, which is what the game shows (its IDs are not the web ones).
                # También por el texto del criterio, que es lo que muestra el juego (sus IDs no son los de la web).
                key = bare if "�" in desc else desc
                crit_text.setdefault(caid, {})[key] = tip
                crit_text_cid[(caid, key)] = cid  # for the English text / para el texto en inglés
                continue
            # 2) a row that is itself an achievement / una fila que es un logro
            aid = match_ach(name)
            if aid and aid not in cur:
                add_steps([aid], step_of(text or name, where))
                topic_achs.append(aid)
                continue
            # 3) a detail of the current achievement (not the row of the achievement itself)
            # 3) un detalle del logro actual (no la fila del propio logro)
            if cur and aid not in cur: add_steps(cur, step_of(name + (": " + text if text else ""), where))
            continue
        head = None
        body = re.sub(r"^(\d+\.|[-*])\s+", "", s)
        m = re.match(r"^\*\*([^*]+?)\*\*:?\s*(.*)$", body)
        if m and not cur:
            aid = match_ach(m.group(1).rstrip(":"))
            if aid:
                add_steps([aid], step_of(m.group(2) or m.group(1), coords(body)))
                topic_achs.append(aid)
                continue
        if cur:
            add_steps(cur, step_of(body, coords(body)))
        elif re.match(r"^\*\*Sugerencia", body):
            st = step_of(body, coords(body))
            if st: topic_tips.append(st)
    flush_topic()

###########################################################################
# Game names (D-84): the guides say what the game shows.
#   1. English → es_MX with Blizzard's own names: achievements and criteria (logros_en_US.json next
#      to the es_MX export) and dungeons, raids and bosses (diario.json, export_diario.py).
#   2. The official spelling of the achievement's criteria and of Midnight achievement names
#      (accents and capitals: "La Llama sin Eco" → "La llama sin eco").
#   3. A short list checked by hand (names that are another word, not a spelling).
# Nombres del juego (D-84): las guías dicen lo que muestra el juego.
###########################################################################
EXPORT_DIR = os.path.dirname(os.path.abspath(EXPORT))
EN_PATH = os.path.join(EXPORT_DIR, "logros_en_US.json")
DIARIO_PATH = os.path.join(EXPORT_DIR, "diario.json")

def crit_tree(n, out):
    if not n: return out
    if n.get("id") is not None and n.get("description"): out[n["id"]] = n["description"].strip()
    for ch in n.get("children") or []: crit_tree(ch, out)
    return out

ES_CRIT, CRIT_OWNER = {}, {}
for sid, a in ACH.items():
    t = crit_tree(a.get("criteria"), {})
    ES_CRIT[int(sid)] = t
    for cid in t: CRIT_OWNER[cid] = int(sid)

EN_ES = {}
# One English word that is also a plain word (or the expansion, which keeps its name in Spanish):
# never translated alone. / Una palabra inglesa común (o la expansión, que en español se llama igual).
NOT_ALONE = {"midnight", "common", "uncommon", "epic", "heroic", "mythic", "normal", "rare", "legendary",
             "silence", "spirit", "light", "shadow", "void", "hope", "village", "den", "row", "arena",
             "edition", "honor", "glory", "darkness", "fear", "rest", "home", "family"}
def pair(en, es):
    en, es = (en or "").strip().rstrip("."), (es or "").strip().rstrip(".")
    if not (en and es and en != es and len(en) >= 5 and norm(en) != norm(es)): return
    if " " not in en and en.lower() in NOT_ALONE: return
    EN_ES.setdefault(en, es)
names_src = []
if os.path.exists(DIARIO_PATH):
    for inst in json.load(open(DIARIO_PATH, encoding="utf-8"))["instances"]:
        pair(inst["en"], inst["es"])
        for e in inst["encounters"]: pair(e["en"], e["es"])
    names_src.append("diario")
if os.path.exists(EN_PATH):
    EN_ACH = json.load(open(EN_PATH, encoding="utf-8"))["achievements"]
    for sid, a in EN_ACH.items():
        if int(sid) < MIN_ID or sid not in ACH: continue
        pair(a.get("name"), ACH[sid]["name"])
    for sid, a in EN_ACH.items():
        if int(sid) < MIN_ID or sid not in ACH: continue
        es_t = ES_CRIT.get(int(sid), {})
        for cid, d in crit_tree(a.get("criteria"), {}).items(): pair(d, es_t.get(cid))
    names_src.append("logros en inglés")
EN_LIST = sorted(EN_ES.items(), key=lambda kv: -len(kv[0]))
EN_RX = {}
def en_rx(en):
    rx = EN_RX.get(en)
    if not rx:
        flags = re.I if " " in en else 0
        # A leading English "The" goes with it: "The Silence at…" → "Silencio en…".
        # Un "The" inglés delante se va con el nombre.
        lead = "" if en.lower().startswith("the ") else r"(?:\bThe\s+)?"
        rx = EN_RX[en] = re.compile(r"(?<![\w'’])" + lead + re.escape(en) + r"(?![\w'’])", flags)
    return rx

ACC = {"a": "aáàAÁÀ", "e": "eéEÉ", "i": "iíIÍ", "o": "oóOÓ", "u": "uúüUÚÜ", "n": "nñNÑ"}
def acc_rx(name):
    out = []
    for ch in name:
        base = unicodedata.normalize("NFKD", ch)[0].lower()
        if ch.isspace(): out.append(r"\s+")
        elif base in ACC: out.append("[" + ACC[base] + "]")
        else: out.append(re.escape(ch))
    return re.compile(r"(?<![\w'’])" + "".join(out) + r"(?![\w'’])", re.I)
GLOBAL_NAMES = sorted({a["name"].strip() for sid, a in ACH.items()
                       if int(sid) >= MIN_ID and len(a["name"]) >= 10 and " " in a["name"]}, key=len, reverse=True)
ACC_RX = {}
def spell_fix(s, names):
    ns = norm(s)
    for c in names:
        if norm(c) not in ns: continue
        rx = ACC_RX.get(c) or ACC_RX.setdefault(c, acc_rx(c))
        def rep(m, c=c):
            w = m.group(0)
            if w == c or (w[1:] == c[1:] and w[0].lower() == c[0].lower()): return w
            return (w[0] + c[1:]) if w[0].lower() == c[0].lower() else c
        s = rx.sub(rep, s)
    return s

# Checked by hand: the guide used another word for the official name. / Revisados a mano.
HAND_FIX = [
    (r"Guarda de Wey'nan", "Resguardo de Wey'nan"),
    (r"(?<!El )Caldero de Ecos", "El caldero de ecos"),
    (r"Alcance de Russula", "Socorro de Russula"),
    (r"Floración de Aln'hara", "Flor de Aln'hara"),
]
HAND_FIX = [(re.compile(a), b) for a, b in HAND_FIX]

changed = {"en": 0, "spell": 0, "hand": 0}
def game_names(s, aid):
    if not s: return s
    orig = s
    low = s.lower()
    for en, es in EN_LIST:
        if en.lower() in low:
            s2 = en_rx(en).sub(lambda m, es=es: es, s)
            if s2 != s: s, low, changed["en"] = s2, s2.lower(), changed["en"] + 1
    for rx, b in HAND_FIX:
        s2 = rx.sub(lambda m, b=b: b, s)
        if s2 != s: s, changed["hand"] = s2, changed["hand"] + 1
    own = sorted(set(ES_CRIT.get(aid, {}).values()) | {(ACH.get(str(aid)) or {}).get("name", "")}, key=len, reverse=True)
    own = [c for c in own if len(c) >= 6 and " " in c]
    s2 = spell_fix(spell_fix(s, own), GLOBAL_NAMES)
    if s2 != s: s, changed["spell"] = s2, changed["spell"] + 1
    # "Lithiel Cinderfury · Lithiel Furicienta" → once the English one is translated, only one.
    # Only names repeat-drop (≥4 letters): "1 · 1 · 1" stays. / Solo nombres: "1 · 1 · 1" se queda.
    parts = s.split(" · ")
    dedup = [p for i, p in enumerate(parts)
             if i == 0 or p != parts[i - 1] or len(re.sub(r"[^A-Za-zÀ-ÿ]", "", p)) < 4]
    s = " · ".join(dedup)
    # "Pecados del pasado (Pecados del pasado)" → once; "X (X, con L'ura)" → "X (con L'ura)".
    s = re.sub(r"([^()·:]{4,}?) \(\1\)", r"\1", s)
    s = re.sub(r"([^()·:]{4,}?) \(\1,\s*", r"\1 (", s)
    return s

def fix_step(st, aid):
    if isinstance(st, list): return [game_names(st[0], aid)] + st[1:]
    return game_names(st, aid)
for aid in guides: guides[aid] = [fix_step(st, aid) for st in guides[aid]]
for cid in crits: crits[cid] = fix_step(crits[cid], CRIT_OWNER.get(cid))
for aid in crit_text:
    crit_text[aid] = {t: fix_step(v, aid) for t, v in crit_text[aid].items()}

# English that is still there (quests and NPCs have no official name in the exports): reported.
# Inglés que queda (misiones y PNJ no tienen nombre oficial en las exportaciones): se avisa.
EN_WORDS = re.compile(r"\b(?:The|of|the|and|from|with|for|to|in|at|on|Defeat|Kill|Den|Hunter|Row)\b")
TITLE = re.compile(r"\b[A-Z][\w'’-]*(?:\s+(?:of|the|and|from|with|for|to|in|at|on|a|an|[A-Z][\w'’-]*)\b)+")
still_en = set()
def scan_en(s):
    for seg in TITLE.findall(s or ""):
        if EN_WORDS.search(seg) and len(seg.split()) >= 2: still_en.add(seg)
for aid in guides:
    for st in guides[aid]: scan_en(st[0] if isinstance(st, list) else st)
for v in crits.values(): scan_en(v[0] if isinstance(v, list) else v)

def lua(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'
def val(v):
    if isinstance(v, list): return "{ " + lua(v[0]) + ", " + str(v[1]) + ", " + repr(v[2]) + ", " + repr(v[3]) + " }"
    return lua(v)

def write_guides(path, head, guard, g, c, ct, names):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        for h in head: f.write("-- " + h + "\n")
        f.write("-- © 2026 iAthVo_Kr · MIT License\n")
        f.write("local _, IL = ...\n")
        f.write("local es = (GetLocale and GetLocale() or \"\"):match(\"^es\") ~= nil\n")
        f.write("if %s then return end\n" % guard)
        f.write("IL.GUIDES = {\n\tach = {\n")
        for aid in sorted(g):
            f.write("\t\t[%d] = { -- %s\n" % (aid, names(aid)))
            for st in g[aid]: f.write("\t\t\t" + val(st) + ",\n")
            f.write("\t\t},\n")
        f.write("\t},\n\tcrit = {\n")
        for cid in sorted(c): f.write("\t\t[%d] = %s,\n" % (cid, val(c[cid])))
        f.write("\t},\n\t-- critText[achID][criterion text] = same tip, matched by the text the game shows (D-80)\n\tcritText = {\n")
        for aid in sorted(ct):
            f.write("\t\t[%d] = { -- %s\n" % (aid, names(aid)))
            for t in sorted(ct[aid]): f.write("\t\t\t[%s] = %s,\n" % (lua(t), val(ct[aid][t])))
            f.write("\t\t},\n")
        f.write("\t},\n}\n")

def es_name(aid): return ACH[str(aid)]["name"].replace("\n", " ")
write_guides(OUT, [
    "ItemLens · Data/iLs_Guides.lua",
    "GENERATED by tools/logrosdoc_guides.py from the LogrosDoc guide — do not edit by hand.",
    "GENERADO por tools/logrosdoc_guides.py desde la guía LogrosDoc — no editar a mano.",
    "Spanish text; only es clients load it (D-86). / Texto en español; solo lo cargan clientes en español.",
], "not es", guides, crits, crit_text, es_name)

###########################################################################
# English guides (D-86): the same guide for every client that is not in Spanish.
#   · tools/guides_en.json = { "Spanish text": "English text" }, translated by hand; a new or changed
#     LogrosDoc line goes to tools/guides_en_todo.json (with the game names already in English as
#     a help) and stays out of the English file until it is translated.
#   · Criterion texts use the game's own English text (same criterion ID in logros_en_US.json).
# Guías en inglés (D-86): la misma guía para todo cliente que no esté en español.
#   · tools/guides_en.json = { "texto en español": "texto en inglés" }, traducido a mano; una línea
#     nueva o cambiada del LogrosDoc va a tools/guides_en_todo.json (con los nombres del juego ya en
#     inglés como ayuda) y no entra al archivo en inglés hasta traducirla.
#   · Los textos de criterio usan el texto en inglés del propio juego (mismo ID en logros_en_US.json).
TOOLS = os.path.dirname(os.path.abspath(__file__))
TR_PATH = os.path.join(TOOLS, "guides_en.json")
TODO_PATH = os.path.join(TOOLS, "guides_en_todo.json")
OUT_EN = os.path.join(TOOLS, "..", "Data", "iLs_Guides_enUS.lua")
TR = json.load(open(TR_PATH, encoding="utf-8")) if os.path.exists(TR_PATH) else {}
EN_ACH = EN_ACH if os.path.exists(EN_PATH) else {}
EN_CRIT = {}
for sid, a in EN_ACH.items(): EN_CRIT.update(crit_tree(a.get("criteria"), {}))

# Spanish → English game names, only as a help for the translator. / Solo como ayuda al traducir.
ES_EN = {}
for en, es in EN_ES.items(): ES_EN.setdefault(es, en)
ES_LIST = sorted(ES_EN.items(), key=lambda kv: -len(kv[0]))
def pre_en(s):
    for es, en in ES_LIST:
        if es.lower() not in s.lower(): continue
        rx = re.compile(r"(?<![\w'’])" + re.escape(es) + r"(?![\w'’])", re.I if " " in es else 0)
        s = rx.sub(lambda m, en=en: en, s)
    return s

missing, used = {}, set()
def tr(s):
    if not s: return None
    t = TR.get(s)
    if t is None: missing[s] = pre_en(s); return None
    used.add(s)
    return t
def tr_step(st):
    if isinstance(st, list):
        t = tr(st[0])
        return [t] + st[1:] if t else None
    return tr(st)

g_en, c_en, ct_en = {}, {}, {}
for aid in guides:
    steps = [x for x in (tr_step(st) for st in guides[aid]) if x]
    if steps: g_en[aid] = steps
for cid in crits:
    x = tr_step(crits[cid])
    if x: c_en[cid] = x
no_en_crit = 0
for aid in crit_text:
    for t, v in crit_text[aid].items():
        en_t = EN_CRIT.get(crit_text_cid.get((aid, t)))
        x = tr_step(v)
        if not en_t: no_en_crit += 1; continue
        if x: ct_en.setdefault(aid, {})[en_t.strip()] = x
for s in TR.values():  # D-83 and nothing personal, also in English / también en inglés
    if FORBIDDEN.search(s): leftovers.add("(en) " + s)
    if any(n in s.lower() for n in PRIVATE): leftovers.add("(en, privado) " + s)

def en_name(aid):
    return ((EN_ACH.get(str(aid)) or {}).get("name") or es_name(aid)).replace("\n", " ")
write_guides(OUT_EN, [
    "ItemLens · Data/iLs_Guides_enUS.lua",
    "GENERATED by tools/logrosdoc_guides.py from the LogrosDoc guide and tools/guides_en.json — do not edit by hand.",
    "GENERADO por tools/logrosdoc_guides.py desde la guía LogrosDoc y tools/guides_en.json — no editar a mano.",
    "English text; every client that is not in Spanish loads it (D-86). / Texto en inglés; lo cargan los clientes que no están en español.",
], "es", g_en, c_en, ct_en, en_name)
with open(TODO_PATH, "w", encoding="utf-8", newline="\n") as f:
    json.dump([{"es": k, "pre": v} for k, v in sorted(missing.items())], f, ensure_ascii=False, indent=1)

print("archivos %d · secciones con logro %d · logros con guía %d · pasos %d · criterios con sugerencia %d"
      % (stats["files"], stats["sections"], len(guides), sum(len(v) for v in guides.values()), len(crits)))
print("secciones sin logro (%d):" % len(unmatched))
for u in unmatched: print("  ", u)
if leftovers:
    print("OJO: quedan menciones de otros addons o sitios (agrega una regla a SOURCE_FIX):")
    for s in sorted(leftovers): print("  -", s[:200])
else:
    print("sin menciones de otros addons ni sitios (D-83)")
print("nombres del juego (D-84): fuentes %s · %d pares inglés→español · cambios: %d de inglés, %d de ortografía, %d a mano"
      % (", ".join(names_src) or "ninguna", len(EN_ES), changed["en"], changed["spell"], changed["hand"]))
print("guías en inglés (D-86): %d logros · %d criterios · %d textos de criterio · traducidas %d · faltan %d (en %s)"
      % (len(g_en), len(c_en), sum(len(v) for v in ct_en.values()), len(used), len(missing),
         os.path.basename(TODO_PATH)))
if no_en_crit: print("  textos de criterio sin inglés oficial: %d" % no_en_crit)
unused = set(TR) - used
if unused: print("  traducciones que ya no se usan (la línea cambió en LogrosDoc): %d" % len(unused))
if still_en:
    print("queda en inglés (%d; misiones o PNJ sin nombre oficial en las exportaciones):" % len(still_en))
    for s in sorted(still_en): print("  ·", s)
