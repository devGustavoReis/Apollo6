shader_type spatial;
render_mode unshaded;
// Terra vista da Lua: continentes vindos de uma máscara de baixa resolução,
// com litoral, relevo e nuvens gerados por ruído.

uniform sampler2D land_mask : filter_linear, repeat_enable;
uniform vec3 sun_dir = vec3(0.74, 0.42, 0.52); // mundo, aponta para o Sol
uniform float lon_shift = 0.0;                 // fração de volta que centraliza o continente
uniform float spin = 0.0006;                   // voltas por segundo

varying vec3 local_dir;
varying vec3 world_normal;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
		mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y);
	float b = mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
		mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p = p * 2.02 + 11.3;
		a *= 0.5;
	}
	return v;
}

vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

// Máscara borrada em 9 amostras, para o litoral não sair em degraus.
float soft_mask(vec2 uv) {
	vec2 t = vec2(1.0 / 180.0, 1.0 / 90.0) * 0.8;
	float m = texture(land_mask, uv).r * 0.25;
	m += (texture(land_mask, uv + vec2(t.x, 0.0)).r + texture(land_mask, uv - vec2(t.x, 0.0)).r
		+ texture(land_mask, uv + vec2(0.0, t.y)).r + texture(land_mask, uv - vec2(0.0, t.y)).r) * 0.125;
	m += (texture(land_mask, uv + t).r + texture(land_mask, uv - t).r
		+ texture(land_mask, uv + vec2(t.x, -t.y)).r + texture(land_mask, uv + vec2(-t.x, t.y)).r) * 0.0625;
	return m;
}

void vertex() {
	local_dir = normalize(VERTEX);
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float turn = lon_shift + TIME * spin;
	vec2 uv = vec2(fract(UV.x + turn), UV.y);
	// Gira o ponto de amostragem do ruído junto com a máscara.
	float a = turn * TAU;
	vec3 d = normalize(local_dir);
	vec3 p = vec3(d.x * cos(a) + d.z * sin(a), d.y, d.z * cos(a) - d.x * sin(a));
	float lat = abs(d.y); // seno da latitude

	float mask = soft_mask(uv);
	float land = smoothstep(0.47, 0.53, mask + (fbm3(p * 7.0) - 0.5) * 0.55);
	float n1 = fbm3(p * 5.0 + 3.1);
	float n2 = fbm3(p * 11.0 + 9.7);

	vec3 forest = srgb(vec3(0.13, 0.37, 0.17));
	vec3 grass = srgb(vec3(0.38, 0.52, 0.23));
	vec3 desert = srgb(vec3(0.76, 0.64, 0.41));
	float dry = smoothstep(0.26, 0.42, lat) * smoothstep(0.62, 0.48, lat);
	vec3 ground = mix(forest, grass, smoothstep(0.35, 0.65, n1));
	ground = mix(ground, desert, clamp(dry * 0.85 + (n2 - 0.55) * 1.2, 0.0, 1.0));
	vec3 sea = mix(srgb(vec3(0.05, 0.15, 0.46)), srgb(vec3(0.12, 0.36, 0.74)),
		smoothstep(0.3, 0.75, n1 * 0.6 + mask * 1.2));
	vec3 color = mix(sea, ground, land);

	float ice_land = smoothstep(0.85, 0.92, lat + (n2 - 0.5) * 0.12);
	float ice_sea = smoothstep(0.94, 0.975, lat + (n2 - 0.5) * 0.05);
	color = mix(color, srgb(vec3(0.93, 0.95, 0.98)), mix(ice_sea, ice_land, land));

	vec3 cp = p * 4.6 + vec3(TIME * 0.004, 0.0, TIME * 0.002);
	float warp = fbm3(cp * 1.7 + 4.0);
	float cloud = smoothstep(0.56, 0.72, fbm3(cp + vec3(warp * 1.3, lat * 2.0, warp)));
	color = mix(color, srgb(vec3(0.96, 0.97, 1.0)), cloud * 0.85);

	float day = smoothstep(-0.12, 0.30, dot(normalize(world_normal), normalize(sun_dir)));
	color *= mix(0.03, 1.0, day);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	color += srgb(vec3(0.35, 0.60, 1.0)) * rim * 0.7 * day;
	ALBEDO = color;
}
