shader_type spatial;
global uniform float tempo_visual;
render_mode cull_disabled;

uniform sampler2D textura_profundidade : hint_depth_texture, repeat_disable, filter_nearest;

uniform vec4 agua_profunda : source_color = vec4(0.03, 0.46, 0.48, 1.0);
uniform vec4 agua_clara : source_color = vec4(0.14, 0.76, 0.64, 1.0);
varying vec3 posicao_mundo;

void vertex() {
	posicao_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += 0.025 * sin(VERTEX.z * 1.8 + VERTEX.x * 1.2 + tempo_visual * 1.1);
}

void fragment() {
	vec2 p = posicao_mundo.xz;
	float ondas = sin(p.y * 2.8 + sin(p.x * 1.5 + tempo_visual * 0.3) * 1.1 + tempo_visual * 0.9);
	float detalhe = sin(p.y * 9.0 + p.x * 4.0 + tempo_visual * 1.6);
	float profundidade = texture(textura_profundidade, SCREEN_UV).r;
	vec4 fundo = INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,profundidade,1.0);
	float distancia_fundo = max(0.0,-fundo.z/fundo.w+VERTEX.z);
	float raso = 1.0-smoothstep(0.05,1.7,distancia_fundo);
	float fita = smoothstep(0.97, 0.999, ondas) * smoothstep(0.0,0.8,detalhe) * 0.11;
	vec3 cor = mix(agua_profunda.rgb, agua_clara.rgb, 0.20 + raso * 0.65 + ondas * 0.05);
	float espuma = (1.0-smoothstep(0.025,0.16,distancia_fundo)) * (0.45+ondas*.1);
	ALBEDO = mix(cor + fita * vec3(0.25,0.34,0.20), vec3(0.70,0.83,0.63), espuma);
	NORMAL_MAP = vec3(0.5 + ondas * 0.018, 0.5 + detalhe * 0.012, 1.0);
	ROUGHNESS = 0.16;
	METALLIC = 0.18;
	SPECULAR = 0.7;
	ALPHA = 0.96;
}
