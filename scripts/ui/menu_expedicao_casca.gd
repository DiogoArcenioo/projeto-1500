extends CanvasLayer
## Componentes visuais compartilhados entre a partida e a cena de inspeção.
const E=preload("res://scripts/partida/estado_partida.gd")
const Config=preload("res://scripts/partida/configuracao_partida.gd")
const Exp=preload("res://scripts/partida/expedicoes.gd")
const Regioes=preload("res://scripts/partida/regioes.gd")
const ArmaIcone=preload("res://scripts/inspecao/icone_arma_menu.gd")
const FONTE_TITULO=preload("res://assets/ui/fonts/alegreya_sc/AlegreyaSC-Bold.ttf")
const FONTE_TEXTO=preload("res://assets/ui/fonts/alegreya_sans/AlegreyaSans-Medium.ttf")
const MARGEM_CASCA=Vector4(112,94,112,92)
const Casca=preload("res://scripts/ui/estilo_casca.gd")
var previa:=true
var estado
var superficie: Control
var quadro: PanelContainer
var mini: PanelContainer
var conteudo: VBoxContainer
var etapa:=0
var tipo:="caca"
var equipe: Array=[]
var armas: Dictionary={}
var equipando:=""
var regiao:=14
var frente: Button
var voltar: Button
var seletor_destino: OptionButton
var cards: Dictionary={}
var botao_abrir: Button
var titulo_mini: Label
var mensagem: Label
var barra:=preload("res://scripts/partida/barra_superior.gd").new()
var escala:=1.0

func plano(cor: String,borda: String="987348",raio:=8) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(cor)
	s.border_color=Color(borda)
	s.set_border_width_all(1)
	s.set_corner_radius_all(raio)
	s.content_margin_left=12
	s.content_margin_right=12
	s.content_margin_top=8
	s.content_margin_bottom=8
	return s
func casca() -> StyleBoxTexture:
	var s:=StyleBoxTexture.new()
	s.texture=load("res://assets/ui/expedicoes/casca_interna_painel.png")
	# A borda irregular atravessa os antigos cortes de nine-patch. Escalar
	# a folha inteira mantém a casca fora da área clara reservada ao conteúdo.
	s.texture_margin_left=0
	s.texture_margin_right=0
	s.texture_margin_top=0
	s.texture_margin_bottom=0
	s.content_margin_left=MARGEM_CASCA.x
	s.content_margin_top=MARGEM_CASCA.y
	s.content_margin_right=MARGEM_CASCA.z
	s.content_margin_bottom=MARGEM_CASCA.w
	return s
func texto(p: Node,t: String,tamanho:=16,cor:="35271b") -> Label:
	var l:=Label.new()
	l.text=t
	l.add_theme_font_override("font",FONTE_TITULO if tamanho>=20 else FONTE_TEXTO)
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",Color(cor))
	p.add_child(l)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l
func botao(p: Node,t: String,acao: Callable,primario:=false) -> Button:
	var b:=Button.new()
	b.text=t
	b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size=Vector2(0,38)
	b.add_theme_font_size_override("font_size",17)
	Casca.botao(b,primario)
	b.pressed.connect(acao)
	p.add_child(b)
	return b
func preencher_estado() -> void:
	estado=E.nova(Config.new())
