extends SceneTree
const E=preload("res://scripts/partida/estado_partida.gd")
const C=preload("res://scripts/partida/configuracao_partida.gd")
const A=preload("res://scripts/partida/alimentacao.gd")
const G=preload("res://scripts/partida/agricultura.gd")
const X=preload("res://scripts/partida/expedicoes.gd")
const S=preload("res://scripts/partida/salvamento.gd")
var total:=0
var falhas:=0
var cena
var imagens:=false
var pasta: String

func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func passo(e,s: float) -> void:
	var d: float=e.relogio.avancar(s)
	e.avancar_simulacao(d)
func aldeia():
	var e=E.nova(C.new())
	ok(e.construir("oca",Vector2(-5,-4))=="","Fundação")
	passo(e,18)
	return e
func pronta(e,tipo: String,p: Vector2) -> void:
	ok(e.construir(tipo,p)=="","Construir "+tipo)
	passo(e,e.DURACAO[tipo])
	ok(e.construcoes.back().pronta,"Concluir "+tipo)
	# Esta suíte conserva a economia dos talhões anteriores como regressão de saves.
	# A grade modular é exercitada em test_construcao_modular.gd.
	if tipo=="agricultura":
		for t: Dictionary in e.construcoes.back().talhoes: t.erase("celulas")
func limpar_comida(e) -> void:
	for r in A.TIPOS: e.estoque[r]=0
	e.alimentos={}
	A.assegurar(e)
func nutrir(e) -> void:
	limpar_comida(e)
	e.receber("vegetais",12,"milho",e.tempo_economia+100000)
	e.receber("vegetais",12,"mandioca",e.tempo_economia+100000)
	for h: Dictionary in e.habitantes: h.alimentacao=100
func validar(e,n: String) -> void:
	var erro:=E.validar(e.serializar())
	ok(erro=="",n+" "+erro)
func recarregar(e):
	var s:=S.new(pasta)
	var r: Dictionary=s.salvar(e,"manual")
	ok(r.ok,"Gravação "+str(r))
	var l: Dictionary=s.carregar("manual")
	ok(l.ok,"Leitura")
	return l.estado if l.ok else e

func economia() -> void:
	var e=E.nova(C.new())
	ok(A.total(e)==8,"Oito alimentos iniciais")
	passo(e,1200)
	ok(A.total(e)==8 and e.alimentos.fracao==0,"Zero moradores não consome")
	passo(e,1200)
	ok(A.total(e)==0,"Vegetais estragam após quatro dias")
	e=aldeia()
	ok(e.alimentos.fracao==0 and e.habitantes.size()==2,"Sem consumo retroativo antes da chegada")
	passo(e,600)
	ok(A.total(e)==4 and e.habitantes[0].alimentacao==100,"Dois alimentos por adulto por dia")
	limpar_comida(e)
	passo(e,1800)
	ok(e.habitantes[0].alimentacao==40 and A.eficiencia(e)<1,"Escassez gradual e produtividade")
	e.receber("vegetais",12,"milho",e.tempo_economia+10000)
	e.receber("vegetais",12,"mandioca",e.tempo_economia+10000)
	passo(e,900)
	ok(e.habitantes[0].alimentacao>40,"Recuperação ao voltar a comer")
	e=E.nova(C.new())
	limpar_comida(e)
	e.receber("vegetais",10,"mandioca")
	e.receber("peixe",4,"pesca")
	ok(e.alimentos.lotes[0].tipo=="peixe","Consome primeiro o que vence antes")
	passo(e,1200)
	ok(e.estoque.peixe==0 and e.estoque.vegetais==10,"Pescado dura dois dias")
	ok(e.receber("vegetais",30,"milho")==14 and A.total(e)==24,"Capacidade compartilhada de 24")
	validar(e,"Estoque válido")
	var d: Dictionary=e.serializar()
	d.erase("alimentos")
	d.erase("tempo_economia")
	d.estoque.vegetais=60
	d.estoque.peixe=3
	e=E.desserializar(d)
	ok(e!=null and A.total(e)==63 and e.alimentos.lotes[0].tipo=="peixe","Migração preserva reserva antiga e ordena validade")
	ok(e.receber("peixe",1)==0,"Reserva antiga acima da capacidade bloqueia novas entradas")
	d=e.serializar()
	d.alimentos.lotes[0].quantidade+=1
	ok(E.validar(d)!="","Lotes inconsistentes rejeitados")

