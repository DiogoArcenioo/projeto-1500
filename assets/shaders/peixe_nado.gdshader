shader_type spatial;
render_mode cull_disabled;
// Natação dos peixes (etapa 12), sem esqueleto: onda lateral que cresce do focinho
// para a cauda (assets/models/peixes/peixes.glb mede 1 m; focinho em +Z, cauda em -Z).
uniform float fase = 0.0;        // avançada pelo script (velocidade da batida)
uniform float amplitude = 0.06;  // em fração do comprimento
uniform float curvatura = 0.0;   // curva lateral estática (virando)
uniform float arqueio = 0.0;     // corpo arqueado (debatendo fora da água)
uniform float molhado = 1.0;     // brilho da pele molhada

void vertex() {
	float s = clamp(0.5 - VERTEX.z, 0.0, 1.0);
	float onda = sin(fase - s * 5.5) * amplitude * (0.12 + s * s * 1.5);
	VERTEX.x += onda + curvatura * s * s * 0.45;
	VERTEX.y += arqueio * ((s - 0.45) * (s - 0.45) - 0.08) * 0.4;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = mix(0.6, 0.16, molhado);
	SPECULAR = 0.55;
	METALLIC = 0.15 * molhado;
}
