shader_type canvas_item;
// Metal escovado do logotipo: degradê claro, faixas horizontais e um reflexo que varre as letras.

uniform float shine_period = 6.5;

void fragment() {
	float y = UV.y;
	vec3 col = mix(vec3(1.0), vec3(0.85, 0.86, 0.93), smoothstep(0.0, 0.45, y));
	col = mix(col, vec3(0.68, 0.70, 0.83), smoothstep(0.45, 1.0, y));
	col *= mix(1.0, 0.86, step(0.5, fract(y * 12.5)) * smoothstep(0.28, 0.5, y));
	col = mix(col, vec3(1.0), step(y, 0.07));
	col *= mix(1.0, 0.72, step(0.93, y));
	float sweep = UV.x - y * 0.06 - (fract(TIME / shine_period) * 2.2 - 0.5);
	col += smoothstep(0.07, 0.0, abs(sweep)) * 0.45;
	COLOR = vec4(col, COLOR.a);
}
