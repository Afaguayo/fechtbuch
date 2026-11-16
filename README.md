# Fechtbuch

A combat HUD mod for **Half Sword** (Steam, Early Access). It shows what the game normally hides: health, consciousness, stamina, pain, bleeding, broken bones, dislocations and damage, for you and for the enemy you tag.

*A Fechtbuch ("fight book") is a medieval German fencing manual, the kind of treatise half-swording techniques come from.*

## Features

**Your panel** (bottom-left by default)
- Body diagram: every limb is colored by its health (bone-white → yellow → orange → red → dark red), flashes red when hit, pulses when a bone is broken and turns violet when a joint is dislocated.
- Bars for health, consciousness, stamina, pain and bleeding.
- Injury list, e.g. `Left arm: BROKEN, Wounded 55%`, plus pain shock and spilled guts.
- Damage dealt, damage taken, best hit and kills.
- Weight, height, strength and gear weight.
- Progress bars for strength, weapon skill and body skill, including gain that is still pending.

**Tagged enemy**
- Press **Z** while looking at an enemy to tag them (Z on them again to untag).
- Only the tagged enemy gets a stats card (body diagram, bars, injuries, weight, height, strength), a tag over their head and floating damage numbers when you hit them. Untagged enemies show nothing.

**Settings menu** (**Home** key)
- Turn every piece on or off, move each panel to one of 8 positions, nudge it, and resize it (40-160%).
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

- Tested on Half Sword Early Access 0.6.1.5 with the UE4SS experimental build (Unreal Engine 5.4). Version 1.1.0 also loads on 0.7 "The Crypts" with UE4SS v3.0.1 Beta; 1.2.0 has not been played on 0.7 yet.
- On 0.7 the game no longer has the pending strength gain (`Muscle Rate Due`), so the strength bar shows no pending part. The new energy, wound healing and faction stats are not shown yet: `UE4SS.log` lists their names in a `[Fechtbuch] class ... unmapped:` line, and `docs/hud-upgrades-0.7.md` has the plan for them.
- Weight is the physics mass of the body and height is measured from the head to the feet, so both are close estimates.
- Damage dealt counts health lost by enemies, so it assumes enemies don't hurt each other. In 0.7 factions can fight each other, so the total can include damage you didn't deal.
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
