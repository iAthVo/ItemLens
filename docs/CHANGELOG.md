# ItemLens — Changelog

Dos números de versión (D-48):
- **Versión pública** = parche del juego + número de entrega: `12.1.0.1` es la primera entrega
  para el parche 12.1.0; con cada parche nuevo vuelve a `.1`. Es la que ven los jugadores.
- **Build interna** = **X.Y.Z**: X = cambios grandes · Y = cambios estéticos o de configuración ·
  Z = cambios menores (D-17). Va en el `.toc` (`X-Build`) y en `/il creditos`.

Desde 12.1.0.1 cada entrada lleva las dos: `[pública] · build interna`. Las anteriores solo
tienen la build interna.

## [12.1.0.6] · build 14.6.1 — 2026-10-06

**Z**: publicación ordenada.
- El `.toc` dice la misma versión que la etiqueta de publicación (12.1.0.6), para que el juego,
  CurseForge y GitHub coincidan.
- El archivo publicado se llama siempre **`ItemLens.zip`**, así el enlace de descarga directa no cambia:
  `https://github.com/iAthVo/ItemLens/releases/latest/download/ItemLens.zip`

### Versiones publicadas antes
- **12.1.0.1** (06/10): primera publicación en GitHub y CurseForge, con todo lo de la build 14.6.0.
- **12.1.0.5** (06/10): misma versión del addon, publicada de nuevo con el logo corregido
  (sin la "W" de Blizzard). El logo está en `media/` y no viaja dentro del addon.
  En ambas el `.toc` todavía decía 12.1.0.1.

## [12.1.0.1] · build 14.6.0 — 2026-10-06

**Y**: las misiones muestran su evento, el requisito y las zonas (D-54). 192 pruebas.
**Pendiente de probar dentro del juego.**

### Cambiado
- En "Cómo se obtiene", una misión ahora se ve así (ejemplo: colores de compañera ohuna):
  ```
  Misión semanal: Grand Hunts
  Requisito: Renombre 5 con Centauros Maruuk
  Zonas: Costas del Despertar · Llanuras de Ohn'ahra · Extensión Azur · Thaldraszus
  ```
  - El **evento** (Feria de la Luna Negra, Festival de Fuego del Solsticio de Verano, Grandes
    Cacerías…) reemplaza al "Misión #… (título no disponible)" cuando ATT lo conoce.
  - **Zonas** solo en eventos que ocurren en pocas zonas (5 o menos), como los que rotan.
  - Los nombres de evento salen en inglés cuando ATT no tiene la traducción al español.
- Todos los orígenes llevan dos puntos tras la etiqueta: "Botín de jefe: Onyxia".

## [12.1.0.1] · build 14.5.0 — 2026-10-06

**Y**: misiones mejor explicadas y aviso cuando no se sabe de dónde sale un objeto (D-53). 190 pruebas.
**Pendiente de probar dentro del juego.**

### Corregido
- Las misiones cuyo título no manda el servidor (semanales fuera de rotación, misiones ocultas)
  decían **"(no disponible en el juego)"**, aunque sí existen; por ejemplo, los colores de
  compañera ohuna. Ahora dicen **"(título no disponible)"**.

### Agregado
- Orígenes de misión con **"Misión semanal" / "Misión diaria"** y la **reputación que piden**:
  "Requiere: Centauros Maruuk — Renombre 5". Datos regenerados desde ATT 5.3.15: 1,251
  orígenes semanales y 792 diarios.
- La reputación de facciones nuevas se muestra como **Renombre N** (antes salía "Neutral").
- Objetos sin origen conocido: el encabezado dice **"Se obtiene: Desconocido"** y la sección
  **CÓMO SE OBTIENE** explica que ItemLens lo aprenderá al verlo en un vendedor o botín.
  Son 737 objetos que ATT no registra (bebidas, comida, objetos de misiones antiguas…).

## [12.1.0.1] · build 14.4.3 — 2026-10-06

