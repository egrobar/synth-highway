// Roadside props, weathered. ThemeWorld swaps each prop's plain (opaque, unlit-by-itself) glTF
// material for this one at build time, keeping its colour, roughness, metalness and texture, and adds:
//   grime   dirt collected toward the ground and run down vertical faces in streaks
//   dust    a fine layer settled on upward faces, in the region's dust colour
//   grain   procedural surface relief, so flat panels catch the headlights unevenly
//   mottle  slow variation in colour and roughness across a surface
//   detail  a surface map from the shared library (tools/gimp/surfaces.py: hull plating, concrete,
//           rock, grating...) projected from three sides (triplanar) in model space: its tone
//           modulates the colour and its slopes become relief (seams sink, rivets stand up)
// All the noise is 3D and in the model's own space, so it needs no UV unwrap or tangents, never
// swims as the scenery scrolls past, and copies of one prop each get their own pattern from the
// instance's position (INSTANCE_CUSTOM is not needed).
// Emissive, see-through and unshaded materials are left alone (lights, glass, beacons, lava).
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, hint_default_white;
uniform bool use_albedo_tex = false;
uniform bool use_vertex_color = false;
uniform float roughness : hint_range(0.0, 1.0) = 0.8;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform vec4 grime_color : source_color = vec4(0.16, 0.12, 0.1, 1.0);
uniform float grime = 0.35;
uniform float grime_height = 1.6;  // metres up from the model's base that ground dirt reaches
uniform vec4 dust_color : source_color = vec4(0.6, 0.5, 0.42, 1.0);
uniform float dust = 0.25;
uniform float grain = 0.3;
uniform float grain_frequency = 6.0;  // per metre
uniform float mottle = 0.12;
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_detail = false;
uniform float detail_scale = 0.33;  // map tiles per metre
uniform float detail_tone = 0.6;  // how far the map's light and dark push the colour
uniform float detail_bump = 1.0;  // relief from the map's slopes
uniform float detail_rough = 0.35;  // recessed (dark) parts of the map are rougher

varying vec3 obj_pos;
varying vec3 obj_normal;
varying vec3 seed;

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), u.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), u.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

// One of the three triplanar projections: adds its weighted tone, and its slope as a model-space
// gradient along the projection's two axes. Slopes are measured one screen footprint apart, so far
// away the relief softens with the mip chain instead of sparkling.
void project(vec2 uv, float weight, vec3 axis_u, vec3 axis_v, inout float tone, inout vec3 grad) {
	if (weight < 0.01) {
		return;
	}
	vec2 texel = 1.0 / vec2(textureSize(detail_tex, 0));
	vec2 step_uv = max(fwidth(uv), texel);
	float h0 = texture(detail_tex, uv).r;
	float hu = texture(detail_tex, uv + vec2(step_uv.x, 0.0)).r;
	float hv = texture(detail_tex, uv + vec2(0.0, step_uv.y)).r;
	vec2 slope = vec2(hu - h0, hv - h0) / (step_uv / texel);
	tone += h0 * weight;
	grad += (axis_u * slope.x + axis_v * slope.y) * weight;
}


float fbm3(vec3 p) {
	return noise3(p) * 0.55 + noise3(p * 2.1 + 7.3) * 0.3 + noise3(p * 4.3 + 1.9) * 0.15;
}

void vertex() {
	obj_pos = VERTEX;
	obj_normal = NORMAL;
	// Each copy (a MultiMesh instance or a placed node) gets its own offset into the noise. Its
	// position along the road changes as it scrolls, so only the sideways and vertical parts are used.
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	seed = vec3(origin.x * 1.7, origin.y, origin.x * 0.61) + vec3(float(INSTANCE_ID) * 13.7);
}

void fragment() {
	vec3 p = obj_pos + seed;
	vec3 base = albedo.rgb;
	if (use_albedo_tex) {
		base *= texture(albedo_tex, UV).rgb;
	}
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	float up = obj_normal.y;

	float m = fbm3(p * 0.45);
	vec3 colour = base * (1.0 + (m - 0.5) * 2.0 * mottle);
	float rough = clamp(roughness + (m - 0.5) * 0.2, 0.04, 1.0);

	// Ground dirt: thickest at the base, ragged at its top edge.
	float low = 1.0 - smoothstep(0.0, grime_height, obj_pos.y + (noise3(p * 1.3) - 0.5) * grime_height * 0.6);
	// Streaks: noise stretched tall, only on faces that stand up.
	float streak = smoothstep(0.55, 0.85, noise3(vec3(p.x * 5.0, p.y * 0.35, p.z * 5.0))) * (1.0 - abs(up));
	float dirt = clamp((low * 0.85 + streak * 0.5) * grime * (0.6 + 0.8 * noise3(p * 2.7)), 0.0, 1.0);
	colour = mix(colour, colour * grime_color.rgb * 2.2, dirt);
	rough = mix(rough, 1.0, dirt * 0.6);
	// Dust on anything facing up.
	float settle = smoothstep(0.45, 0.95, up) * smoothstep(0.35, 0.7, fbm3(p * 1.8)) * dust;
	colour = mix(colour, dust_color.rgb, settle);
	rough = mix(rough, 0.95, settle);

	// Relief: gradients in model space (procedural grain, plus the surface map's slopes), turned
	// into view space and tilted into the normal.
	vec3 gp = p * grain_frequency;
	float g0 = noise3(gp);
	float near = clamp(1.0 - length(VERTEX) / 90.0, 0.0, 1.0);
	vec3 grad = (vec3(noise3(gp + vec3(0.2, 0, 0)), noise3(gp + vec3(0, 0.2, 0)), noise3(gp + vec3(0, 0, 0.2))) - g0) * grain * 6.0 * near;
	if (use_detail) {
		vec3 w = pow(abs(normalize(obj_normal)), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 q = (obj_pos + vec3(seed.x, 0.0, seed.z) * 0.37) * detail_scale;
		float tone = 0.0;
		vec3 detail_grad = vec3(0.0);
		project(q.zy, w.x, vec3(0, 0, 1), vec3(0, 1, 0), tone, detail_grad);
		project(q.xz, w.y, vec3(1, 0, 0), vec3(0, 0, 1), tone, detail_grad);
		project(q.xy, w.z, vec3(1, 0, 0), vec3(0, 1, 0), tone, detail_grad);
		// The map's own average (its smallest mip) is neutral, whatever its overall brightness.
		float mean = textureLod(detail_tex, vec2(0.5), 12.0).r;
		colour *= clamp(1.0 + (tone - mean) * 2.0 * detail_tone, 0.0, 2.0);
		rough = clamp(rough + (mean - tone) * detail_rough, 0.04, 1.0);
		grad += detail_grad * detail_bump * 20.0;
	}
	vec3 grad_view = (VIEW_MATRIX * MODEL_MATRIX * vec4(grad, 0.0)).xyz;
	vec3 n = NORMAL;
	vec3 along = grad_view - dot(grad_view, n) * n;
	NORMAL = normalize(n - along);

	ALBEDO = colour;
	ROUGHNESS = rough;
	METALLIC = metallic * (1.0 - dirt * 0.7) * (1.0 - settle);
	SPECULAR = specular;
	AO = 1.0 - low * 0.35;
	AO_LIGHT_AFFECT = 0.2;
}
