extends SceneTree
const G=preload("res://scripts/partida/agricultura.gd")
const S=preload("res://scripts/partida/salvamento.gd")
var cena
var e
var grafico:=false
var total:=0
var falhas:=0
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func quadro(chave: String) -> Vector2:
	return root.get_camera_3d().unproject_position(cena.aldeia.celulas_visuais[chave].no.position+Vector3.UP*.03)
func mouse(p: Vector2,pressionado: bool) -> void:
	var m:=InputEventMouseMotion.new()
	m.position=p
	root.push_input(m)
	var b:=InputEventMouseButton.new()
	b.position=p
	b.button_index=MOUSE_BUTTON_LEFT
	b.pressed=pressionado
	root.push_input(b)
func clicar_terreno(chave: String) -> void:
	var p:=quadro(chave)
	if grafico:
		mouse(p,true)
		mouse(p,false)
		await process_frame
	else:
		cena.aldeia.inicio_arraste=p
		cena.aldeia.concluir_selecao(p)
func botao(nome: String) -> void:
	for b: Button in cena.painel.controles.find_children("*","Button",true,false):
		if b.text!=nome: continue
		if grafico:
			cena.painel.rolagem.ensure_control_visible(b)
			for i in range(8): await process_frame
			var p:=b.get_global_rect().get_center()
			mouse(p,true)
			mouse(p,false)
			await process_frame
		else: b.pressed.emit()
		return
	ok(false,"Botão ausente "+nome)
func arrastar(chaves: Array,inverter:=false) -> void:
	var inicio:=Vector2(INF,INF)
	var fim:=Vector2(-INF,-INF)
	for chave in chaves:
		var p:=quadro(chave)
		inicio=inicio.min(p)
		fim=fim.max(p)
	inicio-=Vector2.ONE*8
	fim+=Vector2.ONE*8
	if inverter:
		var t:=inicio
		inicio=fim
		fim=t
	if grafico:
		mouse(inicio,true)
		var m:=InputEventMouseMotion.new()
		m.position=fim
		root.push_input(m)
		await process_frame
		ok(cena.aldeia.retangulo_selecao.ativo,"Retângulo visível durante arraste")
		mouse(fim,false)
		await process_frame
	else:
		cena.aldeia.inicio_arraste=inicio
		cena.aldeia.concluir_selecao(fim)
func captura(nome: String) -> void:
	if not grafico: return
	for i in range(25): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_selecao_plantio")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_selecao_plantio/"+nome+".png")==OK,"Captura "+nome)