**Z**: sin leyendas de Mayús+clic. Se quitó el texto del pie de la ventana ("Mayús+clic en un
objeto: lo busca aquí…") y la línea del tooltip ("Mayús+clic: abrir en ItemLens"). La función
sigue igual y se activa o desactiva con `/il clic`.

## [12.1.0.1] · build 14.4.2 — 2026-10-06

**Z**: orden de pestañas: Mochila · Banco » · Catálogo · **Colecciones** · **Favoritos**
(antes Favoritos iba antes de Colecciones).

## [12.1.0.1] · build 14.4.1 — 2026-10-06

**Z**: la pestaña **Diccionario** ahora se llama **Catálogo** (*Catalog* en inglés) (D-52).

## [12.1.0.1] · build 14.4.0 — 2026-10-05

**Y** (estético): grupos plegables en Mochila, Diccionario y Colecciones (D-51). 187 pruebas.
**Pendiente de probar dentro del juego.**

### Cambiado
- **Mochila:** un grupo por bolsa (Mochila, cada bolsa equipada con su nombre e ícono, bolsa
  de componentes) y al final **Monedas**. Empiezan abiertos.
- **Diccionario:** agrupado **por abecedario** (A, B, C… N, Ñ, O… Z y `#` para lo que no empieza
  con letra; los acentos van con su letra). Empiezan **plegados**.
- **Colecciones:** sus grupos (dragón, clase, expansión, arma…) se pliegan; empiezan **plegados**.
- Clic en un encabezado (**+** / **−**) lo pliega o despliega; se recuerda por pestaña
  (`options.folded`). Al buscar, los grupos se abren para mostrar las coincidencias.
- Favoritos sigue como lista simple.

## [12.1.0.1] · build 14.3.0 — 2026-10-05

**Y** (estético): pestañas del banco plegables (D-50). 179 pruebas.
**Pendiente de probar dentro del juego.**

### Agregado
- Cada pestaña del panel de banco (Personaje y Banda guerrera) se pliega o despliega con un
  clic en su encabezado (**+** / **−**). Plegada muestra solo su nombre y cuántos objetos tiene.
- Se recuerda qué pestañas dejaste plegadas, por separado en cada banco
  (`options.bankFolded`).
- Al buscar, las pestañas plegadas muestran igual sus coincidencias.

## [12.1.0.1] · build 14.2.0 — 2026-10-05

**Y** (estético): el panel de banco separa los objetos por pestaña del banco (D-49). 177 pruebas.
**Pendiente de probar dentro del juego.**

### Cambiado
- **Banco del personaje y banda guerrera, por pestaña:** cada pestaña es un encabezado con su
  nombre e ícono del juego (o "Pestaña N" si no tiene nombre) y cuántos objetos tiene; debajo,
  sus objetos. La búsqueda muestra solo las pestañas con coincidencias.
- La copia del banco guarda cada pestaña por separado, además del total (que sigue usando
  "Lo tienen"). Syndicator, si se usa como respaldo, también se muestra por pestaña.
- Las copias guardadas antes de este cambio se ven como lista única hasta abrir el banco una vez.

## [12.1.0.1] · build 14.1.0 — 2026-10-05

**Y** (configuración): primera versión pública y nuevo esquema de dos versiones (D-48).
Permiso de AllTheThings confirmado (D-47). 168 pruebas.

### Cambiado
- `## Version` del `.toc` = versión pública `12.1.0.1`; nuevo `## X-Build: 14.1.0` con la build
  interna. La ventana y CurseForge muestran la pública; `/il creditos` muestra las dos.
- README: insignia con la versión pública.

## [14.0.1] — 2026-10-05

**Z**: reorganización interna del código (D-46). Sin cambios de funciones. 168 pruebas.
**Pendiente de probar dentro del juego.**

### Cambiado
- Archivos organizados en carpetas: `Locales/` (`esMX.lua`, `enUS.lua`), `Core/` (`Util`, `Init`,
  `Commands`), `Modules/` (`Data`, `Integrations`, `Learn`, `Inventory`, `Collections`,
  `Tooltip`) y `UI/`. Mochila, banco y personajes quedan juntos en `Modules/Inventory.lua`.
- Comentarios en inglés y español, sin historial de versiones dentro del código.
- Código repetido reemplazado por utilidades compartidas: lectura de bolsas y monedas, registro
  de eventos, enlaces al chat, nombres cortos de personaje, colores y tooltips simples.
- El panel de detalle dibuja cada tipo de fila con su propia función; la ventana principal se
  arma por partes (barra de título, pestañas, filtros, lista, detalle).
- La pestaña Mochila y el panel de banco calculan cada nombre una sola vez al ordenar.
- Los personajes de otro reino se muestran como "Nombre-Reino" también en las misiones de clase.

### Quitado
- Funciones y textos que ya no usaba nada (restos de los precios de subasta y versiones viejas).

## [14.0.0] — 2026-10-05

**X**: dos funciones grandes, aprendizaje e interfaz en inglés (D-44, D-45), más datos de ATT
5.3.15. Se usa 14 para no repetir los números 12 y 13 que se revirtieron. 168 pruebas.
**Pendiente de probar dentro del juego.**

### Agregado
- **Aprende mientras juegas** (`Learn.lua`, activado por defecto). Guarda en
  `ItemLensDB.learned`, solo en tu PC:
  - **Vendedores**: al abrir uno, qué vende, precio en oro o costo en monedas u objetos, NPC,
    zona y coordenadas. Los canjes nuevos aparecen en "Dónde canjearlo" y en el Diccionario.
  - **Botín**: de qué NPC o cofre cayó, dónde y cuántas veces (el mismo cadáver no cuenta doble).
  - **Misiones**: quién la da, dónde, y sus recompensas fijas y a elegir.
  - **Fabricación**: al abrir una profesión, cada receta con su resultado y materiales
    obligatorios (en bloques, sin trabar el juego).
  - Se suma a los datos importados sin duplicar. Lo aprendido lleva un **librito** y su tooltip
    lo explica. El botín dice "visto N veces".
  - `/il aprender` (`/il learn`) lo activa o desactiva y muestra cuánto lleva;
    `/il aprender borrar` (`/il learn clear`) borra todo.
  - Los "valores secretos" de Midnight (instancias, combate) se ignoran sin errores.
- **Interfaz en inglés** para cualquier cliente que no sea esMX o esES. Los comandos aceptan
  las dos formas (`/il characters`, `/il click`, `/il learn`, `/il credits`).
- Nombres de objetos del mundo y encabezados de ATT en **inglés y español** (`objects` /
  `objectsES`, `headers` / `headersES`).

### Cambiado
- `Data/iLs_Import.lua` regenerado con **ATT 5.3.15**: 1,299 tokens y 29,909 canjes (antes
  1,294 y 29,857). Su encabezado ya no dice "uso personal": cita la licencia MIT y el crédito.
- El extractor (`tools/att_extract.lua`) guarda el inglés como base y el español aparte.
- Syndicator y TomTom se confirman como complementos opcionales (sin cambios).

## [11.0.1] — 2026-10-05

**Z**: preparación para publicar (D-43). Sin cambios de funciones.

### Agregado
- **Licencia MIT** propia: `LICENSE`, © 2026 TavoD_Gus_KrG, con aviso de los datos de terceros.
- **Créditos**: `CREDITS.md` (bilingüe) y `licenses/AllTheThings-MIT.txt`, el texto completo de
  la licencia de AllTheThings, como lo pide su MIT.
- **`README.md`** bilingüe (inglés y español) para GitHub, CurseForge y Wago.
- Comando **`/il creditos`** (también `/il credits`): créditos y licencias dentro del juego.
- `.pkgmeta`: deja fuera del paquete público `tools/`, `DISENO.md` y `NOTAS_INTERNAS.md`.

### Cambiado
- `.toc`: autor **TavoD_Gus_KrG**, `X-License: MIT`, `X-Credits` y descripción en inglés, más
  `Notes-esMX` y `Notes-esES`.

## Versiones 12.0.0 – 13.0.0 — revertidas (2026-10-05)

Se probaron precios con TradeSkillMaster (12.0.0, D-40), el tooltip con precio mínimo antes que TSM
(12.1.0, D-41) y un lector de precios propio `ItemLens_Prices` (13.0.0). A pedido del usuario se
**regresó a 11.0.0**: sin precios de subasta y sin TSM, hasta terminar de definir la lógica de
precios propios (D-42, en definición). Se borraron `Auction.lua` y la carpeta `ItemLens_Prices`.

## [11.0.0] — 2026-10-05

**X**: se quita una función completa (D-39, revoca D-23). 145 pruebas.

### Quitado
- **Precios de subasta**: `Auction.lua` (escaneo completo de la casa de subastas), la fila
  "Subasta" del detalle, "Valor en subasta" en el pie de la Mochila y del panel del banco, y
  los textos `AH_*` / `AGE_*`. No se reemplaza con TSM.
- `ItemLensDB.ah`: los precios guardados se borran al cargar el addon.

### Cambiado
- El 4.º renglón del encabezado del detalle solo aparece en misiones (Lugar) y artefactos
  (Conjunto); en objetos y monedas el encabezado es más bajo.
- El pie del panel del banco es más bajo (solo queda la fuente y fecha de la copia).
- El precio en oro de los vendedores ("Cómo se obtiene") se sigue mostrando, ahora con
  `GetMoneyString` directo.

## [10.1.1] — 2026-10-04

**Z**: arreglo de un error visto en BugSack dentro del juego. 153 pruebas.

### Corregido
- `Integrations.lua:21` — *"attempt to compare local 'name' (a secret string value, while
  execution tainted by 'ItemLens')"* (5 veces). En Midnight el nombre de un NPC leído del
  tooltip puede llegar como **valor secreto**. Ahora se revisa con `IL.IsSecret` (nuevo, en
  `Core.lua`) antes de compararlo: si es secreto, se muestra "NPC #id" y se reintenta después.