func _ready() -> void:
	layer=5
	preencher_estado()
	superficie=Control.new()
	superficie.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(superficie)
	superficie.add_child(barra)
	barra.configurar(estado)
	barra.visible=previa
	barra.pausa_solicitada.connect(func():
		estado.relogio.pausado=not estado.relogio.pausado
		barra.atualizar())
	var sombra:=ColorRect.new()
	sombra.name="Sombra"
	sombra.color=Color(0.025,.035,.025,.22)
	sombra.mouse_filter=Control.MOUSE_FILTER_IGNORE
	superficie.add_child(sombra)
	quadro=PanelContainer.new()
	quadro.add_theme_stylebox_override("panel",casca())
	quadro.minimum_size_changed.connect(func(): ajustar.call_deferred())
	superficie.add_child(quadro)
	conteudo=VBoxContainer.new()
	conteudo.add_theme_constant_override("separation",5)
	quadro.add_child(conteudo)
	mini=PanelContainer.new()
	var casca_pequena:=casca()
	casca_pequena.content_margin_left=28
	casca_pequena.content_margin_right=28
	casca_pequena.content_margin_top=28
	casca_pequena.content_margin_bottom=28
	mini.add_theme_stylebox_override("panel",casca_pequena)
	superficie.add_child(mini)
	var coluna:=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",5)
	mini.add_child(coluna)
	titulo_mini=texto(coluna,"Centro de caça",21)
	titulo_mini.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	botao_abrir=botao(coluna,"Caçar",func(): mostrar_passo(1),true)
	botao(coluna,"Acompanhar",func(): mostrar_passo(4))
	var aviso:=texto(superficie,"PRÉVIA · F1 caça · F2 pesca · F3 coleta · dados ilustrativos · envio desativado",13,"f2e3c2")
	aviso.name="Aviso"
	aviso.visible=previa
	get_viewport().size_changed.connect(ajustar)
	mostrar_passo(0)

func mudar_tipo(novo: String) -> void:
	tipo=novo
	equipe.clear()
	armas.clear()
	equipando=""
	regiao=21 if tipo=="pesca" else 14
	titulo_mini.text={"caca":"Centro de caça","pesca":"Centro de pesca","coleta":"Centro de coleta"}[tipo]
	botao_abrir.text={"caca":"Caçar","pesca":"Pescar","coleta":"Enviar expedição"}[tipo]
	if get_parent().has_method("mostrar_centro"): get_parent().mostrar_centro(tipo)
	mostrar_passo(0)

func habilidade() -> String:
	return {"caca":"Caça","pesca":"Pesca","coleta":"Coleta","reconhecimento":"Exploração"}[tipo]

func disponivel(_h: Dictionary) -> bool:
	return true

func chave_habilidade() -> String:
	return "exploracao" if tipo=="reconhecimento" else tipo

func xp_atividade(h: Dictionary) -> int:
	return int(h.xp) if tipo=="reconhecimento" else int(h.habilidades.get(chave_habilidade(),0))

func ajustar() -> void:
	var tam:=get_viewport().get_visible_rect().size
	escala=minf(1,minf(tam.x/1180,tam.y/700))
	superficie.scale=Vector2.ONE*escala
	superficie.size=tam/escala
	barra.size=Vector2(superficie.size.x,58)
	barra.ajustar()
	var largura:=minf(1160,superficie.size.x-42)
	var altura:=minf(640,superficie.size.y-80)
	quadro.position=Vector2((superficie.size.x-largura)*.5,(superficie.size.y-altura)*.5+10)
	quadro.size=Vector2(largura,altura)
	mini.size=Vector2(265,0)
	mini.position=Vector2(superficie.size.x*.54,superficie.size.y*.40)
	var aviso: Label=superficie.get_node("Aviso")
	aviso.position=Vector2(20,superficie.size.y-24)
	var sombra: ColorRect=superficie.get_node("Sombra")
	sombra.position=Vector2(0,58)
	sombra.size=superficie.size-Vector2(0,58)
	sombra.visible=etapa>0

func mostrar_passo(passo: int) -> void:
	if passo in [2,3] and equipe.is_empty(): passo=1
	etapa=passo
	cards.clear()
	mini.visible=passo==0
	quadro.visible=passo>0
	for c in conteudo.get_children():
		conteudo.remove_child(c)
		c.queue_free()
	if passo>0:
		cabecalho()
		match passo:
			1: escolher_equipe()
			2: escolher_armas()
			3: confirmacao()
			4: acompanhar()
		rodape()
	ajustar()
