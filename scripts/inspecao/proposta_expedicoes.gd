extends "res://scripts/inspecao/menu_contextual_visual.gd"
## Protótipo visual da nova interface. Não envia expedições nem usa slots da partida.
var partida
var quadro: PanelContainer
var conteudo: VBoxContainer
var integrantes: Label
var escolhas: Array[CheckBox]=[]
var destino: OptionButton
var atividade: OptionButton
var duracao: Label
var tela_atual:="preparar"

func _ready() -> void:
	partida=load("res://scenes/main.tscn").instantiate()
	partida.salvamento=preload("res://scripts/partida/salvamento.gd").new("user://revisao_visual_etapa7")
	get_tree().root.add_child.call_deferred(partida)
	call_deferred("montar")

func montar() -> void:
	var e=partida.estado
	e.construir("oca",Vector2(-5,-4))
	e.avancar_aldeia(18)
	e.construir("coleta",Vector2(6,-1))
	e.avancar_aldeia(10)
	partida.set_process(false)
	partida.aldeia.sincronizar()
	partida.abrir_mapa()
	partida.mapa_regional.mapa.centralizar()
	layer=5
	_superficie=Control.new()
	add_child(_superficie)
	_superficie.mouse_filter=Control.MOUSE_FILTER_IGNORE
	quadro=painel()
	quadro.add_theme_stylebox_override("panel",caixa(Color("102f22fc"),Color("c0a467")))
	conteudo=VBoxContainer.new()
	conteudo.add_theme_constant_override("separation",12)
	quadro.add_child(conteudo)
	get_viewport().size_changed.connect(ajustar)
	apresentar("preparar")

func acao(pai: Node,nome: String,funcao: Callable) -> Button:
	var b:=botao(pai,nome)
	b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size.y=36
	b.pressed.connect(funcao)
	return b

func apresentar(tela: String) -> void:
	tela_atual=tela
	escolhas.clear()
	for no in conteudo.get_children():
		conteudo.remove_child(no)
		no.queue_free()
	var topo:=HBoxContainer.new()
	conteudo.add_child(topo)
	var titulo:=texto(topo,"Expedições · prévia visual",24)
	titulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	acao(topo,"Preparar",apresentar.bind("preparar"))
	acao(topo,"Acompanhar",apresentar.bind("acompanhar"))
	if tela=="preparar": formulario()
	else: acompanhamento()
	ajustar()

func formulario() -> void:
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",32)
	conteudo.add_child(linha)
	var origem:=VBoxContainer.new()
	origem.custom_minimum_size.x=250
	linha.add_child(origem)
	texto(origem,"Centro de coleta · 1 expedição",18)
	atividade=OptionButton.new()
	atividade.add_item("Coleta")
	atividade.add_item("Reconhecimento")
	origem.add_child(atividade)
	destino=OptionButton.new()
	destino.add_item("Arredores",14)
	destino.add_item("Margem do rio",21)
	origem.add_child(destino)
	destino.item_selected.connect(func(_i: int): atualizar_resumo())
	var equipe:=VBoxContainer.new()
	equipe.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	linha.add_child(equipe)
	integrantes=texto(equipe,"Equipe · 2/2 integrantes",18)
	for h: Dictionary in partida.estado.habitantes:
		var c:=CheckBox.new()
		c.text="%s · %d anos · Disponível"%[h.nome,h.idade]
		c.add_theme_color_override("font_color",Color("f2e6c9"))
		c.button_pressed=true
		c.focus_mode=Control.FOCUS_NONE
		equipe.add_child(c)
		escolhas.append(c)
		c.toggled.connect(func(_valor: bool): atualizar_resumo())
	var resumo:=VBoxContainer.new()
	linha.add_child(resumo)
	texto(resumo,"Modo simulado",18)
	duracao=texto(resumo,"",16)
	texto(resumo,"A carga chega ao estoque no retorno.",15)
	var confirmar:=acao(resumo,"Confirmar envio",func(): pass)
	confirmar.disabled=true
	confirmar.tooltip_text="Prévia da interface para aprovação no chat."
	atualizar_resumo()

func atualizar_resumo() -> void:
	var total:=0
	for c in escolhas:
		if c.button_pressed: total+=1
	integrantes.text="Equipe · %d/2 integrantes"%total
	var viagem:=preload("res://scripts/partida/regioes.gd").viagem(destino.get_selected_id(),partida.estado.conhecimento)
	partida.mapa_regional.mapa.selecionada=destino.get_selected_id()
	partida.mapa_regional.mapa.queue_redraw()
	partida.mapa_regional.selecionar(destino.get_selected_id())
	duracao.text="Ida %d s · Exploração 60 s\nRetorno %d s · Tempo a 1×"%[ceili(viagem),ceili(viagem)]

func acompanhamento() -> void:
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",32)
	conteudo.add_child(linha)
	var dados:=VBoxContainer.new()
	dados.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	linha.add_child(dados)
	texto(dados,"Coleta · Arredores",21)
	var nomes: Array[String]=[]
	for h: Dictionary in partida.estado.habitantes: nomes.append(h.nome)
	texto(dados,"Equipe · "+", ".join(nomes),17)
	texto(dados,"Carga · 6 madeira · 3 fibras",17)
	var andamento:=VBoxContainer.new()
	andamento.custom_minimum_size.x=360
	linha.add_child(andamento)
	texto(andamento,"Explorando · 24 s / 60 s",19)
	var progresso:=ProgressBar.new()
	progresso.value=40
	progresso.custom_minimum_size.y=24
	andamento.add_child(progresso)
	var retorno:=acao(andamento,"Solicitar retorno",func(): pass)
	retorno.disabled=true
	retorno.tooltip_text="Prévia da interface para aprovação no chat."
	texto(conteudo,"Dados demonstrativos para avaliar o painel.",15,Color("d7c390"))

func ajustar() -> void:
	if not quadro: return
	var tam:=get_viewport().get_visible_rect().size
	var escala:=minf(1,tam.x/1180)
	_superficie.scale=Vector2.ONE*escala
	_superficie.size=tam/escala
	var largura:=minf(1120,_superficie.size.x-24)
	quadro.offset_left=-largura/2
	quadro.offset_right=largura/2
	quadro.offset_top=-290
	quadro.offset_bottom=-16