- Misma protección al leer las líneas "Uso:" del tooltip de los objetos.

### Nota
- En la misma revisión se aplicó un parche local a **GW2_UI** (otro addon); está documentado
  en `X:\Games\Blizzard\World Of WarCraft\_parches\LEEME.md`, no en ItemLens.

## [10.1.0] — 2026-10-04

**Y**: el Diccionario busca en mucho más (D-38). 151 pruebas.

### Cambiado
- El **Diccionario** ya no es solo de tokens: incluye **8,806 objetos** con algo que decir
  (tokens y monedas, objetos con usos —invocar raros, logros, eventos, misiones—,
  materiales de profesión y coleccionables). Ejemplo: **Caracola ominosa** ya aparece.
- **Búsqueda por número de ID**. Si el ID no está en la lista, se puede abrir igual
  (cualquier objeto del juego).

### Agregado
- **Caché de nombres guardada** (`ItemLensDB.names`, por idioma del cliente): los nombres
  se cargan en segundo plano (100 objetos cada 0.2 s, sin trabar el juego) y se guardan;
  después de la primera vez la búsqueda es instantánea. Pie del Diccionario: "Cargando
  nombres… X de Y" mientras tanto.

### Límite
- Los demás objetos del juego (~140,000 con origen) no se listan en el Diccionario, pero se
  abren con Mayús+clic, desde Mochila/Banco o buscando su ID.

## [10.0.0] — 2026-10-04

**X**: función grande con datos nuevos y un tipo de entrada nuevo (apariencias) (D-37).
Verificada fuera del juego (143 pruebas); **pendiente de probar dentro del juego**.

