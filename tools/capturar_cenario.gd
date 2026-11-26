extends SceneTree
## Captura e medição internas; nenhuma interface de gameplay é adicionada.

func _initialize() -> void:
	call_deferred("capturar")

func capturar() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vista := "Geral"
	var preset := "alto"
	var sem_sombras := false
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--vista="):
			vista = argumento.trim_prefix("--vista=")
		if argumento.begins_with("--qualidade="):
			preset = argumento.trim_prefix("--qualidade=")
		if argumento == "--sem-sombras":
			sem_sombras = true
	var cena: Node3D = (load("res://scenes/ambientes/clareira.tscn") as PackedScene).instantiate()
	cena.set("enquadramento_inicial", vista)
	cena.set("qualidade_de_inspecao", "Leve" if preset == "leve" else "Completa")
	root.add_child(cena)
	var camera := cena.get_node("Enquadramentos/" + vista) as Camera3D
	camera.make_current()
	if sem_sombras:
		cena.get_node("SolDourado").shadow_enabled = false
		cena.get_node("Fogueira/LuzDoFogo").shadow_enabled = false
		preset += "_sem_sombras"
	print("GPU: ", RenderingServer.get_video_adapter_name())
	print("RENDERIZADOR: ", RenderingServer.get_current_rendering_method())
	for i in range(120):
		await process_frame
	var inicio := Time.get_ticks_usec()
	for i in range(180):
		await process_frame
	var duracao := (Time.get_ticks_usec()-inicio)/1000000.0
	await RenderingServer.frame_post_draw
	var caminho := "res://exports/revisao_etapa_1/" + vista.to_lower() + "_" + preset + ".png"
	var erro := root.get_texture().get_image().save_png(caminho)
	print("CAPTURA: ", caminho, " ", error_string(erro))
	print("MEDICAO: ", snapped(180.0/duracao,.1), " FPS; ", snapped(duracao/180*1000,.1), " ms/frame; ", root.size)
	print("DESENHO: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " chamadas; ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " primitivas")
	quit(erro)
