shader_type spatial;
global uniform float tempo_visual;
render_mode cull_disabled, diffuse_burley;

uniform vec4 cor_folha : source_color = vec4(0.15, 0.45, 0.25, 1.0);
uniform float amplitude = 0.06;
varying float luz_variada;

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float vento = sin(p.x * 0.31 + p.z * 0.26 + tempo_visual * 0.72);
	float detalhe = sin(p.x * 1.9 - p.z * 0.7 + tempo_visual * 1.8);
	VERTEX.x += (vento + detalhe * 0.2) * amplitude;
	VERTEX.z += vento * amplitude * 0.35;
	luz_variada = sin(p.x * 0.7 + p.y * 0.5 + p.z * 0.4) * 0.07;
}

void fragment() {
	ALBEDO = cor_folha.rgb * (1.0 + luz_variada);
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
	BACKLIGHT = cor_folha.rgb * 0.23;
}
