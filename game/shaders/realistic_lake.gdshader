shader_type spatial;
render_mode depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

// The lake intentionally uses bounded arrays so interaction cost is predictable.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_linear;

group_uniforms water_colors;
uniform vec3 shallow_color : source_color = vec3(0.12, 0.42, 0.43);
uniform vec3 deep_color : source_color = vec3(0.018, 0.12, 0.18);
uniform vec3 reflection_color : source_color = vec3(0.32, 0.56, 0.61);
uniform vec3 foam_color : source_color = vec3(0.78, 0.93, 0.88);
uniform vec3 caustic_color : source_color = vec3(0.27, 0.68, 0.62);
uniform vec3 ripple_color : source_color = vec3(0.47, 0.91, 0.86);

group_uniforms optics;
uniform float absorption = 0.72;
uniform float refraction_strength : hint_range(0.0, 0.08) = 0.018;
uniform float fresnel_power : hint_range(1.0, 10.0) = 5.0;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.075;
uniform float micro_normal_strength : hint_range(0.0, 1.0) = 0.28;
uniform float wetness : hint_range(0.0, 1.0) = 0.54;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.68;

group_uniforms waves;
uniform float wave_speed = 0.72;
uniform vec4 wave_1 = vec4(1.0, 0.15, 0.075, 5.8);
uniform vec4 wave_2 = vec4(-0.4, 1.0, 0.045, 3.1);
uniform vec4 wave_3 = vec4(0.7, -0.8, 0.025, 1.55);
uniform vec4 wave_4 = vec4(-0.9, -0.25, 0.015, 0.82);

group_uniforms shoreline;
uniform float foam_width : hint_range(0.01, 2.0) = 0.42;
uniform float foam_intensity : hint_range(0.0, 3.0) = 1.15;
uniform float caustic_intensity : hint_range(0.0, 3.0) = 0.2;

group_uniforms interaction;
uniform vec2 ripple_origins[32];
uniform float ripple_start_times[32];
uniform float ripple_strengths[32];
uniform float ripple_radii[32];
uniform float interaction_time = 0.0;
uniform float ripple_speed : hint_range(0.1, 4.0) = 1.65;
uniform float ripple_amplitude : hint_range(0.0, 0.3) = 0.065;
uniform float ripple_lifetime : hint_range(0.5, 8.0) = 4.8;
uniform float ripple_glow : hint_range(0.0, 2.0) = 0.72;

varying vec3 world_position;
varying float wave_elevation;
varying float interaction_strength;
varying float interaction_crest;


float hash21(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453123);
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


float gerstner_height(vec2 position, vec4 wave, float time) {
	vec2 direction = normalize(wave.xy);
	float wave_number = 2.0 * PI / wave.w;
	float phase_speed = sqrt(9.81 / wave_number);
	return wave.z * sin(wave_number * dot(direction, position) - phase_speed * time);
}


float lake_height(vec2 position, float time) {
	return gerstner_height(position, wave_1, time)
		+ gerstner_height(position, wave_2, time * 1.07)
		+ gerstner_height(position, wave_3, time * 0.93)
		+ gerstner_height(position, wave_4, time * 1.19);
}


float interaction_height(vec2 point, float time) {
	float height = 0.0;
	for (int index = 0; index < 32; index++) {
		float age = time - ripple_start_times[index];
		float active = step(0.0, age) * step(age, ripple_lifetime);
		float distance_from_origin = distance(point, ripple_origins[index]);
		float front_distance = distance_from_origin - age * ripple_speed * (0.82 + ripple_radii[index] * 0.16);
		float ring_envelope = exp(-front_distance * front_distance * 22.0);
		float temporal_decay = exp(-age * 0.72);
		float oscillation = sin(front_distance * 19.0);
		height += oscillation * ring_envelope * temporal_decay * active * ripple_amplitude * ripple_strengths[index];
	}
	return height;
}


float interaction_crest_mask(vec2 point, float time) {
	float mask = 0.0;
	for (int index = 0; index < 32; index++) {
		float age = time - ripple_start_times[index];
		float active = step(0.0, age) * step(age, ripple_lifetime);
		float distance_from_origin = distance(point, ripple_origins[index]);
		float front_distance = distance_from_origin - age * ripple_speed * (0.82 + ripple_radii[index] * 0.16);
		float crest = exp(-front_distance * front_distance * 15.0);
		float inner_ring = exp(-(front_distance + 0.18) * (front_distance + 0.18) * 24.0);
		mask = max(mask, max(crest, inner_ring * 0.62) * exp(-age * 0.38) * active * ripple_strengths[index]);
	}
	return clamp(mask, 0.0, 1.0);
}


