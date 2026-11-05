# PROTOTYPE - NOT FOR PRODUCTION. ADR checks stub. (ADR-0010 V4)
class_name PinGeometry
extends RefCounted


func check(x: float) -> HeroSim.PinResult:
	if x < 0.0:
		return HeroSim.PinResult.OFF_PATH
	return HeroSim.PinResult.OK
