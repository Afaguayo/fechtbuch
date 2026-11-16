# Fechtbuch

A combat HUD mod for **Half Sword** (Steam, Early Access). It shows what the game normally hides: health, consciousness, stamina, pain, bleeding, broken bones, dislocations and damage, for you and for the enemy you tag.

*A Fechtbuch ("fight book") is a medieval German fencing manual, the kind of treatise half-swording techniques come from.*

## Features

**Your panel** (bottom-left by default)
- Body diagram: every limb is colored by its health (bone-white → yellow → orange → red → dark red), flashes red when hit, pulses when a bone is broken and turns violet when a joint is dislocated.
- Cuts are drawn on the diagram as short red strokes on the bone that was hit, placed along the limb where the blade landed. While you bleed, drops fall from every cut, faster the more you bleed. Healed cuts disappear.
- Bars for health, consciousness, stamina, energy, pain and bleeding.
- Injury list, e.g. `Left arm: BROKEN, Wounded 55%, healing`, plus pain shock and spilled guts. Each wound says whether it is healing or getting worse.
- Bleed-out estimate next to the bleeding bar (`out in ~12 s`), from how fast health and consciousness are dropping.
- Warning in the panel title when you are losing consciousness, bleeding heavily or out of energy.
- Damage dealt, damage taken, best hit and kills.
- Weight, height, strength and gear weight, plus the raw exhaustion and fear values.
- Progress bars for strength, weapon skill and body skill, including gain that is still pending.

**Tagged enemy**
- Press **Z** while looking at an enemy to tag them (Z on them again to untag).
- Only the tagged enemy gets a stats card (body diagram, bars, injuries, weight, height, strength), a tag over their head and floating damage numbers when you hit them. Untagged enemies show nothing.

**Threat list** (middle-right by default)
- The three nearest living enemies within 30 m: type (enemy or revenant), distance, health and whether they are to your left, right or behind you.

**Fight recap**
- When a fight ends (nobody left nearby, or you fall) a short line shows the time, damage dealt and taken, hits, best hit and kills.

**Settings menu** (**Home** key)
- Turn every piece on or off, move each panel to one of 8 positions, nudge it, and resize it (40-160%).
- Layout presets: Full, Compact (your bars only) and Duel (your bars plus the enemy card). A preset only switches pieces on or off; positions and sizes stay as you set them.
- Choose how an enemy gets focused: Z tag only, or Z tag plus lock-on, crosshair or nearest enemy.
- Settings are saved to `settings.txt` and survive updates.

## Install

1. Download **`FechtbuchInstaller.exe`** from the [latest release](../../releases/latest).
2. Close Half Sword and run the installer, then choose **1**.
3. Start the game and fight.

The installer finds Half Sword through your Steam libraries, installs [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (the mod loader) if you don't have it, installs Fechtbuch and enables it. Your settings are kept when you update, including settings from the older "Battle Eye" version, which the installer replaces.

Windows SmartScreen may warn about the installer because it isn't code-signed: click **More info → Run anyway**.

### Manual install

1. Install the UE4SS experimental build into `Half Sword\HalfswordUE5\Binaries\Win64` (so `dwmapi.dll` and the `ue4ss` folder sit next to the game's `.exe`).
2. Download `Fechtbuch-mod.zip` from the release and extract it into `Win64\ue4ss\Mods\` so you get `Mods\Fechtbuch\Scripts\main.lua`.
3. Add `Fechtbuch : 1` to `Win64\ue4ss\Mods\mods.txt` above the `; Built-in keybinds` line.

## Keys

| Key | Action |
|---|---|
| Z | Tag / untag the enemy you're looking at |
| Home | Open / close the Fechtbuch menu (arrows to change, Enter to toggle) |
| F7 | HUD on / off |
| F8 | Reset damage counters |
| F9 | Save every property of your fighter to `props_dump.txt` (for troubleshooting; also saved once automatically each time you start the game) |

## Uninstall

Run the installer and choose **2** (Fechtbuch only) or **3** (Fechtbuch and UE4SS).

## Notes

- Tested on Half Sword Early Access 0.7 "The Crypts" (0.7.0.2) and 0.6.1.5, with UE4SS v3.0.1 Beta (Unreal Engine 5.4).
- On 0.7 the HUD also shows the new energy stat as a bar and the heart as an injury region. The exhaustion and fear numbers are shown as the game stores them, because their scale is not known yet.
- With no fight going on the HUD refreshes about 10 times a second instead of 30.
- Weight is the physics mass of the body and height is measured from the head to the feet, so both are close estimates.
- The game does not say who hit whom. Damage dealt counts health lost by enemies within 5 m of you, or by the enemy you tagged at any distance, because in 0.7 factions also fight each other. A kill counts if you damaged that enemy before. Hits with thrown or shot weapons on untagged enemies further away are not counted.
- The bleed-out estimate and the "bleeding heavily" threshold are estimates and have not been tuned in play.
- Cut positions come from the data the game uses to paint blood on the body (`RT_Blood_Bones`, `RT_Blood_Locations`). The diagram is a flat front view, so a cut on the back shows on the same limb at the same height. Every cut is also written to `wounds_dump.txt` with how it was placed (`world`, `local` or `bone`), to check the placement.
- The game doesn't expose its own maximum for strength and skill progress; the bars treat 100% as the cap.
- If the in-game HUD doesn't show, right-click `ue4ss\Mods\Fechtbuch\overlay.ps1` → *Run with PowerShell* for a separate stats window (run the game in borderless/windowed mode).

## Building the installer

```powershell
powershell -ExecutionPolicy Bypass -File installer\build.ps1
```

This downloads the latest UE4SS experimental build, packs it with the mod into `dist\FechtbuchInstaller.exe` and writes `dist\Fechtbuch-mod.zip`. Pass `-UE4SSZip <path>` to use a specific UE4SS zip. Needs only Windows and the .NET Framework compiler that ships with it.

## Credits

- [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) (MIT, see `third_party/UE4SS-LICENSE`) loads the mod and is bundled in the installer.
- The first property names came from [HalfSwordTrainerMod](https://github.com/massclown/HalfSwordTrainerMod).

## License

MIT, see `LICENSE`.
