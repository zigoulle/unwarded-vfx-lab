## How tall the mage is drawn, and where the cues around him sit for that
## height (ticket 17, readability). Node-free; the [look] values on the
## camera-and-arena page. Presentation only: the simulation never reads them,
## and his hit shapes, the slot disc and the ground rings stay where the
## simulation puts them.
class_name MageLook
extends RefCounted

## How tall the baked GLB stands (m): the crown of his head in the rest pose.
## The Rigify mage is rigged on mage-clean.glb at its own size (mage-clips.json
## "height_m"; a test checks the two agree).
const MODEL_HEIGHT_M := 0.804
## The height the cues were placed for (the mage of the first art pass).
const BASE_HEIGHT_M := 1.9


## A new model to draw him with (his roster `look`; PlayerAvatar).
static func build_model() -> CharacterModel:
	return MageModel.new()


## The model's scale for a mage `height_m` tall.
static func model_scale(height_m: float) -> float:
	return height_m / MODEL_HEIGHT_M


## Over the head: `over_m` above a `height_m` mage's crown, as it sat over the
## 1.9 m mage's (the cast's hourglass). Metres above his feet.
static func over_head_m(height_m: float, over_m: float) -> float:
	return height_m + over_m


## The drawn mage's yaw `delta` seconds on, turning from `drawn` toward the
## facing `target` (radians) the short way round, eased with a time constant
## of `smoothing_s` (run-fluid #5: the facing turns in one tick, a 180 drew as a
## pop). 0 snaps. Exponential, so it is the same however the frames are cut.
## Looks only: his facing, hit shapes and the rings stay the simulation's.
static func turn_toward(drawn: float, target: float, delta: float, smoothing_s: float) -> float:
	if smoothing_s <= 0.0:
		return target
	return drawn + angle_difference(drawn, target) * (1.0 - exp(-maxf(delta, 0.0) / smoothing_s))


## On the body: a point `at_m` above the 1.9 m mage's feet (the flask at his
## mouth), moved with him to a `height_m` mage. Metres above his feet.
static func at_body_m(height_m: float, at_m: float) -> float:
	return at_m * height_m / BASE_HEIGHT_M
