extends SceneTree
var cena
var total:=0
var falhas:=0
var grafico:=false
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func esperar() -> void:
	for i in range(12): await process_frame
func clicar(b: Button) -> void:
	if not grafico:
		b.pressed.emit()
		return
	await esperar()
	var p:=b.get_global_rect().get_center()
	var mover:=InputEventMouseMotion.new()
	mover.position=p
	root.push_input(mover)
	for baixo in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=p
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=baixo
		root.push_input(e)
	await process_frame
func captura(nome: String) -> void:
	if not grafico: return
	await esperar()
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_menu_casca_integrado")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_menu_casca_integrado/"+nome+".png")==OK,"Captura "+nome)
func executar() -> void:
	grafico=DisplayServer.get_name()!="headless"
	cena=load("res://scenes/main.tscn").instantiate()
	var pasta:="user://testes_menu_casca/"+Crypto.new().generate_random_bytes(8).hex_encode()
	cena.salvamento=load("res://scripts/partida/salvamento.gd").new(pasta)
	root.add_child(cena)
	cena.set_process(false)
	var estado=cena.estado
	estado.estoque.madeira=400
	estado.estoque.fibras_vegetais=300
	for obra in [["oca",Vector2(-5,-4)],["oca",Vector2(4,-8)],["coleta",Vector2(-13,3)],["caca",Vector2(-6,5.5)],["pesca",Vector2(8,1.2)]]:
		ok(estado.construir(obra[0],obra[1])=="","Construir "+obra[0])
		estado.avancar_aldeia(60)
	cena.aldeia.sincronizar()
	var p=cena.painel_expedicoes
	for caso in [["obra_4","caca"],["obra_5","pesca"],["obra_3","coleta"],["obra_3","reconhecimento"]]:
		cena.aldeia.selecionado.emit(caso[0])
		ok(p.aberto and p.mini.visible and not p.quadro.visible,"Seleção abre menu pequeno: "+caso[1])
		await captura(caso[1]+"_compacto")
		await clicar(p.botao_abrir)
		if caso[1]=="reconhecimento":
			p.seletor_tipo.select(1)
			p.seletor_tipo.item_selected.emit(1)
		ok(p.frente.disabled,"Sem equipe bloqueia avanço")
		for h: Dictionary in estado.habitantes.slice(0,2): await clicar(p.cards[h.id])
		ok(p.equipe.size()==2 and not p.frente.disabled,"Fichas selecionam equipe real")
		ok(p.cards[estado.habitantes[2].id].disabled,"Terceiro integrante bloqueado")
		await captura(caso[1]+"_equipe")
		await clicar(p.frente)
		if caso[1]=="caca":
			await clicar(p.cards.lanca)
			ok(p.armas[p.equipe[0]]=="lanca","Arma individual real")
		await captura(caso[1]+"_equipamentos")
		await clicar(p.frente)
		ok(p.etapa==3 and not p.confirmar.disabled,"Resumo válido: "+caso[1])
		for i in range(p.seletor_destino.item_count):
			var r: int=p.seletor_destino.get_item_id(i)
			ok(caso[1]!="pesca" or p.Regioes.definicoes()[r].recursos.has("peixe"),"Pesca só oferece água com peixes")
		await captura(caso[1]+"_confirmacao")
		var quantidade: int=estado.expedicoes.size()
		await clicar(p.confirmar)
		ok(estado.expedicoes.size()==quantidade+1 and p.etapa==4,"Envio real: "+caso[1])
		var viagem: Dictionary=estado.expedicoes[-1]
		ok(viagem.tipo==caso[1] and estado.habitantes[0].estado=="em_expedicao","Atividade e disponibilidade persistidas")
		if caso[1]=="caca": ok(viagem.armas[estado.habitantes[0].id]=="lanca","Lança chega ao motor")
		ok(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Salvar/carregar viagem real")
		estado=cena.estado
		cena.abrir_expedicoes(caso[0])
		await clicar(p.botao_abrir)
		ok(p.cards[estado.habitantes[0].id].disabled,"Morador viajando indisponível")
		p.apresentar("acompanhar")
		await captura(caso[1]+"_acompanhamento")
		await clicar(p.linhas[viagem.id].retorno)
		ok(estado.expedicoes[-1].fase=="concluida" and estado.habitantes[0].estado=="livre","Cancelar preparação libera equipe")
		cena.fechar_expedicoes()
		ok(cena._controle.is_processing(),"Fechar restaura câmera")
	# Mortos e trabalhadores de outros centros não podem compor a equipe.
	var h: Dictionary=estado.habitantes[2]
	h.estado="morto"
	h.saude=0
	cena.abrir_expedicoes("obra_4")
	await clicar(p.botao_abrir)
	ok(not p.cards.has(h.id),"Falecidos excluídos das fichas")
	h.estado="trabalhando"
	h.saude=100
	h.setor="obra_3"
	p.mostrar_passo(1)
	ok(p.cards[h.id].disabled,"Trabalhador de outro centro bloqueado")
	h.estado="livre"
	h.setor=""
	# Uma fronteira no mapa escolhe o centro de coleta mesmo após usar caça.
	for r: Dictionary in p.Regioes.definicoes():
		if int(estado.conhecimento[str(r.id)])==0 and p.Regioes.fronteira(r.id,estado.conhecimento):
			cena.abrir_expedicoes("",r.id)
			ok(p.tipo=="reconhecimento" and p.centro=="obra_3" and p.regiao==r.id,"Mapa preserva fronteira e escolhe centro compatível")
			break
	cena.fechar_expedicoes()
	# Viagem completa de pesca, incluindo entrega e retomada sem duplicação.
	cena.abrir_expedicoes("obra_5")
	await clicar(p.botao_abrir)
	await clicar(p.cards[estado.habitantes[0].id])
	await clicar(p.frente)
	await clicar(p.frente)
	await clicar(p.confirmar)
	var x: Dictionary=estado.expedicoes[-1]
	cena._process(3+x.viagem+x.duracao_exploracao+x.viagem+5)
	p._process(.3)
	ok(x.fase=="concluida" and not x.entregue.is_empty(),"Pesca completa entrega recursos")
	var estoque: Dictionary=estado.estoque.duplicate()
	ok(cena.salvar_partida("manual") and cena.carregar_partida("manual") and cena.estado.estoque==estoque,"Carregar não duplica entrega")
	cena.queue_free()
	await process_frame
	print("MENU_CASCA_INTEGRADO: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
