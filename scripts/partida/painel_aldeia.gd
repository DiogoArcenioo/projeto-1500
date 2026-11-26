extends "res://scripts/inspecao/menu_contextual_visual.gd"
signal iniciar_obra(tipo: String)
signal cancelar_obra
signal mudar_setor(id: String,destino: String)
signal pausa_solicitada
signal velocidade_solicitada(valor: int)
signal mapa_solicitado
signal expedicoes_solicitadas(centro: String)
signal cultivo_solicitado(centro: String,indice: int,cultivo: String)
signal plantio_solicitado(centro: String,indice: int)
signal giro_solicitado(sentido: int)
signal plantar_selecao_solicitado(cultivo: String)
signal limpar_selecao_solicitado
const Alim=preload("res://scripts/partida/alimentacao.gd")
const IconeRecurso=preload("res://scripts/partida/icone_recurso.gd")
const MINIATURAS:="res://assets/ui/construcoes/"
## O que cada construção faz, em uma frase curta para os cartões e dicas.
const FUNCOES:={
	"oca":"Moradia para 2 pessoas. Novas famílias chegam quando há vaga.",
	"coleta":"Moradores colhem fibras e vegetais nos arredores.",
	"agricultura":"Roça de milho e mandioca. Precisa de um agricultor.",
	"pesca":"Peixe do rio. Deve ficar perto da água.",
	"caca":"Prepara caçadas por carne e couro. Tem riscos.",
}
const RESUMOS:={"oca":"Moradia","coleta":"Fibras e vegetais","agricultura":"Milho e mandioca","pesca":"Peixe","caca":"Carne e couro"}
const DICA_INICIO:="Passe o mouse sobre uma opção para saber o que ela faz."
var voltar: Button
var dica_ativa:=""

var estado
var contexto := "inicio"
var escolha := ""
var aviso := ""
var conteiner: PanelContainer
var coluna: VBoxContainer
var titulo: Label
var resumo: Label
var detalhe: Label
var mensagem: Label
var controles: VBoxContainer
var rolagem: ScrollContainer
var colocando := ""
var assinatura := ""
var topo_hud := preload("res://scripts/partida/barra_superior.gd").new()
var escala_usuario := 1.0
var escala_efetiva := 1.0
var angulo_obra: Label
var rotacao_graus:=0
var terrenos_selecionados: Array=[]

func _ready() -> void:
	_superficie=Control.new()
	add_child(_superficie)
	_superficie.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_superficie.add_child(topo_hud)
	topo_hud.pausa_solicitada.connect(func(): pausa_solicitada.emit())
	topo_hud.velocidade_solicitada.connect(func(v: int): velocidade_solicitada.emit(v))
	topo_hud.escala_solicitada.connect(definir_escala)
	topo_hud.ocultar_solicitado.connect(alternar_hud)
	conteiner=painel()
	conteiner.minimum_size_changed.connect(func(): ajustar.call_deferred())
	coluna=VBoxContainer.new()
	conteiner.add_child(coluna)
	var topo:=HBoxContainer.new()
	coluna.add_child(topo)
	titulo=texto(topo,"",22)
	titulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	resumo=texto(topo,"",16,Casca.TINTA_SUAVE)
	resumo.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	voltar=botao_acao(topo,"Voltar",abrir.bind("inicio"))
	voltar.tooltip_text="Voltar ao menu da aldeia · Esc"
	rolagem=ScrollContainer.new()
	rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	controles=VBoxContainer.new()
	controles.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	rolagem.add_child(controles)
	mensagem=texto(coluna,"",15,Casca.TINTA_DESTAQUE)
	mensagem.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	get_viewport().size_changed.connect(ajustar)
	ajustar()

