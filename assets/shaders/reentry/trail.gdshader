shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Filamentos do rastro: afinam e perdem brilho com a distância, com oscilação leve.
#include "res://assets/shaders/reentry/noise.gdshaderinc"

uniform float heat = 0.0;
uniform float flow = 0.0;
uniform float reach = 1.0; // comprimento visível do rastro (0..1)

void vertex() {
	float v = 1.0 - UV.y; // o glTF inverte o V
	VERTEX.x += sin(v * 9.0 + flow * 7.0 + VERTEX.z) * 0.12 * v;
	VERTEX.z += cos(v * 7.0 + flow * 6.0 + VERTEX.x) * 0.12 * v;
}

void fragment() {
	float v = 1.0 - UV.y;
	float across = 1.0 - abs(UV.x * 2.0 - 1.0);
	float streak = r_noise(vec3(UV.x * 3.0, v * 10.0 - flow * 6.0, 0.0));
	float visible = 1.0 - smoothstep(reach * 0.7, reach, v);
	float a = heat * pow(1.0 - v, 1.3) * across * (0.35 + 0.8 * streak) * visible;
	vec3 col = mix(vec3(1.0, 0.8, 0.45), vec3(0.9, 0.25, 0.08), smoothstep(0.0, 0.7, v));
	ALBEDO = col * a * 1.4;
}
