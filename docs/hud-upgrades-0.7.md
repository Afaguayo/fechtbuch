# HUD upgrades for Half Sword 0.7 (draft)

Status: all ten upgrades are built in version 1.3.0 (2026-11-15), except faction colors. Checked against a mock of the game; 1.3.0 has not been played yet. The rest of this note is the original proposal, kept for the reasoning.

## What 1.3.0 built

| # | Upgrade | How it was built |
|---|---|---|
| 1 | Energy bar | `SMH Energy`, 0 to 1 (in 1.2.1) |
| 2 | Wound trend | "healing" or "worse" after an injury, from the change in limb health over about 3 seconds |
| 3 | Bleed-out estimate | "out in ~N s" on the bleeding bar, from the loss rate of health and consciousness, shown when under 3 minutes |
| 4 | Enemy type | "REVENANT" for `Willie_BP_Zombie_C`, "ENEMY" otherwise |
| 5 | Threat list | Three nearest living enemies within 30 m, with LEFT, RIGHT or BEHIND |
| 6 | Fair damage credit | Health loss counts within 5 m of you or on the tagged enemy; a kill counts if you damaged them. Faction colors are not built: the dump has no per-fighter faction id |
| 7 | Layout presets | Full, Compact, Duel in the menu |
| 8 | Low-state warning | Title of your panel pulses and names the problem: consciousness under 25%, bleeding over 10, energy under 15% |
| 9 | Fight recap | One card when the fight ends or you fall |
| 10 | Slower refresh out of combat | Every third tick when no fight is going on |

Also added: raw `Exhaustion` and `Fear` values on the physique lines, to learn their scale.

To tune in play: the bleeding threshold (10), the 5 m credit reach, and whether the `Muscle Growth Due` readout is on the same scale as the old one.

## Update after the first 0.7 fight (2026-11-15)

Version 1.2.0 ran in a real fight on 0.7.0.2 and wrote the property dump. Real names found:

- Energy: `SMH Energy` (0 to 1), with `Energy Past`, `Energy Spent`, `Rest` and `Rest Rate`.
- Pending strength gain: `Muscle Growth Due` (was `Muscle Rate Due`).
- New: `Heart Health`, `Exhaustion`, `Fear`, `Faction Buff Int`. No per-fighter faction id was found; `Team Int` is still there.

Built in 1.2.1: upgrade 1 (energy bar), the renamed strength gain, and the heart as an injury region. Still open: everything else in the table. `Exhaustion` and `Fear` are good candidates for the enemy tag status line.

## What 0.7 changed that matters to the HUD

Half Sword 0.7 "The Crypts Update" (2026-11-10, hotfixes 0.7.0.1 and 0.7.0.2) added:

- an Energy System next to stamina,
- wounds that persist between fights and heal over time,
- NPC factions, awareness and emotions, so NPCs can fight each other,
- the Crypts dungeon and Purgatory, with Revenants (`Willie_BP_Zombie_C`),
- reworked combat, physics and armor collision. The engine is still Unreal 5.4.

What we know from the game's own log on 0.7: Fechtbuch 1.1.0 loads, builds the HUD and resolves every property except `Muscle Rate Due`. The names of the new properties are not known yet, because the game files are compressed and no property dump existed.

**First step for everything marked "needs names":** start the game once with Fechtbuch 1.2.0 and enter a fight. It writes `ue4ss\Mods\Fechtbuch\props_dump.txt` by itself and logs a `[Fechtbuch] class Willie_BP_C unmapped: ...` line in `ue4ss\UE4SS.log`. Those two files hold the real 0.7 names.

## Proposed upgrades

Ordered by value for the effort. "Ready" means it needs no new property names.

| # | Upgrade | What it shows | Needs | Effort |
|---|---|---|---|---|
| 1 | Energy bar | Energy under stamina, in your panel and the enemy card | names | small |
| 2 | Wound trend | An arrow per injury line: healing, stable or getting worse, from the change in limb health over the last few seconds | ready | small |
| 3 | Bleed-out estimate | "Out in ~12 s" next to the bleeding bar, from the current rate of health and consciousness loss | ready | small |
| 4 | Enemy type in the card title | "REVENANT" instead of "ENEMY", from the fighter class | ready | small |
| 5 | Threat list | The three nearest living enemies as short rows: distance, a health pip and an arrow when they are off-screen or behind you | ready | medium |
| 6 | Faction colors and fair damage credit | Tag and card colored by faction; damage dealt counts only hits on fighters hostile to you | names | medium |
| 7 | Layout presets | One menu row that switches between Full, Compact (bars only) and Duel (your bars plus the enemy card) | ready | medium |
| 8 | Low-state warning | The title bar of your panel pulses when consciousness is under 25% or bleeding is heavy | ready | small |
| 9 | Fight recap | A short card after a kill or your death: time, damage dealt and taken, hits, best hit | ready | medium |
| 10 | Slower refresh out of combat | Refresh 10 times a second when no enemy is within 20 m, 30 times in a fight | ready | small |

### Notes on the less obvious ones

- **Threat list (5)** became cheap in 1.2.0: unfocused enemies now cost three property reads per tick, so listing three of them adds almost nothing.
- **Fair damage credit (6)** fixes a number that is wrong on 0.7. The HUD credits every enemy health loss to you, which was true when enemies never fought each other. With factions it over-counts. Until the faction property is known, a partial fix is to credit only hits on fighters within weapon reach of you.
- **Wound trend (2)** is the HUD-side view of the new healing system and works even if the game exposes no healing property: the HUD already reads every limb's health.
- **Strength bar**: `Muscle Rate Due` is gone in 0.7, so the pending part of the strength bar never shows. If the dump shows a replacement, map it; if not, drop the pending part for strength.

## Suggested order

1. Play one fight on 1.2.0, collect `props_dump.txt` and the `unmapped` log line.
2. Build 1, 4 and 8 (small, visible).
3. Build 2 and 3 (the 0.7 wound system).
4. Build 6, then 5.
5. Build 7, 9 and 10.

## UE4SS

Stay on the installed UE4SS v3.0.1 Beta for now: it works with 0.7. UE4SS v4.0.0 (2026-11-12) has breaking Lua API changes and has not been tried with this mod.
