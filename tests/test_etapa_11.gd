extends SceneTree
## Etapa 11 — encontros perigosos, alerta no feed, intervenção e simulação completa.
## Headless: regras e interface por sinais. Gráfico (sem --headless): cliques reais e
## capturas em exports/revisao_etapa_11/.
const E=preload("res://scripts/partida/estado_partida.gd")
const C=preload("res://scripts/partida/configuracao_partida.gd")
const B=preload("res://scripts/partida/combate.gd")
const X=preload("res://scripts/partida/expedicoes.gd")
const S=preload("res://scripts/partida/salvamento.gd")
const Regioes=preload("res://scripts/partida/regioes.gd")
var total:=0
var falhas:=0
var pasta: String
var grafico:=false

func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func passo(e,t: float) -> Array[String]: return e.avancar_simulacao(e.relogio.avancar(t))
## Avança segundos de jogo (independente da velocidade escolhida).
func jogo(e,t: float) -> Array[String]:
	e.relogio.tempo_total+=t
	return e.avancar_simulacao(t)

## Coleta e caça com alertas abertos ao mesmo tempo (a coleta sai quando a caça está perto do encontro).
func dois_alertas(e,ids: Array) -> Array:
	var r:=X.enviar(e,centro(e,"caca"),"caca",14,[ids[2],ids[3]] if ids.size()>3 else [ids[2]],"simulado",{ids[2]:"arco"} if ids.size()<=3 else {ids[2]:"arco",ids[3]:"lanca"})
	ok(r.ok,"Caça enviada "+str(r.get("erro","")))
	var caca:=X.buscar(e,r.get("id",""))
	var coleta: Dictionary={}
	var planejado:=false
	for i in range(3000):
		if coleta.is_empty() and caca.fase=="exploracao" and caca.restante<3+Regioes.viagem(6,e.conhecimento)+30:
			var c:=X.enviar(e,centro(e,"coleta"),"coleta",6,[ids[0],ids[1]])
			ok(c.ok,"Coleta enviada "+str(c.get("erro","")))
			coleta=X.buscar(e,c.id)
		if not coleta.is_empty() and coleta.fase=="exploracao" and not planejado:
			# A coleta encontra o perigo 3 s antes da caça: os dois alertas ficam abertos juntos.
			var espera: float=maxf(1.0,float(caca.restante)-3.0) if caca.fase=="exploracao" else 1.0
			coleta.encontro={"em":coleta.explorado+espera,"animal":"queixada"}
			planejado=true
		if caca.fase=="alerta" and not coleta.is_empty() and coleta.fase=="alerta": break
		jogo(e,1)
	return [coleta,caca]
func valido(e,n: String) -> void:
	var erro:=E.validar(e.serializar())
	ok(erro=="",n+" "+erro)

## Aldeia com quatro moradores, centros de coleta e caça e o mapa todo investigado.
func aldeia():
	var e=E.nova(C.new())
	e.construir("oca",Vector2(-5,-4))
	passo(e,18)
	e.construir("oca",Vector2(-6,5.5))
	for h: Dictionary in e.habitantes: e.atribuir(h.id,e.construcoes[-1].id)
	passo(e,60)
	for k in e.conhecimento: e.conhecimento[k]=maxi(2,int(e.conhecimento[k]))
	e.construir("coleta",Vector2(-13,3))
	e.construir("caca",Vector2(6,-1))
	for h: Dictionary in e.habitantes:
		e.atribuir(h.id,e.construcoes[-2].id)
	passo(e,30)
	for h: Dictionary in e.habitantes:
		e.atribuir(h.id,e.construcoes[-1].id)
	passo(e,70)
	for h: Dictionary in e.habitantes:
		if h.estado!="livre": e.atribuir(h.id,"")
	return e

func centro(e,tipo: String) -> String:
	for c: Dictionary in e.construcoes:
		if c.tipo==tipo and c.pronta: return c.id
	return ""

