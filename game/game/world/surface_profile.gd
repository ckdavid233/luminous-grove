class_name SurfaceProfile
extends MaterialProfile

enum SurfaceType {
	DRY_SOIL,
	WET_MUD,
	MOSS,
	STONE,
	WOOD,
	WATER,
}

func to_sample(normal: Vector3, wetness: float) -> Dictionary:
	return {
		"type": surface_type,
		"profile": self,
		"normal": normal,
		"wetness": clampf(wetness, 0.0, 1.0),
		"friction": friction,
		"speed_multiplier": speed_multiplier,
		"footstep_tag": footstep_tag,
		"ripple_tag": ripple_tag,
	}