func ajustar() -> void:
	if not conteiner: return
	var tam:=get_viewport().get_visible_rect().size
	var minimo:=maxf(1080,topo_hud.barra.get_combined_minimum_size().x+16)
	escala_efetiva=minf(escala_usuario,tam.x/minimo)
	_superficie.scale=Vector2.ONE*escala_efetiva
	tam/=escala_efetiva
	_superficie.size=tam
	topo_hud.size=Vector2(tam.x,60)
	var largura:=minf(1100,tam.x-32)
	var recolhido:=contexto=="inicio" and colocando==""
	var construir:=contexto=="fogueira" and colocando==""
	if construir: largura=minf(880,largura)
	titulo.get_parent().visible=not recolhido
	voltar.visible=construir
	var gestor:=colocando=="" and (contexto=="comunidade" or contexto.begins_with("obra_"))
	rolagem.custom_minimum_size.y=minf(211,tam.y*.30) if gestor else (90 if largura<670 else 50)
	if contexto=="terrenos" and colocando=="": rolagem.custom_minimum_size.y=minf(112,tam.y*.22)
	if construir: rolagem.custom_minimum_size.y=170
	if recolhido: rolagem.custom_minimum_size.y=controles.get_combined_minimum_size().y
	conteiner.offset_top=-10
	conteiner.offset_bottom=-10
	conteiner.grow_vertical=Control.GROW_DIRECTION_BEGIN
	conteiner.reset_size()
	conteiner.offset_left=-largura/2
	conteiner.offset_right=largura/2
	if recolhido:
		var metade:=maxf(250,controles.get_combined_minimum_size().x*.5+40)
		conteiner.offset_left=-metade
		conteiner.offset_right=metade
		conteiner.reset_size()
		conteiner.offset_left=-metade
		conteiner.offset_right=metade
	topo_hud.ajustar()

func reiniciar(novo) -> void:
	estado=novo
	terrenos_selecionados=[]
	topo_hud.configurar(estado)
	contexto="inicio"
	escolha=""
	colocando=""
	aviso="Selecione a fogueira para construir a primeira oca." if estado.construcoes.is_empty() else ""
	atualizar(true)

func abrir(id: String) -> void:
	contexto=id
	aviso=""
	atualizar(true)

func botao_acao(pai: Node, rotulo: String, acao: Callable, destaque:=false) -> Button:
	var b:=botao(pai,rotulo,destaque)
	b.custom_minimum_size=Vector2(0,36)
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",16)
	Casca.margens(b,12,6)
	b.pressed.connect(acao)
	return b

func notificar(msg: String) -> void:
	aviso=msg
	mostrar_dica(dica_ativa)

## Linha inferior: dica da opção sob o mouse; sem ela, o último aviso; no menu
## inicial e no Construir, uma orientação fixa para o painel não pular.
func mostrar_dica(valor: String) -> void:
	dica_ativa=valor
	var guia:=colocando=="" and contexto in ["inicio","fogueira"]
	mensagem.text=valor if valor!="" else (aviso if aviso!="" else (DICA_INICIO if guia else ""))
	mensagem.add_theme_color_override("font_color",Casca.TINTA_DESTAQUE if valor=="" and aviso!="" else Casca.TINTA_SUAVE)
	mensagem.visible=mensagem.text!=""
	ajustar()

func ligar_dica(b: Control,valor: String) -> void:
	b.tooltip_text=valor
	b.mouse_entered.connect(mostrar_dica.bind(valor))
	b.mouse_exited.connect(func(): if dica_ativa==valor: mostrar_dica(""))

## Bloco ilustrado do menu inicial: figura em cima, nome embaixo.
func atalho(pai: Node,rotulo: String,figura: String,descricao: String,acao: Callable) -> Button:
	var b:=Button.new()
	b.text=rotulo
	b.icon=load(MINIATURAS+figura+".png")
	b.expand_icon=true
	b.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment=VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size=Vector2(112,92)
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",15)
	b.add_theme_constant_override("h_separation",2)
	for cor in ["icon_normal_color","icon_hover_color","icon_pressed_color","icon_hover_pressed_color","icon_focus_color"]:
		b.add_theme_color_override(cor,Color.WHITE)
	Casca.margens(b,8,7)
	var claro:=Casca.estilo("panel","CartaoCasca")
	claro.content_margin_left=8
	claro.content_margin_right=8
	claro.content_margin_top=7
	claro.content_margin_bottom=7
	b.add_theme_stylebox_override("normal",claro)
	ligar_dica(b,descricao)
	b.pressed.connect(acao)
	pai.add_child(b)
	return b

