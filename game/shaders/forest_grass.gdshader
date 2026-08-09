shader_type spatial;
render_mode cull_disabled;

uniform vec3 dark_green : source_color = vec3(0.045, 0.16, 0.07);
uniform vec3 fresh_green : source_color = vec3(0.18, 0.36, 0.13);
uniform vec3 tip_green : source_color = vec3(0.31, 0.48, 0.19);
uniform float wind_strength = 0.085;
uniform float wetness : hint_range(0.0, 1.0) = 0.54;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.62;
uniform vec3 actor_position = vec3(0.0);
uniform float actor_influence = 1.0;
uniform vec4 interaction_spheres[8];
uniform int interaction_count = 0;
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
	vec2 actor_offset = world_position.xz - actor_position.xz;
	float actor_distance = length(actor_offset);
	float actor_bend = (1.0 - smoothstep(0.18, 1.25, actor_distance)) * actor_influence;
	if (actor_distance > 0.01) {
		VERTEX.xz += normalize(actor_offset) * actor_bend * 0.085 * UV.y;
	}
	for (int index = 0; index < 8; index++) {
		if (index >= interaction_count) {
			break;
		}
		vec2 body_offset = world_position.xz - interaction_spheres[index].xy;
		float body_distance = length(body_offset);
		float body_bend = (1.0 - smoothstep(0.16, interaction_spheres[index].w, body_distance));
		if (body_distance > 0.01) {
			VERTEX.xz += normalize(body_offset) * body_bend * 0.072 * UV.y;
		}
	}
}


void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float irregular = hash21(floor(world_position.xz * 8.0));
	vec3 base = mix(dark_green, fresh_green, instance_variation.r);
	vec3 color = mix(base, tip_green, UV.y * (0.34 + instance_variation.g * 0.22));
	color = mix(color, color * vec3(0.72, 0.82, 0.78), wetness * 0.18);
	ALBEDO = color * mix(0.86, 1.12, irregular);
	ROUGHNESS = mix(0.91, 0.52, wetness * 0.6);
	SPECULAR = mix(0.22, 0.54, wetness);
	BACKLIGHT = fresh_green * (0.16 + rain_intensity * 0.08);
}
