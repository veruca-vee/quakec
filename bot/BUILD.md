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
