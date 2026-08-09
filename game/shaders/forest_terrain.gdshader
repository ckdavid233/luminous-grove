shader_type spatial;

render_mode diffuse_burley, specular_schlick_ggx;

group_uniforms material_layers;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dry_albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wet_albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cavity_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D height_texture : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool detail_maps_enabled = false;

group_uniforms palette;
uniform vec3 moss_tint : source_color = vec3(0.31, 0.48, 0.3);
uniform vec3 earth_tint : source_color = vec3(0.29, 0.24, 0.17);
uniform vec3 mud_tint : source_color = vec3(0.25, 0.20, 0.15);
uniform vec3 wet_specular_tint : source_color = vec3(0.33, 0.47, 0.46);

group_uniforms wetness;
uniform float wetness : hint_range(0.0, 1.0) = 0.54;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.62;

varying vec3 world_position;
varying float terrain_slope;


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
	terrain_slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
}


void fragment() {
	vec2 first_uv = world_position.xz * 0.115;
	mat2 rotation = mat2(vec2(0.819, 0.574), vec2(-0.574, 0.819));
	vec2 second_uv = rotation * world_position.xz * 0.073 + vec2(0.37, 0.61);
	float macro = value_noise(world_position.xz * 0.055);
	float meso = value_noise(world_position.xz * 0.19 + 7.3);
	float leaf_mask = smoothstep(0.56, 0.82, meso + macro * 0.18);
	float shoreline_distance = length((world_position.xz - vec2(-8.0, -8.0)) / vec2(8.15, 5.65));
	float shoreline_mask = 1.0 - smoothstep(0.72, 1.08, shoreline_distance);
	float slope_mask = smoothstep(0.16, 0.72, terrain_slope);
	float wet_mask = clamp(max(shoreline_mask * 0.86, wetness * (0.22 + macro * 0.46)), 0.0, 1.0);
	float height_value = 0.5;
	if (detail_maps_enabled) {
		height_value = texture(height_texture, first_uv).r;
	}
	vec2 parallax = (VIEW.xz / max(abs(VIEW.y), 0.22)) * (height_value - 0.5) * 0.018;
	first_uv += parallax;
	second_uv += parallax * 0.72;

	vec3 base_dry = mix(
		texture(albedo_texture, first_uv).rgb,
		texture(dry_albedo_texture, second_uv).rgb,
		0.24 + macro * 0.42
	);
	vec3 base_wet = texture(wet_albedo_texture, first_uv * 1.18 + vec2(0.08, -0.12)).rgb;
	vec3 base_leaf = texture(leaf_albedo_texture, second_uv * 1.65).rgb;
	base_dry *= mix(vec3(0.67), earth_tint * 1.38, 0.3);
	base_wet *= mix(vec3(0.52), mud_tint * 1.44, 0.32);
	base_leaf *= mix(vec3(0.62), moss_tint * 1.32, 0.3);
	vec3 base = mix(base_dry, base_wet, wet_mask * (0.64 + slope_mask * 0.2));
	base = mix(base, base_leaf, leaf_mask * (1.0 - wet_mask * 0.58));

	vec3 normal_a = texture(normal_texture, first_uv).rgb;
	vec3 normal_b = texture(detail_normal_texture, second_uv * 2.2).rgb;
	NORMAL_MAP = mix(normal_a, normal_b, 0.28 + macro * 0.16);
	NORMAL_MAP_DEPTH = 0.66 + wetness * 0.16;

	float base_roughness = texture(roughness_texture, first_uv).r;
	float roughness = clamp(base_roughness * (1.06 - wet_mask * 0.42), 0.22, 1.0);
	float ao = 0.86 + macro * 0.12;
	float cavity = 0.94 + meso * 0.06;
	if (detail_maps_enabled) {
		ao = texture(ao_texture, first_uv).r;
		cavity = texture(cavity_texture, first_uv).r;
	}
	base *= 1.0 + (cavity - 0.5) * 0.12;

	ALBEDO = base;
	ROUGHNESS = roughness;
	AO = clamp(ao * cavity, 0.45, 1.0);
	SPECULAR = mix(0.32, 0.76, wet_mask);
	SPECULAR *= 1.0 + wetness * 0.18;
	EMISSION = wet_specular_tint * rain_intensity * wet_mask * 0.006;
}