func cabecalho() -> void:
	var topo:=HBoxContainer.new()
	conteudo.add_child(topo)
	var titulo:=texto(topo,["","Preparar "+{"caca":"caça","pesca":"pescaria","coleta":"expedição","reconhecimento":"expedição"}[tipo],"Equipar a equipe","Tudo pronto para partir?","Suas expedições"][etapa],27)
	titulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	botao(topo,"×",func(): mostrar_passo(0))
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",16)
	conteudo.add_child(linha)
	if etapa<=3:
		for i in range(3):
			var l:=texto(linha,["1  Equipe","2  Equipamentos","3  Confirmar"][i],17,"713c23" if etapa==i+1 else "51402a")
			if etapa==i+1: l.add_theme_font_size_override("font_size",19)
	var sep:=HSeparator.new()
	sep.modulate=Color("6d4328")
	conteudo.add_child(sep)
func retrato(p: Node,h: Dictionary,tamanho: Vector2) -> void:
	var fundo:=PanelContainer.new()
	fundo.add_theme_stylebox_override("panel",plano("284638","917341"))
	fundo.custom_minimum_size=tamanho
	p.add_child(fundo)
	var img:=TextureRect.new()
	img.texture=load("res://assets/ui/retratos/%s.png"%h.visual)
	img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.custom_minimum_size=tamanho-Vector2(12,12)
	img.mouse_filter=Control.MOUSE_FILTER_IGNORE
	fundo.add_child(img)
	fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE
func escolher_equipe() -> void:
	texto(conteudo,"Escolha quem vai participar · %d de 2 selecionados"%equipe.size(),18)
	var grid:=GridContainer.new()
	grid.columns=4
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	grid.size_flags_vertical=Control.SIZE_EXPAND_FILL
	conteudo.add_child(grid)
	for h: Dictionary in estado.habitantes:
		if h.estado=="morto": continue
		var selecionado: bool=h.id in equipe
		var card:=PanelContainer.new()
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.custom_minimum_size=Vector2(220,140)
		var estilo:=plano("355447" if selecionado else "e4c899","eec779" if selecionado else "9d764b")
		estilo.content_margin_top=6
		estilo.content_margin_bottom=6
		estilo.set_border_width_all(3 if selecionado else 1)
		card.add_theme_stylebox_override("panel",estilo)
		grid.add_child(card)
		var col:=VBoxContainer.new()
		col.add_theme_constant_override("separation",2)
		card.add_child(col)
		var linha:=HBoxContainer.new()
		col.add_child(linha)
		var cor: String="fff0cb" if selecionado else "35271b"
		var nome:=texto(linha,h.nome,20,cor)
		nome.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		texto(linha,"✓" if selecionado else "",19,"f7d789")
		var corpo:=HBoxContainer.new()
		corpo.add_theme_constant_override("separation",9)
		col.add_child(corpo)
		retrato(corpo,h,Vector2(68,72))
		var info:=VBoxContainer.new()
		info.add_theme_constant_override("separation",2)
		corpo.add_child(info)
		texto(info,"%s %d XP"%[habilidade(),xp_atividade(h)],16,cor)
		texto(info,"Combate %d XP"%h.habilidades.combate,15,cor)
		texto(info,"FOR %d   AGI %d"%[h.atributos.forca,h.atributos.agilidade],15,cor)
		texto(info,"PER %d   RES %d"%[h.atributos.percepcao,h.atributos.resistencia],15,cor)
		var b:=botao(col,"Selecionado" if selecionado else "Selecionar",func(): alternar(h.id),selecionado)
		b.custom_minimum_size.y=27
		b.add_theme_font_size_override("font_size",14)
		Casca.margens(b,12,4)
		b.disabled=not disponivel(h) or (not selecionado and equipe.size()>=2)
		b.tooltip_text="Indisponível · "+h.estado.replace("_"," ") if not disponivel(h) else "Saúde %d%%"%h.saude
		cards[h.id]=b
func alternar(id: String) -> void:
	if not disponivel(estado.pessoa(id)): return
	if id in equipe: equipe.erase(id)
	elif equipe.size()<2: equipe.append(id)
	mostrar_passo(1)