func agricultura() -> void:
	var e=aldeia()
	pronta(e,"agricultura",Vector2(-5.5,5.5))
	var c: Dictionary=e.construcoes.back()
	var h: Dictionary=e.habitantes[0]
	ok(e.atribuir(h.id,c.id)=="","Alocar agricultor")
	ok(c.talhoes[0].trabalhador==h.id,"Uma pessoa por talhão")
	passo(e,500)
	ok(c.talhoes[0].progresso==500 and c.talhoes[1].progresso==0,"Talhão sem trabalhador não cresce")
	e=recarregar(e)
	c=e.construcoes.back()
	h=e.habitantes[0]
	ok(c.talhoes[0].progresso==500 and c.talhoes[0].trabalhador==h.id,"Cultivo e vínculos persistidos")
	ok(G.escolher(e,c.id,0,"mandioca")=="" and c.talhoes[0].cultivo=="milho","Troca programa próxima safra sem apagar atual")
	passo(e,580)
	ok(h.habilidades.agricultura==6 and c.talhoes[0].cultivo=="mandioca","Milho colhe automaticamente em 1080 segundos e dá XP")
	ok(e.alimentos.lotes.any(func(l): return l.origem=="milho" and l.quantidade==6),"Milho rende seis")
	e.atribuir(h.id,"")
	var p: float=c.talhoes[0].progresso
	passo(e,100)
	ok(c.talhoes[0].progresso==p,"Liberar interrompe trabalho")
	e.atribuir(h.id,c.id)
	nutrir(e)
	passo(e,1680)
	ok(h.habilidades.agricultura==12 and c.talhoes[0].progresso==0,"Mandioca em 1680 segundos e XP acumulada")
	ok(e.alimentos.lotes.any(func(l): return l.origem=="mandioca" and l.quantidade>=11),"Mandioca rende onze")
	ok(is_equal_approx(G.bonus(h),.1),"Primeiro ganho de produtividade pela prática")
	h.habilidades.agricultura=100
	ok(is_equal_approx(G.bonus(h),.3),"Bônus máximo de 30%")
	limpar_comida(e)
	e.receber("vegetais",24,"reserva",e.tempo_economia+10000)
	c.talhoes[0].cultivo="milho"
	c.talhoes[0].proximo="milho"
	c.talhoes[0].progresso=1079
	passo(e,1)
	ok(c.talhoes[0].pendente==7 and is_equal_approx(c.talhoes[0].fracao_rendimento,.8),"Excedente e fração do bônus preservados")
	e=recarregar(e)
	c=e.construcoes.back()
	passo(e,150)
	ok(c.talhoes[0].pendente<7 and A.total(e)<=24,"Espaço liberado recebe colheita pendente")
	validar(e,"Agricultura válida")

