shader_type spatial;
// Escudo térmico: grafite com variação de carvão e marrom; brilho de calor concentrado na borda.
#include "res://assets/shaders/reentry/noise.gdshaderinc"

uniform float heat = 0.0;  // 0..1, intensidade atual da reentrada
uniform float burn = 0.0;  // 0..1, quanto o escudo já foi aquecido (manchas que ficam)
uniform float flicker = 0.0;

void fragment() {
	vec2 q = UV - vec2(0.5);
	float r = length(q) * 2.0;           // 0 no centro, ~1 na borda
	float ang = atan(q.y, q.x);
	float grain = r_fbm(vec3(UV * 18.0, 0.0));
	float streak = r_noise(vec3(ang * 6.0, r * 3.0, 2.0));
	vec3 charcoal = vec3(0.10, 0.085, 0.075);
	vec3 warm = vec3(0.26, 0.19, 0.14);
	vec3 col = mix(charcoal, warm, grain * 0.7 + streak * 0.2);
	col = mix(col, col * 0.55, burn * smoothstep(0.3, 1.0, r) * (0.6 + 0.4 * streak));
	ALBEDO = col;
	ROUGHNESS = mix(0.82, 0.97, smoothstep(0.6, 1.0, r) + burn * 0.3);
	float rim = smoothstep(0.62, 0.98, r);
	float glow = heat * (rim * (0.75 + 0.5 * r_noise(vec3(ang * 9.0, flicker, 1.0))) + 0.18 * grain * (1.0 - rim));
	EMISSION = mix(vec3(1.0, 0.42, 0.08), vec3(1.0, 0.86, 0.5), rim * heat * 0.6) * glow * 1.7;
}
