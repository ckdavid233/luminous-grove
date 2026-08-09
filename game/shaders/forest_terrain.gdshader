shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 moss_tint : source_color = vec3(0.31, 0.48, 0.3);
uniform vec3 earth_tint : source_color = vec3(0.29, 0.24, 0.17);
varying vec3 world_position;


float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 first_uv = world_position.xz * 0.115;
	mat2 rotation = mat2(vec2(0.819, 0.574), vec2(-0.574, 0.819));
	vec2 second_uv = rotation * world_position.xz * 0.073 + vec2(0.37, 0.61);
	float macro = value_noise(world_position.xz * 0.055);
	float blend = smoothstep(0.28, 0.72, value_noise(world_position.xz * 0.19 + 7.3));
	vec3 first = texture(albedo_texture, first_uv).rgb;
	vec3 second = texture(albedo_texture, second_uv).rgb;
	vec3 base = mix(first, second, blend);
	vec3 macro_tint = mix(earth_tint, moss_tint, macro);
	ALBEDO = base * mix(vec3(0.66), macro_tint * 1.35, 0.34);
	NORMAL_MAP = texture(normal_texture, first_uv).rgb;
	NORMAL_MAP_DEPTH = 0.58;
	ROUGHNESS = clamp(texture(roughness_texture, first_uv).r * 1.08, 0.78, 1.0);
}