func executar() -> void:
	grafico=DisplayServer.get_name()!="headless"
	root.size=Vector2i(1280,720)
	cena=load("res://scenes/main.tscn").instantiate()
	cena.configuracao=cena.configuracao.duplicate()
	cena.configuracao.hora_inicial=6
	cena.salvamento=S.new("user://testes_selecao_plantio/"+Crypto.new().generate_random_bytes(8).hex_encode())
	root.add_child(cena)
	cena.set_process(false)
	e=cena.estado
	cena.iniciar_obra("oca")
	cena.confirmar_obra(Vector2(-5,-4))
	cena._process(18)
	cena.iniciar_obra("agricultura")
	cena.confirmar_obra(Vector2(-5.5,5.5))
	cena._process(60)
	for x in range(-1,2):
		for z in range(6,8): ok(G.adicionar_celula(e,"obra_2",z-6,Vector2(x,z))=="","Preparar terreno vazio")
	e.atribuir(e.habitantes[0].id,"obra_2")
	e.atribuir(e.habitantes[1].id,"obra_2")
	cena._process(120)
	var chaves: Array=[]
	for t: Dictionary in e.construcoes[1].talhoes:
		for u: Dictionary in t.celulas:
			ok(not u.plantada and u.progresso==0,"Terreno vazio não cresce mesmo com agricultor")
			chaves.append(G.chave_celula(u))
	cena.aldeia.sincronizar()
	for item: Dictionary in cena.aldeia.celulas_visuais.values(): ok(item.no.planta==null,"Terreno vazio não apresenta planta")
	ok(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Terrenos preparados vazios persistem em arquivo")
	e=cena.estado
	for chave in chaves: ok(not G.encontrar_celula(e,chave).plantada and cena.aldeia.celulas_visuais[chave].no.planta==null,"Vazio preservado no estado e no visual após carregar")
	cena._controle.restaurar({"x":-1,"z":7,"angulo":1.0,"fov":26})
	cena.painel.abrir("inicio")
	for i in range(8): await process_frame
	await captura("terrenos_vazios")
	await clicar_terreno(chaves[0])
	ok(cena.aldeia.terrenos_selecionados==[chaves[0]],"Clique seleciona somente um terreno")
	ok(cena.painel.contexto=="terrenos","Seleção abre escolha de cultura")
	await botao("Plantar milho")
	var primeiro: Dictionary=G.encontrar_celula(e,chaves[0])
	ok(primeiro.plantada and primeiro.cultivo=="milho","Escolha individual semeia milho")
	for chave in chaves.slice(1): ok(not G.encontrar_celula(e,chave).plantada,"Terrenos fora da seleção permanecem vazios")
	cena._process(30)
	ok(is_equal_approx(primeiro.progresso,30),"Planta semeada cresce normalmente")
	await arrastar(chaves)
	ok(cena.aldeia.terrenos_selecionados.size()==6,"Arraste seleciona seis terrenos de duas áreas")
	for chave in chaves: ok(cena.aldeia.celulas_visuais[chave].no.destaque.visible,"Destaque de seleção em cada terreno")
	await captura("selecao_6_terrenos")
	await botao("Plantar mandioca")
	ok(primeiro.cultivo=="milho" and primeiro.proximo=="mandioca" and is_equal_approx(primeiro.progresso,30),"Safra em curso preservada ao escolher nova cultura")
	for chave in chaves.slice(1):
		var u:=G.encontrar_celula(e,chave)
		ok(u.plantada and u.cultivo=="mandioca" and u.progresso==0,"Mandioca começa apenas nos terrenos vazios selecionados")
	var erro:=G.semear_selecao(e,[chaves[0],"ausente"],"milho")
	ok(erro!="" and primeiro.proximo=="mandioca","Seleção inválida não aplica alteração parcial")
	cena.painel.abrir("inicio")
	await arrastar(chaves,true)
	ok(cena.aldeia.terrenos_selecionados.size()==6,"Arraste invertido também seleciona terrenos")
	await botao("Limpar seleção")
	ok(cena.aldeia.terrenos_selecionados.is_empty() and cena.painel.contexto=="inicio","Limpar seleção encerra menu e destaque")
	var reserva: Dictionary=G.unidade("milho")
	reserva.plantada=false
	reserva.progresso=2
	ok(G.validar_unidade(reserva,cena.Estado.numero)!="","Terreno vazio com produção corrompida é rejeitado")
	# Terrenos anteriores a este ajuste continuam plantados ao carregar.
	var antigo: Dictionary=e.serializar()
	antigo.construcoes[1].talhoes[0].celulas[0].erase("plantada")
	ok(cena.Estado.desserializar(antigo)!=null,"Compatibilidade com células já plantadas de saves anteriores")
	cena._process(600)
	cena.estado.relogio.pausado=true
	cena.painel.abrir("inicio")
	await captura("cultivos_selecionados")
	ok(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Salvar e carregar culturas escolhidas")
	ok(cena.aldeia.terrenos_selecionados.is_empty(),"Carregamento limpa seleção temporária")
	var l: Dictionary=G.encontrar_celula(cena.estado,chaves[0])
	ok(l.cultivo=="milho" and l.proximo=="mandioca" and l.plantada,"Cultivo e próxima safra preservados")
	cena.queue_free()
	await process_frame
	print("SELECAO_PLANTIO: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
