## Where the arena's scenery goes, and how much of it to draw. Pure static
## functions so they can be tested headless; looks only, nothing here touches
## the simulation.
class_name ArenaLayout
extends RefCounted

## Every effect: particles (embers, smoke), volumetric fog, shadows,
## anti-aliasing (MSAA 4x and SMAA).
const HIGH := "high"
## No particles, no volumetric fog, no shadows, no anti-aliasing: for headless, smoke and
## several-windows runs.
const LOW := "low"