## Envia e leva até a exploração, com o encontro planejado num instante controlado.
func coleta_com_perigo(e,equipe: Array,regiao:=6,animal:="queixada",politica:="") -> Dictionary:
	var r:=X.enviar(e,centro(e,"coleta"),"coleta",regiao,equipe,"simulado",{},politica)
	ok(r.ok,"Envio de coleta "+str(r.get("erro","")))
	var x:=X.buscar(e,r.get("id",""))
	if x.is_empty(): return x
	jogo(e,3+x.viagem+.5)
	ok(x.fase=="exploracao" and x.has("encontro"),"Exploração sorteia o encontro uma única vez")
	x.encontro={"em":x.explorado+5.0,"animal":animal}
	return x

func regras() -> void:
	var e=aldeia()
	ok(e.populacao()>=4 and centro(e,"coleta")!="" and centro(e,"caca")!="","Aldeia de teste com quatro moradores e dois centros")
	var ids: Array=e.habitantes.map(func(h): return h.id)
	# Sorteio único e persistido: carregar não sorteia outra vez.
	var r:=X.enviar(e,centro(e,"coleta"),"coleta",6,[ids[0]])
	var x:=X.buscar(e,r.id)
	ok(x.politica=="prudente","Política padrão prudente fora da caça")
	jogo(e,3+x.viagem+.5)
	var plano: Dictionary=x.encontro.duplicate()
	var dados: Dictionary=JSON.parse_string(JSON.stringify(e.serializar()))
	var clone=E.desserializar(dados)
	ok(clone!=null and clone.expedicoes[-1].encontro.animal==plano.animal and is_equal_approx(float(clone.expedicoes[-1].encontro.em),float(plano.em)),"Encontro planejado sobrevive ao salvamento")
	X.planejar_encontro(e,x)
	ok(x.encontro==plano,"Planejar de novo não rerrola")
	X.retornar(e,x.id)
	passo(e,600)
	# Alerta: velocidade cai para 1×, prazo de 15 s, pausa congela.
	e=aldeia()
	ids=e.habitantes.map(func(h): return h.id)
	e.relogio.definir_velocidade(3)
	x=coleta_com_perigo(e,[ids[0],ids[1]],10,"onca_pintada")
	var avisos:=jogo(e,2)
	ok(x.fase=="exploracao","Antes do instante não há alerta")
	avisos=jogo(e,3)
	ok(x.fase=="alerta" and x.combate.animal=="onca_pintada","Perigo interrompe a equipe com alerta")
	ok(avisos.any(func(m): return m.contains("PERIGO")),"Alerta enviado ao feed")
	ok(e.relogio.velocidade==1 and e.velocidade_antes_alerta==3,"Velocidade reduzida para 1× durante o alerta")
	ok(is_equal_approx(x.restante,X.PRAZO_ALERTA),"Prazo de 15 s")
	ok(not X.manual_disponivel(x) and X.assumir(e,x.id)!="","Sem apresentação (onça), Assumir é recusado")
	valido(e,"Estado com alerta")
	e.relogio.pausado=true
	ok(e.relogio.avancar(10)==0.0 and is_equal_approx(x.restante,X.PRAZO_ALERTA),"Pausa congela o prazo")
	e.relogio.pausado=false
	# Salvar durante o alerta e carregar: mesmo sorteio, mesmo prazo.
	var salvar:=S.new(pasta)
	ok(salvar.salvar(e,"manual").ok,"Salvar durante o alerta")
	var l: Dictionary=salvar.carregar("manual")
	ok(l.ok and l.estado.expedicoes[-1].fase=="alerta" and l.estado.expedicoes[-1].combate.rng==x.combate.rng and is_equal_approx(l.estado.expedicoes[-1].restante,x.restante),"Carregar preserva alerta e sorteio")
	ok(l.ok and l.estado.velocidade_antes_alerta==3,"Carregar preserva a velocidade a retomar")
	# Ignorar: o prazo acaba, a equipe resolve sozinha e o relógio volta a 3×.
	jogo(e,X.PRAZO_ALERTA)
	ok(x.fase=="confronto","Prazo esgotado inicia a simulação")
	for i in range(400):
		if x.fase!="confronto": break
		passo(e,2)
	ok(x.combate.aplicado and x.has("relatorio"),"Encontro resolvido uma única vez com relatório")
	ok(e.relogio.velocidade==3 and e.velocidade_antes_alerta==0,"Velocidade escolhida retomada após o alerta")
	var resultado: String=x.combate.resultado
	if resultado in ["vitoria","animal_fugiu"] and x.combate.atores.all(func(a): return a.lado!="equipe" or a.vida>0):
		ok(x.fase=="exploracao","Vitória com todos aptos retoma a atividade")
	else:
		ok(x.fase=="retorno","Ferido, retirada ou derrota inicia o retorno")
	var estoque: Dictionary=e.estoque.duplicate()
	var xp_antes: Array=e.habitantes.map(func(h): return h.xp)
	X.Caca.aplicar(e,x)
	ok(e.estoque==estoque and e.habitantes.map(func(h): return h.xp)==xp_antes,"Aplicar de novo não duplica XP nem recursos")
	avisos=passo(e,1200)
	ok(x.fase=="concluida","Expedição concluída")
	ok(avisos.any(func(m): return m.contains("Resumo ·") and m.contains("Trazido") and m.contains("XP")),"Resumo final com recursos, XP e condição")
	valido(e,"Estado após conclusão")
	# Deixar simular de imediato e perda de carga na retirada.
	e=aldeia()
	ids=e.habitantes.map(func(h): return h.id)
	x=coleta_com_perigo(e,[ids[0]],6,"queixada","agressiva")
	x.carga={"madeira":6}
	jogo(e,6)
	ok(x.fase=="alerta","Alerta aberto")
	ok(X.manual_disponivel(x),"Queixada pode ser assumida também na coleta")
	ok(x.combate.atores.all(func(a): return a.lado!="equipe" or a.equipamento=="ferramenta"),"Equipe de coleta luta com a ferramenta básica")
	ok(X.simular(e,x.id)=="" and x.fase=="confronto","Deixar simular inicia o confronto")
	ok(X.simular(e,x.id)!="","Segundo clique não repete")
	ok(x.combate.politica=="agressiva","Confronto recebe a política escolhida")
	B.finalizar(x.combate,"retirada")
	X.terminar_confronto(e,x,[])
	ok(x.carga.get("madeira",0)==3 and x.relatorio.perdas.get("madeira",0)==3,"Retirada perde 50% da carga")
	ok(x.fase=="retorno" and x.cancelada,"Retirada encerra a atividade")
	# Políticas: mesma situação, decisões diferentes.
	var c:=B.novo([B.humano(e.habitantes[0],"ferramenta",1,3)],"jacare_papo_amarelo",7)
	c.cursor=c.ordem.find(e.habitantes[0].id);B.iniciar_turno(c)
	c.politica="prudente"
	ok(B.decisao(c).acao=="fugir","Prudente recua diante de predador")
	c.politica="agressiva"
	ok(B.decisao(c).acao!="fugir","Agressiva não recua de saída")
	ok(c.atores[0].dano=="1d4" and c.atores[0].alcance==1,"Ferramenta básica fora da caça")

