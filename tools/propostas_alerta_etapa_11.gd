extends SceneTree
## Etapa 11 · Portão A — propostas visuais do alerta de perigo no feed.
## Composições sobre uma captura real da aldeia, com o tema de casca e as fontes do jogo.
## Não liga regras nem altera a partida. Executar em modo gráfico:
##   godot --path . --resolution 1280x720 --script res://tools/propostas_alerta_etapa_11.gd
const Estilo = preload("res://scripts/ui/estilo_casca.gd")
const FUNDO := "res://exports/revisao_menus_casca/01_aldeia_inicio.png"
const PASTA := "res://art/references/etapa_11/"
const URUCUM := Color("b5482a")

class Pata extends Control:
	## Ícone de perigo: pegada de animal desenhada em vetor.
	var cor := Color("fff1cf")
	func _draw() -> void:
		var s:=size.x
		draw_circle(Vector2(s*.5,s*.66),s*.22,cor)
		for p: Vector2 in [Vector2(.22,.36),Vector2(.4,.2),Vector2(.6,.2),Vector2(.78,.36)]:
			draw_circle(p*s,s*.1,cor)

class Prazo extends Control:
	## Barra de prazo que esvazia (fração restante).
	var fracao := .7
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.21,0.15,0.1,.35))
		draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*fracao,size.y)),Color("b5482a"))

class Anel extends Control:
	var fracao := .7
	func _draw() -> void:
		var c:=size*.5
		draw_arc(c,size.x*.42,0,TAU,40,Color(0.21,0.15,0.1,.4),4,true)
		draw_arc(c,size.x*.42,-PI*.5,-PI*.5+TAU*fracao,40,Color("b5482a"),4,true)

func _initialize() -> void:
	executar.call_deferred()

func rotulo(pai: Node,texto: String,tam:=15,cor:=Estilo.TINTA,titulo:=false) -> Label:
	var l:=Label.new()
	l.text=texto
	l.add_theme_font_override("font",Estilo.FONTE_TITULO if titulo else Estilo.FONTE_TEXTO)
	l.add_theme_font_size_override("font_size",tam)
	l.add_theme_color_override("font_color",cor)
	pai.add_child(l)
	return l

func retrato(pai: Node,visual: String,tam:=34) -> void:
	var t:=TextureRect.new()
	t.texture=load("res://assets/ui/retratos/%s.png"%visual)
	t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.custom_minimum_size=Vector2(tam,tam)
	pai.add_child(t)

func caixa(pai: Node,fino:=false) -> VBoxContainer:
	var p:=PanelContainer.new()
	p.add_theme_stylebox_override("panel",Estilo.painel(fino))
	pai.add_child(p)
	var v:=VBoxContainer.new()
	v.add_theme_constant_override("separation",4)
	p.add_child(v)
	return v

func faixa_perigo(pai: Node,texto: String) -> void:
	var fundo:=PanelContainer.new()
	var sb:=StyleBoxFlat.new()
	sb.bg_color=URUCUM
	sb.set_corner_radius_all(4)
	sb.content_margin_left=8;sb.content_margin_right=8;sb.content_margin_top=3;sb.content_margin_bottom=3
	fundo.add_theme_stylebox_override("panel",sb)
	pai.add_child(fundo)
	var h:=HBoxContainer.new()
	fundo.add_child(h)
	var pata:=Pata.new();pata.custom_minimum_size=Vector2(20,20);h.add_child(pata)
	rotulo(h,texto,15,Estilo.CREME,true)

func botao(pai: Node,texto: String,primario:=false) -> Button:
	var b:=Button.new()
	b.text=texto
	Estilo.botao(b,primario)
	b.add_theme_font_size_override("font_size",14)
	pai.add_child(b)
	return b

func cartao_alerta(pai: Node,atividade: String,titulo: String,regiao: String,equipe: Array,segundos: int,fracao: float,manual:=true) -> void:
	var v:=caixa(pai)
	faixa_perigo(v,"Perigo · "+atividade)
	rotulo(v,titulo,17,Estilo.TINTA_DESTAQUE,true)
	var linha:=HBoxContainer.new();v.add_child(linha)
	for e: String in equipe: retrato(linha,e,30)
	rotulo(linha,"  "+regiao,14,Estilo.TINTA_SUAVE)
	var prazo:=Prazo.new();prazo.custom_minimum_size=Vector2(0,7);prazo.fracao=fracao;v.add_child(prazo)
	rotulo(v,"Intervir em %d s · velocidade reduzida para 1×"%segundos,13,Estilo.TINTA_SUAVE)
	var bs:=HBoxContainer.new();bs.add_theme_constant_override("separation",6);v.add_child(bs)
	if manual: botao(bs,"Assumir combate",true)
	else: rotulo(bs,"Manual ainda indisponível",13,Estilo.TINTA_SUAVE)
	botao(bs,"Deixar simular")

