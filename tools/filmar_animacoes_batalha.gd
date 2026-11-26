extends SceneTree
func _initialize() -> void: executar.call_deferred()
func executar() -> void:
	if DisplayServer.get_name()=="headless":
		quit(1)
		return
	var cena=load("res://scenes/inspecao/batalha_animacoes_etapa_10.tscn").instantiate()
	root.add_child(cena)
	for i in range(24): await process_frame
	var pasta:="res://exports/revisao_animacoes_batalha/frames"
	DirAccess.make_dir_recursive_absolute(pasta)
	var numero:=0
	for acao in ["lanca_acerto","lanca_erro","arco_acerto","arco_erro","animal_acerto","animal_erro"]:
		cena.repor()
		cena.demonstrar(acao)
		for i in range(30):
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(pasta+"/frame_%04d.png"%numero)
			numero+=1
	print("BATALHA_VIDEO: ",numero," frames em 12 fps")
	cena.queue_free()
	await process_frame
	quit()