## Duas equipes em perigo: nenhuma some, só um combate manual por vez, sem duplicar recompensa.
func duas_equipes() -> void:
	var e=aldeia()
	var ids: Array=e.habitantes.map(func(h): return h.id)
	e.relogio.definir_velocidade(2)
	var pares:=dois_alertas(e,ids)
	var coleta: Dictionary=pares[0]
	var caca: Dictionary=pares[1]
	ok(coleta.fase=="alerta" and caca.fase=="alerta" and X.alertas(e).size()==2,"Dois alertas simultâneos na fila")
	ok(X.manual_disponivel(caca) and caca.combate.animal=="capivara","Capivara da caça pode ser assumida")
	ok(X.assumir(e,caca.id)=="" and X.manual_pendente(e).id==caca.id,"Assumir abre o combate manual com o estado sorteado")
	var prazo: float=coleta.restante
	jogo(e,10)
	ok(is_equal_approx(coleta.restante,prazo) and coleta.fase=="alerta","Durante o combate manual o outro alerta fica congelado")
	ok(e.relogio.velocidade==1,"Velocidade segue em 1× durante o combate")
	valido(e,"Estado com combate manual e alerta pendente")
	# Conclui o manual pelo motor: a capivara foge.
	for i in range(300):
		if caca.fase!="confronto": break
		var a:=B.atual(caca.combate)
		if a.lado=="equipe": X.comando_manual(e,caca.id,a.id,"passar")
		else: B.agir_automatico(caca.combate);X.terminar_confronto(e,caca,[])
	ok(caca.combate.aplicado,"Combate manual concluído")
	jogo(e,1)
	ok(coleta.restante<prazo,"Alerta pendente volta a contar")
	X.simular(e,coleta.id)
	jogo(e,3000)
	ok(coleta.fase=="concluida" and caca.fase=="concluida","Duas equipes concluem sem sumir")
	ok(e.relogio.velocidade==2,"Velocidade retomada após os dois encontros")
	valido(e,"Estado final com duas equipes")

