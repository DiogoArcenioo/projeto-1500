extends "res://scripts/inspecao/menu_contextual_visual.gd"
## Avaliação do mapa e da navegação. Sem alterar partida ou salvamentos.
var mapa:=preload("res://scripts/inspecao/mapa_regional_visual.gd").new()
var barra:=preload("res://scripts/partida/barra_superior.gd").new()
var ficha: PanelContainer
var conteudo: VBoxContainer
var cabecalho: Label
var rodape: HBoxContainer
var estado=preload("res://scripts/partida/estado_partida.gd").nova(preload("res://assets/configuracoes/partida_inicial.tres"))
var escala_usuario:=1.0

func _ready() -> void:
	_superficie=Control.new()
	add_child(_superficie)
	_superficie.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_superficie.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var fundo:=ColorRect.new()
	fundo.color=Color("0c1e18")
	fundo.mouse_filter=Control.MOUSE_FILTER_STOP
	_superficie.add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_superficie.add_child(mapa)
	_superficie.add_child(barra)
	barra.configurar(estado)
	cabecalho=texto(_superficie,"Mapa regional · 30 regiões",24,Casca.CREME)
	cabecalho.add_theme_color_override("font_outline_color",Color("24170e"))
	cabecalho.add_theme_constant_override("outline_size",6)
	cabecalho.position=Vector2(24,66)
	ficha=PanelContainer.new()
	_superficie.add_child(ficha)
	conteudo=VBoxContainer.new()
	conteudo.add_theme_constant_override("separation",13)
	var rolagem:=ScrollContainer.new()
	rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	ficha.add_child(rolagem)
	conteudo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rolagem.add_child(conteudo)
	rodape=HBoxContainer.new()
	rodape.add_theme_constant_override("separation",8)
	_superficie.add_child(rodape)
	acao(rodape,"−",func(): mapa.zoom_em(1/1.3,mapa.size*.5))
	acao(rodape,"+",func(): mapa.zoom_em(1.3,mapa.size*.5))
	acao(rodape,"Aldeia · R",mapa.centralizar)
	acao(rodape,"Visão geral",mapa.enquadrar_completo)
	acao(rodape,"Arte completa · V",alternar_inspecao)
	mapa.regiao_selecionada.connect(selecionar)
	barra.ocultar_solicitado.connect(alternar_interface)
	barra.escala_solicitada.connect(definir_escala)
	barra.pausa_solicitada.connect(alterar_pausa)
	barra.velocidade_solicitada.connect(alterar_velocidade)
	get_viewport().size_changed.connect(ajustar)
	get_window().focus_exited.connect(mapa.cancelar_arraste)
	ajustar()
	mapa.centralizar()
	selecionar(21)
	barra.move_to_front()
	if get_script().resource_path.ends_with("inspecao_mapa_regional.gd"):
		print("[Mapa · inspeção] Roda ou +/-: zoom | arraste esquerdo/meio: mover | WASD: deslocar | R: aldeia | V: inspecionar toda a arte")
		print("[Mapa · inspeção] Prévia visual, informações ilustrativas; sem salvamento ou desbloqueio de regiões da partida.")

func acao(pai: Node,valor: String,funcao: Callable) -> void:
	var b:=botao(pai,valor)
	b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size=Vector2(40,36)
	b.add_theme_font_size_override("font_size",15)
	Casca.margens(b,12,7)
	b.pressed.connect(funcao)

func alterar_pausa() -> void:
	estado.relogio.pausado=not estado.relogio.pausado
	barra.atualizar()

func alterar_velocidade(valor: int) -> void:
	estado.relogio.definir_velocidade(valor)
	barra.atualizar()

func alternar_interface() -> void:
	var mostrar:=not ficha.visible
	for no in [barra,ficha,cabecalho,rodape]: no.visible=mostrar

func definir_escala(valor: float) -> void:
	escala_usuario=valor
	ajustar()

func ajustar() -> void:
	var tam:=get_viewport().get_visible_rect().size
	var escala:=minf(escala_usuario,tam.x/1180)
	_superficie.scale=Vector2.ONE*escala
	tam/=escala
	_superficie.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_superficie.size=tam
	barra.size=Vector2(tam.x,56)
	mapa.position=Vector2(0,104)
	mapa.size=Vector2(tam.x-334,tam.y-168)
	ficha.position=Vector2(tam.x-318,104)
	ficha.size=Vector2(302,tam.y-168)
	rodape.position=Vector2(20,tam.y-54)
	barra.ajustar()
	mapa.limitar()

func selecionar(indice: int) -> void:
	for no in conteudo.get_children():
		conteudo.remove_child(no)
		no.queue_free()
	var r: Dictionary=mapa.regioes[indice]
	var conhecida: bool=r.conhecida or mapa.mostrar_tudo
	var titulo:=texto(conteudo,r.nome if conhecida else "Desconhecido",22)
	titulo.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var linhas: PackedStringArray=mapa.dica(indice).split("\n")
	for i in range(1,linhas.size()):
		var l:=texto(conteudo,linhas[i],17)
		l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var contador:=texto(conteudo,"3 regiões conhecidas\n27 regiões para descobrir",16,Casca.TINTA_SUAVE)
	contador.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var ajuda:=texto(conteudo,"Roda · aproximar/afastar\nArraste · mover o mapa\nR · voltar à aldeia no mapa",15,Casca.TINTA_SUAVE)
	ajuda.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if mapa.mostrar_tudo:
		texto(conteudo,"Arte completa para inspeção",15,Color("edca82"))
	texto(conteudo,"Prévia visual · região fictícia",14,Color("c4b680"))

func alternar_inspecao() -> void:
	mapa.mostrar_tudo=not mapa.mostrar_tudo
	mapa.queue_redraw()
	selecionar(mapa.selecionada)

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	match e.physical_keycode:
		KEY_V: alternar_inspecao()
		KEY_R: mapa.centralizar()
		KEY_EQUAL,KEY_KP_ADD: mapa.zoom_em(1.3,mapa.size*.5)
		KEY_MINUS,KEY_KP_SUBTRACT: mapa.zoom_em(1/1.3,mapa.size*.5)
		_: return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var eixo:=Input.get_vector("camera_esquerda","camera_direita","camera_cima","camera_baixo")
	if eixo.length_squared()>0:
		mapa.centro+=eixo*550*delta/mapa.zoom
		mapa.limitar()
