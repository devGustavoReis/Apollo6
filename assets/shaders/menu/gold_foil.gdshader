shader_type spatial;
// Manta térmica dourada do estágio de descida: facetas amassadas, cada uma com seu brilho.

uniform vec3 base : source_color = vec3(0.86, 0.62, 0.20);
uniform float cells = 5.0;

varying vec3 obj_pos;

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 p = obj_pos * cells;
	vec3 base_cell = floor(p);
	float best = 8.0;
	vec3 best_id = base_cell;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 id = base_cell + vec3(float(x), float(y), float(z));
				float dist = distance(p, id + hash33(id));
				if (dist < best) {
					best = dist;
					best_id = id;
				}
			}
		}
	}
	vec3 rnd = hash33(best_id + 7.7);
	ALBEDO = base * mix(0.62, 1.18, rnd.x);
	NORMAL = normalize(NORMAL + (rnd - 0.5) * 0.55);
	METALLIC = 0.25;
	ROUGHNESS = 0.45;
	SPECULAR = 0.6;
}