## Simulação completa enquanto a aldeia constrói, sem janela forçada.
func simulacao_completa() -> void:
	var e=aldeia()
	var ids: Array=e.habitantes.map(func(h): return h.id)
	var x:=coleta_com_perigo(e,[ids[0],ids[1]],7,"anta")
	var erro_obra: String=e.construir("coleta",Vector2(6,-8))
	if erro_obra!="": erro_obra=e.construir("coleta",Vector2(-8,9))
	ok(erro_obra=="","Obra iniciada durante a viagem "+erro_obra)
	e.atribuir(ids[3],e.construcoes[-1].id)
	var forcado:=false
	for i in range(600):
		passo(e,5)
		if not X.manual_pendente(e).is_empty(): forcado=true
		if x.fase=="concluida": break
	ok(x.fase=="concluida" and x.combate.aplicado,"Expedição simulada inteira com encontro")
	ok(not forcado,"Nenhum combate manual forçado")
	ok(e.construcoes[-1].pronta,"Aldeia continuou construindo")
	# Frequência dos encontros (sorteio da proposta aprovada).
	var contagem:={"coleta_baixo":0,"coleta_alto":0,"pesca_rio":0,"reco":0}
	for i in range(400):
		for caso in [["coleta_baixo","coleta",14],["coleta_alto","coleta",6],["pesca_rio","pesca",3],["reco","reconhecimento",6]]:
			var semente:=RandomNumberGenerator.new()
			semente.seed=hash("teste_%d_%d"%[i,caso[2]])
			var y:={"tipo":caso[1],"regiao":caso[2],"rng":str(semente.state),"duracao_exploracao":240.0}
			X.planejar_encontro(e,y)
			if y.encontro.animal not in ["","capivara"]: contagem[caso[0]]+=1
	ok(contagem.coleta_baixo==0,"Coleta perto da aldeia só encontra capivara (tranquila)")
	ok(contagem.coleta_alto>80 and contagem.coleta_alto<160,"Coleta em região pouco conhecida perto de 30%% (%d/400)"%contagem.coleta_alto)
	ok(contagem.pesca_rio>20 and contagem.pesca_rio<70,"Pesca com jacaré perto de 10%% (%d/400)"%contagem.pesca_rio)
	ok(contagem.reco>25 and contagem.reco<75,"Reconhecimento em região investigada perto de 12%% (%d/400)"%contagem.reco)

