# Dispel Highlight

**Never miss a dispel again.** Dispel Highlight is a minimalist addon for World of Warcraft: Forever that shows you at a glance who in your group has a debuff *you* can remove.

When a party or raid member is afflicted, their frame gets a colored border so you can spot them without hunting through debuff icons. The color tells you the school before you even read the spell:

- **Blue:** Magic
- **Purple:** Curse
- **Green:** Poison
- **Brown:** Disease
- **Orange:** Dispellable, but the school couldn't be determined (a fallback that should rarely appear)

## Features

- **Only what you can dispel.** The client decides what you can remove, so a highlight always means you can act on it. Debuffs you can't dispel are ignored.
- **Works in combat.** Detection uses only the aura APIs that stay available while aura data is restricted, so highlights keep working during combat, encounters and instanced content.
- **Sound alert.** Get an audio cue the moment a new dispellable debuff lands. It plays once per debuff, so it won't spam you. Pick a built-in preset, a SoundKit ID, or your own sound file.
- **Options panel.** Turn the addon on or off, adjust border thickness, toggle the colored tint, choose your sound, and preview it with a Test button.
- **Minimap button.** Left-click opens the options and right-click toggles the addon. Drag it to reposition it, or hide it from the options.
- **Addon compartment support.** Find Dispel Highlight in the built-in addon compartment menu, with the same quick controls and tooltip.
- **Lightweight.** No libraries. Works with the default Blizzard party and raid frames.

## Installation

1. Download the latest release.
2. Place the `DispelHighlight` folder in:
   `World of Warcraft\_forever_\Interface\AddOns\`
3. Log in. Settings are saved automatically.

Type `/dh` to open the options, or `/dh test` to preview the highlight and sound.

## Options

Open the panel with `/dh`, the minimap button, or the addon compartment menu. You can also find it under **AddOns** in the game settings.

| Option | Description |
|---|---|
| Enable addon | Turns highlights and sounds on or off |
| Tint the frame | Adds a faint colored fill inside the border |
| Show minimap button | Shows or hides the minimap button |
| Border thickness | 1 to 8 pixels |
| Alert sound | Choose a preset, or enter a SoundKit ID or file path |
| Test | Plays the sound and flashes your own frame |

## Sounds

Presets: `alarm`, `raid`, `ready`, `bell`, `quest`, or `off` to mute.

You can also use any numeric SoundKit ID, or a file path such as `Interface\AddOns\DispelHighlight\ding.ogg`.

## Slash commands

| Command | What it does |
|---|---|
| `/dh` | Open the options panel |
| `/dh toggle` | Enable or disable the addon |
| `/dh minimap` | Show or hide the minimap button |
| `/dh sound <preset, ID or path>` | Set the alert sound (`off` to mute) |
| `/dh test` | Preview the highlight and sound |
| `/dh thickness <1-8>` | Set the border thickness |
| `/dh fill` | Toggle the colored tint |

`/dispelhl` works as an alias for `/dh`.

## Compatibility

- Built for World of Warcraft: Forever (interface `16001`).
- Highlights the default Blizzard party and raid frames. Third-party unit frame addons are not supported.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

[MIT](LICENSE) © 2026 Hynch
