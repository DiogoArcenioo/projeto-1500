extends SceneTree
## Capturas da etapa 13: centro de cura com paciente e cuidador, painel do centro e
## painel comunitário, à luz do dia.
##   godot --path . --resolution 1280x720 --script res://tools/capturar_cura.gd
const PASTA:="res://exports/revisao_etapa_13/"
const S=preload("res://scripts/partida/salvamento.gd")

func _initialize() -> void: executar.call_deferred()

func captura(nome: String) -> void:
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	print("CAPTURA ",nome," ",error_string(root.get_texture().get_image().save_png(PASTA+nome+".png")))

func executar() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	var cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=S.new("user://capturas_etapa_13")
	root.add_child(cena)
	cena.set_process(false)
	var e=cena.estado
	cena.iniciar_obra("oca")
	cena.confirmar_obra(Vector2(-5,-4))
	cena._process(18)
	e.estoque.madeira=200
	e.estoque.fibras_vegetais=200
	e.estoque.plantas_medicinais=14
	cena.iniciar_obra("oca")
	cena.confirmar_obra(Vector2(4,-8))
	cena._process(20)
	cena.iniciar_obra("cura")
	cena.confirmar_obra(Vector2(-6,5.5))
	cena._process(42)
	var cura: String=e.construcoes.back().id
	cena.painel.mudar_setor.emit(e.habitantes[0].id,cura)
	e.habitantes[1].saude=22.0
	e.habitantes[2].saude=58.0
	e.habitantes[2].descanso=30.0
	e.habitantes[3].descanso=18.0
	for i in range(3): cena._process(10)
	# Meio da tarde.
	var dia: float=e.relogio.duracao_dia_segundos
	e.relogio.tempo_total=dia+dia*14.5/24.0
	e.tempo_economia=e.relogio.tempo_total
	cena.iluminacao.aplicar(14.5)
	cena.aldeia.sincronizar()
	for i in range(60): cena.aldeia.mover(.25)
	cena.painel.abrir(cura)
	await captura("centro_de_cura")
	cena.painel.abrir("comunidade")
	await captura("comunidade_dia")
	quit(0)
