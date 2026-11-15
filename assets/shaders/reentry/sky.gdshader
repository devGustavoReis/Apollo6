shader_type sky;
// Céu da reentrada: espaço escuro com poucas estrelas no alto, azul vivo perto do mar.
#include "res://assets/shaders/reentry/noise.gdshaderinc"

uniform float low = 0.0; // 0 = espaço, 1 = baixa altitude
uniform vec3 sun_dir = vec3(-0.4, 0.6, 0.5);

void sky() {
	float up = EYEDIR.y;
	vec3 space = mix(vec3(0.004, 0.007, 0.02), vec3(0.02, 0.05, 0.13), smoothstep(0.35, -0.05, up));
	vec3 day_zenith = vec3(0.07, 0.19, 0.44);
	vec3 day_horizon = vec3(0.38, 0.52, 0.68);
	vec3 day = mix(day_horizon, day_zenith, smoothstep(-0.02, 0.55, up));
	vec3 col = mix(space, day, low);
	// estrelas poucas e suaves, somem com a atmosfera
	vec3 cell = floor(EYEDIR * 180.0);
	float star = step(0.9965, r_hash(cell)) * (0.35 + 0.65 * r_hash(cell + 7.0));
	col += vec3(star) * (1.0 - low) * smoothstep(-0.1, 0.25, up) * 0.8;
	// brilho do Sol
	float s = max(dot(EYEDIR, normalize(sun_dir)), 0.0);
	col += vec3(1.0, 0.95, 0.85) * (pow(s, 600.0) * 3.0 + pow(s, 12.0) * 0.12 * (0.4 + low));
	COLOR = col;
}
