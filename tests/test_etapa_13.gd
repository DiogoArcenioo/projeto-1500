extends SceneTree
## Etapa 13 — saúde, fadiga, centro de cura e morte permanente.
##   godot --headless --path . --script res://tests/test_etapa_13.gd
## Gráfico (sem --headless): capturas em exports/revisao_etapa_13/.
const E=preload("res://scripts/partida/estado_partida.gd")
const C=preload("res://scripts/partida/configuracao_partida.gd")
const X=preload("res://scripts/partida/expedicoes.gd")
const H=preload("res://scripts/partida/saude.gd")
const S=preload("res://scripts/partida/salvamento.gd")
var total:=0
var falhas:=0
var grafico:=false

func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func jogo(e,t: float) -> Array[String]:
	e.relogio.tempo_total+=t
	return e.avancar_simulacao(t)
func valido(e,n: String) -> void:
	var erro:=E.validar(e.serializar())
	ok(erro=="",n+" "+erro)
func dias(e,n: float) -> Array[String]:
	var avisos: Array[String]=[]
	var passos:=int(ceil(n*24))
	for i in range(passos): avisos.append_array(jogo(e,e.relogio.duracao_dia_segundos/24.0))
	return avisos

## Aldeia com quatro moradores, comida farta, centro de coleta e (opcional) centro de cura.
func aldeia(com_cura:=true):
	var e=E.nova(C.new())
	e.construir("oca",Vector2(-5,-4))
	jogo(e,18)
	e.construir("oca",Vector2(4,-8))
	for h: Dictionary in e.habitantes: e.atribuir(h.id,e.construcoes[-1].id)
	jogo(e,20)
	for k in e.conhecimento: e.conhecimento[k]=maxi(2,int(e.conhecimento[k]))
	e.estoque.madeira=200
	e.estoque.fibras_vegetais=200
	ok(e.construir("coleta",Vector2(-13,3))=="","Centro de coleta")
	jogo(e,12)
	if com_cura:
		ok(e.construir("cura",Vector2(-6,5.5))=="","Centro de cura construído "+e.impedimento("cura",Vector2(-6,5.5)))
		jogo(e,42)
	for h: Dictionary in e.habitantes:
		if h.estado!="livre": e.atribuir(h.id,"")
	fartura(e)
	return e

func fartura(e) -> void:
	e.estoque.plantas_medicinais=40
	for i in range(3): e.receber(["vegetais","peixe","carne"][i],60,["milho","pesca","caca"][i])

func centro(e,tipo: String) -> String:
	for c: Dictionary in e.construcoes:
		if c.tipo==tipo and c.pronta: return c.id
	return ""

func gravidades() -> void:
	var h:={"estado":"livre","saude":100,"descanso":100,"alimentacao":100}
	var nomes:=[]
	for s in [100,74,49,24,0]:
		h.saude=s
		nomes.append(H.gravidade(h))
	ok(nomes==["saudavel","leve","moderado","grave","morto"],"Cinco níveis de saúde")
	h.saude=60
	h.descanso=40
	ok(H.fator(h)<1.0 and H.penalidade(h)<0,"Ferimento leve e cansaço reduzem rendimento e ataque")
	h.descanso=10
	h.nome="Teste"
	ok(H.impedimento_expedicao(h)!="","Exausto não sai em expedição")
	h.descanso=80
	h.saude=20
	ok(H.impedimento_expedicao(h)!="","Ferido grave indisponível")

