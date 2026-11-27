# KNOWLEDGE.md — the bot's world model for NZ:P Nacht der Untoten

The brain does not memorize recipes. It derives decisions from the
quantities below, each with its reason. Constants are NZ:P's own,
read from the QuakeC source (identical in the Nov native tree and
the Sep web tree — one model serves both builds) unless marked
[research] (community/WaW data, NZ:P docs bless WaW parity) or
[telemetry] (measured in our own runs).

## 1. Points — what a zombie is worth (source: server/damage.qc:35-43)

- Non-lethal hit: **+10**
- Kill bonus by style: headshot **+100**, melee **+130**, upper torso
  +60, lower torso +50, grenade +50, explosive +60. The lethal hit
  pays the kill bonus instead of the +10.
- Repair: +10 per board [research; consistent with telemetry].
- Start: 500. Doors cost 1000 (verified in-game, HUD receipt).

Meaning: points are future options (doors, guns, box). A zombie is a
small bank: the longer it stays alive while being hit, the more it
pays — up to the knife finish, which is the richest kill. Killing
fast is sometimes worth less than killing slowly. That tension IS
the early game.

## 2. Zombie health (source: server/ai/zombie_core.qc set_z_health)

- Rounds 1–10: HP = 50 + 100×round → R1 150, R2 250, R3 350, R9 950,
  R10 1050.
- Round 11+: 1040 × 1.1^(round−10) → R11 1144, R15 ≈ 1675.
- Player dies in 2 zombie hits (no Juggernog on Nacht) [research].
- Max alive at once (solo): 24 [research — verify in source].

## 3. Weapons (source: shared/weapon_stats.qc)

Damage is base × location multiplier. Multipliers differ per gun —
the same zombie is a different puzzle for every weapon.

| Weapon | Cost | Dmg | Head × | Limb × | Mag | Reserve | Reload | Fire delay |
|---|---|---|---|---|---|---|---|---|
| Colt M1911 | — (start) | 20 | 3 (60) | 0.8 (16) | 8 | 80 | 1.9s | 0.10 |
| Kar98k | 200 | 100 | 3.5 (350) | 0.7 (70) | 5 | 50 | 2.5s | 0.30 |
| M1A1 Carbine | 600 | 120 | — | — | 15 | 120 | 2.9s | 0.22 |
| Thompson | 1200 | 120 | 4 (480) | 1 (120) | 20 | 200 | 2.1s | 0.085 |
| BAR | 1400 | 100 | 2.7 (270) | 1.5 (150) | 20 | 140 | 2.75s | 0.17 |
| Trench Gun | 1200 | 160 ×8 pellets | — | — | 6 | 60 | 0.6s/shell | 0.283 |
| Double-Barrel | 1000 | 200 ×8 pellets | — | — | 2 | 60 | 3.0s | 0.50 |
| Sawed-Off | 1000 | 200 ×8 pellets | — | — | 2 | 60 | 2.65s | 0.283 |
| Kar98k Scoped | 1500 | 800 | — | — | 5 | 50 | — | — |
| Ray Gun (box) | 950/box | 1000 | — | — | 20 | 160 | 2.75s | 0.35 |

Costs: Kar and door verified in-game; others NZ:P wiki via research
(WaW prices differ — do not import WaW tables). Knife damage: 150
(weapon_stats.qc WepDef_CalculateMeleeDamage, no Bowie).

**Reload exposure** = reload seconds × zombie closing speed = the
ground a zombie gains while you cannot shoot. It is a weapon stat
as real as damage:
- Double-Barrel: 3.0s of total helplessness every 2 shots, no
  partial reload. This is the trap that killed Vee's 2026-11-27 run
  (round 2, score 1240): the gun's damage is fine; its exposure is
  lethal. The brain prices exposure or it repeats her death.
- Trench Gun: reloads per shell (0.6s) and can fire between shells —
  exposure ≈ 0. Same family, opposite risk. (This is also why the
  reload watchdog never touches the shell-by-shell family.)
- Thompson: best wall gun not because 120 dmg, but because high
  damage × fast fire × 2.1s reload × deep reserve = sustained
  output with short exposure windows [research consensus agrees].
- BAR: slow fire, 2.75s reload, mediocre multipliers — buys
  nothing the Thompson doesn't do better. Do-not-buy [research].

