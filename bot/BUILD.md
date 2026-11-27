# Building the bot build 🖤🩷

## The critical discovery (2026-11-26)
The live web build's `nzp/progs.pk3` was compiled from quakec commit
**7ab55bf (2026-09-01 18:09 -0700)** — the file timestamps inside the stock
pk3 match that commit to the minute. Building from current HEAD produces a
qwprogs.dat the web engine rejects on map load (silent disconnect back to
menu): the CSQC/SSQC pair must come from the SAME tree.

With the repo's own official build flags (from `tools/qc-compiler-gnu.sh`
at that commit), the unmodified tree reproduces all three stock file sizes
exactly: csprogs.dat 710614, menu.dat 503170, qwprogs.dat 844430.

## Exact recipe
```
git checkout 7ab55bf
python3 bin/qc_hash_generator.py -i tools/asset_conversion_table.csv -o source/server/hash_table.qc   # needs: pip install fastcrc colorama
bin/fteqcc-cli-lin -DFTE -Wall      -srcfile progs/csqc.src   # -> build/fte/csprogs.dat (+ .lno)
bin/fteqcc-cli-lin -O3 -DFTE -Wall  -srcfile progs/ssqc.src   # -> build/fte/qwprogs.dat (FTE branch via #ifdef FTE in ssqc.src)
bin/fteqcc-cli-lin -O3 -DFTE -Wall  -srcfile progs/menu.src   # -> build/fte/menu.dat
```
Do NOT use `-Tfte` with a hand-edited ssqc.src, and do NOT swap
defs/standard.qc for defs/fte.qc. The `-DFTE` define + the `#ifdef FTE`
pragma block at the top of ssqc.src is the whole trick.

## Bot merge (bot/qc/*.qc)
- `source/server/bot_export.qc` — read-only BOTSTATE printer (10 Hz, from StartFrame).
- `source/server/bot_brain.qc` — in-engine reflex bot inside PlayerPreThink:
  sets `v_angle`+`fixangle`, `movement`, pulses `button0`. No cheats.
  Off switch: console `set bot_off 1`.
- Includelist: add both files to `progs/ssqc.src` after `ai/zombie_core.qc`.
- Hooks: `main.qc` StartFrame calls `BotExport_Think();` after the
  `framecount` increment (forward-declare above StartFrame);
  `player/player_core.qc` PlayerPreThink calls `BotBrain_Think();` first
  (forward-declare above PlayerPreThink).
- Bot build qwprogs.dat = 846530 bytes (stock 844430 + 2100 of bot), 0 warnings.
- `progs.pk3` = csprogs.dat + csprogs.lno + menu.dat + qwprogs.dat, all four
  from this one tree/compile run.

## Page side
Stock `index.html` routes engine print to `Module.print`. Wrap it before
`begin()` to capture `BOTSTATE` lines into `window.__botStates`
(see SPEC.md). The live bot build runs from the nzp-team.github.io fork
via GitHub Pages.

## Native rig + current-code build (2026-11-26, later)
The web build is pinned to the Sep tree above, but upstream HEAD
(f922835, Nov 15) builds DIFFERENTLY: official script compiles SSQC
with `-O3 -Ono-compound_jumps` and NO `-DFTE` (Vril/standard target),
producing a single `build/standard/progs.dat`. That file drops
straight into the official nzportable Linux build as `nzp/progs.dat`.

A full local test rig now exists (see native/README-RIG.md in the
project workspace): the game runs headless on the build machine and
the bot writes `nzp/botstate.log` via fopen/fputs (bprint is not a
reliable channel on this engine; multi-ftos strcat collapses).

Measured on the native rig (Nacht der Untoten, solo, hands-off):
- v10 (verified-hitbox aimbot + tap reload): 500 -> 1010 pts,
  ~3 kills, 4 clean reloads, died round 1 at t=79 out of ammo.
- v11 (+ knife range + dry-gun kiting): 500 -> 1500 pts,
  REACHED ROUND 2, still alive at hp=100 when the run was cut.
Open issue: the Sep WEB build still never completes a reload with
this brain (native/Nov code reloads fine — 554 diff lines in
weapon_core.qc between the trees; exact Sep culprit not yet found).

## v12 routine + v13 Fred (2026-11-26, native-verified)

