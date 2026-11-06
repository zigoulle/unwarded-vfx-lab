# Third-party licences

Everything in this repository is under the MIT licence in `LICENSE` (the lab's code, the effect recipes and presets, the Mage's model, rig, clips and textures, the ring arena and its shaders, the tuning pages and the docs), except the third-party sources below, which keep their own licences. Each one is MIT or CC0, so the whole lab can be used, changed and shipped, commercially too.

Each licence was read from the files that came with the source, not only from its store page.

## Code and shaders

| Source | Where in the repo | Licence | Credit line |
|---|---|---|---|
| [LinearAbiltyCastingThreeJS](https://github.com/achrefelouafi/LinearAbiltyCastingThreeJS) by mohamedachrefelouafi (Three.js; shader maths only, ported to Godot shaders and GDScript; none of its assets): `src/shaders/lib/noise.glsl.js` (hashes, simplex, fbm, ridged, curl, Voronoi; its simplex is Ashima Arts / Stefan Gustavson's, MIT) and `src/materials/LightningMaterial.js` (the ribbon shaped in the vertex shader), and its particles' technique (moved from their spawn time; no code) | `fx/shaders/fx_noise.gdshaderinc`, `fx/fx_noise.gd`, `fx/shaders/fx_ribbon.gdshader`, `fx/shaders/fx_ribbon_shape.gdshaderinc`, `fx/fx_ribbon.gd`, `fx/fx_particles.gd` (each file's header names the source) | MIT ("Copyright (c) 2026 mohamedachrefelouafi", the repo's `LICENSE`, read 2026-10-22) | "Ribbon and noise shader maths after LinearAbiltyCastingThreeJS by mohamedachrefelouafi, MIT licence" |
| [Godot Engine](https://godotengine.org) 4.7 | not in the repo (installed separately; the web build carries its engine) | MIT | "Made with Godot Engine" |

## Visual effects

| Source | Where in the repo | Licence (confirmed from) | Credit line |
|---|---|---|---|
| [Stylized 3D Fire and Smoke](https://knowercoder.itch.io/3d-fire-and-smoke) v1.0 by knowercoder: the ring arena's vent eruptions; `scenes/vent_fire.gdshader` is its ToonFire shader recoloured to lava | `vfx/knowercoder-3d-fire-and-smoke/` (`LICENSE.md`), `scenes/vent_fire.gdshader` | MIT (the zip has no licence file: the itch page says "Code license: MIT License" and the author's comment there, "this is MIT licensed; you may credit me with the link to this itch.io page") | "3D Fire and Smoke by knowercoder (https://knowercoder.itch.io/3d-fire-and-smoke), MIT licence" |
| [Binbun Battle FX](https://binbun3d.itch.io/battle-fx) (free version) by Binbun3D: its `shield_shell.gdshader` (fresnel shell) is the starting point of the time slow's hourglass glass; the pack itself is not in this repo | `scenes/hourglass_glass.gdshader` (its header names the source) | CC0 1.0 (the pack's `license.txt`: free for personal, educational and commercial projects, no attribution required) | "VFX by Binbun (binbun3d.itch.io)" (optional under CC0) |

## Textures

| Source | Where in the repo | Licence (confirmed from) | Credit line |
|---|---|---|---|
| [Kenney](https://kenney.nl/assets/particle-pack) Particle Pack 1.1: the particle sprites of every effect (sand, dust, sparks, smoke, flames, cracks) and of the ring arena's eruptions, splashes and embers | `vfx/kenney-particle-pack/` (`License.txt`): the 512 px `PNG (Transparent)` set | CC0 1.0 (the pack's `License.txt`) | "Particles by Kenney (kenney.nl)" (optional under CC0) |

## Made with generation tools (not third-party licences, recorded for provenance)

| Tool | What | Terms |
|---|---|---|
| Tripo (P-O's paid account) | The Mage's mesh and textures (`assets/mage/`), generated from P-O's own turnaround views, then cleaned, rigged (Rigify) and keyed by hand in Blender | Generated on P-O's paid account under Tripo's terms of service; released here under the MIT licence |