## 4. The farming derivation (replaces all hardcoded shot counts)

Farm value of one zombie = 10 × (non-lethal hits) + kill bonus.
Maximize hits without killing, then finish with the knife (+130)
when the knife (150) covers the remaining HP:

    hits = floor((HP − 1) / dmg_per_hit)     (aim where dmg is LOW)
    value = 10 × hits + 130

Colt, aiming at an ARM hitbox (limb ×0.8 = 16 dmg):
- R1 (150 HP): 9 hits (144) + knife → **220/zombie**
- R2 (250 HP): 15 hits (240) + knife → **280/zombie** (one reload
  mid-farm; the window routine already reloads at the window)
- R3 (350 HP): 21 hits — impractical. The model itself says stop
  farming: switch to headshot kills (60/hit, 6 shots, 150/zombie)
  or a bought gun. Farming dies of arithmetic, not of a round flag.

Corollaries the brain must embody:
- **Farm aim ≠ combat aim.** At a window in farm rounds, aim at the
  arm hitbox. Head-aim (60/hit) farms only 150/zombie on R1 and
  kills the bank early. (Vee's rule "shots in a non-lethal spot,
  then knife" is this corollary in words; the counts differ because
  NZ:P's numbers differ from WaW's.)
- Window duty is only worth it while zombies arrive one or two at a
  time and stay outside claw range behind boards. When they pile in
  faster than the farm cycle, the window stops being a bank and
  becomes a funnel pointed at you — leave (breach-abandon already
  encodes the emergency half of this).

## 5. The map as a graph (layout dump 2026-11-26 + research)

Rooms are nodes; doors are edges costing 1000; windows are zombie
entry points. Closed doors block zombie pathing (NZ:P .way graph
guarantee [research, NZ:P docs]) — a closed door is not just an
unopened purchase, it is a wall zombies must route around.

Two schools exist and are mutually exclusive [research]:
- **Route A (camp):** open Help door, live in the box room, never
  open the spawn stairs. Simple, caps out ~R10–14.
- **Route B (train) — CHOSEN:** open the spawn-room STAIRS door
  first (~R3), then the second stairs down into the Help room.
  The Help door itself NEVER opens, so Help-room zombies can only
  arrive via the stairs — one visible funnel. Camp upstairs to ~R10,
  then TRAIN: loop the upstairs/spawn rooms so the horde (capped at
  24 alive) collects behind you; a loop turns a surrounding horde
  into a queue. Shoot the queue, loop again.
  Route B is chosen because it is the only school whose survival
  scales with rounds instead of with a corner's luck — and because
  "moving around the map" is what playing Zombies actually is.

Door identity is by position, never "nearest": the bot's current
nearest-door logic can open the Help door and silently destroy
Route B. Pin each door's bbox center from the BSP at build time.

## 6. Threat model

- A zombie behind you at equal speed is a solved problem; a zombie
  in front is not. Training works because the loop keeps all of
  them in the first category.
- Never be stationary with zombies inbound and an unready gun:
  reloading, buying, and repairing are all exposure windows; do
  them behind boards, behind a crawler, or on the move.
- **Crawler discipline** [research + Plutonium bot postmortems]:
  the last zombie of a round is an asset — it buys unlimited time
  to repair, buy, and reposition. Never kill the final zombie until
  the between-round work is done. (NZ:P crawlers: explosive damage
  to a crawling zombie makes crawlers — handle box explosives with
  care, and never fire them at close range: Vee's standing rule.)
- The bot's deaths so far, read through the model: dry-gun deaths
  (ammo economy ignored), reload deaths (exposure ignored), window
  breaches (funnel ignored). Every past failure is a missing term
  in this model, not bad luck.

## 7. How the brain uses this (v16 contract)

- Every mode choice logs a reason code to telemetry (e.g.
  `rsn=farm_arm`, `rsn=buy_thompson_exposure`, `rsn=train_loop`),
  so a death can be audited: were the facts wrong, or the
  derivation? Different fixes.
- Shot counts, buy choices, and door choices are computed from the
  tables above at think time. If a number in this doc changes, the
  behavior changes — that is the test that the bot "knows why".
- The LLM strategist (offline) revises this doc when telemetry
  disagrees with it. The doc is the bot's understanding; the code
  is just its hands.
