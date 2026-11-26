extends Control
signal pausa_solicitada
signal velocidade_solicitada(valor: int)
signal escala_solicitada(valor: float)
signal ocultar_solicitado
## Etapa 11: botões do cartão de alerta de perigo.
signal alerta_assumir(id: String)
signal alerta_simular(id: String)
const Icone=preload("res://scripts/partida/icone_recurso.gd")
const Casca=preload("res://scripts/ui/estilo_casca.gd")
const RECURSOS := {"madeira":"Madeira","pedra":"Pedra","fibras_vegetais":"Fibras vegetais","vegetais":"Vegetais","carne":"Carne","peixe":"Peixe","couro":"Couro","plantas_medicinais":"Plantas medicinais"}
var estado
var numeros: Dictionary={}
var populacao: Label
var horario: Label
var pausa: Button
var velocidades: Array[Button]=[]
var barra: PanelContainer
var linha: HBoxContainer
var feed: VBoxContainer
var avisos: Array[Dictionary]=[]
## Cartões de alerta (topo do feed), lidos do estado das expedições a cada atualização.
var cartoes: VBoxContainer
var alertas: Dictionary={}
const URUCUM:=Color("b5482a")

class Pata extends Control:
	## Ícone de perigo: pegada desenhada em vetor.
	var cor:=Color("fff1cf")
	func _draw() -> void:
		var s:=size.x
		draw_circle(Vector2(s*.5,s*.66),s*.22,cor)
		for p: Vector2 in [Vector2(.22,.36),Vector2(.4,.2),Vector2(.6,.2),Vector2(.78,.36)]:
			draw_circle(p*s,s*.1,cor)

class Prazo extends Control:
	var fracao:=1.0:
		set(v):
			fracao=v
			queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.21,0.15,0.1,.35))
		draw_rect(Rect2(Vector2.ZERO,Vector2(size.x*clampf(fracao,0,1),size.y)),Color("b5482a"))
var escala_indice:=1
var acumulado:=0.0

## Faixa de casca interna (borda fina) usada pela barra e pelos avisos.
func estilo() -> StyleBox:
	return Casca.painel(true)

func rotulo(pai: Node, valor: String) -> Label:
	var l:=Label.new()
	l.text=valor
	l.add_theme_color_override("font_color",Casca.TINTA)
	l.add_theme_font_size_override("font_size",17)
	l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	pai.add_child(l)
	return l

func botao(valor: String, dica: String, acao: Callable) -> Button:
	var b:=Button.new()
	b.text=valor
	b.tooltip_text=dica
	b.focus_mode=Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size",16)
	Casca.margens(b,10,4)
	# A velocidade ativa fica desativada: mostra a lasca tingida de urucum.
	var ativo:=Casca.estilo("normal","BotaoCascaPrimario")
	ativo.content_margin_left=10
	ativo.content_margin_right=10
	ativo.content_margin_top=4
	ativo.content_margin_bottom=4
	b.add_theme_stylebox_override("disabled",ativo)
	b.add_theme_color_override("font_disabled_color",Casca.CREME)
	b.pressed.connect(acao)
	linha.add_child(b)
	return b

func separador() -> void:
	var s:=VSeparator.new()
	linha.add_child(s)

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	barra=PanelContainer.new()
	barra.add_theme_stylebox_override("panel",estilo())
	add_child(barra)
	linha=HBoxContainer.new()
	linha.add_theme_constant_override("separation",8)
	barra.add_child(linha)
	for recurso: String in RECURSOS:
		var celula:=HBoxContainer.new()
		celula.add_theme_constant_override("separation",3)
		celula.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		celula.tooltip_text=RECURSOS[recurso]
		celula.mouse_filter=Control.MOUSE_FILTER_STOP
		linha.add_child(celula)
		var icone:=Icone.new()
		icone.tipo=recurso
		celula.add_child(icone)
		numeros[recurso]=rotulo(celula,"0")
	separador()
	var grupo:=HBoxContainer.new()
	grupo.tooltip_text="Moradores / capacidade de moradia"
	grupo.mouse_filter=Control.MOUSE_FILTER_STOP
	linha.add_child(grupo)
	var icone:=Icone.new()
	icone.tipo="populacao"
	grupo.add_child(icone)
	populacao=rotulo(grupo,"0/0")
	separador()
	horario=rotulo(linha,"Dia 1 · 16:00")
	pausa=botao("Ⅱ","Pausar ou retomar · Espaço",func(): pausa_solicitada.emit())
	for v in range(1,4):
		velocidades.append(botao("%d×"%v,"Velocidade %d× · tecla %d"%[v,v],velocidade_solicitada.emit.bind(v)))
	botao("UI","Escala da interface · alternar entre 85%, 100% e 115%",trocar_escala)
	botao("H","Ocultar interface · H para retornar",func(): ocultar_solicitado.emit())
	feed=VBoxContainer.new()
	feed.add_theme_constant_override("separation",6)
	add_child(feed)
	feed.mouse_filter=Control.MOUSE_FILTER_IGNORE
	cartoes=VBoxContainer.new()
	cartoes.add_theme_constant_override("separation",6)
	cartoes.mouse_filter=Control.MOUSE_FILTER_IGNORE
	feed.add_child(cartoes)
	resized.connect(ajustar)
	ajustar()

