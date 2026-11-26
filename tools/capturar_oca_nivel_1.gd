extends SceneTree
## Capturas reais do asset no Godot. A cena de inspeção não usa o estado/salvamento.
func _initialize() -> void:
	call_deferred("capturar")

func capturar() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.use_taa = bool(ProjectSettings.get_setting("rendering/anti_aliasing/quality/use_taa",false))
	print("SUAVIZACAO_TEMPORAL: ",root.use_taa)
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_oca_nivel_1")
	var cena: Node3D = (load("res://scenes/inspecao/oca_nivel_1.tscn") as PackedScene).instantiate()
	root.add_child(cena)
	var casos := [
		{"nome":"oca_frente","vista":"Frente","noite":false},
		{"nome":"oca_lateral","vista":"Lateral","noite":false},
		{"nome":"oca_costas","vista":"Costas","noite":false},
		{"nome":"oca_gameplay","vista":"Geral","noite":false},
		{"nome":"oca_noite","vista":"Frente","noite":true},
	]
	var filtro := ""
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--somente="):
			filtro = argumento.trim_prefix("--somente=")
	for caso: Dictionary in casos:
		if not filtro.is_empty() and not caso.nome in filtro.split(","):
			continue
		cena.definir_enquadramento(caso.vista)
		cena.definir_noite(caso.noite)
		for i in range(90):
			await process_frame
		var inicio := Time.get_ticks_usec()
		for i in range(90):
			await process_frame
		var duracao := (Time.get_ticks_usec()-inicio)/1000000.0
		await RenderingServer.frame_post_draw
		var arquivo: String = "res://exports/revisao_oca_nivel_1/" + caso.nome + ".png"
		var erro := root.get_texture().get_image().save_png(arquivo)
		print("OCA_CAPTURA: ",caso.nome," ",error_string(erro)," | ",snapped(90.0/duracao,.1)," FPS | ",root.size)
		if erro != OK:
			quit(erro)
			return
	quit()
