extends SceneTree
var cena
var falhas:=0
var verificacoes:=0
const PASTA:="res://exports/revisao_mapa_regional/"

func _initialize() -> void:
	call_deferred("executar")

func conferir(valor: bool,texto: String) -> void:
	verificacoes+=1
	if not valor:
		falhas+=1
		push_error(texto)

func capturar(nome: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in range(16): await process_frame
	await RenderingServer.frame_post_draw
	conferir(root.get_texture().get_image().save_png(PASTA+nome+".png")==OK,"Captura "+nome)

func executar() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	cena=load("res://scenes/inspecao/mapa_regional.tscn").instantiate()
	root.add_child(cena)
	for i in range(8): await process_frame
	var mapa=cena.mapa
	conferir(mapa.regioes.size()==30,"Trinta regiões na prévia")
	var conhecidas:=0
	for r: Dictionary in mapa.regioes:
		if r.conhecida: conhecidas+=1
		conferir(r.poligono.size()>=3,"Região com área "+str(r.id))
	conferir(conhecidas==3,"Três regiões inicialmente conhecidas")
	var mouse: Vector2=mapa.size*Vector2(.4,.6)
	var antes: Vector2=mapa.mundo(mouse)
	mapa.zoom_em(1.18,mouse)
	conferir(mapa.mundo(mouse).distance_to(antes)<.01,"Zoom ancora o ponto sob o cursor")
	for i in range(30): mapa.zoom_em(1.3,mouse)
	conferir(is_equal_approx(mapa.zoom,1.5),"Limite de aproximação")
	mapa.centro=Vector2(-9999,9999)
	mapa.limitar()
	conferir(mapa.centro.x>=0 and mapa.centro.y<=mapa.TAMANHO.y,"Deslocamento limitado ao mapa")
	mapa.enquadrar_completo()
	conferir(is_equal_approx(mapa.zoom,mapa.zoom_minimo()),"Visão geral")
	mapa.centralizar()
	if DisplayServer.get_name()!="headless":
		var inicial: Vector2=mapa.centro
		var tela: Vector2=mapa.get_global_rect().get_center()
		mouse_botao(tela,MOUSE_BUTTON_LEFT,true)
		var movimento:=InputEventMouseMotion.new()
		movimento.position=tela+Vector2(100,30)
		movimento.relative=Vector2(100,30)
		movimento.button_mask=MOUSE_BUTTON_MASK_LEFT
		root.push_input(movimento)
		mouse_botao(movimento.position,MOUSE_BUTTON_LEFT,false)
		conferir(mapa.centro.distance_to(inicial)>20,"Arraste real desloca o mapa")
		conferir(not mapa.arrastando,"Soltar o botão encerra deslocamento")
		var zoom_anterior: float=mapa.zoom
		mouse_botao(tela,MOUSE_BUTTON_WHEEL_UP,true)
		conferir(mapa.zoom>zoom_anterior,"Roda real aproxima o mapa")
		mapa.centralizar()
	conferir(mapa.regiao_em(mapa.transformar(mapa.regioes[20].pos))==20,"Seleção da aldeia")
	conferir(not mapa.dica(0).contains(mapa.regioes[0].nome),"Área desconhecida preserva nome oculto")
	mapa.arrastando=true
	cena.get_window().focus_exited.emit()
	conferir(not mapa.arrastando,"Perda de foco encerra arraste")
	await capturar("regioes_iniciais")
	mapa.zoom_em(1.5,mapa.size*.5)
	await capturar("aproximacao")
	cena.alternar_inspecao()
	mapa.enquadrar_completo()
	await capturar("arte_completa")
	cena.alternar_inspecao()
	conferir(not mapa.mostrar_tudo and not mapa.regioes[0].conhecida,"Inspeção completa não desbloqueia região")
	cena.queue_free()
	await process_frame
	print("MAPA_VISUAL: %d verificações; %d falhas"%[verificacoes,falhas])
	quit(1 if falhas else 0)

func mouse_botao(pos: Vector2,botao: MouseButton,pressionado: bool) -> void:
	var movimento:=InputEventMouseMotion.new()
	movimento.position=pos
	root.push_input(movimento)
	var e:=InputEventMouseButton.new()
	e.position=pos
	e.button_index=botao
	e.pressed=pressionado
	root.push_input(e)