- Movement: `.movement` set in PlayerPreThink is stomped by the local
  client's usercmd on the listen-server rig. The brain now drives
  `velocity_x/y` directly (190 = walk speed); arrival zeroes it.
- Routine layer complete and measured (Nacht, native): window duty
  rounds 1-2 with Vee's recipe (R1: 4 shots + knife, R2: 8 + knife),
  repair between rounds (mode 3), Kar98k wall-buy on the last mag
  (mode 4: find the `buy_weapon` trigger with weapon==W_KAR, stand at
  its chalk + 18, face it, hold use), door after round 2 (mode 5:
  `door_nzp_cost`, bbox-center targeting, push in with use held).
  Best runs: 2,140 pts / round 3 / alive at cutoff (v12j, first full
  routine), 2,240 pts / round 3 / alive (Fred build), door purchase
  confirmed on the HUD (-1000 popup).
- Reload watchdog (Sep web tree only, bot_export_sep_web.qc): if a
  reload's anim chain drops the ammo grant, W_Give_Ammo delivers it
  0.15s after reload_delay expires. Shipped in web v12; not yet
  exercised on the web surface (cloud browser starves the game).
- Fred the Brain zombies (v13): Fred_the_Brain_Rigged.glb baked in
  Blender (decimate -> weld -> 211 frames matching zfull.mdl's frame
  table; walk/idle are his real clips, death = tip-over, window
  attack = lean). Engine hard cap found by bisection: alias models
  over ~2048 verts are rejected ("Invalid or truncated alias
  model"); final fred.mdl = 1,718 verts / 899 tris, 256x256
  palette-quantized skin. QC: zombie setmodel zfull/zb% -> fred.mdl
  (+ precaches). Hitbox models untouched, so bot performance is
  unchanged. Web progs.pk3 carries models/ai/fred.mdl inside.
Web v13 deployed 2026-11-26: quakec fork commit e577e14 (sources,
md5-verified), webhost commit 6a76146 (progs.pk3 1,514,117 bytes,
md5-verified; live Pages serves the new size). Cloud-browser smoke
test: map loads 3/3, no fred.mdl errors, Freds render (dark, spiky
silhouettes in the death cam -- the palette-quantized skin reads
dark on the web renderer). Bot moves/fires but scores 0 kills in
the harness: the cloud browser starves the engine to a few
ticks/sec, the same limitation every web version has shown; the
identical brain scores 2,240 / round 3 on the native rig at full
framerate. Real web verdict waits on a full-speed browser (Vee's
LibreWolf on Bluefin).

## v14 DEBUG build (2026-11-26, temporary -- NOT an honest build)
At Vee's direction, a configuration/debug build so bot tuning can
proceed past the current blockers. Assists are gated by the cvar
bot_noassist: they are ON unless `set bot_noassist 1`. Honest runs
use the v13 lineage or v14 with bot_noassist set.
- Auto-aim snap (weapons/weapon_core.qc FireTrace; full edited file
  staged as bot/qc/weapon_core_v14.qc): when the shooter is the
  bot-driven player, the shot direction is recomputed exactly onto
  self.enemy's head point (origin + forward*10 + '0 0 35') and the
  spread jitter is zeroed. The brain publishes its current target
  on self.enemy every think (bot_brain.qc) and clears it when
  bot_off. Native proof: game-over screen 8 kills / 8 headshots.
- Bright map (bot_export.qc, both trees): for the first 6 seconds
  of a game, lightstyle(0..63) are set to "z" (steady overbright).
  QC-side brightening has a ceiling -- Nacht's darkness is mostly
  lightmap falloff -- but flicker is gone and lit areas double.
- Hit-point shapes: zombies use models/ai/dbgz.mdl (procedural
  block figure: red head, yellow arms, green torso, cyan legs,
  211 frames, generated by fred/gen_dbg.py) and the hitbox
  entities use dbgzh.mdl (red cube) / dbgza.mdl (yellow box), so
  the visible geometry IS the hittable geometry. Fred returns when
  the honest build resumes. Model swaps: zombie_core.qc setmodels
  + main.qc precaches (Sep tree also has hitbox setmodels in
  main.qc's LinkZombiesHitbox -- swapped there too).
- Web v14: qwprogs 852,942 (Sep tree, 0 errors, other dats
  stock-sized); pk3 503,740 bytes (no fred.mdl inside this time).
