shader_type spatial;
global uniform float tempo_visual;
uniform float intensidade_luz : hint_range(0.0,1.0) = 1.0;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

void fragment() {
	float borda = pow(max(0.0,1.0-abs(UV.x*2.0-1.0)), 2.5);
	float comprimento = sin(UV.y*3.14159265);
	float po = 0.9 + 0.1*sin(UV.y*30.0 + tempo_visual*0.18);
	ALBEDO = vec3(1.0,0.77,0.36);
	ALPHA = borda*comprimento*po*0.06*intensidade_luz;
}
