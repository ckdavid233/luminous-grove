extends SceneTree


func _initialize() -> void:
	var environment := Environment.new()
	var available := {}
	for property in environment.get_property_list():
		available[property.name] = true
	for required_property in [
		&"ssr_enabled",
		&"ssao_enabled",
		&"ssil_enabled",
		&"sdfgi_enabled",
		&"volumetric_fog_enabled",
	]:
		assert(available.has(required_property), "Missing Environment property: " + required_property)
	print("ENVIRONMENT_CAPABILITY_TEST_OK")
	quit()

