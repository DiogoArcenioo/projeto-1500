extends SceneTree
const PASTA:="res://exports/revisao_etapa_7/"
var cena

func _initialize() -> void:
	call_deferred("executar")

func capturar(nome: String) -> void:
	for i in range(18): await process_frame
	await RenderingServer.frame_post_draw
	var erro:=root.get_texture().get_image().save_png(PASTA+nome+".png")
	print("CAPTURA_ETAPA_7: ",nome," ",error_string(erro))

func executar() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	cena=load("res://scenes/inspecao/expedicoes_etapa_7.tscn").instantiate()
	root.add_child(cena)
	for i in range(12): await process_frame
	await capturar("preparar")
	cena.apresentar("acompanhar")
	await capturar("acompanhar")
	cena.hide()
	await capturar("mapa_integrado")
	quit()
