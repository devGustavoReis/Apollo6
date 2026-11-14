shader_type canvas_item;
// Filtro de televisor antigo aplicado sobre a tela inteira do menu:
// curvatura leve, linhas de varredura, franja de cor, brilho, ruído e vinheta.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float curvature = 0.03;
uniform float scanlines = 0.26;
uniform float aberration = 0.8;
uniform float glow = 0.18;
uniform float grain = 0.04;
uniform float vignette = 0.30;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 c = SCREEN_UV * 2.0 - 1.0;
	c += c * c.yx * c.yx * curvature;
	vec2 uv = c * 0.5 + 0.5;

	vec2 fringe = c * aberration * px;
	vec3 col = vec3(
		texture(screen_tex, uv + fringe).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - fringe).b);

	// Brilho: média de vizinhos, somada onde a imagem é clara.
	vec3 halo = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7854;
		halo += texture(screen_tex, uv + vec2(cos(ang), sin(ang)) * px * 4.0).rgb;
	}
	halo *= 0.125;
	col = mix(col, max(col, halo), 0.10) + halo * halo * glow;

	// Linhas de varredura em pixels inteiros da janela, para não formar moiré.
	float period = max(2.0, floor(0.5 + 1.0 / (px.y * 240.0)));
	float line = fract(FRAGCOORD.y / period);
	col *= 1.0 - scanlines * smoothstep(0.45, 0.95, line);
	col *= 1.0 + 0.035 * sin(FRAGCOORD.x * 2.0944);

	col += (hash12(FRAGCOORD.xy + fract(TIME) * 311.0) - 0.5) * grain;
	col *= 1.0 + 0.012 * sin(TIME * 97.0);
	col += 0.012 * smoothstep(0.12, 0.0, abs(fract(uv.y - TIME * 0.07) - 0.5));

	vec2 v = uv * (1.0 - uv);
	col *= mix(1.0 - vignette, 1.0, clamp(pow(16.0 * v.x * v.y, 0.22), 0.0, 1.0));
	col = col * 0.97 + vec3(0.010, 0.011, 0.016);

	// Cantos arredondados do tubo.
	vec2 edge = abs(c) - (1.0 - 0.045);
	float corner = length(max(edge, 0.0)) - 0.045;
	col *= smoothstep(0.004, -0.004, corner);
	COLOR = vec4(col, 1.0);
}
