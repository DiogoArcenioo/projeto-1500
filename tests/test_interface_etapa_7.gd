extends SceneTree
const PASTA:="res://exports/revisao_etapa_7_final/"
var cena
var total:=0
var falhas:=0
var pasta: String

func _initialize() -> void:
	call_deferred("executar")

func verificar(valor: bool,nome: String) -> void:
	total+=1
	if not valor:
		falhas+=1
		push_error(nome)

func aguardar() -> void:
	for i in range(8): await process_frame

func captura(nome: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await aguardar()
	await RenderingServer.frame_post_draw
	verificar(root.get_texture().get_image().save_png(PASTA+nome+".png")==OK,"Captura "+nome)

func clicar(botao: Control) -> void:
	if DisplayServer.get_name()=="headless":
		botao.pressed.emit()
		return
	await aguardar()
	var rolagem: Variant = cena.painel_expedicoes.rolagem
	if is_instance_valid(rolagem) and rolagem.is_ancestor_of(botao):
		rolagem.ensure_control_visible(botao)
		await aguardar()
	var p:=botao.get_global_rect().get_center()
	var movimento:=InputEventMouseMotion.new()
	movimento.position=p
	root.push_input(movimento)
	var evento:=InputEventMouseButton.new()
	evento.position=p
	evento.button_index=MOUSE_BUTTON_LEFT
	evento.pressed=true
	root.push_input(evento)
	evento=InputEventMouseButton.new()
	evento.position=p
	evento.button_index=MOUSE_BUTTON_LEFT
	evento.pressed=false
	root.push_input(evento)

func botao_por_texto(raiz: Node,nome: String) -> Button:
	for b: Button in raiz.find_children("*","Button",true,false):
		if b.text==nome: return b
	return null

func executar() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	pasta="user://testes_interface_7/"+Crypto.new().generate_random_bytes(8).hex_encode()
	cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=preload("res://scripts/partida/salvamento.gd").new(pasta)
	root.add_child(cena)
	cena.set_process(false)
	var e=cena.estado
	for obra in [["oca",Vector2(-5,-4)],["oca",Vector2(4,-8)],["coleta",Vector2(6,-1)],["coleta",Vector2(-13,3)]]:
		verificar(e.construir(obra[0],obra[1])=="","Construção de preparação")
		e.avancar_aldeia(18)
	cena.aldeia.sincronizar()
	cena.painel.atualizar(true)
	var p=cena.painel_expedicoes
	await aguardar()
	var botao_abrir:=botao_por_texto(cena.painel.controles,"Expedições")
	verificar(botao_abrir!=null,"Entrada pela comunidade")
	await captura("entrada")
	await clicar(botao_abrir)
	verificar(p.aberto and p.visible and p.centro=="obra_3","Abrir painel real")
	if not p.aberto:
		cena.queue_free()
		quit(1)
		return
	await clicar(p.botao_abrir)
	verificar(p.frente.disabled,"Bloqueio sem equipe")
	await clicar(p.cards[e.habitantes[0].id])
	await clicar(p.cards[e.habitantes[1].id])
	verificar(not p.frente.disabled and p.equipe.size()==2,"Fichas selecionam equipe")
	await clicar(p.frente)
	await clicar(p.frente)
	if DisplayServer.get_name()!="headless":
		tecla(KEY_H)
		verificar(not p.visible and not cena.painel.visible,"H oculta o painel e o HUD")
		tecla(KEY_H)
		verificar(p.visible and cena.painel.visible and p.equipe.size()==2,"H restaura a seleção da equipe")
	await captura("preparar")
	await clicar(p.confirmar)
	verificar(e.expedicoes.size()==1 and p.tela_atual=="acompanhar","Envio real pelo botão")
	verificar(e.habitantes[0].estado=="em_expedicao","Integrante indisponível")
	cena.fechar_expedicoes()
	verificar(not p.aberto and cena._controle.is_processing(),"Continuar administrando a aldeia")
	cena.painel.abrir("obra_4")
	await aguardar()
	await clicar(botao_por_texto(cena.painel.controles,"Expedições"))
	verificar(p.centro=="obra_4","Entrada contextual escolhe o centro")
	await clicar(p.botao_abrir)
	p.seletor_tipo.select(1)
	p.seletor_tipo.item_selected.emit(1)
	verificar(p.tipo=="reconhecimento","Selecionar reconhecimento")
	verificar(p.cards[e.habitantes[0].id].disabled,"Outra equipe bloqueada na seleção")
	await clicar(p.cards[e.habitantes[2].id])
	await clicar(p.frente)
	await clicar(p.frente)
	var candidato:=-1
	var indice_destino:=-1
	var viagem_mais_curta:=INF
	for i in range(p.seletor_destino.item_count):
		var id: int=p.seletor_destino.get_item_id(i)
		if int(e.conhecimento[str(id)])==0:
			var viagem: float=cena.estado.Regioes.viagem(id,e.conhecimento)
			if viagem<viagem_mais_curta:
				viagem_mais_curta=viagem
				candidato=id
				indice_destino=i
	if indice_destino>=0:
		p.seletor_destino.select(indice_destino)
		p.seletor_destino.item_selected.emit(indice_destino)
	verificar(candidato>=0,"Fronteira desconhecida elegível")
	await clicar(p.confirmar)
	verificar(e.expedicoes.size()==2,"Duas equipes simultâneas")
	cena.abrir_mapa()
	cena.abrir_expedicoes()
	p.apresentar("acompanhar")
	cena._process(3)
	var primeira: Dictionary=e.expedicoes[0]
	cena._process(maxf(float(primeira.viagem),float(e.expedicoes[1].viagem))+60)
	p._process(.3)
	verificar(primeira.ciclos>0,"Atividade real avançou")
	verificar(int(e.conhecimento[str(candidato)])>0,"Reconhecimento ampliou o mapa")
	cena.mapa_regional._process(0)
	verificar(cena.mapa_regional.mapa.regioes[candidato].conhecida,"Mapa exibe descoberta imediatamente")
	verificar(p.linhas.has(primeira.id) and p.linhas[primeira.id].carga.text.contains("Carga"),"Acompanhamento usa carga real")
	await captura("exploracao")
	verificar(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Salvar e carregar durante expedição")
	e=cena.estado
	verificar(e.expedicoes.size()==2 and not p.aberto,"Carregar restaura o estado sem formulário antigo")
	cena.abrir_expedicoes()
	p.apresentar("acompanhar")
	primeira=e.expedicoes[0]
	await clicar(p.linhas[primeira.id].retorno)
	verificar(primeira.fase=="retorno","Retorno antecipado pelo botão")
	verificar(p.linhas[primeira.id].retorno.disabled,"Retorno não pode ser solicitado duas vezes")
	cena._process(400)
	p._process(.3)
	verificar(e.expedicoes[0].fase=="concluida" and e.expedicoes[1].fase=="concluida","Duas equipes retornaram")
	verificar(p.linhas[primeira.id].carga.text.begins_with("Entregue"),"Resumo exibe entrega real")
	await captura("retorno")
	var estoque: Dictionary=e.estoque.duplicate()
	cena.salvar_partida("manual")
	cena.carregar_partida("manual")
	verificar(cena.estado.estoque==estoque,"Recarregar não duplica carga")
	cena.abrir_expedicoes()
	p.apresentar("acompanhar")
	for resolucao in [Vector2i(960,540),Vector2i(1920,1080)]:
		root.content_scale_size=Vector2i.ZERO
		root.size=resolucao
		await aguardar()
		var ret: Rect2=p.quadro.get_global_rect()
		verificar(ret.position.x>=0 and ret.end.x<=resolucao.x+1 and ret.position.y>0 and ret.end.y<=resolucao.y+1,"Painel cabe em "+str(resolucao))
		await captura("painel_%dx%d"%[resolucao.x,resolucao.y])
	cena.queue_free()
	await process_frame
	var d:=DirAccess.open(pasta)
	if d:
		for f in d.get_files(): DirAccess.remove_absolute(pasta.path_join(f))
		DirAccess.remove_absolute(pasta)
	print("INTERFACE_ETAPA_7: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)

func tecla(valor: Key) -> void:
	var e:=InputEventKey.new()
	e.physical_keycode=valor
	e.pressed=true
	root.push_input(e)
	e=InputEventKey.new()
	e.physical_keycode=valor
	e.pressed=false
	root.push_input(e)
