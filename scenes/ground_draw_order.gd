## The draw order on the ground plane (VFX lab ticket 08; grill Q12, spec
## story 37): enemy ground marks (the telegraphs' fills and borders) always
## draw above player effects on the ground (the lab's ground marks: a
## scorch, its streaks; the boons' ground decals, BoonEventVfx.ground_decal;
## the mage's ultimate hourglass), so a bright spell can never hide a
## danger. Both are see-through and drawn without depth, so the render
## priority alone decides: every player ground effect at PLAYER_EFFECTS (one
## over another of his own at PLAYER_EFFECTS + 1, still below), every enemy
## mark at ENEMY_MARKS or above (a telegraph's border one above its fill).
class_name GroundDrawOrder
extends RefCounted

## Player effects on the ground plane.
const PLAYER_EFFECTS := -4
## Enemy ground marks: the fill here, the border one above.
const ENEMY_MARKS := 0
