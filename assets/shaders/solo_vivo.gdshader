shader_type spatial;
render_mode diffuse_burley;

varying vec3 mundo;
uniform vec2 centro_clareira = vec2(0.0);

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1,0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0,1), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1,1), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment() {
	vec2 p = mundo.xz;
	float r = length(p - centro_clareira);
	float n = ruido(p * 0.45);
	float detalhe = ruido(p * 3.0);
	float vegetacao = smoothstep(7.0, 15.5, r + n * 3.2 - 1.6);
	float rio = 17.0 + 3.2 * sin(-p.y * 0.075) + 1.3 * sin(-p.y * 0.17);
	float margem = abs(p.x-rio);
	vegetacao *= smoothstep(3.7,6.1,margem);
	vec3 terra = mix(vec3(0.29,0.105,0.043), vec3(0.48,0.255,0.095), n);
	vec3 verde = mix(vec3(0.045,0.15,0.063), vec3(0.13,0.25,0.078), n);
	vec3 areia = vec3(0.37,0.27,0.14);
	terra = mix(terra,areia, (1.0-smoothstep(3.0,5.3,margem))*.65);
	ALBEDO = mix(terra,verde,vegetacao) * (0.94+detalhe*0.12);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
