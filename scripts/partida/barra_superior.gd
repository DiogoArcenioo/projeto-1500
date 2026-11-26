extends Control
signal pausa_solicitada
signal velocidade_solicitada(valor: int)
signal escala_solicitada(valor: float)
signal ocultar_solicitado
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
	resized.connect(ajustar)
	ajustar()

func trocar_escala() -> void:
	escala_indice=(escala_indice+1)%3
	escala_solicitada.emit([.85,1.0,1.15][escala_indice])

func ajustar() -> void:
	if not feed: return
	barra.size.x=size.x
	feed.position=Vector2(maxf(8,size.x-320),barra.size.y+12)
	feed.size.x=308

func configurar(novo) -> void:
	estado=novo
	avisos.clear()
	for filho in feed.get_children(): filho.queue_free()
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

func notificar(msg: String) -> void:
	if msg.is_empty(): return
	var painel:=PanelContainer.new()
	painel.add_theme_stylebox_override("panel",estilo())
	feed.add_child(painel)
	var texto:=rotulo(painel,msg)
	texto.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	avisos.append({"painel":painel,"restante":9.0})
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
