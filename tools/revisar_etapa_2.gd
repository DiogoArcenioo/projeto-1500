extends SceneTree
## Revisão gráfica da partida real, sem tocar em slots do jogador nem criar HUD.
const Salvamento = preload("res://scripts/partida/salvamento.gd")

func _initialize() -> void:
	call_deferred("revisar")

func revisar() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_etapa_2")
	var partida: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	partida.set("salvamento",Salvamento.new("user://testes_etapa_2/captura_sem_gravacao"))
	root.add_child(partida)
	partida.set_process(false)
	var controle: Node = partida.get_node("ControleDaCamera")
	var casos := [
		{"nome":"dia_12h","hora":12.0,"vista":"Geral"},
		{"nome":"tarde_16h","hora":16.0,"vista":"Geral"},
		{"nome":"noite_23h","hora":23.0,"vista":"Geral"},
		{"nome":"fogueira_noite","hora":23.0,"vista":"Fogueira"},
		{"nome":"camera_zoom_proximo","hora":16.0,"vista":"Geral","camera":{"x":1.5,"z":-2.5,"angulo":0.5914,"fov":22.0}},
		{"nome":"camera_ampla_90","hora":16.0,"vista":"Geral","camera":{"x":1.5,"z":-2.5,"angulo":PI/2,"fov":50.0}},
		{"nome":"camera_ampla_180","hora":16.0,"vista":"Geral","camera":{"x":1.5,"z":-2.5,"angulo":PI,"fov":50.0}},
		{"nome":"camera_limite_nordeste","hora":16.0,"vista":"Geral","camera":{"x":18.0,"z":10.0,"angulo":PI/2,"fov":50.0}},
		{"nome":"camera_limite_sudoeste","hora":16.0,"vista":"Geral","camera":{"x":-8.0,"z":-8.0,"angulo":PI*1.5,"fov":50.0}},
	]
	var filtro := ""
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--somente="):
			filtro = argumento.trim_prefix("--somente=")
	for caso: Dictionary in casos:
		if not filtro.is_empty() and not caso.nome in filtro.split(","):
			continue
		partida.estado.relogio.tempo_total=partida.estado.relogio.duracao_dia_segundos*caso.hora/24.0
		partida.iluminacao.aplicar(caso.hora)
		controle.restaurar(caso.get("camera",{}))
		var camera := partida.get_node("Clareira1500/Enquadramentos/"+caso.vista) as Camera3D
		camera.make_current()
		for i in range(100):
			await process_frame
		await RenderingServer.frame_post_draw
		var caminho: String = "res://exports/revisao_etapa_2/"+caso.nome+".png"
		var erro := root.get_texture().get_image().save_png(caminho)
		print("REVISAO: ",caso.nome," ",error_string(erro))
		if erro != OK:
			quit(1)
			return
	quit()