func aviso(pai: Node,texto: String) -> void:
	var v:=caixa(pai,true)
	var l:=rotulo(v,texto,14)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func tela(nome: String,montar: Callable) -> void:
	var base:=Control.new()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.size=Vector2(1280,720)
	root.add_child(base)
	var fundo:=TextureRect.new()
	fundo.texture=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(FUNDO)))
	fundo.size=Vector2(1280,720)
	base.add_child(fundo)
	# Remove o aviso antigo da captura de fundo.
	var tampa:=ColorRect.new();tampa.color=Color(0,0,0,0);base.add_child(tampa)
	montar.call(base)
	var etiqueta:=PanelContainer.new();etiqueta.add_theme_stylebox_override("panel",Estilo.painel(true))
	base.add_child(etiqueta);etiqueta.position=Vector2(16,60)
	rotulo(etiqueta,"PROPOSTA "+nome.to_upper().replace("_"," · ")+" — composição para aprovação, sem regras",13,Estilo.TINTA)
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA+nome+".png")
	base.queue_free()
	await process_frame

func coluna_feed(base: Control,largura:=330) -> VBoxContainer:
	var v:=VBoxContainer.new()
	v.add_theme_constant_override("separation",6)
	v.position=Vector2(1280-largura-12,58)
	v.custom_minimum_size=Vector2(largura,0)
	v.size=Vector2(largura,0)
	base.add_child(v)
	return v

func executar() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Propostas precisam de renderização gráfica.");quit(1);return
	DirAccess.make_dir_recursive_absolute(PASTA)
	root.size=Vector2i(1280,720)
	# A — cartão no feed (recomendada).
	await tela("a_cartao_no_feed",func(base: Control):
		var f:=coluna_feed(base)
		cartao_alerta(f,"Coleta","Queixadas cercam a equipe","Mata fechada",["mulher_02","homem_03"],12,.8)
		aviso(f,"exp_2 · Pesca: 2 peixes na carga."))
	# B — faixa central compacta, abaixo da barra.
	await tela("b_faixa_central",func(base: Control):
		var p:=PanelContainer.new();p.add_theme_stylebox_override("panel",Estilo.painel())
		base.add_child(p);p.position=Vector2(330,56)
		var h:=HBoxContainer.new();h.add_theme_constant_override("separation",10);p.add_child(h)
		var anel:=Anel.new();anel.custom_minimum_size=Vector2(40,40);anel.fracao=.8;h.add_child(anel)
		var pata:=Pata.new();pata.cor=URUCUM;pata.custom_minimum_size=Vector2(26,26);h.add_child(pata)
		var t:=VBoxContainer.new();h.add_child(t)
		rotulo(t,"Queixadas cercam a equipe de coleta",17,Estilo.TINTA_DESTAQUE,true)
		rotulo(t,"Mata fechada · Iara e Moacir · 12 s",14,Estilo.TINTA_SUAVE)
		botao(h,"Assumir",true);botao(h,"Simular")
		var f:=coluna_feed(base,300)
		aviso(f,"exp_2 · Pesca: 2 peixes na carga."))
	# C — selo compacto no feed + destaque no botão Expedições.
	await tela("c_selo_e_marcador",func(base: Control):
		var f:=coluna_feed(base,310)
		var v:=caixa(f,true)
		var h:=HBoxContainer.new();v.add_child(h)
		var pata:=Pata.new();pata.cor=URUCUM;pata.custom_minimum_size=Vector2(22,22);h.add_child(pata)
		rotulo(h,"Perigo na coleta · 12 s",15,Estilo.TINTA_DESTAQUE,true)
		rotulo(v,"Clique para ver as opções",13,Estilo.TINTA_SUAVE)
		aviso(f,"exp_2 · Pesca: 2 peixes na carga.")
		var selo:=PanelContainer.new()
		var sb:=StyleBoxFlat.new();sb.bg_color=URUCUM;sb.set_corner_radius_all(14)
		sb.content_margin_left=8;sb.content_margin_right=8
		selo.add_theme_stylebox_override("panel",sb);base.add_child(selo);selo.position=Vector2(842,566)
		rotulo(selo,"1",16,Estilo.CREME,true)
		var borda:=ReferenceRect.new();borda.border_color=URUCUM;borda.border_width=4;borda.editor_only=false
		borda.position=Vector2(756,568);borda.size=Vector2(114,96);base.add_child(borda))
	# Estados da opção A: fila com duas equipes e resumo após simulação.
	await tela("a_estados_fila_e_resumo",func(base: Control):
		var f:=coluna_feed(base)
		cartao_alerta(f,"Coleta","Queixadas cercam a equipe","Mata fechada",["mulher_02","homem_03"],9,.6)
		cartao_alerta(f,"Pesca","Jacaré na margem","Margem do rio",["homem_01"],15,1.0,false)
		var v:=caixa(f)
		rotulo(v,"Resumo · Caça nos Arredores",16,Estilo.TINTA_DESTAQUE,true)
		for linha: String in ["Simulado · capivara abatida","Trazendo: 6 carnes, 2 couros (entram ao chegar)","XP: Moacir +12 caça · Jaci +8 caça","Feridos: Jaci (−3 de vida) · Perdas: nenhuma"]:
			rotulo(v,linha,13))
	print("PROPOSTAS ETAPA 11 GRAVADAS")
	quit()
