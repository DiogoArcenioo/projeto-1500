extends Control
## Arena abstrata de debug autorizada na etapa 9; não apresenta arte de animais.
const B=preload("res://scripts/partida/combate.gd")
const E=preload("res://scripts/partida/estado_partida.gd")
const C=preload("res://scripts/partida/configuracao_partida.gd")
var combate: Dictionary={}
var tabuleiro:=preload("res://scripts/inspecao/tabuleiro_combate_teste.gd").new()
var animal: OptionButton
var semente: SpinBox
var estado: Label
var detalhes: Label
var registro: RichTextLabel
var mensagem: Label
var pasta:="user://arena_etapa_9"
var alvo:=""
var destino:=Vector2i(-1,-1)
var coluna: VBoxContainer
func texto(p: Node,s: String,tamanho:=16) -> Label:
	var l:=Label.new()
	l.text=s
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",Color("f1e5c7"))
	p.add_child(l)
	return l
func botao(p: Node,s: String,f: Callable) -> Button:
	var b:=Button.new()
	b.text=s
	b.custom_minimum_size.y=32
	b.focus_mode=Control.FOCUS_NONE
	b.pressed.connect(f)
	p.add_child(b)
	return b
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fundo:=ColorRect.new()
	fundo.color=Color("10271e")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var margem:=MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left","right","top","bottom"]: margem.add_theme_constant_override("margin_"+lado,18)
	add_child(margem)
	coluna=VBoxContainer.new()
	coluna.add_theme_constant_override("separation",10)
	margem.add_child(coluna)
	texto(coluna,"1500 · Arena de teste da etapa 9",24)
	texto(coluna,"Tabuleiro e marcadores abstratos para validar regras. A partida e seus saves não são alterados.",15)
	var topo:=HFlowContainer.new()
	coluna.add_child(topo)
	animal=OptionButton.new()
	for a: Dictionary in B.regras.animais: animal.add_item(B.nome_animal(a.id))
	topo.add_child(animal)
	texto(topo,"Semente:",16)
	semente=SpinBox.new()
	semente.min_value=1
	semente.max_value=1000000
	semente.value=1509
	topo.add_child(semente)
	botao(topo,"Novo confronto",novo)
	botao(topo,"Salvar confronto · F6",salvar)
	botao(topo,"Carregar · F7",carregar)
	var conteudo:=HBoxContainer.new()
	conteudo.add_theme_constant_override("separation",18)
	coluna.add_child(conteudo)
	conteudo.add_child(tabuleiro)
	tabuleiro.celula_clicada.connect(func(p: Vector2i):
		destino=p
		alvo=""
		for a: Dictionary in combate.atores:
			if B.pos(a)==p: alvo=a.id
		atualizar())
	var direita:=VBoxContainer.new()
	direita.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	conteudo.add_child(direita)
	estado=texto(direita,"",18)
	detalhes=texto(direita,"",15)
	detalhes.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var acoes:=HFlowContainer.new()
	direita.add_child(acoes)
	for acao in [["Mover até seleção","mover"],["Atacar selecionado","atacar"],["Mirar","mirar"],["Defender","defender"],["Proteger selecionado","proteger"],["Retirada da equipe","fugir"],["Passar turno","passar"]]:
		botao(acoes,acao[0],comandar.bind(acao[1]))
	botao(acoes,"Uma ação automática",automatico)
	botao(acoes,"Resolver automaticamente",resolver)
	mensagem=texto(direita,"Clique no tabuleiro para escolher destino ou alvo.",15)
	mensagem.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	registro=RichTextLabel.new()
	registro.custom_minimum_size.y=230
	registro.size_flags_vertical=Control.SIZE_EXPAND_FILL
	registro.scroll_following=true
	registro.add_theme_color_override("default_color",Color("d9dfcd"))
	direita.add_child(registro)
	texto(coluna,"1/2: equipe · A: animal · cinza: obstáculo alto · ocre: cobertura · azul: água · contorno: turno atual",15)
	novo()
func novo() -> void:
	var e=E.nova(C.new())
	e.construir("oca",Vector2(-5,-4))
	e.avancar_aldeia(18)
	var equipe: Array=[]
	for i in range(2):
		var h: Dictionary=e.habitantes[i]
		for k in h.atributos: h.atributos[k]=5
		h.nome="Caçador %d"%(i+1)
		h.especialista_caca=true
		equipe.append(B.humano(h,"arco" if i==0 else "lanca",1,3+i))
	var id: String=B.regras.animais[animal.selected].id
	var aguas: Array=[]
	if id=="jacare_papo_amarelo":
		for z in range(8): aguas.append({"x":7,"z":z})
	combate=B.novo(equipe,id,int(semente.value),[{"x":3,"z":5},{"x":4,"z":1}],[{"x":4,"z":4}],aguas)
	alvo=""
	destino=Vector2i(-1,-1)
	tabuleiro.selecionada=destino
	mensagem.text="Confronto iniciado. Escolha destino ou alvo."
	atualizar()
func comandar(acao: String) -> void:
	var a:=B.atual(combate)
	if a.is_empty():
		mensagem.text="Confronto encerrado."
		return
	mensagem.text=B.agir(combate,a.id,acao,alvo,destino)
	if mensagem.text=="": mensagem.text="Ação executada."
	atualizar()
func automatico() -> void:
	mensagem.text=B.agir_automatico(combate)
	atualizar()
func resolver() -> void:
	B.resolver(combate)
	mensagem.text="Resolução automática concluída pelas mesmas regras."
	atualizar()
func atualizar() -> void:
	tabuleiro.combate=combate
	tabuleiro.queue_redraw()
	var a:=B.atual(combate)
	estado.text="Resultado: "+combate.resultado if a.is_empty() else "Rodada %d · %s · %d PA"%[combate.rodada,a.nome,a.pa]
	var linhas: Array[String]=[]
	for h: Dictionary in combate.atores:
		linhas.append("%s: %d/%d HP · defesa %d · armadura %d"%[h.nome,h.vida,h.vida_max,h.defesa+h.defesa_temp,h.armadura])
	detalhes.text="\n".join(linhas)
	registro.text="\n".join(combate.registro)
func salvar() -> void:
	var erro:=B.validar(combate,E.numero)
	if erro!="":
		mensagem.text=erro
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	var arquivo:=FileAccess.open(pasta.path_join("confronto.tmp"),FileAccess.WRITE)
	if arquivo==null:
		mensagem.text="Não foi possível salvar."
		return
	arquivo.store_string(JSON.stringify(combate))
	arquivo.close()
	var r:=DirAccess.rename_absolute(pasta.path_join("confronto.tmp"),pasta.path_join("confronto.json"))
	mensagem.text="Confronto salvo na pasta de teste." if r==OK else "Falha ao substituir salvamento."
func carregar() -> void:
	var dados: Variant=JSON.parse_string(FileAccess.get_file_as_string(pasta.path_join("confronto.json"))) if FileAccess.file_exists(pasta.path_join("confronto.json")) else null
	var erro:=B.validar(dados,E.numero)
	if erro!="":
		mensagem.text=erro
		return
	combate=dados
	mensagem.text="Confronto carregado sem repetir sorteios."
	atualizar()
func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	if e.physical_keycode==KEY_F6: salvar()
	elif e.physical_keycode==KEY_F7: carregar()
	else: return
	get_viewport().set_input_as_handled()
