# Changelog

## 1.0.0

Initial release.

- Highlights party and raid frames with a colored border and a translucent tint for debuffs you can dispel. The color shows the school: blue for Magic, purple for Curse, green for Poison, brown for Disease.
- Works in combat. The client's own aura container does the detection and coloring, so the addon never reads aura data.
- Only debuffs you can dispel are shown. Debuffs with no school are ignored.
- Options panel with enable, tint, tint opacity (5% to 100%), border thickness, minimap button and a Preview button. The panel can't be opened during combat, which is a game restriction.
- Minimap button that can be hidden, and addon compartment support.
- Slash commands: `/dh`, `/dh toggle`, `/dh minimap`, `/dh test`, `/dh thickness`, `/dh opacity`, `/dh fill`, `/dh debug`.