## Cartão de construção: foto do modelo real, nome, função e custo com os
## mesmos ícones da barra de recursos.
func cartao_construcao(pai: Node,tipo: String) -> Button:
	var b:=Button.new()
	b.name="Construir_"+tipo
	b.focus_mode=Control.FOCUS_NONE
	b.custom_minimum_size=Vector2(152,164)
	b.add_theme_stylebox_override("normal",Casca.estilo("panel","CartaoCasca"))
	for nome in ["hover","pressed","hover_pressed"]: b.add_theme_stylebox_override(nome,Casca.estilo(nome))
	pai.add_child(b)
	var custo: Dictionary=estado.CUSTOS[tipo]
	var faltam: Array[String]=[]
	for r: String in custo:
		if estado.estoque[r]<custo[r]: faltam.append("%d %s"%[custo[r]-estado.estoque[r],"madeira" if r=="madeira" else "fibras"])
	var descricao:="%s · %s %s"%[estado.NOMES_CONSTRUCOES[tipo],FUNCOES[tipo],"" if faltam.is_empty() else "Faltam "+" e ".join(faltam)+"."]
	ligar_dica(b,descricao.strip_edges())
	var col:=VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left=8
	col.offset_right=-8
	col.offset_top=6
	col.offset_bottom=-7
	col.add_theme_constant_override("separation",0)
	col.mouse_filter=Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var foto:=TextureRect.new()
	foto.texture=load(MINIATURAS+tipo+".png")
	foto.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foto.custom_minimum_size=Vector2(0,82)
	foto.mouse_filter=Control.MOUSE_FILTER_IGNORE
	col.add_child(foto)
	var nome:=texto(col,estado.NOMES_CONSTRUCOES[tipo],16)
	nome.theme_type_variation="TituloCasca"
	nome.add_theme_font_size_override("font_size",16)
	nome.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	nome.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var funcao:=texto(col,RESUMOS[tipo],14,Casca.TINTA_SUAVE)
	funcao.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	funcao.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var linha_custo:=HBoxContainer.new()
	linha_custo.alignment=BoxContainer.ALIGNMENT_CENTER
	linha_custo.add_theme_constant_override("separation",3)
	linha_custo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	col.add_child(linha_custo)
	for r: String in custo:
		var icone:=IconeRecurso.new()
		icone.tipo=r
		icone.scale=Vector2.ONE*.78
		icone.custom_minimum_size=Vector2(20,20)
		linha_custo.add_child(icone)
		var valor:=texto(linha_custo,str(custo[r]),15,Casca.TINTA if estado.estoque[r]>=custo[r] else Color("a3301a"))
		valor.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var espaco:=Control.new()
		espaco.custom_minimum_size.x=6
		linha_custo.add_child(espaco)
	return b

