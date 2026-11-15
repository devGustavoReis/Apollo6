shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// Envelope de ar aquecido: forte junto ao escudo, transparente nas bordas, puxado para trás.
#include "res://assets/shaders/reentry/noise.gdshaderinc"

uniform float heat = 0.0;
uniform float flow = 0.0;      // tempo visual acumulado
uniform float opacity = 1.0;
uniform float length_fade = 1.6;

void fragment() {
	float v = 1.0 - UV.y;                 // 0 na frente (escudo), 1 no fim (o glTF inverte o V)
	float n = r_fbm(vec3(UV.x * 8.0, v * 4.0 - flow * 2.4, flow * 0.6));
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	// mais forte no contorno, quase transparente de frente: o casco continua visível no pico
	float edge = mix(0.18, 1.0, pow(1.0 - facing, 1.5));
	float along = pow(clamp(1.0 - v, 0.0, 1.0), length_fade);
	float a = heat * along * edge * (0.45 + 0.9 * n) * opacity;
	vec3 hot = vec3(1.0, 0.88, 0.55);
	vec3 orange = vec3(1.0, 0.45, 0.10);
	vec3 red = vec3(0.6, 0.12, 0.05);
	vec3 col = mix(hot, orange, smoothstep(0.0, 0.25, v));
	col = mix(col, red, smoothstep(0.35, 0.9, v));
	ALBEDO = col * a;
}