func trocar_escala() -> void:
	escala_indice=(escala_indice+1)%3
	escala_solicitada.emit([.85,1.0,1.15][escala_indice])

func ajustar() -> void:
	if not feed: return
	barra.size.x=size.x
	feed.position=Vector2(maxf(8,size.x-352),barra.size.y+12)
	feed.size.x=340

func configurar(novo) -> void:
	estado=novo
	avisos.clear()
	for filho in feed.get_children():
		if filho!=cartoes: filho.queue_free()
	for c in cartoes.get_children(): c.queue_free()
	alertas.clear()
	atualizar()

func atualizar() -> void:
	if estado==null: return
	for r: String in RECURSOS:
		numeros[r].text=str(estado.estoque[r])
		numeros[r].get_parent().tooltip_text="%s · %d / %d"%[RECURSOS[r],estado.estoque[r],estado.LIMITE_ESTOQUE]
		if r in estado.Alimentacao.TIPOS:
			numeros[r].get_parent().tooltip_text="%s · %d\nAlimentos: %d/%d no total. Validade: %d dias. Detalhes em Comunidade."%[RECURSOS[r],estado.estoque[r],estado.Alimentacao.total(estado),estado.Alimentacao.parametros.capacidade,estado.Alimentacao.parametros.validade_dias[r]]
	populacao.text="%d/%d"%[estado.populacao(),estado.capacidade_residencial()]
	var minutos:=floori(estado.relogio.obter_hora()*60)
	horario.text="Dia %d · %02d:%02d"%[estado.relogio.obter_dia(),minutos/60,minutos%60]
	pausa.text="▶" if estado.relogio.pausado else "Ⅱ"
	for i in range(velocidades.size()):
		velocidades[i].disabled=estado.relogio.velocidade==i+1
	atualizar_alertas()

func texto_casca(pai: Node,valor: String,tam: int,cor: Color,titulo:=false) -> Label:
	var l:=Label.new()
	l.text=valor
	l.add_theme_font_override("font",Casca.FONTE_TITULO if titulo else Casca.FONTE_TEXTO)
	l.add_theme_font_size_override("font_size",tam)
	l.add_theme_color_override("font_color",cor)
	pai.add_child(l)
	return l

## Título do perigo conforme o animal (texto curto, legível no feed).
static func titulo_perigo(animal: String) -> String:
	return {"queixada":"Queixada cerca a equipe","anta":"Anta assustada avança","jacare_papo_amarelo":"Jacaré na margem",
		"onca_pintada":"Onça-pintada à espreita","capivara":"Capivara à vista"}.get(animal,"Animal ameaça a equipe")