func atualizar(forcar:=false) -> void:
	if estado==null: return
	topo_hud.atualizar()
	var c: Dictionary=estado.estrutura(contexto)
	resumo.text="%d moradores  ·  %d vagas de moradia"%[estado.populacao(),estado.capacidade_residencial()]
	var partes: Array=[contexto,escolha,colocando,estado.estoque,estado.populacao(),terrenos_selecionados]
	for obra: Dictionary in estado.construcoes:
		partes.append([obra.id,obra.pronta,ceili(obra.restante)])
		for t: Dictionary in obra.get("talhoes",[]): partes.append([t.cultivo,t.proximo,t.pendente,floori(t.progresso/10),t.trabalhador])
		for t: Dictionary in obra.get("talhoes",[]): partes.append([t.get("celulas",[]).size()])
	partes.append([floori(estado.tempo_economia/10),estado.alimentos.consumo_dia,estado.alimentos.faltas_dia])
	for h: Dictionary in estado.moradores_vivos():
		partes.append([h.id,h.estado,h.setor,h.xp])
	var chave:=str(partes)
	if chave==assinatura and not forcar: return
	assinatura=chave
	var scroll:=rolagem.scroll_vertical
	for no in controles.get_children():
		controles.remove_child(no)
		no.queue_free()
	titulo.text="Construir" if contexto=="fogueira" else "Aldeia"
	dica_ativa=""
	notificar(aviso)
	if colocando!="":
		titulo.text="Preparar terrenos" if colocando=="plantio" else "Posicionar "+estado.NOMES_CONSTRUCOES[colocando]
		var linha:=HFlowContainer.new()
		controles.add_child(linha)
		botao_acao(linha,"Cancelar",func(): cancelar_obra.emit())
		botao_acao(linha,"↶ Z",func(): giro_solicitado.emit(-1))
		botao_acao(linha,"X ↷",func(): giro_solicitado.emit(1))
		angulo_obra=texto(linha,"%d°"%rotacao_graus,16)
		texto(linha,"Cada clique prepara terreno vazio. Esc encerra; depois selecione para plantar." if colocando=="plantio" else "Clique no terreno verde. Z/X giram em passos de 15°.",16)
	elif contexto=="terrenos":
		titulo.text="%d terrenos selecionados"%terrenos_selecionados.size()
		var linha:=HFlowContainer.new()
		controles.add_child(linha)
		botao_acao(linha,"Plantar milho",func(): plantar_selecao_solicitado.emit("milho"),true)
		botao_acao(linha,"Plantar mandioca",func(): plantar_selecao_solicitado.emit("mandioca"))
		botao_acao(linha,"Limpar seleção",func(): limpar_selecao_solicitado.emit())
		var vazios:=0
		var culturas:={"milho":0,"mandioca":0}
		var programados:=0
		for id_terreno in terrenos_selecionados:
			var u: Dictionary=estado.Agricultura.encontrar_celula(estado,id_terreno)
			if not u.get("plantada",true): vazios+=1
			else:
				culturas[u.cultivo]+=1
				if u.proximo!=u.cultivo: programados+=1
		texto(controles,"%d vazios · Milho %d · Mandioca %d · %d com troca programada"%[vazios,culturas.milho,culturas.mandioca,programados],16)
		texto(controles,"A escolha vale só para a seleção. Plantas em crescimento mantêm a safra atual e trocam no replantio.",15)
	elif contexto=="fogueira":
		resumo.text="Estoque · %d madeira · %d fibras"%[estado.estoque.madeira,estado.estoque.fibras_vegetais]
		var linha:=HBoxContainer.new()
		linha.add_theme_constant_override("separation",8)
		linha.alignment=BoxContainer.ALIGNMENT_CENTER
		linha.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		controles.add_child(linha)
		for tipo: String in (["oca","coleta","agricultura","pesca","caca"] if estado.populacao()>0 else ["oca"]):
			cartao_construcao(linha,tipo).pressed.connect(func(): iniciar_obra.emit(tipo))
		if estado.populacao()==0:
			var nota:=texto(linha,"Centros de trabalho liberam\ncom os primeiros moradores.",15,Casca.TINTA_SUAVE)
			nota.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	elif contexto=="inicio":
		var linha:=HBoxContainer.new()
		linha.add_theme_constant_override("separation",8)
		controles.add_child(linha)
		atalho(linha,"Construir","oca","Construir · escolha uma oca ou centro de trabalho e posicione no terreno.",abrir.bind("fogueira"))
		atalho(linha,"Comunidade","comunidade","Comunidade · moradores, quem trabalha onde e a reserva de comida.",abrir.bind("comunidade"))
		atalho(linha,"Mapa · M","mapa","Mapa · regiões ao redor da aldeia e o que já foi descoberto.",func(): mapa_solicitado.emit())
		if not estado.moradores_vivos().is_empty():
			atalho(linha,"Expedições","expedicao","Expedições · envie equipes para caçar, pescar, coletar ou explorar.",func(): expedicoes_solicitadas.emit(""))
	else:
		if contexto=="comunidade": titulo.text="Comunidade"
		elif not c.is_empty():
			titulo.text=estado.NOMES_CONSTRUCOES[c.tipo]+" "+str(c.id).get_slice("_",1)
		var barra:=HFlowContainer.new()
		controles.add_child(barra)
		botao_acao(barra,"Recolher",abrir.bind("inicio"))
		if contexto!="comunidade": botao_acao(barra,"Comunidade",abrir.bind("comunidade"))
		if contexto=="comunidade" or (not c.is_empty() and c.tipo in ["coleta","pesca","caca"] and c.pronta):
			botao_acao(barra,"Expedições",func(): expedicoes_solicitadas.emit(c.id if not c.is_empty() else ""))
		if not c.is_empty():
			if not c.pronta: texto(barra,"Obra em andamento · %d s"%ceili(c.restante),16)
			elif c.tipo=="oca": texto(barra,"%d de %d vagas ocupadas"%[c.ocupantes.filter(func(id): return estado.pessoa(id).estado!="morto").size(),estado.vagas(c)],16)
			else: texto(barra,"%d de %d vagas de trabalho"%[estado.ocupacao(c.id),estado.vagas(c)],16)
		if contexto=="comunidade": resumo_alimentar()
		if not c.is_empty() and c.tipo=="agricultura" and c.pronta: talhoes(c)
		for h: Dictionary in estado.moradores_vivos():
			if not c.is_empty() and c.tipo=="oca" and h.casa!=c.id: continue
			linha_pessoa(h,c)
		if estado.moradores_vivos().is_empty(): texto(controles,"Os primeiros moradores chegam quando a oca fica pronta." if estado.habitantes.is_empty() else "A aldeia ficou sem moradores vivos. Ctrl+N inicia outra partida.",16)
		if escolha!="":
			var h: Dictionary=estado.pessoa(escolha)
			if not h.is_empty(): ficha(h)
	ajustar()
	rolagem.set_deferred("scroll_vertical",scroll)