func combate_e_tratamento() -> void:
	var e=aldeia()
	var cura:=centro(e,"cura")
	var a: Dictionary=e.habitantes[0]
	var b: Dictionary=e.habitantes[1]
	ok(e.atribuir(b.id,cura)=="","Cuidador vinculado ao centro de cura")
	# Ferido numa caça simulada até o fim do confronto.
	e.construir("caca",Vector2(6,-1))
	jogo(e,62)
	var r:=X.enviar(e,centro(e,"caca"),"caca",6,[a.id],"simulado",{a.id:"lanca"})
	ok(r.ok,"Caçada enviada "+str(r.get("erro","")))
	var v:=X.buscar(e,r.id)
	var ferido:=false
	for i in range(3000):
		jogo(e,1)
		if v.fase=="alerta": X.simular(e,v.id)
		if v.get("combate",{}).get("aplicado",false) and not ferido:
			# Garante o caso do aceite: volta com ferimento moderado.
			a.saude=minf(float(a.saude),40.0)
			ferido=true
		if v.fase=="concluida": break
	ok(v.fase=="concluida","Equipe voltou")
	if a.estado=="morto":
		ok(e.cronica.size()>0,"Morte no encontro registrada na crônica")
		return
	ok(H.gravidade(a) in ["moderado","grave"] or a.estado=="em_tratamento","Volta ferido")
	ok(float(a.descanso)<100,"Expedição e combate cansam")
	dias(e,.2)
	ok(a.estado=="em_tratamento" and a.tratamento==cura,"Ferido entra sozinho no centro de cura")
	valido(e,"Save válido durante o tratamento")
	# Save/load no meio: fadiga e saúde preservadas.
	var dados: Dictionary=JSON.parse_string(JSON.stringify(e.serializar()))
	var c=E.desserializar(dados)
	var a2: Dictionary=c.pessoa(a.id)
	ok(is_equal_approx(float(a2.saude),float(a.saude)) and is_equal_approx(float(a2.descanso),float(a.descanso)) and a2.estado=="em_tratamento","Carregar mantém tratamento e fadiga")
	var plantas:=int(e.estoque.plantas_medicinais)
	var xp_cura:=int(b.habilidades.cura)
	var avisos:=dias(e,6)
	ok(a.estado in ["livre","trabalhando"] and float(a.saude)>=70,"Tratamento leva à alta (saúde %d)"%a.saude)
	ok(avisos.any(func(m): return m.contains("recebeu alta")),"Aviso de alta no feed")
	ok(int(e.estoque.plantas_medicinais)<plantas,"Tratamento consome plantas medicinais")
	ok(int(b.habilidades.cura)>xp_cura,"Cuidador ganha experiência de cura")
	valido(e,"Save válido após a alta")

func grave_sem_tratamento() -> void:
	var e=aldeia(false)
	var a: Dictionary=e.habitantes[0]
	e.atribuir(a.id,centro(e,"coleta"))
	a.saude=20.0
	var avisos:=dias(e,.1)
	ok(a.estado=="convalescente","Grave sem centro fica convalescente e para de trabalhar")
	ok(X.erro_envio(e,"","coleta",6,[a.id],"simulado")!="","Envio do grave bloqueado")
	valido(e,"Save válido com convalescente")
	var pop:=int(e.populacao())
	avisos=dias(e,6)
	ok(a.estado=="morto" and a.setor=="" and a.saude==0,"Grave sem tratamento morre")
	ok(int(e.populacao())==pop-1,"População diminui")
	ok(avisos.any(func(m): return m.contains("morreu")),"Morte avisada no feed")
	ok(e.cronica.any(func(i): return i.texto.contains(a.nome) and i.texto.contains("morreu")),"Morte preservada na crônica")
	valido(e,"Save válido após a morte")
	var c=E.desserializar(JSON.parse_string(JSON.stringify(e.serializar())))
	dias(c,3)
	ok(c.pessoa(a.id).estado=="morto","Carregar não ressuscita mortos")
	var ruim: Dictionary=JSON.parse_string(JSON.stringify(e.serializar()))
	for h: Dictionary in ruim.habitantes:
		if h.id==a.id: h.estado="livre"
	ok(E.validar(ruim)!="","Save com morto revivido é rejeitado")

func leve_natural() -> void:
	var e=aldeia(false)
	var a: Dictionary=e.habitantes[2]
	a.saude=60.0
	dias(e,2.5)
	ok(float(a.saude)>=75 and a.estado=="livre","Ferimento leve sara sozinho com repouso")
	var b: Dictionary=e.habitantes[3]
	b.saude=40.0
	var antes:=float(b.saude)
	e.construcoes=e.construcoes.filter(func(c): return c.tipo!="cura")
	dias(e,1)
	ok(float(b.saude)>antes and float(b.saude)<antes+5,"Moderado sem tratamento melhora muito devagar")

func fadiga_e_revezamento() -> void:
	var e=aldeia(false)
	var a: Dictionary=e.habitantes[0]
	var b: Dictionary=e.habitantes[1]
	var coleta:=centro(e,"coleta")
	# Expedições seguidas acumulam fadiga até a exaustão.
	var enviados:=0
	for i in range(6):
		var r:=X.enviar(e,coleta,"coleta",6,[a.id])
		if not r.ok:
			ok(r.erro.contains("exaust"),"Bloqueio por exaustão: "+r.erro)
			break
		enviados+=1
		var v:=X.buscar(e,r.id)
		v.encontro={"em":-1.0,"animal":""}
		for k in range(2000):
			jogo(e,1)
			if v.fase=="concluida": break
	ok(H.cansaco(a)=="exausto","Expedições consecutivas exaurem (%d enviadas, descanso %d)"%[enviados,a.descanso])
	var r2:=X.enviar(e,coleta,"coleta",6,[b.id])
	ok(r2.ok,"Revezamento: outro morador descansado pode ir")
	var antes:=float(a.descanso)
	dias(e,1)
	ok(float(a.descanso)>antes+20,"Descanso e sono recuperam a fadiga")
	valido(e,"Save válido com fadiga")

