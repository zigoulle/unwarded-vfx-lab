## The noise library's CPU half (VFX lab ticket 04): the hash and the kink
## noise of res://fx/shaders/fx_noise.gdshaderinc, the same formulas, so a
## block's data (its ribbon points) is worked out as its shader draws it.
## Ported from LinearAbiltyCastingThreeJS (MIT; THIRD_PARTY_LICENSES.md).
## Node-free, pure static.
class_name FxNoise
extends RefCounted

## The shader library every effect shader includes.
const INCLUDE := "res://fx/shaders/fx_noise.gdshaderinc"


## A hash of `p`, 0..1 (hash11).
static func hash11(p: float) -> float:
	p = _fract(p * 0.1031)
	p *= p + 33.33
	p *= p + p
	return _fract(p)


## Value noise with a LINEAR ramp between its knots at the whole numbers,
## -1..1: straight between them, so its corners stay sharp (vnoise).
static func vnoise(x: float, seed: float) -> float:
	var i := floorf(x)
	var f := x - i
	return lerpf(hash11(i + seed), hash11(i + 1.0 + seed), f) * 2.0 - 1.0


## The fractional part of `x` (GLSL's fract: always 0 to 1, below 0 too).
static func _fract(x: float) -> float:
	return x - floorf(x)