func escolher_armas() -> void:
	if tipo!="caca":
		equipamento_do_centro()
		return
	if equipe.is_empty():
		mostrar_passo(1)
		return
	if equipando not in equipe: equipando=equipe[0]
	var pessoas:=HBoxContainer.new()
	conteudo.add_child(pessoas)
	for id in equipe:
		var h: Dictionary=estado.pessoa(id)
		botao(pessoas,h.nome,func():
			equipando=id
			mostrar_passo(2),id==equipando)
	var h: Dictionary=estado.pessoa(equipando)
	texto(conteudo,"Escolha a arma de %s"%h.nome,18)
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",15)
	linha.size_flags_vertical=Control.SIZE_EXPAND_FILL
	conteudo.add_child(linha)
	var pessoa:=VBoxContainer.new()
	pessoa.custom_minimum_size.x=180
	linha.add_child(pessoa)
	retrato(pessoa,h,Vector2(145,160))
	texto(pessoa,h.nome,21)
	texto(pessoa,"Caça %d XP · Combate %d XP"%[h.habilidades.caca,h.habilidades.combate],14)
	for tipo_arma in ["arco","lanca"]:
		var dados: Dictionary=Exp.Caca.Combate.regras.equipamentos[tipo_arma]
		var ativo: bool=armas.get(equipando,"arco")==tipo_arma
		var card:=PanelContainer.new()
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel",plano("f0d9aa" if ativo else "debd87","b57038" if ativo else "957148"))
		linha.add_child(card)
		var col:=VBoxContainer.new()
		col.add_theme_constant_override("separation",4)
		card.add_child(col)
		texto(col,"Arco" if tipo_arma=="arco" else "Lança",23)
		var icone:=ArmaIcone.new()
		icone.tipo=tipo_arma
		col.add_child(icone)
		texto(col,"Dano  1d6 + 1   ·   2 a 7",18)
		texto(col,"Alcance  %d %s"%[dados.alcance,"quadrado" if dados.alcance==1 else "quadrados"],17)
		texto(col,"Usa percepção" if tipo_arma=="arco" else "Usa força",16)
		var nota:=texto(col,"Ataque à distância; exige linha de tiro." if tipo_arma=="arco" else "Combate próximo; alcance de 1 quadrado.",14)
		nota.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var b:=botao(col,"Equipado" if ativo else "Equipar",func():
			armas[equipando]=tipo_arma
			mostrar_passo(2),ativo)
		cards[tipo_arma]=b

func equipamento_do_centro() -> void:
	texto(conteudo,"Equipamento básico do centro",23)
	texto(conteudo,"A equipe leva o material de pesca." if tipo=="pesca" else "A equipe leva o material de coleta e exploração.",18)
	var linha:=HBoxContainer.new()
	linha.add_theme_constant_override("separation",18)
	conteudo.add_child(linha)
	for id in equipe:
		var h: Dictionary=estado.pessoa(id)
		var ficha:=PanelContainer.new()
		ficha.add_theme_stylebox_override("panel",plano("e4c899","9d764b"))
		linha.add_child(ficha)
		var col:=VBoxContainer.new()
		ficha.add_child(col)
		retrato(col,h,Vector2(100,110))
		texto(col,h.nome,21)
		texto(col,"%s %d XP"%[habilidade(),xp_atividade(h)],15)
		texto(col,"✓  Preparado",17,"355447")