func producao() -> void:
	var resultados: Array=[]
	for ferido in [false,true]:
		var e=aldeia(false)
		var coleta:=centro(e,"coleta")
		var a: Dictionary=e.habitantes[0]
		e.atribuir(a.id,coleta)
		if ferido:
			a.saude=55.0
			a.descanso=30.0
		var antes:=int(e.estoque.madeira)
		for i in range(60): jogo(e,1)
		resultados.append(int(e.estoque.madeira)-antes)
	ok(resultados[1]<resultados[0],"Ferido e cansado produz menos (%d contra %d)"%[resultados[1],resultados[0]])

func passos() -> void:
	var e=aldeia()
	e.habitantes[0].saude=30.0
	e.habitantes[1].saude=60.0
	e.habitantes[2].descanso=40.0
	e.atribuir(e.habitantes[3].id,centro(e,"cura"))
	var clone=E.desserializar(e.serializar())
	jogo(e,1800)
	for i in range(360): jogo(clone,5)
	ok(e.habitantes==clone.habitantes and e.estoque==clone.estoque,"Saúde e fadiga independem do tamanho do passo")

func lotacao_e_triagem() -> void:
	var e=aldeia()
	var cura:=centro(e,"cura")
	for i in range(4): e.habitantes[i].saude=[40.0,15.0,30.0,45.0][i]
	dias(e,.1)
	var dentro: Array=e.habitantes.filter(func(h): return h.estado=="em_tratamento")
	ok(dentro.size()==3,"Três leitos ocupados")
	ok(e.habitantes[3].estado!="em_tratamento","O menos grave espera vaga")
	ok(H.taxa_tratamento(e,e.estrutura(cura))==float(H.p.tratamento.sem_cuidador),"Sem cuidador: só repouso")
	e.estoque.plantas_medicinais=0
	var c: Dictionary=e.estrutura(cura)
	c.remedio=0.0
	var avisos:=dias(e,.5)
	ok(avisos.any(func(m): return m.contains("Faltam plantas")),"Falta de plantas avisada")
	valido(e,"Save válido com centro lotado")

func interface() -> void:
	var cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=S.new("user://testes_etapa_13/"+Crypto.new().generate_random_bytes(6).hex_encode())
	root.add_child(cena)
	cena.set_process(false)
	var e=cena.estado
	cena.iniciar_obra("oca")
	cena.confirmar_obra(Vector2(-5,-4))
	cena._process(18)
	e.estoque.madeira=200
	e.estoque.fibras_vegetais=200
	e.estoque.plantas_medicinais=12
	cena.iniciar_obra("cura")
	cena.confirmar_obra(Vector2(-6,5.5))
	cena._process(42)
	var cura:=centro(e,"cura")
	ok(cura!="","Centro de cura pela interface")
	cena.painel.mudar_setor.emit(e.habitantes[0].id,cura)
	e.habitantes[1].saude=30.0
	for i in range(3): cena._process(10)
	cena.aldeia.sincronizar()
	ok(e.habitantes[1].estado=="em_tratamento","Paciente no centro pela partida")
	cena.painel.abrir("comunidade")
	ok(cena.painel.titulo.text=="Comunidade","Painel comunitário abre")
	var textos: Array=cena.painel.controles.find_children("*","Label",true,false).map(func(l): return l.text)
	ok(textos.any(func(t): return str(t).begins_with("Saúde ·")),"Resumo de saúde no painel")
	ok(textos.any(func(t): return str(t).contains("Em tratamento")),"Estado do paciente no painel")
	cena.painel.abrir(cura)
	textos=cena.painel.controles.find_children("*","Label",true,false).map(func(l): return l.text)
	ok(textos.any(func(t): return str(t).begins_with("Leitos 1/3")),"Detalhe do centro de cura")
	for i in range(30): cena.aldeia.mover(.2)
	if grafico:
		cena.set_process(true)
		await process_frame
		cena.painel.abrir("comunidade")
		for i in range(30): await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://exports/revisao_etapa_13")
		root.get_texture().get_image().save_png("res://exports/revisao_etapa_13/comunidade.png")
	cena.queue_free()
	await process_frame

func executar() -> void:
	grafico=DisplayServer.get_name()!="headless"
	gravidades()
	combate_e_tratamento()
	grave_sem_tratamento()
	leve_natural()
	fadiga_e_revezamento()
	producao()
	passos()
	lotacao_e_triagem()
	await interface()
	print("ETAPA_13: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
