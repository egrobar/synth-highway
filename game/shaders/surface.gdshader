// The road and the ground: a region's painted tile, made physically based in the shader.
//
// Every region paints one albedo tile (tools/themes/<id>/textures.py). From it this shader derives:
//   bump      normals from the tile's own shading (dark cracks, seams and joints sit lower), so the
//             headlights rake across real relief instead of a flat print
//   grain     a fine procedural normal grain, faded out with distance before it can shimmer
//   macro     two scales of slow variation in colour and roughness, so the tile never reads as a grid
//   anti_tile (ground) a second, rotated copy of the tile blended in by noise, breaking the repeat
//   wetness   damp darkening plus mirror-smooth puddles; with screen-space reflections on, the lights
//             and the notes reflect in them
// The surface scrolls with the road: `scroll` is set every frame by ThemeWorld, in tiles.
// Positions in the noise are in metres along the road, so the patterns travel with the surface.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_tex : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_roughness_tex = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float tile_metres = 10.0;  // ThemeWorld.ROAD_TILE: one tile of the texture, in metres
uniform float scroll = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float bump_strength = 1.6;
uniform float grain_strength = 0.35;
uniform float grain_frequency = 9.0;  // per metre
uniform float macro_strength = 0.16;
uniform bool anti_tile = false;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float puddle_frequency = 0.11;  // per metre
uniform vec4 puddle_tint : source_color = vec4(0.55, 0.55, 0.6, 1.0);
uniform float detail_fade = 70.0;  // metres from the camera where the fine detail has gone

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 3.7);
		amp *= 0.5;
	}
	return total;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// The tile, with a second rotated, shifted copy blended in where `mask` is high (ground only).
vec3 sample_tile(vec2 uv, float mask) {
	vec3 a = texture(albedo_tex, uv).rgb;
	if (!anti_tile) {
		return a;
	}
	vec2 uv2 = vec2(uv.x * 0.8 - uv.y * 0.6, uv.x * 0.6 + uv.y * 0.8) * 0.71 + vec2(0.37, 0.61);
	vec3 b = texture(albedo_tex, uv2).rgb;
	// Keep the overall brightness: the blend only shuffles detail.
	b *= luma(a) / max(luma(b), 0.001) * 0.5 + 0.5;
	return mix(a, b, mask);
}

void fragment() {
	vec2 uv = UV * uv_scale + vec2(0.0, scroll);
	vec2 metres = uv * tile_metres;
	float dist = length(VERTEX);
	float near = clamp(1.0 - dist / detail_fade, 0.0, 1.0);

	float tile_mask = anti_tile ? smoothstep(0.35, 0.65, fbm(metres * 0.045 + 5.0)) : 0.0;
	vec3 base = sample_tile(uv, tile_mask);

	// Relief from the tile's own shading, sampled one screen footprint apart so far away it softens
	// with the mip chain instead of sparkling.
	vec2 texel = 1.0 / vec2(textureSize(albedo_tex, 0));
	vec2 step_uv = max(fwidth(uv), texel);
	float h0 = luma(base);
	float hx = luma(sample_tile(uv + vec2(step_uv.x, 0.0), tile_mask));
	float hy = luma(sample_tile(uv + vec2(0.0, step_uv.y), tile_mask));
	vec2 slope = vec2(hx - h0, hy - h0) / (step_uv / texel) * bump_strength * 6.0;

	// Fine grain, gone by detail_fade.
	vec2 gp = metres * grain_frequency;
	float g0 = noise(gp);
	vec2 grain = vec2(noise(gp + vec2(0.37, 0.0)) - g0, noise(gp + vec2(0.0, 0.37)) - g0) * grain_strength * 2.4 * near;

	// Slow variation in colour and roughness, at two scales.
	float macro = fbm(metres * 0.06) * 0.65 + fbm(metres * 0.21 + 11.0) * 0.35;
	vec3 colour = base * tint.rgb * (1.0 + (macro - 0.5) * 2.0 * macro_strength);
	float rough = use_roughness_tex ? texture(roughness_tex, uv).r * roughness : roughness;
	rough = clamp(rough + (macro - 0.5) * 0.25, 0.04, 1.0);

	// Damp patches darken and go glossy; the deepest become standing water: dark, flat, a mirror.
	float puddle = 0.0;
	if (wetness > 0.0) {
		float wet_field = fbm(metres * puddle_frequency + vec2(3.1, 8.7)) + (h0 - 0.5) * 0.25;
		float damp = smoothstep(0.62 - wetness * 0.45, 0.78 - wetness * 0.45, wet_field);
		puddle = smoothstep(0.7 - wetness * 0.3, 0.74 - wetness * 0.3, wet_field);
		colour *= mix(1.0, 0.82, damp);
		colour = mix(colour, colour * puddle_tint.rgb, puddle);
		rough = mix(rough, rough * 0.45, damp);
		rough = mix(rough, 0.03, puddle);
	}

	vec2 tilt = (slope + grain) * (1.0 - puddle);
	vec3 n = normalize(vec3(-tilt.x, -tilt.y, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	ALBEDO = colour;
	ROUGHNESS = rough;
	// Standing water reflects more than the road: seen from the driver's height, at specular 0.5
	// the puddles read as dark stains instead of mirrors.
	SPECULAR = mix(specular, 1.0, puddle);
	METALLIC = metallic;
	// Crevices take a little less light: cheap cavity occlusion from the same relief.
	AO = clamp(0.75 + h0 * 0.6, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.25;
}
