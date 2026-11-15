shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
// Mancha de espuma da amerissagem: anel que se expande e perde intensidade.
#include "res://assets/shaders/reentry/noise.gdshaderinc"

uniform float life = 0.0; // 0 = contato, 1 = espuma dissolvida

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float n = r_fbm(vec3(UV * 14.0, life * 2.0));
	float ring = smoothstep(0.35, 0.85, r) * (1.0 - smoothstep(0.85, 1.0, r));
	float inner = (1.0 - smoothstep(0.0, 0.7, r)) * 0.5;
	ALBEDO = vec3(0.9, 0.95, 0.97);
	ALPHA = clamp((ring + inner) * (0.4 + n) * (1.0 - life), 0.0, 1.0) * 0.85;
}
