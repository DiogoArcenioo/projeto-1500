extends SceneTree
var cena: Node3D
const PASTA := "res://exports/revisao_etapa_4/"

func _initialize() -> void:
	call_deferred("capturar")

func gravar(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var erro := root.get_texture().get_image().save_png(PASTA + nome + ".png")
	print("REVISAO_ETAPA_4: ", nome, " ", error_string(erro))
	if erro != OK:
		quit(erro)

func aquecer() -> void:
	for i in range(75):
		await process_frame

func capturar() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.use_taa = true
	DirAccess.make_dir_recursive_absolute(PASTA)
	cena = (load("res://scenes/inspecao/moradores_etapa_4.tscn") as PackedScene).instantiate()
	root.add_child(cena)
	cena.get_node("MenuVisual").visible = false
	for vista: String in ["Frente", "Rosto", "Costas", "Geral"]:
		cena.definir_vista(vista)
		await aquecer()
		await gravar("moradores_" + vista.to_lower())
	cena.get_node("MenuVisual").visible = true
	cena.definir_vista("Geral")
	for expandido: bool in [false, true]:
		cena.get_node("MenuVisual").definir_expandido(expandido)
		await aquecer()
		await gravar("painel_expandido" if expandido else "painel_recolhido")
	cena.get_node("MenuVisual").visible = false
	cena.definir_vista("Frente")
	for nome: String in ["Andar", "Trabalhar"]:
		cena.definir_animacao(nome)
		await aquecer()
		var animadores: Array = cena.animadores
		for animador in animadores:
			var jogador: AnimationPlayer = animador.jogador
			print("ANIMACAO: ", nome, " | ", jogador.current_animation, " | duracao ", jogador.current_animation_length)
			jogador.play(animador.atual, 0)
			jogador.advance(0)
			jogador.pause()
		for i in range(12):
			for animador in animadores:
				var jogador: AnimationPlayer = animador.jogador
				var duracao := jogador.get_animation(animador.atual).length
				jogador.seek(duracao * i / 12.0, true)
			await process_frame
			await gravar("anim_" + nome.to_lower() + "_%02d" % i)
	quit()