void vertex() {
	float time = TIME * wave_speed;
	vec2 undeformed_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float interaction = interaction_height(undeformed_world_position, interaction_time);
	float height = lake_height(VERTEX.xz, time) + interaction;
	float epsilon = 0.08;
	float height_x = lake_height(VERTEX.xz + vec2(epsilon, 0.0), time);
	height_x += interaction_height(undeformed_world_position + vec2(epsilon, 0.0), interaction_time);
	float height_z = lake_height(VERTEX.xz + vec2(0.0, epsilon), time);
	height_z += interaction_height(undeformed_world_position + vec2(0.0, epsilon), interaction_time);
	VERTEX.y += height;
	NORMAL = normalize(vec3((height - height_x) / epsilon, 1.0, (height - height_z) / epsilon));
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wave_elevation = height;
	interaction_strength = clamp(abs(interaction) * 12.0, 0.0, 1.0);
	interaction_crest = interaction_crest_mask(undeformed_world_position, interaction_time);
}


float caustic_pattern(vec2 point, float time) {
	vec2 first = sin(point * vec2(3.1, 2.7) + vec2(time * 0.72, -time * 0.51));
	vec2 second = sin(point.yx * vec2(4.3, 3.7) + vec2(-time * 0.39, time * 0.61));
	float ridges = abs(first.x + first.y + second.x + second.y) * 0.25;
	return pow(clamp(1.0 - ridges, 0.0, 1.0), 7.0);
}


void fragment() {
	float ripple_x = sin(world_position.x * 4.7 + TIME * 0.83);
	ripple_x += sin(world_position.z * 7.3 - TIME * 1.07) * 0.55;
	float ripple_z = cos(world_position.z * 5.3 - TIME * 0.71);
	ripple_z += cos(world_position.x * 8.1 + TIME * 0.94) * 0.45;
	vec2 normal_a = vec2(ripple_x, ripple_z) * micro_normal_strength * 0.08;
	vec2 normal_b = vec2(
		sin(world_position.z * 11.0 - TIME * 1.32),
		cos(world_position.x * 12.4 + TIME * 1.08)
	) * micro_normal_strength * 0.045;
	NORMAL_MAP = vec3(mix(normal_a, normal_b, 0.38) * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = micro_normal_strength * (0.82 + wetness * 0.24);

	float radial = clamp(length((UV - vec2(0.5)) * 2.0), 0.0, 1.0);
	float center_depth = 1.0 - smoothstep(0.18, 0.92, radial);
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	float depth_edge = smoothstep(0.06, 0.34, 1.0 - scene_depth);
	vec2 refracted_uv = clamp(
		SCREEN_UV + mix(normal_a, normal_b, 0.42) * refraction_strength,
		vec2(0.001),
		vec2(0.999)
	);
	vec3 refracted_scene = textureLod(screen_texture, refracted_uv, 0.0).rgb;
	vec3 absorption_color = mix(shallow_color, deep_color, center_depth * absorption);
	vec3 transmitted = mix(absorption_color, refracted_scene * absorption_color * 1.28, 0.34);
	float caustic = caustic_pattern(world_position.xz * 1.25, TIME);
	transmitted += caustic_color * caustic * caustic_intensity * 0.12;

	float foam_noise = value_noise(world_position.xz * 2.8 + TIME * vec2(0.12, -0.09));
	float edge_mask = smoothstep(0.84, 0.985, radial);
	edge_mask *= smoothstep(0.44, 0.76, foam_noise + edge_mask * 0.2);
	float depth_foam = smoothstep(0.02, foam_width, depth_edge) * (0.52 + foam_noise * 0.48);
	float crest_mask = smoothstep(0.095, 0.15, wave_elevation) * foam_noise * 0.18;
	float ripple_foam = smoothstep(0.22, 0.72, interaction_crest) * (0.62 + foam_noise * 0.38);
	float foam = clamp((edge_mask + depth_foam * 0.7 + crest_mask + ripple_foam * 0.66) * foam_intensity, 0.0, 1.0);

	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	fresnel = mix(0.025, 1.0, fresnel);
	vec3 reflected = reflection_color * (0.78 + 0.22 * value_noise(world_position.xz * 0.18));
	vec3 final_color = mix(transmitted, reflected, fresnel * (0.56 + wetness * 0.22));
	final_color = mix(final_color, foam_color, foam);
	final_color = mix(final_color, foam_color, interaction_strength * 0.22);
	float ring_highlight = interaction_crest * ripple_glow;
	final_color += ripple_color * ring_highlight * (0.1 + rain_intensity * 0.08);

	ALBEDO = final_color;
	ROUGHNESS = mix(surface_roughness, 0.72, max(foam, ring_highlight * 0.35));
	ROUGHNESS = mix(ROUGHNESS, 0.035, wetness * 0.3);
	SPECULAR = 0.92;
	METALLIC = 0.0;
	EMISSION = ripple_color * ring_highlight * 0.035;
}
