extends SceneTree
## Capturas da partida em vários horários, sem interface, para revisar a luz.
## Uso (modo gráfico): godot --path . -s tools/capturar_iluminacao.gd -- prefixo
const PASTA:="res://exports/revisao_iluminacao/"
const HORARIOS:={"amanhecer":6.6,"manha":9.5,"meio_dia":12.5,"tarde":16.5,"por_do_sol":18.1,"noite":22.0}

func _initialize() -> void: executar.call_deferred()

func executar() -> void:
	var prefixo:="depois"
	for a in OS.get_cmdline_user_args(): prefixo=a
	var cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=load("res://scripts/partida/salvamento.gd").new("user://capturas_iluminacao/"+Crypto.new().generate_random_bytes(6).hex_encode())
	root.add_child(cena)
	cena.set_process(false)
	var estado=cena.estado
	estado.estoque.madeira=400
	estado.estoque.fibras_vegetais=300
	for obra in [["oca",Vector2(-5,-4)],["oca",Vector2(4,-8)],["coleta",Vector2(-13,3)],["caca",Vector2(-6,5.5)],["pesca",Vector2(8,1.2)]]:
		estado.construir(obra[0],obra[1])
		estado.avancar_aldeia(60)
	cena.aldeia.sincronizar()
	for no in cena.find_children("*","CanvasLayer",true,false): no.visible=false
	DirAccess.make_dir_recursive_absolute(PASTA)
	for nome: String in HORARIOS:
		cena.iluminacao.aplicar(HORARIOS[nome])
		for i in range(40): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(PASTA+prefixo+"_"+nome+".png")
		print("Captura ",prefixo,"_",nome)
	quit()
