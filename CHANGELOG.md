# Changelog

## 1.0.2

- Removed per-school sounds. The addon now uses a single alert sound for all dispellable debuffs.
- Removed the `/dh sound <school>` and `/dh test <school>` forms. Use `/dh sound <value>` and `/dh test`.
- Renamed "Default sound" to "Alert sound" in the options panel.

## 1.0.1

- Fixed a Lua error during combat (`GetDebuffDataByIndex(): Auras cannot be accessed when secret while tainted`). Detection now uses only combat-safe aura APIs.
- The highlight color is now supplied by the client, so school colors keep working in combat when the debuff type is hidden from addons.
- The sound now plays once per new dispellable debuff instead of once per player.
- Removed the `/dh types` override command. The client decides what you can dispel, so it was no longer needed. The "You can dispel" line in the options is for display only.

## 1.0.0

- Initial release.
- Highlights party and raid frames with a border colored by debuff school, for debuffs you can dispel.
- Optional alert sound with presets, SoundKit IDs and custom file paths.
- Options panel, minimap button (can be hidden) and addon compartment support.
- Slash commands: `/dh`, `/dh toggle`, `/dh minimap`, `/dh sound`, `/dh test`, `/dh thickness`, `/dh fill`.
