# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0010 V4)
class_name HeroSim
extends RefCounted
## Holds a PinGeometry, while PinGeometry returns HeroSim.PinResult.

enum PinResult { OK = 0, OFF_PATH = 1, BUSY = 3, TOO_FAR = 2 }

var geometry: PinGeometry = PinGeometry.new()


func try_pin(x: float) -> PinResult:
	return geometry.check(x)
