## An effect's seed from its cast (grill Q8): the move's event, its tick and
## its actor, so every peer and every replay draws the same shapes. Looks
## only: the simulation never reads it. Pure integer maths (no engine hash),
## the same on every machine.
class_name FxSeed
extends RefCounted


## The seed of the cast `actor` made on `tick`: 0 to 2^31 - 1.
static func of(tick: int, actor: int) -> int:
	var h := (tick * 73856093) ^ (actor * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 0x2c1b3c6d
	h = h ^ (h >> 16)
	return h & 0x7fffffff