func cartao_alerta(e: Dictionary) -> Dictionary:
	var painel:=PanelContainer.new()
	painel.add_theme_stylebox_override("panel",Casca.painel())
	painel.mouse_filter=Control.MOUSE_FILTER_STOP
	cartoes.add_child(painel)
	var v:=VBoxContainer.new()
	v.add_theme_constant_override("separation",4)
	painel.add_child(v)
	var faixa:=PanelContainer.new()
	var sb:=StyleBoxFlat.new()
	sb.bg_color=URUCUM
	sb.set_corner_radius_all(4)
	sb.content_margin_left=8
	sb.content_margin_right=8
	sb.content_margin_top=3
	sb.content_margin_bottom=3
	faixa.add_theme_stylebox_override("panel",sb)
	v.add_child(faixa)
	var h:=HBoxContainer.new()
	faixa.add_child(h)
	var pata:=Pata.new()
	pata.custom_minimum_size=Vector2(20,20)
	h.add_child(pata)
	texto_casca(h,"Perigo · "+estado.Expedicoes.NOMES_ATIVIDADE.get(e.tipo,e.tipo),15,Casca.CREME,true)
	texto_casca(v,titulo_perigo(e.combate.animal),17,Casca.TINTA_DESTAQUE,true)
	var linha_equipe:=HBoxContainer.new()
	v.add_child(linha_equipe)
	for id in e.equipe:
		var p: Dictionary=estado.pessoa(id)
		var t:=TextureRect.new()
		t.texture=load("res://assets/ui/retratos/%s.png"%p.get("visual","homem_01"))
		t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.custom_minimum_size=Vector2(30,30)
		t.tooltip_text=p.get("nome","")
		linha_equipe.add_child(t)
	var regiao: int=int(e.regiao)
	var nome_regiao: String=estado.Regioes.definicoes()[regiao].nome if int(estado.conhecimento[str(regiao)])>0 else "Região desconhecida"
	texto_casca(linha_equipe,"  "+nome_regiao,14,Casca.TINTA_SUAVE)
	var prazo:=Prazo.new()
	prazo.custom_minimum_size=Vector2(0,7)
	v.add_child(prazo)
	var contagem:=texto_casca(v,"",13,Casca.TINTA_SUAVE)
	var botoes:=HBoxContainer.new()
	botoes.add_theme_constant_override("separation",6)
	v.add_child(botoes)
	var id_exp: String=e.id
	var assumir:=Button.new()
	assumir.text="Assumir combate"
	Casca.botao(assumir,true)
	assumir.add_theme_font_size_override("font_size",14)
	assumir.focus_mode=Control.FOCUS_NONE
	assumir.pressed.connect(func(): alerta_assumir.emit(id_exp))
	botoes.add_child(assumir)
	var indisponivel:=texto_casca(botoes,"Manual ainda indisponível",13,Casca.TINTA_SUAVE)
	var simular:=Button.new()
	simular.text="Deixar simular"
	Casca.botao(simular)
	simular.add_theme_font_size_override("font_size",14)
	simular.focus_mode=Control.FOCUS_NONE
	simular.pressed.connect(func(): alerta_simular.emit(id_exp))
	botoes.add_child(simular)
	return {"painel":painel,"prazo":prazo,"contagem":contagem,"assumir":assumir,"indisponivel":indisponivel,"simular":simular}

func atualizar_alertas() -> void:
	if not cartoes or estado==null: return
	var abertos:={}
	for e: Dictionary in estado.Expedicoes.alertas(estado):
		abertos[e.id]=true
		if not alertas.has(e.id): alertas[e.id]=cartao_alerta(e)
		var c: Dictionary=alertas[e.id]
		c.prazo.fracao=float(e.restante)/estado.Expedicoes.PRAZO_ALERTA
		c.contagem.text="Intervir em %d s · velocidade reduzida para 1×"%ceili(e.restante)
		var manual: bool=estado.Expedicoes.manual_disponivel(e)
		var ocupado: bool=not estado.Expedicoes.manual_pendente(estado).is_empty()
		c.assumir.visible=manual
		c.assumir.disabled=ocupado
		c.assumir.tooltip_text="Conclua o combate em andamento antes." if ocupado else "Jogar este encontro no tabuleiro (o sorteio já feito é mantido)."
		c.indisponivel.visible=not manual
		c.simular.tooltip_text="A equipe resolve sozinha com a política %s."%e.get("politica","equilibrada")
	for id in alertas.keys():
		if not abertos.has(id):
			alertas[id].painel.queue_free()
			alertas.erase(id)

func notificar(msg: String) -> void:
	if msg.is_empty(): return
	# O alerta de perigo tem cartão próprio; não repetir como aviso simples.
	if msg.contains("PERIGO ·"):
		atualizar_alertas()
		return
	var painel:=PanelContainer.new()
	var duracao:=9.0
	if msg.contains("Resumo ·"):
		# Resumo final da viagem: título e linhas, mais tempo na tela.
		painel.add_theme_stylebox_override("panel",Casca.painel())
		feed.add_child(painel)
		var v:=VBoxContainer.new()
		painel.add_child(v)
		var partes:=msg.substr(msg.find("Resumo ·")).split("\n")
		texto_casca(v,partes[0],16,Casca.TINTA_DESTAQUE,true)
		for linha in partes.slice(1):
			var l:=texto_casca(v,linha,14,Casca.TINTA)
			l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		duracao=20.0
	else:
		painel.add_theme_stylebox_override("panel",estilo())
		feed.add_child(painel)
		var texto:=rotulo(painel,msg)
		texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	avisos.append({"painel":painel,"restante":duracao})
	if avisos.size()>3:
		avisos.pop_front().painel.queue_free()

func _process(delta: float) -> void:
	acumulado+=delta
	if acumulado>.15:
		atualizar()
		acumulado=0
	for i in range(avisos.size()-1,-1,-1):
		avisos[i].restante-=delta
		if avisos[i].restante<=0:
			avisos[i].painel.queue_free()
			avisos.remove_at(i)
	ajustar()
