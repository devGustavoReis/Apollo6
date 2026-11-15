shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Camada de nuvens próxima: massas brancas com sombra azulada, bordas suaves e
// transparência perto da câmera para não esconder a cápsula ao atravessar.
#include "res://assets/shaders/reentry/noise.gdshaderinc"

uniform float coverage = 0.5;
uniform float seed = 0.0;
uniform float visibility = 1.0;
uniform vec2 drift = vec2(0.0);

varying float cam_dist;

void vertex() {
	cam_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec2 uv = UV + drift;
	float n = r_fbm(vec3(uv * 9.0, seed));
	float shape = smoothstep(1.0 - coverage, 1.0 - coverage + 0.18, n);
	float radial = 1.0 - smoothstep(0.3, 0.5, length(UV - vec2(0.5)));
	float near = smoothstep(1.5, 14.0, cam_dist);
	float light = r_fbm(vec3(uv * 9.0 + vec2(0.02, 0.03), seed));
	vec3 col = mix(vec3(0.62, 0.70, 0.82), vec3(0.97, 0.98, 1.0), clamp((n - light) * 6.0 + 0.6, 0.0, 1.0));
	ALBEDO = col;
	// vista por baixo, a camada fica mais rala para não apagar o céu e o HUD
	ALPHA = shape * radial * near * visibility * (FRONT_FACING ? 0.9 : 0.32);
}
