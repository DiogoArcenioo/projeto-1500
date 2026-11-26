extends SceneTree
## Capturas gráficas dos menus no padrão de casca interna.
## Uso: godot --path . -s tools/capturar_menus_casca.gd  (modo gráfico)
const PASTA:="res://exports/revisao_menus_casca/"
var cena

func _initialize() -> void: executar.call_deferred()

func esperar(n:=14) -> void:
	for i in range(n): await process_frame

func captura(nome: String) -> void:
	await esperar()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(PASTA)
	root.get_texture().get_image().save_png(PASTA+nome+".png")
	print("Captura ",nome)

func executar() -> void:
	cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=load("res://scripts/partida/salvamento.gd").new("user://capturas_menus_casca/"+Crypto.new().generate_random_bytes(6).hex_encode())
	root.add_child(cena)
	cena.set_process(false)
	var estado=cena.estado
	estado.estoque.madeira=400
	estado.estoque.fibras_vegetais=300
	for obra in [["oca",Vector2(-5,-4)],["oca",Vector2(4,-8)],["coleta",Vector2(-13,3)],["caca",Vector2(-6,5.5)],["pesca",Vector2(8,1.2)]]:
		estado.construir(obra[0],obra[1])
		estado.avancar_aldeia(60)
	cena.aldeia.sincronizar()
	var p=cena.painel
	p.topo_hud.notificar("Obra concluída: centro de pesca.")
	p.abrir("inicio")
	p.notificar("Centro de pesca pronto. Atribua moradores ao setor.")
	await captura("01_aldeia_inicio")
	p.abrir("fogueira")
	await captura("02_construir")
	p.abrir("comunidade")
	p.selecionar_pessoa(estado.habitantes[0].id)
	await captura("03_comunidade")
	cena.aldeia.selecionado.emit("obra_4")
	await captura("04_expedicao_compacto")
	cena.painel_expedicoes.mostrar_passo(1)
	await captura("05_expedicao_equipe")
	cena.painel_expedicoes.hide()
	cena.abrir_mapa()
	await captura("06_mapa")
	quit()
