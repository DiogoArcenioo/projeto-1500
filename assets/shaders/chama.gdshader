shader_type spatial;
global uniform float tempo_visual;
render_mode unshaded, cull_disabled;

uniform vec4 cor_base : source_color = vec4(1.0, 0.75, 0.12, 1.0);
uniform vec4 cor_ponta : source_color = vec4(1.0, 0.15, 0.02, 1.0);
uniform float fase = 0.0;

void vertex() {
	float t = UV.y;
	VERTEX.x += sin(tempo_visual * 3.5 + t * 6.0 + fase) * t * t * 0.13;
	VERTEX.z += cos(tempo_visual * 2.7 + t * 7.0 + fase) * t * 0.09;
	VERTEX.y *= 1.0 + sin(tempo_visual * 4.0 + fase) * 0.07 * t;
}

void fragment() {
	vec3 cor = mix(cor_base.rgb, cor_ponta.rgb, smoothstep(0.15, 1.0, UV.y));
	ALBEDO = cor;
	EMISSION = cor * (2.8 - UV.y * 0.8);
}
