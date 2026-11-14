shader_type spatial;
render_mode unshaded, cull_disabled;
// Bandeira deixada na superfície. As dobras são fixas: sem ar, o tecido não tremula.

varying float fold;

vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

void vertex() {
	float x = UV.x;
	float phase = x * 9.0 + UV.y * 2.5;
	VERTEX.z += (sin(phase) * 0.05 + sin(x * 4.0 - UV.y * 3.0) * 0.035) * x;
	// O tecido cede longe do mastro e a borda de baixo acompanha as dobras.
	VERTEX.y += sin(x * 7.5 + 0.6) * 0.05 * x * (0.4 + UV.y) - x * x * UV.y * 0.09;
	fold = cos(phase) * min(1.0, x * 3.0);
}

void fragment() {
	vec3 red = srgb(vec3(0.74, 0.14, 0.18));
	vec3 white = srgb(vec3(0.94, 0.93, 0.90));
	vec3 blue = srgb(vec3(0.17, 0.21, 0.47));
	vec3 col = mod(floor(UV.y * 13.0), 2.0) < 0.5 ? red : white;
	float canton_h = 7.0 / 13.0;
	if (UV.x < 0.4 && UV.y < canton_h) {
		col = blue;
		// 9 fileiras alternando 6 e 5 estrelas.
		vec2 c = vec2(UV.x / 0.4, UV.y / canton_h);
		float odd = mod(floor(c.y * 9.0), 2.0);
		float fx = c.x * 6.0 - odd * 0.5;
		vec2 cell = vec2(fract(fx), fract(c.y * 9.0)) - 0.5;
		if (fx > 0.0 && fx < 6.0 - odd && length(cell) < 0.30) {
			col = white;
		}
	}
	ALBEDO = col * (0.78 + fold * 0.24);
}
