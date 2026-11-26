# NZ:P Bot — Spec v1 🖤🩷

Goal: an AI agent that actually plays Nazi Zombies: Portable (WebGL/FTE build)
on Nacht der Untoten, solo, no cheats (no god/notarget/noclip, no point/health edits).

## Architecture (two layers, from the 2026-11-25 feasibility report)

1. **State export (QuakeC, in-engine):** a small SSQC addition prints one line
   every 0.1s to the engine console:
   `BOTSTATE t=<time> round=<n> alive=<n> hp=<n> pts=<n> mag=<n> reserve=<n> weapon=<name> p=<x,y,z> a=<pitch,yaw> z=<x,y,z,hp,dist>;...`
   In the web build, engine print goes to `Module.print` → `console.log`
   (verified in the stock `index.html`), so a page-side script can capture it
   without screenshots.
2. **Reflex brain (JS, in-page, ~10 Hz from state, movement at frame rate):**
   pure decision functions in `src/brain.js`, driven by parsed BOTSTATE.
   The LLM is NOT in this loop. Strategy calls (buy/open) are separate,
   slow, and rule-based in v1.

## Checkable statements

- S1: `parseBotState(line)` returns a structured object for a well-formed
  BOTSTATE line, and `null` for any other console line.
- S2: Zombie entries parse to `{x,y,z,hp,dist}` numbers, sorted nearest-first
  by the brain, regardless of order in the line.
- S3: Aim math: given player pos/angles and a target pos, `aimAngles()`
  returns yaw/pitch that point at the target's head (target z + head offset),
  in degrees, normalized yaw to [-180,180].
- S4: Fire discipline: brain fires only when (a) a target exists within
  range, (b) aim error < threshold, (c) mag > 0. It requests reload when
  mag == 0, or when mag <= 25% and nearest zombie dist > safeReloadDist.
  It never requests reload while a zombie is within melee danger dist
  and mag > 0 — it requests retreat instead.
- S5: Retreat: if nearest zombie dist < dangerDist, brain requests movement
  away from that zombie (vector away, at player yaw frame) and holds fire
  unless the zombie is point-blank in the crosshair lane.
- S6: Movement keys are expressed as a set of Quake input commands
  (+forward/-forward etc.) — the brain outputs intents, the page adapter
  translates intents to (a) synthetic key events, or (b) console commands
  on the QC-bot route. Brain itself touches no DOM.
- S7: Buy logic (strategy, slow): if pts >= 1200 and no Thompson yet and
  player is in the Help-room zone → intent `buy_thompson`. If pts >= 1000
  and Help door closed and round <= 3 → intent `open_help`. Otherwise no
  buy intent. v1 zones are named constants, tuned after live play.
- S8: No cheat surface: brain/QC export contain no god/notarget/noclip/
  impulse-give code paths. State export is read-only.

## QC export design (qc/bot_export.qc — to be merged into SSQC)

- Hook: called from the existing per-frame server think path at 0.1s cadence.
- Fields used (all standard SSQC / NZ:P globals, read from source):
  player `.health`, `.points` (verify name in defs), `.origin`, `.v_angle`,
  current weapon ammo fields, globals `rounds`, `Current_Zombies`.
- Zombies: iterate `findradius` / nextent chain over classname `ai_zombie`
  (classname verified in zombie_core.qc), emit origin, health, distance.
- Read-only: the export never writes game state.

## Page adapter (src/page_adapter.js)

- Wraps `Module.print` before `begin()` to feed lines to the parser,
  preserving the original print.
- Sends intents via synthetic KeyboardEvent/MouseEvent on the canvas'
  document (trusted-input limits are a known risk — see report; the QC
  route below removes this dependency).
- Preferred long-term input: QC-side bot that reads a cvar set from JS via
  console commands typed through the adapter (`set bot_cmd "..."`), so all
  real input is engine-native. v1 ships the parser+brain+adapter; QC merge
  is gated on the upstream-code processing approval.

## Co-op note

NZ:P supports cooperative lobbies in the same web build. A QC/page bot is
just another client: in co-op it can join Vee's lobby, and the strategy
layer changes (revive duty, window assignment, train-splitting) — the
reflex layer is unchanged. See REPORT.md when the live test lands.
