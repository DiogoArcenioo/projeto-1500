extends SceneTree
## Capturas reais da pescaria jogada (etapa 12), com o robô de inspeção no controle.
##   godot --path . --resolution 1280x720 --script res://tools/capturar_pesca.gd -- robalo 3.4
## Grava exports/revisao_pesca/<especie>_*.png: pronto, arremesso, espera (sombra),
## briga com a vara envergada, salto (se houver) e o peixe na mão.
const PASTA:="res://exports/revisao_pesca/"
var feitos:={}

func _initialize() -> void: executar.call_deferred()

func captura(nome: String) -> void:
	if feitos.has(nome): return
	feitos[nome]=true
	await process_frame
	await RenderingServer.frame_post_draw
	var erro:=root.get_texture().get_image().save_png(PASTA+nome+".png")
	print("CAPTURA ",nome," ",error_string(erro))

func executar() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Capturas precisam de renderização gráfica.");quit(1);return
	DirAccess.make_dir_recursive_absolute(PASTA)
	var args:=OS.get_cmdline_user_args()
	var especie: String=args[0] if args.size()>0 else "robalo"
	var peso: float=float(args[1]) if args.size()>1 else 3.4
	var partida=load("res://scenes/inspecao/pesca_manual.tscn").instantiate()
	partida.automatico=true
	partida.especie_forcada=especie
	partida.peso_forcado=peso
	if args.size()>2: partida.z_rio=float(args[2])
	var so_pronto:=args.size()>3
	root.add_child(partida)
	await process_frame
	await process_frame
	var cena=partida.pesca_manual
	if not is_instance_valid(cena):
		push_error("Pescaria não abriu");quit(1);return
	var t:=0.0
	var pico:=0.0
	while t<150.0 and is_instance_valid(cena):
		await process_frame
		t+=1.0/60.0
		var f: String=cena.fase
		if f=="pronto" and cena.tempo_fase>.6:
			await captura(especie+"_1_pronto"+("_z%d"%roundi(partida.z_rio) if so_pronto else ""))
			if so_pronto: break
		if f=="lancando" and cena.tempo_fase>.42: await captura(especie+"_2_arremesso")
		if f=="espera" and not cena.mordida.is_empty() and cena.t_espera>float(cena.mordida.inicio)-.9: await captura(especie+"_3_sombra")
		if f=="espera" and not cena.mordida.is_empty() and cena.t_espera>float(cena.mordida.inicio)+.12: await captura(especie+"_4_mordida")
		if f=="briga":
			var tv: float=cena.briga.tensao
			if tv>pico+.08 and tv>.55 and cena.tempo_fase>1.0:
				pico=tv
				feitos.erase(especie+"_5_briga")
				await captura(especie+"_5_briga")
			if cena.briga.no_ar and cena.peixe_pos.y>-.2: await captura(especie+"_6_salto")
			if cena.briga.modo=="cansado" and (cena.briga.pos as Vector2).length()<4.0: await captura(especie+"_7_cansado")
		if f=="capturado" and cena.tempo_fase>1.6:
			await captura(especie+"_8_na_mao")
			break
		if f=="resultado" and cena.tempo_fase>.5:
			await captura(especie+"_8_perdeu")
			break
	print("FIM fase ",cena.fase if is_instance_valid(cena) else "-"," capturas ",cena.viagem.pesca.capturas if is_instance_valid(cena) else [])
	quit(0)
