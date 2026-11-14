shader_type canvas_item;
// Céu do menu: estrelas na grade de pixels do cenário, com cintilação.

uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float pixel = 2.0;

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

vec3 star_layer(vec2 px, float cell, float density, float seed) {
	vec2 id = floor(px / cell);
	float pick = hash12(id + seed);
	if (pick > density) {
		return vec3(0.0);
	}
	float kind = hash12(id + seed + 5.3);
	vec2 pos = id * cell + 3.0 + floor(hash22(id + seed * 1.7) * (cell - 6.0));
	vec2 d = abs(px - pos);
	float twinkle = 0.72 + 0.28 * sin(TIME * (0.6 + kind * 2.4) + pick * 190.0);
	vec3 tint = mix(vec3(0.78, 0.86, 1.0), vec3(1.0, 0.93, 0.80), hash12(id + seed + 11.1));
	float v = 0.0;
	if (kind > 0.94) {
		// Estrela com brilho em cruz.
		if (d.x < 0.5 && d.y < 0.5) {
			v = 1.0;
		} else if (d.y < 0.5 && d.x < 3.5) {
			v = 0.75 - d.x * 0.2;
		} else if (d.x < 0.5 && d.y < 3.5) {
			v = 0.75 - d.y * 0.2;
		}
	} else if (kind > 0.74) {
		if (d.x < 0.5 && d.y < 0.5) {
			v = 0.95;
		} else if (d.x + d.y < 1.5) {
			v = 0.32;
		}
	} else if (d.x < 0.5 && d.y < 0.5) {
		v = 0.3 + kind * 0.6;
	}
	return tint * v * twinkle;
}

void fragment() {
	vec2 px = floor(UV * view_size / pixel);
	vec3 col = mix(vec3(0.004, 0.006, 0.014), vec3(0.012, 0.016, 0.034), UV.y);
	col += star_layer(px, 22.0, 0.55, 0.0);
	col += star_layer(px, 37.0, 0.45, 40.0);
	COLOR = vec4(col, 1.0);
}
