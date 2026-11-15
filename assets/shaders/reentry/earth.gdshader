shader_type spatial;
// Terra vista na reentrada: oceano com nuvens em massas grandes; ondas perto da amerissagem.
#include "res://assets/shaders/reentry/noise.gdshaderinc"

uniform float scroll = 0.0;       // rotação aparente da superfície (velocidade em relação ao solo)
uniform float cloud_cover = 0.55; // cobertura das nuvens vistas do alto
uniform float cloud_fade = 1.0;   // some ao chegar perto do mar
uniform float waves = 0.0;        // 0 = longe, 1 = ondas visíveis
uniform float wave_time = 0.0;
uniform vec3 deep = vec3(0.02, 0.10, 0.22);
uniform vec3 shallow = vec3(0.07, 0.26, 0.42);

varying vec3 obj_dir;
varying vec3 world_pos;

void vertex() {
	obj_dir = normalize(VERTEX);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float c = cos(scroll), s = sin(scroll);
	vec3 d = vec3(c * obj_dir.x - s * obj_dir.y, s * obj_dir.x + c * obj_dir.y, obj_dir.z);
	float big = r_fbm(d * 7.0);
	float cloud = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, r_fbm(d * 24.0 + vec3(big * 2.0)));
	cloud *= cloud_fade;
	vec3 sea = mix(deep, shallow, big * 0.6);
	// ondas: ruído no espaço do mundo, amplo e fino
	vec2 p = world_pos.xz;
	float w1 = r_noise(vec3(p * 0.09, wave_time * 0.25));
	float w2 = r_noise(vec3(p * 0.45 + 13.0, wave_time * 0.6));
	float dx = (r_noise(vec3((p + vec2(0.6, 0.0)) * 0.45 + 13.0, wave_time * 0.6)) - w2) * 1.5 + (r_noise(vec3((p + vec2(2.0, 0.0)) * 0.09, wave_time * 0.25)) - w1);
	float dz = (r_noise(vec3((p + vec2(0.0, 0.6)) * 0.45 + 13.0, wave_time * 0.6)) - w2) * 1.5 + (r_noise(vec3((p + vec2(0.0, 2.0)) * 0.09, wave_time * 0.25)) - w1);
	vec3 n_world = normalize(vec3(-dx * 0.9 * waves, 1.0, -dz * 0.9 * waves));
	vec3 n_view = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, n_view, waves));
	sea += vec3(0.05, 0.08, 0.09) * smoothstep(0.62, 0.8, w2) * waves;
	ALBEDO = mix(sea, vec3(0.92, 0.94, 0.97), cloud);
	ROUGHNESS = mix(0.32, 1.0, cloud);
	SPECULAR = mix(0.55, 0.1, cloud);
}
