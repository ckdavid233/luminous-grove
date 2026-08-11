shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform vec3 shadow_color : source_color = vec3(0.055, 0.19, 0.095);
uniform vec3 mid_color : source_color = vec3(0.16, 0.39, 0.19);
uniform vec3 sun_color : source_color = vec3(0.39, 0.59, 0.25);
uniform sampler2D leaf_atlas : source_color, filter_linear, repeat_disable;
uniform bool leaf_atlas_enabled = false;
uniform float wind_strength = 0.075;
uniform float wetness : hint_range(0.0, 1.0) = 0.54;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.62;
uniform float leaf_contrast : hint_range(0.0, 2.0) = 1.18;
uniform float ambient_lift : hint_range(0.0, 0.35) = 0.0;
uniform bool dense_canopy = false;
varying vec3 world_position;
varying float height_tint;
varying vec4 instance_variation;
varying float wind_phase;


float hash31(vec3 point) {
	return fract(sin(dot(point, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}


void vertex() {
	instance_variation = INSTANCE_CUSTOM;
	float world_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	float height_weight = smoothstep(1.4, 7.8, world_height);
	wind_phase = MODEL_MATRIX[3].x * 0.27 + MODEL_MATRIX[3].z * 0.19
		+ instance_variation.b * 6.2831;
	float gust = sin(TIME * 0.48 + wind_phase * 0.63) * 0.55
		+ sin(TIME * 1.17 + wind_phase * 1.91) * 0.24;
	VERTEX.x += sin(TIME * 0.72 + wind_phase + VERTEX.z * 0.24) * wind_strength * height_weight;
	VERTEX.z += cos(TIME * 0.53 + wind_phase + VERTEX.x * 0.19) * wind_strength * 0.62 * height_weight;
	VERTEX.xz += vec2(gust, gust * 0.56) * wind_strength * height_weight * 0.36;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	height_tint = height_weight;
}


void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float variation = hash31(floor(world_position * 2.3) + vec3(instance_variation.rg, 0.0));
	float upward = clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 shaded = mix(shadow_color, mid_color, smoothstep(0.12, 0.88, upward));
	shaded = mix(shaded, sun_color, height_tint * (0.22 + variation * 0.28));
	if (leaf_atlas_enabled) {
		// The supplied atlas is laid out as four columns by six rows.  Picking a
		// cell per instance keeps neighboring cards from repeating the same
		// silhouette while the alpha cutout removes the rectangular card edge.
		vec2 cell_size = vec2(0.25, 1.0 / 6.0);
		vec2 atlas_index = vec2(
			floor(fract(instance_variation.b * 1.73) * 4.0),
			floor(fract(instance_variation.r * 2.11) * 6.0)
		);
		if (dense_canopy) {
			float dense_choice = floor(fract(instance_variation.b * 4.17) * 5.0);
			if (dense_choice < 1.0) {
				atlas_index = vec2(0.0, 1.0);
			} else if (dense_choice < 2.0) {
				atlas_index = vec2(1.0, 1.0);
			} else if (dense_choice < 3.0) {
				atlas_index = vec2(2.0, 1.0);
			} else if (dense_choice < 4.0) {
				atlas_index = vec2(0.0, 3.0);
			} else {
				atlas_index = vec2(2.0, 3.0);
			}
		}
		vec2 cell = atlas_index * cell_size;
		vec4 leaf_sample = texture(leaf_atlas, cell + fract(UV) * cell_size);
		if (leaf_sample.a < 0.08) {
			discard;
		}
		// Keep the atlas contour/vein detail but grade its pale back-lit colors
		// into the darker green canopy palette.
		vec3 atlas_green = leaf_sample.rgb * vec3(0.62, 0.86, 0.50);
		shaded = mix(shaded, shaded * (0.72 + atlas_green * 0.62), 0.34);
	}
	float center_line = 1.0 - smoothstep(0.0, 0.06, abs(UV.x - 0.5));
	float edge = smoothstep(0.015, 0.18, min(UV.x, 1.0 - UV.x));
	float serration = 0.92 + sin(UV.y * 24.0 + UV.x * 7.0) * 0.045;
	shaded = mix(shaded * 0.62, shaded * serration, edge);
	float vein = center_line * smoothstep(0.04, 0.2, UV.y)
		* (0.82 + 0.18 * sin(UV.y * 31.0 + UV.x * 3.0));
	shaded = mix(shaded, shaded * vec3(0.58, 0.72, 0.46), vein * 0.18);
	shaded = mix(shaded, sun_color * 0.88, center_line * 0.12);
	float warm_shift = (instance_variation.r - 0.5) * 0.18 + (variation - 0.5) * 0.1;
	shaded *= vec3(1.0 + warm_shift * 0.32, 1.0 + warm_shift * 0.16, 1.0 - warm_shift * 0.2);
	shaded = mix(shaded, shaded * vec3(0.72, 0.84, 0.79), wetness * 0.14);
	ALBEDO = pow(max(shaded, vec3(0.0)), vec3(0.94))
		* mix(0.78, 1.16, variation) * leaf_contrast;
	NORMAL_MAP = vec3(
		(sin(UV.y * 24.0 + UV.x * 4.0) * 0.08),
		(cos(UV.y * 18.0 - UV.x * 5.0) * 0.08),
		1.0
	);
	NORMAL_MAP_DEPTH = 0.24;
	ROUGHNESS = mix(0.88, 0.34, wetness * 0.72);
	SPECULAR = mix(0.24, 0.72, wetness);
	BACKLIGHT = mix(mid_color, sun_color, height_tint * 0.45)
		* (0.42 + rain_intensity * 0.2);
	// Layered canopy cards can face away from the key light.  A restrained
	// emissive lift keeps those leaves readable in shadow without flattening the
	// authored directional lighting on the detailed GLB leaves.
	EMISSION = ALBEDO * ambient_lift;
}
