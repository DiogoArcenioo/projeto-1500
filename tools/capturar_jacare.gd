extends SceneTree
## Capturas reais do combate manual com o jacaré (cena de teste rápido).
##   godot --path . --resolution 1280x720 --script res://tools/capturar_jacare.gd
## Grava exports/revisao_jacare/: revelação, tabuleiro, investida e vista próxima.
const PASTA:="res://exports/revisao_jacare/"
var cena

func _initialize() -> void: executar.call_deferred()

func esperar(segundos: float) -> void:
	await create_timer(segundos).timeout

func captura(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var erro:=root.get_texture().get_image().save_png(PASTA+nome+".png")
	print("CAPTURA ",nome," ",error_string(erro))
	if erro!=OK: quit(erro)

func executar() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Capturas precisam de renderização gráfica.");quit(1);return
	DirAccess.make_dir_recursive_absolute(PASTA)
	cena=load("res://scenes/inspecao/combate_manual_jacare.tscn").instantiate()
	root.add_child(cena)
	await esperar(1.6)
	await captura("01_revelacao")
	await esperar(3.4)
	await captura("02_tabuleiro")
	var combate_cena=cena.combate_manual
	if not is_instance_valid(combate_cena):
		push_error("Combate não abriu");quit(1);return
	var c: Dictionary=combate_cena.combate
	print("ANIMAL ",c.animal," ORDEM ",c.ordem)
	# Aproxima a câmera da queixada para ver modelo, pelagem e postura.
	var animal: Node3D=combate_cena.get_node("Capivara")
	var cam: Camera3D=combate_cena.get_node("CameraEncontro")
	var antes:=cam.global_transform
	var deslocamento:=cam.v_offset
	cam.v_offset=0
	combate_cena.ui.hide()
	var alvo:=animal.global_position+Vector3(0,.29,0)
	var a: AnimationPlayer=combate_cena.player("Capivara")
	a.play("parada",0)
	a.advance(0)
	a.pause()
	for i in range(2):
		var deslocamentos: Array[Vector3]=[Vector3(-1.38,.47,.94),Vector3(1.62,.33,.34)]
		cam.global_position=alvo+animal.global_basis*deslocamentos[i]
		cam.look_at(alvo)
		await esperar(.4)
		await captura("03_jacare_perto_%d"%(i+1))
	a.play()
	combate_cena.ui.show()
	cam.global_transform=antes
	cam.v_offset=deslocamento
	# Turnos: a política/IA joga pelos dois lados até a primeira investida.
	for i in range(40):
		if c.resultado!="": break
		var atual: Dictionary=combate_cena.Regras.atual(c)
		if atual.is_empty(): break
		if not combate_cena.em_movimento:
			if atual.lado=="equipe":
				var d: Dictionary=combate_cena.Regras.decisao(c)
				combate_cena.executar(atual.id,d.acao,d.get("alvo",""),Vector2i(d.get("x",-1),d.get("z",-1)))
				if d.acao=="atacar":
					await esperar(.5)
					await captura("04_ataque_equipe")
		if a.current_animation in ["investida","errar_ataque"]:
			await captura("05_investida")
			break
		await esperar(.6)
	await esperar(1.0)
	await captura("06_depois")
	quit()
