shader_type canvas_item;
// Reduz a paleta do cenário 3D com pontilhado ordenado, para o render parecer pixel art.

uniform float levels = 14.0;
uniform float dither = 1.0;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 p = ivec2(UV / TEXTURE_PIXEL_SIZE);
	float threshold = BAYER[(p.x & 3) + (p.y & 3) * 4] / 16.0 - 0.5;
	vec3 q = floor(c.rgb * levels + 0.5 + threshold * dither) / levels;
	COLOR = vec4(q, c.a);
}
