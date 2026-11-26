extends SceneTree
const S=preload("res://scripts/partida/salvamento.gd")
const B=preload("res://scripts/partida/combate.gd")
var cena
var total:=0
var falhas:=0
var grafico:=false
var pasta: String
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func obter(raiz: Node,nome: String) -> Button:
	for b: Button in raiz.find_children("*","Button",true,false):
		if b.text==nome: return b
	return null
func clicar(b: Button) -> void:
	ok(b!=null,"Botão existe")
	if b==null: return
	if not grafico:
		b.pressed.emit()
		return
	for i in range(8): await process_frame
	var p:=b.get_global_rect().get_center()
	var m:=InputEventMouseMotion.new()
	m.position=p
	root.push_input(m)
	for pressionado in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=p
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=pressionado
		root.push_input(e)
	await process_frame
func captura(nome: String) -> void:
	if not grafico: return
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_etapa_9_final")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_etapa_9_final/"+nome+".png")==OK,"Captura "+nome)
func executar() -> void:
	pasta="user://testes_interface_9/"+Crypto.new().generate_random_bytes(8).hex_encode()
	grafico=DisplayServer.get_name()!="headless"
	cena=load("res://scenes/main.tscn").instantiate()
	cena.configuracao=cena.configuracao.duplicate()
	cena.configuracao.hora_inicial=8
	cena.salvamento=S.new(pasta)
	root.add_child(cena)
	cena.set_process(false)
	cena.iniciar_obra("oca")
	cena.confirmar_obra(Vector2(-5,-4))
	cena._process(18)
	cena.painel.abrir("fogueira")
	await clicar(cena.painel.controles.find_child("Construir_caca",true,false))
	ok(cena.aldeia.modo=="caca","Menu prepara construção de caça")
	cena.aldeia.girar_previa(6)
	cena.confirmar_obra(Vector2(6,-1))
	cena._process(60)
	var e=cena.estado
	ok(e.construcoes[-1].tipo=="caca" and cena.aldeia.locais.has("obra_2"),"Modelo aprovado instanciado no mundo")
	for h: Dictionary in e.habitantes: cena.painel.mudar_setor.emit(h.id,"obra_2")
	cena.painel.abrir("obra_2")
	await clicar(obter(cena.painel.controles,"Expedições"))
	var p=cena.painel_expedicoes
	ok(p.aberto and p.tipo=="caca","Centro abre formulário da caça")
	await clicar(p.botao_abrir)
	p.armas[e.habitantes[1].id]="lanca"
	p.apresentar("preparar")
	for h: Dictionary in e.habitantes: await clicar(p.cards[h.id])
	await clicar(p.frente)
	await clicar(p.frente)
	ok(not p.confirmar.disabled,"Equipe e destino de caça válidos")
	await captura("preparar_caca")
	await clicar(p.confirmar)
	ok(e.expedicoes.size()==1,"Clique real envia caça")
	if e.expedicoes.is_empty():
		quit(1)
		return
	var x: Dictionary=e.expedicoes[0]
	ok(x.armas[e.habitantes[1].id]=="lanca","Kit da equipe preservado")
	cena.fechar_expedicoes()
	cena._process(3+x.viagem+x.duracao_exploracao)
	# Etapa 11: o encontro abre um alerta; "Deixar simular" inicia o confronto simulado.
	ok(x.fase=="alerta","Encontro abre alerta de intervenção")
	cena.simular_alerta(x.id)
	ok(x.fase=="confronto","Aldeia entrou em confronto simulado")
	cena.abrir_expedicoes("obra_2")
	p.apresentar("acompanhar")
	ok(p.linhas[x.id].fase.text.contains("rodada"),"Acompanhamento mostra animal e rodada")
	await captura("confronto_simulado")
	var rng: String=x.combate.rng
	ok(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Partida salva durante combate")
	e=cena.estado
	x=e.expedicoes[0]
	ok(x.combate.rng==rng,"Sorteio do combate preservado")
	cena._process(1000)
	ok(x.fase=="concluida" and x.combate.aplicado,"Resultado aplicado e retorno concluído")
	cena.abrir_expedicoes("obra_2")
	p.apresentar("acompanhar")
	await captura("resultado_caca")
	cena.queue_free()
	await process_frame
	var arena=load("res://scenes/inspecao/arena_combate_etapa_9.tscn").instantiate()
	arena.pasta=pasta.path_join("arena")
	root.add_child(arena)
	for i in range(8): await process_frame
	ok(not arena.combate.is_empty(),"Arena de teste inicia confronto")
	var original: String=arena.combate.rng
	arena.salvar()
	arena.automatico()
	arena.carregar()
	ok(arena.combate.rng==original,"Arena grava e retoma sem rerrolar")
	arena.salvar()
	ok(arena.mensagem.text.contains("salvo"),"Arena substitui o próprio arquivo com segurança")
	await captura("arena_regras")
	if grafico:
		var posicao: Vector2=arena.tabuleiro.get_global_rect().position+Vector2(2.5,3.5)*arena.tabuleiro.CELULA
		var m:=InputEventMouseMotion.new()
		m.position=posicao
		root.push_input(m)
		for pressionado in [true,false]:
			var clique:=InputEventMouseButton.new()
			clique.position=posicao
			clique.button_index=MOUSE_BUTTON_LEFT
			clique.pressed=pressionado
			root.push_input(clique)
		await process_frame
		ok(arena.destino==Vector2i(2,3),"Clique real seleciona célula da arena")
	await clicar(obter(arena,"Uma ação automática"))
	ok(arena.combate.rng!=original or arena.combate.registro.size()>3,"Botão da arena executa regra")
	await clicar(obter(arena,"Resolver automaticamente"))
	ok(arena.combate.resultado!="","Arena resolve confronto sem travar")
	await captura("arena_resultado")
	arena.queue_free()
	await process_frame
	print("INTERFACE_ETAPA_9: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