func confirmacao() -> void:
	texto(conteudo,"Sua equipe",19)
	var equipe_linha:=HBoxContainer.new()
	equipe_linha.add_theme_constant_override("separation",16)
	conteudo.add_child(equipe_linha)
	for id in equipe:
		var h: Dictionary=estado.pessoa(id)
		var ficha:=PanelContainer.new()
		ficha.custom_minimum_size=Vector2(330,105)
		ficha.add_theme_stylebox_override("panel",plano("e6cb9a","9d794a"))
		equipe_linha.add_child(ficha)
		var linha:=HBoxContainer.new()
		ficha.add_child(linha)
		retrato(linha,h,Vector2(65,80))
		var col:=VBoxContainer.new()
		linha.add_child(col)
		texto(col,h.nome,21)
		texto(col,("Arco" if armas.get(id,"arco")=="arco" else "Lança") if tipo=="caca" else "Equipamento do centro",17)
		texto(col,"%s %d XP · Saúde %d%%"%[habilidade(),xp_atividade(h),h.saude],15)
	texto(conteudo,"Destino",19)
	seletor_destino=OptionButton.new()
	seletor_destino.add_theme_font_override("font",FONTE_TEXTO)
	for r: Dictionary in Regioes.definicoes():
		if r.id==20 or int(estado.conhecimento[str(r.id)])<2: continue
		if tipo=="pesca" and not r.recursos.has("peixe"): continue
		if tipo=="caca" and Exp.Caca.fauna(r.id).is_empty(): continue
		seletor_destino.add_item(r.nome,r.id)
		if r.id==regiao: seletor_destino.select(seletor_destino.item_count-1)
	conteudo.add_child(seletor_destino)
	seletor_destino.add_theme_font_size_override("font_size",18)
	seletor_destino.add_theme_color_override("font_color",Color("35271b"))
	seletor_destino.item_selected.connect(func(_i: int):
		regiao=seletor_destino.get_selected_id()
		mostrar_passo(3))
	var viagem:=Regioes.viagem(regiao,estado.conhecimento)
	texto(conteudo,"Ida %d s   ·   Atividade %d s   ·   Retorno %d s"%[ceili(viagem),ceili(Exp.duracao_planejada(tipo,viagem)),ceili(viagem)],18)
	texto(conteudo,"Os recursos chegam no retorno à aldeia.",16)
	var risco:=texto(conteudo,"A caça pode terminar em fuga, ferimentos ou mortes. O confronto acrescenta tempo à viagem." if tipo=="caca" else "Você pode solicitar o retorno enquanto a equipe estiver viajando ou trabalhando.",16,"7b3523")
	risco.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func acompanhar() -> void:
	texto(conteudo,"Acompanhe suas viagens sem sair da aldeia.",19)
	texto(conteudo,"Nenhuma expedição enviada nesta prévia.",17)
	var vazio:=Control.new()
	vazio.size_flags_vertical=Control.SIZE_EXPAND_FILL
	conteudo.add_child(vazio)
func rodape() -> void:
	var espaco:=Control.new()
	espaco.size_flags_vertical=Control.SIZE_EXPAND_FILL
	conteudo.add_child(espaco)
	var linha:=HBoxContainer.new()
	conteudo.add_child(linha)
	voltar=botao(linha,"Voltar",func(): mostrar_passo(maxi(0,etapa-1)))
	var preenchimento:=Control.new()
	preenchimento.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	linha.add_child(preenchimento)
	if etapa==1: texto(linha,"%d / 2 integrantes"%equipe.size(),17)
	frente=botao(linha,({"caca":"Enviar caça","pesca":"Enviar pescaria","coleta":"Enviar expedição","reconhecimento":"Enviar expedição"}[tipo]) if etapa==3 else "Seguinte",func(): mostrar_passo(etapa+1),true)
	frente.disabled=(etapa==1 and equipe.is_empty()) or etapa>=3
	if etapa==3: frente.tooltip_text="Prévia visual; o envio será integrado após a aprovação."
	if etapa==4: frente.hide()
func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	if e.physical_keycode==KEY_ESCAPE: mostrar_passo(0)
	elif e.physical_keycode==KEY_F1: mudar_tipo("caca")
	elif e.physical_keycode==KEY_F2: mudar_tipo("pesca")
	elif e.physical_keycode==KEY_F3: mudar_tipo("coleta")
	elif e.physical_keycode==KEY_1: mostrar_passo(0)
	elif e.physical_keycode==KEY_2: mostrar_passo(1)
	elif e.physical_keycode==KEY_3: mostrar_passo(2)
	elif e.physical_keycode==KEY_4: mostrar_passo(3)
	else: return
	get_viewport().set_input_as_handled()
