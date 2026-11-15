shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;
// Faixa atmosférica azul no limbo da Terra, vista do espaço.

uniform float strength = 1.0;
uniform vec3 tint = vec3(0.35, 0.62, 1.0);

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float band = pow(rim, 6.0) * 1.6 + pow(rim, 24.0) * 2.0;
	ALBEDO = tint * band * strength;
}