func definir_escala(valor: float) -> void:
	escala_usuario=clampf(valor,.85,1.15)
	ajustar()

func alternar_hud() -> void:
	visible=not visible

func _unhandled_key_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		if evento.physical_keycode==KEY_H:
			alternar_hud()
		elif evento.physical_keycode==KEY_ESCAPE and colocando=="" and contexto!="inicio":
			if contexto=="terrenos": limpar_selecao_solicitado.emit()
			else: abrir("inicio")
		else: return
		get_viewport().set_input_as_handled()

func linha_pessoa(h: Dictionary,c: Dictionary) -> void:
	var linha:=HFlowContainer.new()
	controles.add_child(linha)
	botao_acao(linha,h.nome,selecionar_pessoa.bind(h.id),escolha==h.id)
	var local: String=h.obra if h.estado=="construindo" else h.setor
	texto(linha,h.estado.capitalize()+(" · %s"%local.replace("obra_","#") if local!="" else ""),16)
	if h.estado not in ["livre","trabalhando"]: return
	if h.setor!="": botao_acao(linha,"Liberar",func(): mudar_setor.emit(h.id,""))
	for setor: Dictionary in estado.construcoes:
		if setor.tipo not in estado.SETORES or not setor.pronta or setor.id==h.setor: continue
		if not c.is_empty() and c.tipo in estado.SETORES and c.id!=setor.id: continue
		var label: String="%s %s · %d/%d"%[estado.NOMES_CONSTRUCOES[setor.tipo],setor.id.get_slice("_",1),estado.ocupacao(setor.id),estado.vagas(setor)]
		var b:=botao_acao(linha,label,mudar_setor.emit.bind(h.id,setor.id))
		b.disabled=estado.ocupacao(setor.id)>=estado.vagas(setor)

func selecionar_pessoa(id: String) -> void:
	escolha="" if escolha==id else id
	atualizar(true)
	if escolha!="": rolagem.set_deferred("scroll_vertical",100000)

func resumo_alimentar() -> void:
	var consumo: int=estado.populacao()*int(Alim.parametros.consumo_por_adulto_dia)
	var autonomia: String="sem moradores" if consumo==0 else "%.1f dias (sem considerar perdas)"%(float(Alim.total(estado))/consumo)
	var dieta:=Alim.qualidade(estado)
	var l:=texto(controles,"Alimentos %d/%d · Vegetais %d · Peixe %d · Carne %d\nConsumo %d/dia · Reserva %s\nDieta: %s · Produtividade %d%% · Hoje: %d consumidos, %d faltas, %d perdas"%[Alim.total(estado),Alim.parametros.capacidade,estado.estoque.vegetais,estado.estoque.peixe,estado.estoque.carne,consumo,autonomia,dieta.nome,roundi(100*Alim.eficiencia(estado)),estado.alimentos.consumo_dia,estado.alimentos.faltas_dia,estado.alimentos.perdas_dia],16)
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var vencimento:=INF
	for lote: Dictionary in estado.alimentos.lotes: vencimento=minf(vencimento,lote.vence-estado.tempo_economia)
	if is_finite(vencimento): texto(controles,"Próxima perda por validade em %.1f dias. Consumimos primeiro o que vence antes."%maxf(0,vencimento/estado.relogio.duracao_dia_segundos),15)