func pesca() -> void:
	var e=aldeia()
	ok(e.impedimento("pesca",Vector2(-5,5))!="","Pesca fora da margem bloqueada")
	pronta(e,"pesca",Vector2(8,1.2))
	var c: Dictionary=e.construcoes.back()
	var h: Dictionary=e.habitantes[1]
	e.atribuir(h.id,c.id)
	ok(not X.enviar(e,c.id,"coleta",14,[h.id]).ok,"Atividade incompatível rejeitada")
	ok(not X.enviar(e,c.id,"pesca",14,[h.id]).ok,"Pesca exige região com peixes")
	ok(X.enviar(e,c.id,"pesca",21,[h.id]).ok,"Pesca no rio conhecido")
	ok(not X.enviar(e,c.id,"pesca",21,[e.habitantes[0].id]).ok,"Uma viagem por centro")
	passo(e,200)
	ok(e.expedicoes[0].fase=="exploracao" and h.habilidades.pesca>0,"Pesca pratica habilidade")
	ok(e.estoque.peixe==0,"Peixe só entra no retorno")
	e=recarregar(e)
	passo(e,280)
	var x: Dictionary=e.expedicoes[0]
	ok(x.fase=="concluida" and x.entregue.peixe in [1,2],"Viagem de 480 s entrega um ou dois pescados")
	ok(e.habitantes[1].estado=="trabalhando","Retorno restaura posto")
	validar(e,"Pesca válida")
	e=aldeia()
	pronta(e,"pesca",Vector2(8,1.2))
	c=e.construcoes.back()
	limpar_comida(e)
	e.receber("vegetais",24,"reserva",e.tempo_economia+10000)
	X.enviar(e,c.id,"pesca",21,[e.habitantes[0].id])
	passo(e,479)
	e.receber("vegetais",24,"reserva",e.tempo_economia+10000)
	e.alimentos.fracao=0
	passo(e,1)
	ok(e.expedicoes[0].fase=="aguardando_descarga" and e.expedicoes[0].carga.peixe>0,"Pescado excedente aguarda espaço sem perder carga")
	# Validade curta controlada para verificar deterioração ainda na carga, antes do próximo consumo.
	e.expedicoes[0].vencimentos.peixe=e.tempo_economia+20
	e=recarregar(e)
	passo(e,20)
	ok(e.expedicoes[0].carga.is_empty() and e.estoque.peixe==0,"Pescado deteriora ainda na carga sem reiniciar validade ao carregar")
	validar(e,"Validade de carga persistida")
	e=aldeia()
	pronta(e,"coleta",Vector2(6,-1))
	X.enviar(e,"obra_2","reconhecimento",14,[e.habitantes[0].id])
	var antiga: Dictionary=e.serializar()
	for chave in ["duracao_exploracao","intervalo_atividade","capturas_alvo","equilibrada","vencimentos"]: antiga.expedicoes[0].erase(chave)
	e=E.desserializar(antiga)
	ok(e!=null,"Expedição da etapa 7 migrada")
	passo(e,3+2*e.expedicoes[0].viagem+60)
	ok(e.expedicoes[0].fase=="concluida" and e.expedicoes[0].ciclos==5,"Viagem antiga conserva duração e atividades originais")

func dieta_e_passos() -> void:
	var e=aldeia()
	limpar_comida(e)
	e.alimentos.inicio_populacao=e.tempo_economia
	e.tempo_economia+=8*600
	e.alimentos.historico=[{"origem":"milho","tipo":"vegetais","quantidade":12,"tempo":e.tempo_economia}]
	ok(A.qualidade(e).modificador==-.25,"Monotonia prolongada")
	ok(A.resistencia_efetiva(e,e.habitantes[0])<e.habitantes[0].atributos.resistencia,"Monotonia reduz resistência efetiva sem mudar atributo base")
	e.alimentos.historico.append({"origem":"mandioca","tipo":"vegetais","quantidade":6,"tempo":e.tempo_economia})
	ok(A.qualidade(e).modificador==0,"Duas fontes vegetais reconhecidas")
	e.alimentos.historico.append({"origem":"pesca","tipo":"peixe","quantidade":6,"tempo":e.tempo_economia})
	ok(A.qualidade(e).modificador==.1,"Diversidade beneficia produtividade")
	e=aldeia()
	pronta(e,"agricultura",Vector2(-5.5,5.5))
	pronta(e,"pesca",Vector2(8,1.2))
	e.atribuir(e.habitantes[0].id,"obra_2")
	X.enviar(e,"obra_3","pesca",21,[e.habitantes[1].id])
	var clone=E.desserializar(e.serializar())
	passo(e,4800)
	for i in range(960): passo(clone,5)
	ok(e.estoque==clone.estoque and e.habitantes==clone.habitantes,"Economia independe do tamanho do passo")
	ok(is_equal_approx(e.construcoes[1].talhoes[0].progresso,clone.construcoes[1].talhoes[0].progresso),"Crescimento independente dos passos")
	validar(e,"Simulação longa válida")
	validar(clone,"Simulação fragmentada válida")
	var historico: Array=e.alimentos.historico.duplicate(true)
	e=recarregar(e)
	ok(e.alimentos.historico.size()==historico.size(),"Histórico persistido")
	for i in range(historico.size()):
		ok(e.alimentos.historico[i].origem==historico[i].origem and is_equal_approx(e.alimentos.historico[i].tempo,historico[i].tempo),"Refeição preservada "+str(i))