### Agregado
- **Conjunto "Armas artefacto"** en Colecciones: las **873 apariencias** de las **37 armas
  artefacto** de Legion, incluidas las base, agrupadas por **"Clase · Arma"** con progreso.
  La clase se pone sola en la de tu personaje.
  - Nombre: "<arma> · <conjunto> N". Conjuntos (de ATT, en español): Apariencia base,
    Campaña de orden de clase, Equilibrio de poder, Apariencia de desafío, Apariencia
    oculta, Recompensas de prestigio.
  - ✓/✗ con la **colección de transfiguración** del juego (`PlayerHasTransmogItemModifiedAppearance`).
  - **Detalle**: clase, arma, conjunto y **CÓMO SE CONSIGUE**: misión, objeto del mundo,
    logro, NPC, profesión (arqueología) y **reputación requerida** ("Corte de Farondis —
    Reverenciado"), con zona, coordenadas y 📍. Si ATT no trae un origen propio, lo explica
    el conjunto.
- **"SE NECESITA PARA"**, siempre visible en el detalle de los objetos: **logros** que piden
  el objeto (**2,579** criterios de logro importados), **invocar raros o jefes**, **iniciar
  eventos**, objetos del mundo y misiones. Si no hay ninguno, lo dice.
- Nuevo tipo de origen **reputación** (`r<facción>,<valor>`).

### Cambiado
- Los usos se ordenan por utilidad (invocar raro/jefe/evento primero, logros después), así
  que el resumen "Sirve para" muestra primero lo más útil.

### Corregido
- **Nombres de logros**: siempre salían como "Logro #id" (desde v7.0.0). `GetAchievementName`
  se quedaba solo con el primer valor de `GetAchievementInfo` (el ID).

### Datos
- `IL.DB.artifacts` (873 apariencias) y usos de logros. Archivo: 5.7 MB.

## [9.0.0] — 2026-10-04

**X**: función grande con datos nuevos y un tipo de entrada nuevo (misiones) (D-36).
Verificada fuera del juego (130 pruebas); **pendiente de probar dentro del juego**.

### Agregado
- **Conjunto "Misiones de clase"** en Colecciones: **1,758 misiones de clase vigentes** de
  ATT (sin las retiradas), para las **13 clases**, incluidas las que no tenían desbloqueos:
  Guerrero 112 · Paladín 140 · Cazador 156 · Pícaro 170 · Sacerdote 165 · CM 106 ·
  Chamán 123 · Mago 162 · Brujo 145 · Monje 109 · Druida 141 · **Cazador de demonios 169** ·
  **Evocador 60**. 518 dan recompensa; 1,458 tienen zona.
  - Agrupadas por **"Clase · Expansión"** (de la más nueva a la más vieja), con progreso.
  - Al elegir el conjunto, **la clase se pone sola en la de tu personaje**.
  - Filtros: expansión, clase, **Todas / Faltan / Hechas** y casilla **"Con recompensa"**.
  - En la lista, debajo del título: el lugar ("Zona · Costas del Despertar").
- **Detalle de una misión**: clase (con su color), ✓ Hecha / ✗ Pendiente / Otra clase,
  recompensas (clic → detalle del objeto), lugar con coordenadas y 📍, y **"Tus personajes de
  esta clase"**: a quién **le falta** y quién **ya la hizo**.
- La copia de cada personaje guarda sus **misiones de clase hechas** (`chars[…].classQuests`);
  se actualiza al entregar misiones.
- Las misiones también se pueden marcar como **favoritas**.

### Datos
- `IL.DB.classQuests[questID] = "clase,expATT,mapID,x,y;recompensas"` (ATT 5.3.14).
  Archivo: 5.4 MB.

## [8.2.1] — 2026-10-04

**Z**: ajuste menor del filtro de clase. 117 pruebas.

### Cambiado
- El menú **Clase** muestra **las 13 clases siempre**, con cuántos objetos tiene cada una:
  "Brujo (35)". Las que no tienen objetos en el conjunto salen **atenuadas y no se pueden
  elegir**: Guerrero, Sacerdote, Cazador de demonios y Evocador (0).

### Por qué esas clases tienen 0
- ATT no registra desbloqueos de clase **con objeto** para ellas (sus personalizaciones se
  desbloquean por misión o en la barbería). Detalle en `docs/NOTAS_INTERNAS.md`.

## [8.2.0] — 2026-10-04

**Y**: presentación (tipo de lugar), sin datos nuevos (D-35). 115 pruebas.

### Agregado
- **Tipo de lugar** de cada objeto:
  - **Colecciones**: debajo del nombre, el lugar principal: "Banda · Guarida de Onyxia",
    "Calabozo · …", "Zona · Costas del Despertar", "Instancia · …", "JcJ · Temporada 2"…
  - **Detalle (Cómo se obtiene)**: el lugar con su tipo: "Banda: Guarida de Onyxia (Normal)",
    "Zona: Nagrand 45.2, 60.1"; el botín de instancia sin jefe dice "Banda" o "Calabozo".
- Banda/calabozo se decide con el **Diario de encuentros** del juego (`EJ_GetInstanceInfo`,
  valor `isRaid`) o, si no responde, con el tipo de grupo de la dificultad. Zona/instancia
  con el tipo de mapa (`C_Map.GetMapInfo().mapType`). Nombres en el idioma del juego.

## [8.1.0] — 2026-10-04

**Y**: filtro nuevo (configuración) en Colecciones (D-34). 106 pruebas.

### Agregado
- **Filtro por clase** en Colecciones ("Clase: Brujo ⌄"), con los nombres en el color de
  cada clase. Solo ofrece las clases que tiene el conjunto. Se recuerda y vuelve a
  "Todas" al cambiar de conjunto.
- En **Manuscritos** y **Otros desbloqueos** (que sirven para cualquier clase) el botón se ve
  atenuado y explica por qué al pasar el mouse.
- La barra de filtros pasa a 3 filas: conjunto · expansión + clase · estado.

## [8.0.0] — 2026-10-04

**X**: función grande con datos nuevos (D-33). Objetivo del usuario: tener todo en un solo
addon. Verificada fuera del juego (103 pruebas); **pendiente de probar dentro del juego**.

### Agregado
- **Pestaña Colecciones** con tres conjuntos completos, agrupados y con progreso por grupo:
  | Conjunto | Objetos | Agrupado por | Cómo se sabe si está aprendido |
  |---|---|---|---|
  | Manuscritos de dracoequitación | 428 | dragón (7) + Otros | misión oculta |
  | Desbloqueos de clase (tomos, glifos, formas) | 118 | clase | misión oculta o hechizo conocido |
  | Otros desbloqueos (almas, profesiones, eventos) | 363 | expansión | misión oculta o hechizo conocido |
- **Filtros** en Colecciones: conjunto, **expansión** (solo las del conjunto) y estado
  **Todos / Faltan / Tengo**. La búsqueda también aplica. Los filtros se recuerdan.
  Pie: "Aprendidos: X de Y" (el progreso cuenta todo, sin el filtro de estado).
- **✓ Aprendido / ✗ Te falta / Otra clase** en el detalle (junto a la expansión) y como
  ícono sobre el ícono del objeto en cualquier lista. Además de los conjuntos, funciona con
  **monturas, mascotas, juguetes y apariencias** (funciones nativas del juego).
- Se actualiza solo al completar misiones u obtener monturas, mascotas, juguetes o apariencias.

### Corregido
- El extractor no reconocía los manuscritos (`MountMod` de ATT) como objetos: ahora también
  tienen **"Cómo se obtiene"**.

### Datos
- `IL.DB.collections` (mm / cq / cs) importado de ATT 5.3.14. No se copió nada de
  Manuscripts Journal (no tiene licencia; sus datos son de su autor).

## [7.2.0] — 2026-10-03

**Y**: mejora de datos y de presentación pedida tras la prueba en el juego (D-32).
Verificada fuera del juego (85 pruebas).

### Agregado
- **Lugar de las misiones**: "Recompensa de misión: <título> · **Nagrand** 45.2, 60.1 📍".
  De 30,913 misiones como origen, **94 %** tiene zona y **89 %** coordenadas. Se toma
  de las coordenadas de la misión en ATT o, si no tiene, de la zona donde ATT la ubica.
  Los usos "Se entrega en la misión…" también ganaron zona (3,085 de 3,244).

### Cambiado
- Objetos o misiones que el servidor confirma que **no existen** (retirados del juego)
  ahora dicen **"Objeto #123 (no disponible en el juego)"** / **"Misión #123 (no disponible
  en el juego)"** en lugar de quedarse solo con el número. Los que simplemente todavía no
  cargan siguen mostrando el número y se actualizan solos al llegar.