func talhoes(c: Dictionary) -> void:
	for i in range(c.talhoes.size()):
		var t: Dictionary=c.talhoes[i]
		var linha:=HFlowContainer.new()
		linha.add_theme_constant_override("h_separation",12)
		controles.add_child(linha)
		var h: Dictionary=estado.pessoa(t.trabalhador)
		var duracao: float=Alim.parametros.cultivos[t.cultivo].duracao
		if t.has("celulas"):
			var media:=0.0
			var plantados:=0
			for u: Dictionary in t.celulas: media+=100*u.progresso/float(Alim.parametros.cultivos[u.cultivo].duracao)
			for u: Dictionary in t.celulas:
				if u.get("plantada",true): plantados+=1
			texto(linha,"Área %d · %d terrenos · %d plantados · %d%% · %s"%[i+1,t.celulas.size(),plantados,roundi(media/maxi(1,plantados)),"sem agricultor" if h.is_empty() else h.nome],16)
			botao_acao(linha,"Preparar terrenos",func(): plantio_solicitado.emit(c.id,i))
		else:
			texto(linha,"Talhão antigo %d · %s · %d%% · %s"%[i+1,t.cultivo.capitalize(),floori(100*t.progresso/duracao),"sem agricultor" if h.is_empty() else h.nome],16)
			botao_acao(linha,"Adicionar quadrados",func(): plantio_solicitado.emit(c.id,i))
		if t.pendente>0: texto(linha,"%d aguardando espaço"%t.pendente,16)
		if t.has("celulas"): continue
		texto(linha,"Próximo plantio:",15)
		var seletor:=OptionButton.new()
		seletor.add_item("Milho · 18 min base" if t.has("celulas") else "Milho · 18 min / 6")
		seletor.add_item("Mandioca · 28 min base" if t.has("celulas") else "Mandioca · 28 min / 11")
		seletor.select(0 if t.proximo=="milho" else 1)
		linha.add_child(seletor)
		seletor.item_selected.connect(func(indice: int): cultivo_solicitado.emit(c.id,i,"milho" if indice==0 else "mandioca"))
	texto(controles,"Prepare os quadrados vazios, encerre com Esc e selecione um ou arraste sobre vários para escolher o cultivo.",15)

func ficha(h: Dictionary) -> void:
	var linhas: Array[String]=[
		"%s · %d anos · nível %d · %d XP · Oca %s"%[h.nome,h.idade,h.nivel,h.xp,h.casa.get_slice("_",1)],
		"Saúde %d   Descanso %d   Alimentação %d   ·   %s"%[h.saude,h.descanso,h.alimentacao,", ".join(h.tracos)],
		"Força %d   Agilidade %d   Inteligência %d   Resistência %d   Percepção %d"%[h.atributos.forca,h.atributos.agilidade,h.atributos.inteligencia,h.atributos.resistencia,h.atributos.percepcao],
		"Caça %d   Pesca %d   Agricultura %d   Coleta %d   Construção %d   Combate %d   Artesanato %d   Cura %d"%[h.habilidades.caca,h.habilidades.pesca,h.habilidades.agricultura,h.habilidades.coleta,h.habilidades.construcao,h.habilidades.combate,h.habilidades.artesanato,h.habilidades.cura]]
	for s in linhas:
		var label:=texto(controles,s,16)
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	texto(controles,"Resistência com alimentação atual: %.1f · Rendimento agrícola: +%d%%"%[Alim.resistencia_efetiva(estado,h),roundi(100*estado.Agricultura.bonus(h))],16)
