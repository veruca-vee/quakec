# Building the bot build 🖤🩷

Verified working on 2026-11-26 with the repo's own `bin/fteqcc-cli-lin`.

## Toolchain check (baseline, unmodified source)
- `pip install fastcrc colorama` (needed by `bin/qc_hash_generator.py`)
- `python3 bin/qc_hash_generator.py -i tools/asset_conversion_table.csv -o source/server/hash_table.qc`
- Standard SSQC: `bin/fteqcc-cli-lin -O3 -Ono-compound_jumps -Wall -srcfile progs/ssqc.src`
  → `build/standard/progs.dat`, 0 warnings.
- Menu: `-srcfile progs/menu.src` → `menu.dat` **503170 bytes, byte-size identical to the stock web build's**.
- CSQC from current HEAD does not compile (unknown field `is_in_menu`) — the web
  build ships stock `csprogs.dat`; we keep it.

## FTE / web SSQC (qwprogs.dat)
The web build's `nzp/progs.pk3` contains `qwprogs.dat`, not `progs.dat`.
Reproduce it from `progs/ssqc.src` with the output renamed and the FTE format flag:
1. Copy `progs/ssqc.src` → `progs/ssqc_fte.src`, change line 1 to
   `#pragma progs_dat "../build/fte/qwprogs.dat"`
2. Compile: `bin/fteqcc-cli-lin -O3 -Ono-compound_jumps -Wall -Tfte -srcfile progs/ssqc_fte.src`
   (Do NOT swap `defs/standard.qc` for `defs/fte.qc` — that double-defines `mod`.)

## Bot merge (what bot/qc/*.qc does)
- `source/server/bot_export.qc` — read-only BOTSTATE printer (10 Hz, from StartFrame).
- `source/server/bot_brain.qc` — in-engine reflex bot inside PlayerPreThink:
  sets `v_angle`+`fixangle`, `movement`, and pulses `button0`. No cheats.
  Off switch: console `set bot_off 1`.
- Includelist: add both files to `progs/ssqc.src` (and the FTE copy) after `ai/zombie_core.qc`.
- Hooks: `main.qc` StartFrame calls `BotExport_Think();` after `framecount` increments
  (forward-declare it above StartFrame). `player/player_core.qc` PlayerPreThink calls
  `BotBrain_Think();` first (forward-declare above PlayerPreThink).
- Rebuild `progs.pk3` = stock `csprogs.dat` + `csprogs.lno` + `menu.dat` + new `qwprogs.dat`.

## Page side
Stock `index.html` routes engine print to `Module.print`. Wrap it before `begin()`
to capture `BOTSTATE` lines into `window.__botStates` (see SPEC.md).