func captura(nome: String) -> void:
	if not imagens: return
	for i in range(40): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_etapa_8_final")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_etapa_8_final/"+nome+".png")==OK,"Captura "+nome)

func clicar(b: Button) -> void:
	if not imagens:
		b.pressed.emit()
		return
	if is_instance_valid(cena.painel_expedicoes.rolagem) and cena.painel_expedicoes.rolagem.is_ancestor_of(b):
		cena.painel_expedicoes.rolagem.ensure_control_visible(b)
	for i in range(8): await process_frame
	var p:=b.get_global_rect().get_center()
	var m:=InputEventMouseMotion.new()
	m.position=p
	root.push_input(m)
	for pressionado in [true,false]:
		var evento:=InputEventMouseButton.new()
		evento.position=p
		evento.button_index=MOUSE_BUTTON_LEFT
		evento.pressed=pressionado
		root.push_input(evento)
	await process_frame

func interface() -> void:
	cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=S.new(pasta)
	root.add_child(cena)
	cena.set_process(false)
	var e=cena.estado
	cena.iniciar_obra("oca")
	cena.confirmar_obra(Vector2(-5,-4))
	cena._process(18)
	cena.iniciar_obra("agricultura")
	cena.confirmar_obra(Vector2(-5.5,5.5))
	cena._process(60)
	for t: Dictionary in e.construcoes[1].talhoes: t.erase("celulas")
	cena.iniciar_obra("pesca")
	cena.confirmar_obra(Vector2(8,1.2))
	cena._process(45)
	cena.painel.mudar_setor.emit(e.habitantes[0].id,"obra_2")
	cena.painel.cultivo_solicitado.emit("obra_2",1,"milho")
	ok(e.construcoes[1].talhoes[1].cultivo=="milho","Seletor da interface altera plantio")
	cena.painel.abrir("obra_2")
	ok(cena.painel.titulo.text.begins_with("Roça"),"Painel da roça")
	cena.aldeia.sincronizar()
	ok(cena.aldeia.locais["obra_2"].get_node("Mandioca").especie==1,"Espécie do cultivo corresponde ao modelo")
	cena.alternar_pausa()
	var p: float=e.construcoes[1].talhoes[0].progresso
	cena._process(100)
	ok(e.construcoes[1].talhoes[0].progresso==p,"Pausa congela agricultura e consumo")
	cena.alternar_pausa()
	cena.definir_velocidade(3)
	cena._process(100)
	ok(e.construcoes[1].talhoes[0].progresso==p+300,"Velocidade 3x")
	cena.definir_velocidade(1)
	cena.abrir_expedicoes("obra_3")
	ok(cena.painel_expedicoes.tipo=="pesca" and cena.painel_expedicoes.regiao==21,"Centro seleciona pesca e destino compatíveis")
	cena.painel_expedicoes.equipe=[e.habitantes[1].id]
	cena.painel_expedicoes.mostrar_passo(3)
	ok(not cena.painel_expedicoes.confirmar.disabled,"UI permite envio válido")
	await clicar(cena.painel_expedicoes.confirmar)
	ok(e.expedicoes.size()==1,"Botão envia pesca real")
	cena.fechar_expedicoes()
	cena._process(420)
	cena._process(fposmod(15.5-e.relogio.obter_hora(),24)*e.relogio.duracao_dia_segundos/24)
	cena.estado.relogio.pausado=true
	cena._controle.restaurar({"x":-2,"z":5,"angulo":1.1,"fov":32})
	cena.painel.abrir("obra_2")
	await captura("roca_em_crescimento")
	cena.painel.abrir("inicio")
	await captura("aldeia_agricultura_pesca")
	cena.painel.abrir("comunidade")
	await captura("comunidade")
	ok(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Salvar e carregar integração")
	cena.abrir_expedicoes("obra_3")
	cena.painel_expedicoes.apresentar("acompanhar")
	await captura("pesca_em_andamento")
	cena.queue_free()
	await process_frame

func executar() -> void:
	pasta="user://testes_etapa_8/"+Crypto.new().generate_random_bytes(8).hex_encode()
	imagens=DisplayServer.get_name()!="headless"
	economia()
	agricultura()
	pesca()
	dieta_e_passos()
	await interface()
	print("ETAPA_8: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
