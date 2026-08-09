shader_type spatial;
render_mode cull_disabled;

uniform vec3 shadow_color : source_color = vec3(0.055, 0.19, 0.095);
uniform vec3 mid_color : source_color = vec3(0.16, 0.39, 0.19);
uniform vec3 sun_color : source_color = vec3(0.39, 0.59, 0.25);
uniform float wind_strength = 0.075;
varying vec3 world_position;
varying float height_tint;


float hash31(vec3 point) {
	return fract(sin(dot(point, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}


void vertex() {
	float height_weight = smoothstep(2.2, 8.8, VERTEX.y);
	float seed = MODEL_MATRIX[3].x * 0.27 + MODEL_MATRIX[3].z * 0.19;
	VERTEX.x += sin(TIME * 0.72 + seed + VERTEX.z * 0.24) * wind_strength * height_weight;
	VERTEX.z += cos(TIME * 0.53 + seed + VERTEX.x * 0.19) * wind_strength * 0.62 * height_weight;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height_tint = height_weight;
}


void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float variation = hash31(floor(world_position * 2.3));
	float upward = clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 shaded = mix(shadow_color, mid_color, upward);
	shaded = mix(shaded, sun_color, height_tint * (0.18 + variation * 0.2));
	ALBEDO = shaded * mix(0.82, 1.13, variation);
	ROUGHNESS = 0.84;
	SPECULAR = 0.28;
	BACKLIGHT = mid_color * 0.34;
}