## Interface: cartão no feed, Assumir/Deixar simular por clique.
func interface() -> void:
	var cena=load("res://scenes/main.tscn").instantiate()
	cena.configuracao=cena.configuracao.duplicate()
	cena.configuracao.hora_inicial=9
	cena.salvamento=S.new(pasta+"_ui")
	root.add_child(cena)
	cena.set_process(false)
	var e=aldeia()
	var ids: Array=e.habitantes.map(func(h): return h.id)
	dois_alertas(e,ids.slice(0,3))
	# A partida de teste entra pela mesma rota do carregamento real.
	ok(cena.salvamento.salvar(e,"manual").ok and cena.carregar_partida("manual"),"Partida de teste carregada na cena")
	e=cena.estado
	var caca: Dictionary=e.expedicoes[-2]
	var x: Dictionary=e.expedicoes[-1]
	cena.painel.topo_hud.atualizar()
	var hud=cena.painel.topo_hud
	ok(hud.alertas.size()==2,"Dois cartões de alerta no feed")
	var carta_coleta: Dictionary=hud.alertas.get(x.id,{})
	var carta_caca: Dictionary=hud.alertas.get(caca.id,{})
	ok(not carta_coleta.is_empty() and carta_coleta.assumir.visible and not carta_coleta.indisponivel.visible,"Queixada na coleta: botão Assumir combate")
	ok(not carta_caca.is_empty() and carta_caca.assumir.visible,"Capivara: botão Assumir combate")
	await captura("01_dois_alertas")
	await clicar(carta_caca.get("simular"))
	ok(caca.fase=="confronto","Clique em Deixar simular")
	await clicar(carta_coleta.get("assumir"))
	ok(x.fase=="confronto" and x.modo=="manual" and x.combate.animal=="queixada","Clique em Assumir combate (queixada)")
	cena._process(.1)
	ok(is_instance_valid(cena.combate_manual),"Combate manual aberto a partir do alerta")
	if is_instance_valid(cena.combate_manual):
		var encontro = cena.combate_manual
		var animal: Node3D = encontro.atores[encontro.nomes["animal"]]
		var jogador: AnimationPlayer = encontro.player(encontro.nomes["animal"])
		var clipes := ["parada", "andar", "correr", "investida", "errar_ataque", "receber_golpe", "esquivar"]
		ok(jogador != null and clipes.all(func(clipe): return jogador.has_animation(clipe)), "Queixada importada com os sete clipes")
		var esqueletos := animal.find_children("*", "Skeleton3D", true, false)
		ok(esqueletos.size() == 1 and esqueletos[0].find_bone("cabeca") >= 0, "Queixada com esqueleto e osso da cabeça")
		var direcao: Vector3 = encontro.Orientacao.centro_equipe(encontro.equipe) - animal.global_position
		direcao.y = 0
		ok(animal.global_basis.z.normalized().dot(direcao.normalized()) > .99, "Queixada inicia com o focinho voltado à equipe")
	await captura("02_combate_assumido")
	cena.fechar_combate()
	cena.queue_free()

func clicar(b) -> void:
	ok(b!=null,"Botão existe")
	if b==null: return
	if not grafico:
		b.pressed.emit()
		return
	for i in range(8): await process_frame
	var p: Vector2=b.get_global_rect().get_center()
	var m:=InputEventMouseMotion.new()
	m.position=p
	root.push_input(m)
	for pressionado in [true,false]:
		var ev:=InputEventMouseButton.new()
		ev.position=p
		ev.button_index=MOUSE_BUTTON_LEFT
		ev.pressed=pressionado
		root.push_input(ev)
	await process_frame

func captura(nome: String) -> void:
	if not grafico: return
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_etapa_11")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_etapa_11/"+nome+".png")==OK,"Captura "+nome)

func executar() -> void:
	pasta="user://testes_etapa_11/"+Crypto.new().generate_random_bytes(8).hex_encode()
	grafico=DisplayServer.get_name()!="headless"
	regras()
	duas_equipes()
	simulacao_completa()
	await interface()
	print("ETAPA_11: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
