# Tuning pages

The numbers the lab reads, one plain-text page per subject. They are the game's own pages (Unwarded), cut down to what the lab draws. Each number has a line above it, starting with `;`, that says in plain words what it does, its unit and the range it accepts.

| Page | What the lab reads from it |
|---|---|
| `mage.cfg` | The Mage's kit: every section starts with `mage.`. His moves' frames and reach (`[mage.move.<name>]`, `[mage.move.light]` holding what his three light swings share), his combo (`[mage.combo]`, its `tempo` speeding every move up), his ultimate (`[mage.ultimate]`) and which saved preset each of his moves plays (`[mage.look]`, the `*_fx` lines) |
| `character.cfg` | What every character shares: `[player]` (his flinch and stagger frames, for his clips), the blink (`[blink]`), the dodge and the drink |
| `feel.cfg` | How his hits feel (hit-stop and knockback on his moves), the camera shake (`[shake]`) and the sand trail behind his staff (`[trail]`) |
| `camera-and-arena.cfg` | Where the camera sits (`[camera]`) and how the Mage and the floor warnings are drawn (`[look]`: his height, outline, lift, the tornado's height, the hourglass) |
| `global.cfg` | `effect_intensity_percent`: one knob over every effect, 0 the game's look today, 100 brighter, wider and longer |
| `volcano.cfg` | The ring arena: its size and pit (`[ring]`), the pillars, the vents, the lavafall, the lava, and how it is drawn (`[zone_look]`) |

## How to change something

1. Close the lab.
2. Open the page in any text editor and change the number after the `=`. Leave the name before the `=` and the `[section]` lines as they are.
3. Save, and open the lab again.

The lab never writes these pages. Its reach slider shows a move's reach at a new value until you close the lab; to keep it, write the value on the line its label names.
