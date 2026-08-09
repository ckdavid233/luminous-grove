shader_type spatial;
render_mode cull_disabled;

uniform vec3 dark_green : source_color = vec3(0.045, 0.16, 0.07);
uniform vec3 fresh_green : source_color = vec3(0.18, 0.36, 0.13);
uniform vec3 tip_green : source_color = vec3(0.31, 0.48, 0.19);
uniform float wind_strength = 0.085;
varying vec4 instance_variation;
varying vec3 world_position;


float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}


void vertex() {
	instance_variation = INSTANCE_CUSTOM;
	float bend = UV.y * UV.y;
	float seed = MODEL_MATRIX[3].x * 0.31 + MODEL_MATRIX[3].z * 0.17;
	VERTEX.x += sin(TIME * 1.08 + seed + VERTEX.y * 1.7) * wind_strength * bend;
	VERTEX.z += cos(TIME * 0.83 + seed * 0.73) * wind_strength * 0.58 * bend;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float irregular = hash21(floor(world_position.xz * 8.0));
	vec3 base = mix(dark_green, fresh_green, instance_variation.r);
	vec3 color = mix(base, tip_green, UV.y * (0.34 + instance_variation.g * 0.22));
	ALBEDO = color * mix(0.86, 1.12, irregular);
	ROUGHNESS = 0.91;
	SPECULAR = 0.22;
	BACKLIGHT = fresh_green * 0.16;
}
