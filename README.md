# Dispel Highlight

**Never miss a dispel again.** Dispel Highlight is a minimalist addon for World of Warcraft: Forever that shows you at a glance who in your group has a debuff *you* can remove.

When a party or raid member is afflicted, their frame gets a colored border and a translucent tint so you can spot them without hunting through debuff icons. The color tells you the school before you even read the spell:

- **Blue:** Magic
- **Purple:** Curse
- **Green:** Poison
- **Brown:** Disease

Debuffs with no school, or one the addon doesn't recognize, are ignored.

## Features

- **Only what you can dispel.** The client decides what you can remove, so a highlight always means you can act on it.
- **Works in combat.** The addon never reads aura data. The client's own aura container tracks the debuffs and tints the highlight in the debuff's school color, so it keeps working while aura data is restricted in combat.
- **Adjustable tint.** Turn the tint off, or set its opacity from 5% to 100% so the unit frame stays visible underneath.
- **Options panel.** Turn the addon on or off, adjust border thickness, tint and tint opacity, and preview the highlight on your own frame with a Preview button.
- **Minimap button.** Left-click opens the options and right-click toggles the addon. Drag it to reposition it, or hide it from the options.
- **Addon compartment support.** Find Dispel Highlight in the built-in addon compartment menu, with the same quick controls and tooltip.
- **Lightweight.** No libraries. Works with the default Blizzard party and raid frames.

## Installation

1. Download the latest release from [CurseForge](https://www.curseforge.com/wow/addons/hynchs-dispel-highlight).
2. Place the `DispelHighlight` folder in:
   `World of Warcraft\_forever_\Interface\AddOns\`
3. Log in. Settings are saved automatically.

Type `/dh` to open the options, or `/dh test` to preview the highlight on your own frame.

## Options

Open the panel with `/dh`, the minimap button, or the addon compartment menu. You can also find it under **AddOns** in the game settings.

| Option | Description |
|---|---|
| Enable addon | Turns the highlight on or off |
| Tint the frame | Adds a colored fill inside the border |
| Show minimap button | Shows or hides the minimap button |
| Border thickness | 1 to 8 pixels |
| Tint opacity | 5% to 100%. Lower values let more of the unit frame show through |
| Preview | Flashes the highlight on your own frame for two seconds |

## Slash commands

| Command | What it does |
|---|---|
| `/dh` | Open the options panel |
| `/dh toggle` | Enable or disable the addon |
| `/dh minimap` | Show or hide the minimap button |
| `/dh test` | Flash the highlight on your own frame |
| `/dh thickness <1-8>` | Set the border thickness |
| `/dh opacity <5-100>` | Set the tint opacity in percent |
| `/dh fill` | Toggle the tint |
| `/dh debug` | Print diagnostic information about the aura container. Useful when reporting a problem |

`/dispelhl` works as an alias for `/dh`.

## How it works

On World of Warcraft: Forever, addon code can't read aura data in combat. Instead of reading debuffs, Dispel Highlight asks the client's own aura container to track harmful auras you can dispel, and gives it textures to tint. The client does the detection and colors; the addon only supplies the border and tint and controls their thickness and opacity.

Because the addon never learns that a debuff landed, it can't play an alert sound in combat, so there is no sound option.

## Compatibility

- Built for World of Warcraft: Forever (interface `16001`).
- Highlights the default Blizzard party and raid frames. Third-party unit frame addons are not supported.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE) © 2026 Hynch