## [7.1.1] — 2026-10-02

**Z**: arreglo encontrado en la **primera prueba dentro del juego**.

### Corregido
- **Personaje duplicado sin reino** ("Krhona-"): al entrar al juego el reino podía llegar
  vacío y se guardaba una copia aparte, así que en "Lo tienen" sus monedas se contaban dos
  veces. Ahora el nombre del personaje se arma con `IL.PlayerKey()`, que usa
  `GetNormalizedRealmName` como respaldo y, si todavía no hay reino, **no guarda** y lo
  reintenta 5 s después. Las entradas malas de versiones anteriores se borran solas al
  cargar. Aplica al inventario y al banco.

### Verificado dentro del juego (datos guardados el 02/10, 17:55)
- Sin errores de ItemLens en BugSack.
- Favoritos, nombres de NPC (159), inventario de Krhona (bolsas, equipo y monedas), bancos
  de Thanamy y Krhona, banda guerrera (137) y **escaneo de subastas** (6,204 precios de
  Quel'Thalas, 1,441 materiales con precio) funcionando.

## [7.1.0] — 2026-10-02

**Y**: amplía y completa los datos de origen de la 7.0.0 y corrige dos errores (D-31).
Verificada fuera del juego (77 pruebas).

### Agregado
- **Todos los objetos que ATT ubica tienen ahora origen**: de 98,130 a **132,254** objetos
  (177,350 orígenes). **0** objetos de ATT quedan sin origen ni canje. Causas nuevas:
  | Causa | Objetos | Se muestra como |
  |---|---|---|
  | `providers`: objeto del mundo o NPC (bancos de peces, vetas…) | 1,566 | Tesoro / Botín de NPC |
  | `providers`: otro objeto (bolsa, caja) | 1,530 | **Sale de** <objeto> (clic → su detalle) |
  | `crs`: criaturas que lo sueltan | 7,108 | Botín de NPC |
  | Profesión requerida (pesca, minería…) | 11,303 | Fabricación / profesión |
  | Dentro de una instancia, sin jefe | 3,499 | **Botín de instancia** <mazmorra (dificultad)> |
  | Solo ubicado en una zona | 4,507 | **En la zona** <zona> |
  | Categoría general de ATT | 22,294 | Botín del mundo, JcJ · <temporada>, Evento · <nombre>, Tienda del juego, Puesto comercial, Personaje, Profundidades… |
- Nombres de encabezados de ATT para los subtítulos: 107 de 151, en español cuando ATT los
  tiene (mx > es > inglés), o resueltos con las constantes del juego.
- Ejemplo: **Pepita de draconio** → bancos de peces + NPC (antes no tenía origen).

### Corregido
- Se excluye la categoría **NeverImplemented** de ATT (objetos que nunca llegaron al juego);
  antes podía generar orígenes falsos.
- Nombres de objetos del mundo: el bloque "base" (inglés) incluía por error los bloques de
  alemán, francés, italiano, portugués, ruso y coreano; un objeto sin nombre en español podía
  salir en otro idioma.

### Herramientas
- `ITEMLENS_TRACE=<itemID>`: muestra la ruta de un objeto en el árbol de ATT.
- `tools/sin_origen.txt`: lista de objetos de ATT sin origen (hoy vacía).

### Límite
- Objetos que ATT **no ubica** en su árbol (por ejemplo, *Gran pepita de oro*, que solo
  aparece como material de recetas) siguen sin origen: no hay dato que importar.

## [7.0.0] — 2026-10-02

**X**: función grande con datos nuevos (D-30). Verificada fuera del juego
(`verify_import` + 67 pruebas); **pendiente de probar dentro del juego**.

### Agregado
- **Cómo se obtiene cualquier objeto**: 132,163 orígenes para **98,130 objetos**, importados
  de ATT (todas las expansiones):
  | Origen | Cantidad | Qué muestra |
  |---|---|---|
  | Botín de jefe | 37,990 | jefe · mazmorra/banda (dificultad) |
  | Botín de raro / NPC | 40,439 | NPC · zona · coordenadas · 📍 |
  | Recompensa de misión | 30,946 | título de la misión |
  | Fabricación | 14,211 | profesión |
  | Tesoro / objeto del mundo | 5,030 | nombre del objeto (en español) · zona · coordenadas · 📍 |
  | Logro | 2,143 | nombre del logro |
  | Vendedor con oro | 1,404 | NPC · precio · zona · coordenadas · 📍 |
- **Dónde se ve**: (1) encabezado del detalle, fila **"Se obtiene"** con el origen principal
  y "(+N)"; (2) sección **CÓMO SE OBTIENE** con todos los orígenes (máx. 12 por objeto);
  (3) **tooltip de favoritos**, línea "Se obtiene: …"; (4) línea secundaria de la lista.
- Los nombres de jefes, mazmorras, dificultades, logros y profesiones los da el juego en tu
  idioma. Los objetos del mundo usan los nombres en español de ATT (3,035 de 3,037).

### Rendimiento
- Los orígenes se guardan como **un texto compacto por objeto** y se interpretan solo al
  abrir ese objeto. Comparado con tablas normales: memoria **30.5 → 11.6 MB**, carga
  **0.65 → 0.33 s**, archivo **5.0 → 4.2 MB**.

## [6.2.0] — 2026-10-02

**Y**: usa el probador nativo del juego, sin datos nuevos (D-29). Verificada fuera del
juego (59 pruebas).

### Agregado
- **Probador de Blizzard** (`DressUpLink`, la misma ventana que usa el juego) para ropa,
  armas, monturas y mascotas:
  - **Ctrl+clic**, como en WoW, sobre cualquier objeto dentro de ItemLens: lista, panel de
    banco, recompensas y objetos fabricables del detalle, e ícono grande del detalle.
  - **Botón "Probador"** en el encabezado del detalle, a la izquierda de "Favorito". Solo
    aparece si el objeto se puede probar.
- El ícono grande del detalle también acepta **Mayús+clic** para enlazar en el chat.

## [6.1.0] — 2026-10-02

**Y** porque es un cambio estético (D-28).

### Cambiado
- **Cada expansión tiene su propio color** en las etiquetas (lista, detalle y tooltip).
  Antes, las anteriores a DF iban en gris:

| Exp. | Etiqueta | Color | Tema |
|---|---|---|---|
| Clásico | CL | `#D6CCB4` | pergamino |
| The Burning Crusade | TBC | `#B4D36A` | verde de Terrallende |
| Wrath of the Lich King | WLK | `#8FD6E8` | hielo |
| Cataclysm | CTM | `#E8775C` | fuego |
| Mists of Pandaria | MOP | `#E3CF63` | oro pandaren |
| Warlords of Draenor | WOD | `#C7967C` | óxido / hierro |
| Legion | LEG | `#63D27E` | vil |
| Battle for Azeroth | BFA | `#6E9CEB` | mar |
| Shadowlands | SL | `#B9C7D6` | plata espectral |
| Dragonflight | DF | `#7CC7B4` | (sin cambio) |
| The War Within | TWW | `#E0A659` | (sin cambio) |
| Midnight | MN | `#B4A6F0` | (sin cambio) |

- Prueba nueva: cada color es distinto y suficientemente claro para leerse sobre el panel.

## [6.0.0] — 2026-10-02

**X**: actualización mayor de datos, porque ahora están **todas las expansiones** (D-27).
Verificada fuera del juego (`verify_import` + 54 pruebas).

### Cambiado
- `Data/iLs_Import.lua` regenerado con **todas las expansiones**: Clásico, TBC, WotLK,
  Cata, MoP, WoD, Legion, BfA, SL, DF, TWW y Midnight. También entra el contenido que ATT
  no asigna a una expansión (por ejemplo, vendedores de Paseo en el tiempo en Tanaris y
  campos de batalla).

| | 5.x (Legion → MN) | **6.0.0 (todas)** |
|---|---|---|
| Vendedores | 637 | **891** |
| Tokens y monedas | 516 | **1,291** |
| Canjes | 17,111 | **29,602** |
| Usos (invoca, tesoros, misiones) | 855 en 595 objetos | **3,707 en 1,771 objetos** |
| Objetos del mundo con nombre | 183 | **209** |
| Materiales | 2,424 → 23,303 fabricables | **3,536 → 34,065 fabricables** |
| Archivo | 682 KB | **1,118 KB** |

- Costo medido: ~0.13 s de carga al entrar al juego y ~6.6 MB de memoria.
- Las etiquetas de las expansiones anteriores a DF siguen en gris.

## [5.2.0] — 2026-10-02

**Y** porque es un cambio estético.

### Cambiado
- Se quitó el "(tú)" junto al personaje actual: en el tooltip y en "Lo tienen" del detalle
  aparece **solo el nombre del personaje**.

## [5.1.0] — 2026-10-02

**Y**: no agrega datos nuevos; muestra en el tooltip lo que ya se guardaba desde v5.0.0, y
agrega la opción `/il personajes` (D-26). Verificada fuera del juego (53 pruebas).

### Agregado
- **Personajes en el tooltip de cualquier objeto o moneda**, como Syndicator: cada personaje
  de la cuenta que lo tiene, con color de clase, "(tú)", desglose **bolsas · banco ·
  equipado**, cantidad, banco de **banda guerrera** y **Total** cuando hay más de uno.
  No hace falta que sea favorito. ItemLens lo muestra aunque Syndicator esté activo.
- `/il personajes` lo activa o desactiva (activado por defecto).

### Cambiado
- El tooltip ahora tiene dos bloques independientes: **personajes** (cualquier objeto) y
  **favoritos** (para qué sirve y dónde se canjea, solo favoritos). La línea
  **"Mayús+clic: abrir en ItemLens"** aparece una sola vez al final cuando hay cualquiera
  de los dos.

## [5.0.2] — 2026-10-02

**Z** porque es un cambio menor (nombre interno).

### Cambiado
- La tabla de datos precargados se llama ahora **`IL.DB`** (antes `IL.ATT`). Se actualizaron
  `Data.lua`, `Integrations.lua`, el extractor y las pruebas, y se regeneró
  `Data/iLs_Import.lua` con los mismos datos (ATT 5.3.14). Detalle en
  `docs/NOTAS_INTERNAS.md`.

## [5.0.1] — 2026-10-02

**Z** porque es un cambio menor (nombre de archivo).

### Cambiado
- `Data/ATT_Import.lua` se llama ahora **`Data/iLs_Import.lua`**. Mismo contenido; se
  actualizaron el `.toc`, las herramientas y `DISENO.md`. Detalle y motivo en
  `docs/NOTAS_INTERNAS.md`.

## [5.0.0] — 2026-10-02

**X** porque es una función grande con datos nuevos en SavedVariables (D-24). Verificada
fuera del juego (`luac` + 45 pruebas); **pendiente de probar dentro del juego**.

### Agregado
- **"Lo tienen" sin Syndicator.** Cada personaje que entra con ItemLens guarda en los datos
  de la cuenta (`ItemLensDB.chars`) sus **bolsas**, **equipo puesto** y **monedas** que se
  canjean. El **banco** ya se guardaba (v3.0.0). La copia se actualiza sola cuando cambian
  las bolsas, el equipo o las monedas, y otra vez al salir.
- En el detalle, **LO TIENEN** muestra cada personaje con su **color de clase**, "(tú)" para
  el actual, el desglose **bolsas · banco · equipado** y el total. Incluye también el banco
  de **banda guerrera**.

### Cambiado
- **Syndicator pasa a ser solo respaldo**: ItemLens usa primero sus propios datos y de
  Syndicator solo toma los personajes que todavía no conoce.

### Límites
- Cada personaje tiene que entrar **una vez** con ItemLens para aparecer; su banco, la
  primera vez que lo abra.
- Como todo en WoW, se escribe en disco con `/reload`, al salir del personaje o al cerrar
  el juego normalmente.

## [4.0.0] — 2026-10-01

**X** porque es una función grande con datos nuevos en SavedVariables (D-23). Verificada
fuera del juego (`luac` + 38 pruebas); **pendiente de probar dentro del juego**, sobre todo
el escaneo completo en el cliente 12.1.

### Agregado
- **Precios de la casa de subastas.** Al abrir la casa de subastas, ItemLens hace un
  **escaneo completo** (`C_AuctionHouse.ReplicateItems`, el juego lo permite cada 15 min)
  y guarda, **por reino**, el **precio más bajo por unidad** de cada objeto
  (`ItemLensDB.ah`). Las subastas de solo puja se ignoran. Se procesa en bloques de 4,000
  para no congelar el juego. En el chat avisa al empezar y al terminar.
- **Detalle**: cuarta fila **"Subasta"** en el encabezado: precio (oro, plata, cobre) y
  antigüedad de la copia ("visto hace 2 h"). Si no aplica dice "No se puede subastar"
  (ligado al recogerlo, de misión, ligado a la cuenta o moneda), "Sin subastas" o "Abre
  la casa de subastas para ver precios".
- **Totales**: "Valor en subasta" al pie de la lista **Mochila** y en el **panel de banco**
  (cantidad × precio más bajo de lo que tenga precio).

## [3.2.0] — 2026-10-01

**Y** porque son cambios de configuración (combinación de teclas) y estéticos (pie) (D-22).

### Cambiado
- **Mayús+clic** reemplaza a Alt+clic y funciona como en WoW, **según dónde esté el
  cursor**. Aplica a un objeto en la mochila, el banco, un enlace del chat, etc.:
  - **Cursor en el buscador de ItemLens** → escribe el nombre del objeto ahí y abre su detalle.
  - **Cursor en otro campo** (chat, subastas…) → WoW lo enlaza ahí; ItemLens no interviene.
  - **Sin cursor en ningún campo** → abre ItemLens en ese objeto (se puede desactivar con
    `/il clic`).
- La opción guardada `altClick` se migra sola a `bagClick`. El comando `/il alt` ahora es
  `/il clic`.

### Quitado
- La leyenda "Datos: AllTheThings …" del pie de la ventana.

## [3.1.0] — 2026-10-01

**Y** porque es un cambio estético (de ubicación).

### Cambiado
- El botón **"Banco »"** pasa de la barra de título a la fila de pestañas, justo después
  de **Mochila**: `Mochila · Banco » · Diccionario · Favoritos`. Cuando el panel está
  abierto se ve resaltado en latón ("Banco «"). El panel sigue saliendo por la derecha.

## [3.0.0] — 2026-10-01

**X** porque agrega un panel nuevo, seguimiento del banco y datos nuevos en
SavedVariables (D-21). Verificada fuera del juego (`luac` + 29 pruebas); **pendiente de
probar dentro del juego**.

### Agregado
- **Panel lateral de banco**, pegado a la derecha de la ventana, con selector
  **Personaje / Banda guerrera**. Se abre y se cierra con el botón **"Banco »"** de la
  barra de título y recuerda si lo dejaste abierto.
- Lista con ícono, nombre (color de calidad) y cantidad; primero lo que se canjea. Usa la
  misma búsqueda que la ventana. Clic → abre el detalle; Mayús+clic → enlaza en el chat.
- **Copia del banco**: al abrir el banco, ItemLens guarda lo que hay en el banco del
  personaje y en el de banda guerrera (`ItemLensDB.bank` / `.warband`). Así lo puedes
  consultar desde cualquier lugar. Pie del panel: cantidad de objetos y fecha de la copia.
- Si todavía no hay copia y Syndicator está instalado, se usan sus datos.
- Compatible con el banco por pestañas (11.2+) y con el banco antiguo.

### Corregido (antes de publicar)
- `Bank:Get("warband")` devolvía el banco del personaje cuando no había copia de banda
  guerrera (error de `a and b or c`). Lo encontró la prueba.

## [2.1.0] — 2026-10-01

**Y** porque es un cambio de configuración: el alcance de los datos (D-20). Para probar.

### Cambiado
- Datos ampliados a **Legion, Battle for Azeroth y Shadowlands** (además de DF, TWW y
  Midnight). Ahora son 637 vendedores, 516 tokens y monedas, 17,111 canjes, 855 usos en
  595 objetos, 183 objetos del mundo con nombre y 2,424 materiales con 23,303 objetos
  fabricables. Archivo: 682 KB.
- El filtro de materiales usa el itemID mínimo de la expansión más antigua pedida
  (Legion ≥ 121000, BfA ≥ 152000, SL ≥ 171000, DF ≥ 190000…).

### Corregido
- El extractor normaliza los `itemID.modID` de ATT (por ejemplo `183888.003`) a itemID
  entero. Antes generaban claves inválidas y el archivo no cargaba; apareció al incluir
  Shadowlands.

## [2.0.0] — 2026-10-01

**X** porque agrega una función grande con datos nuevos (D-19). Verificada fuera del juego
(`luac` + 24 pruebas en `tools/smoke_test.lua`); **pendiente de probar dentro del juego**.

### Agregado
- **"Sirve para"**: tercera línea del encabezado del detalle, sección **PARA QUÉ SIRVE** y
  una línea en el tooltip de favoritos. Combina 4 fuentes:
  1. **Usos**: "Invoca a <NPC> (raro)", "Se usa en: <objeto del mundo> (tesoro)",
     "Se entrega en la misión: …", "Inicia la misión: …".
  2. **Monedas y tokens**: "Moneda para comprar: 6 recetas · 3 juguetes · 1 montura…".
  3. **Materiales de profesión**: "Material de profesión (Cuero) · se usa en 50 recetas".
  4. **Cualquier otro objeto**: tipo · subtipo del cliente, más su línea "Uso:".
- Sección **SE USA EN** con lugar, coordenadas y botón para marcar en el mapa.
- Sección **SE USA PARA FABRICAR** con los objetos que se fabrican (máx. 40 a la vista);
  clic para abrir su detalle.
- En la lista, la línea secundaria muestra el uso o el material cuando aplica.

### Datos
- `Data/ATT_Import.lua` regenerado (ATT 5.3.14): + 431 usos en 290 objetos, + 1,590
  materiales con 17,699 objetos fabricables, + 114 nombres de objetos del mundo en español.

### Cambiado
- La descripción del cliente ("Uso:") ahora va dentro de PARA QUÉ SIRVE.

## [1.0.0] — 2026-09-30

Primera versión funcional. Programada y verificada fuera del juego (`luac` + `tools/smoke_test.lua`);
**pendiente de probar dentro del juego**.

### Agregado
- Ventana independiente con el estilo "Obsidiana y latón" (D-14) y fuentes nativas (D-15):
  pestañas **Mochila**, **Diccionario** y **Favoritos**, búsqueda por nombre, lista a la
  izquierda y detalle a la derecha. Se mueve, recuerda su posición y se cierra con Esc.
- Detalle: nombre con color de calidad, **expansión**, **se canjea** (N objetos con M
  vendedores) o **se obtiene con** (token y cantidad), vendedores colapsables con NPC, zona,
  coordenadas y botón para marcar en el mapa; descripción del objeto ("Uso:" y cita);
  "Lo tienen" con Syndicator.
- Navegación: clic en una recompensa abre su detalle; clic en un token abre el token;
  Mayús+clic enlaza en el chat.
- Tooltip de favoritos (D-13): expansión, canjes, vendedor más cercano (primero los de tu
  zona) o con qué token se obtiene.
- Alt+clic en un objeto de la mochila lo abre en ItemLens.
- Waypoints: TomTom si está instalado; si no, el pin nativo del mapa.
- Formas de abrir: `/il`, `/itemlens`, menú de addons del minimapa y una tecla configurable.
- Comandos: `/il tooltip`, `/il alt`, `/il reset`, `/il <link>`.
- `tools/smoke_test.lua`: 16 pruebas de lógica con la API de WoW simulada.

### Datos
- `Data/ATT_Import.lua` (AllTheThings 5.3.14, uso personal, D-12): 419 vendedores,
  364 tokens y monedas, 11,586 canjes de Dragonflight, TWW y Midnight.

### Pendiente
- Semilla curada de descripciones en español.
- Panel de opciones (hoy las opciones van por `/il`).
