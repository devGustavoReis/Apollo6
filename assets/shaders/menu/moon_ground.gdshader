shader_type spatial;
// Regolito lunar do menu principal: tons de cinza, grão e crateras pintados
// a partir da posição no mundo, sem texturas.

uniform vec3 sun_dir = vec3(0.74, 0.42, 0.52); // aponta para o Sol
uniform vec3 tint : source_color = vec3(0.72, 0.71, 0.70);

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x),
		mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + 17.0;
		a *= 0.5;
	}
	return v;
}

// Uma camada de crateras: a parede voltada para o Sol clareia e a oposta escurece.
float craters(vec2 p, float cell, vec2 sun2) {
	vec2 g = floor(p / cell);
	float shade = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = g + vec2(float(x), float(y));
			float pick = hash12(id + 91.7);
			if (pick < 0.45) {
				continue;
			}
			vec2 c = (id + 0.2 + hash22(id) * 0.6) * cell;
			float r = cell * mix(0.08, 0.36, pick * pick);
			vec2 d = p - c;
			float len = length(d);
			float dist = len / r;
			if (dist > 1.35) {
				continue;
			}
			float side = dot(d / max(len, 0.0001), sun2);
			float bowl = smoothstep(1.0, 0.75, dist);
			float wall = bowl * smoothstep(0.1, 0.8, dist);
			float rim = smoothstep(1.35, 1.05, dist) * smoothstep(0.8, 1.0, dist);
			shade += -0.09 * bowl - 0.30 * side * wall + 0.16 * side * rim + 0.05 * rim;
		}
	}
	return shade;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	vec2 sun2 = normalize(sun_dir.xz);
	float near = clamp(1.0 - dist / 45.0, 0.0, 1.0);
	float mid = clamp(1.0 - dist / 130.0, 0.0, 1.0);
	float tone = fbm(p * 0.07) * 0.6 + fbm(p * 0.45) * 0.4;
	float grain = (hash12(floor(p * 14.0)) - 0.5) * 0.30 * near + (vnoise(p * 3.0) - 0.5) * 0.18 * mid;
	float shade = craters(p, 7.0, sun2) * mid + craters(p + 31.0, 2.6, sun2) * near + craters(p + 77.0, 23.0, sun2);
	float v = 0.78 + (tone - 0.5) * 0.45 + grain + shade;
	ALBEDO = tint * clamp(v, 0.25, 1.25);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
