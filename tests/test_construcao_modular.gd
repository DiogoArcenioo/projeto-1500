extends SceneTree
const E=preload("res://scripts/partida/estado_partida.gd")
const C=preload("res://scripts/partida/configuracao_partida.gd")
const G=preload("res://scripts/partida/agricultura.gd")
const T=preload("res://scripts/partida/terreno_construcao.gd")
const S=preload("res://scripts/partida/salvamento.gd")
var total:=0
var falhas:=0
var cena
var pasta: String
var grafico:=false
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func passo(e,s: float) -> void:
	e.avancar_simulacao(e.relogio.avancar(s))
func aldeia():
	var e=E.nova(C.new())
	ok(e.construir("oca",Vector2(-5,-4))=="","Fundação")
	passo(e,18)
	return e
func valida(e,n: String) -> void:
	var erro:=E.validar(e.serializar())
	ok(erro=="",n+": "+erro)

func terreno_e_rotacao() -> void:
	for tipo in ["oca","coleta","agricultura","pesca"]:
		var p: Vector2={"oca":Vector2(4,-8),"coleta":Vector2(6,-1),"agricultura":Vector2(-5.5,5.5),"pesca":Vector2(8,1.2)}[tipo]
		for a in [0.0,PI/2,PI]:
			var e=aldeia()
			var erro: String=e.construir(tipo,p,a)
			ok(erro=="","Posicionamento "+tipo+" "+str(a)+" "+erro)
			if erro!="": continue
			passo(e,e.DURACAO[tipo])
			ok(is_equal_approx(float(e.construcoes[-1].rotacao),wrapf(a,-PI,PI)),"Ângulo registrado")
			valida(e,"Construção girada válida")
			var clone=E.desserializar(e.serializar())
			ok(clone!=null and is_equal_approx(clone.construcoes[-1].rotacao,e.construcoes[-1].rotacao),"Rotação preservada ao carregar")
	var e=aldeia()
	for p in [Vector2(-5,5),Vector2(5,6),Vector2(-8,-3),Vector2(17,0),Vector2(12,0)]:
		ok(e.impedimento("pesca",p)!="","Pesca bloqueia terra distante ou água "+str(p))
	var aprovadas:=0
	var mudanca_por_rotacao:=false
	for x in range(6,13):
		for z in range(-12,13,2):
			var p:=Vector2(x,z)
			var a: String=e.impedimento("pesca",p,0)
			var b: String=e.impedimento("pesca",p,PI/4)
			if (a=="")!=(b==""): mudanca_por_rotacao=true
			if a!="": continue
			aprovadas+=1
			ok(T.distancia_agua(p,T.TAMANHOS.pesca*.5,0)<=2,"Todo ponto aceito de pesca está junto da água")
			for canto in T.cantos(p,T.TAMANHOS.pesca*.5,0): ok(not T.na_agua(canto),"Abrigo não ocupa água")
	ok(aprovadas>0 and mudanca_por_rotacao,"Rotação participa da validação junto ao rio")
	ok(e.construir("coleta",Vector2(-5,-4),PI/2)!="","Sobreposição bloqueada após girar")
	var dados: Dictionary=e.serializar()
	dados.construcoes[0].rotacao="ruim"
	ok(E.validar(dados)!="","Rotação corrompida rejeitada")

func cultivos() -> void:
	var e=aldeia()
	ok(e.construir("agricultura",Vector2(-5.5,5.5),PI/2)=="","Abrigo agrícola girado")
	passo(e,60)
	var c: Dictionary=e.construcoes[-1]
	ok(c.talhoes[0].celulas.is_empty() and c.talhoes[1].celulas.is_empty(),"Sem plantação automática ao construir abrigo")
	var pontos: Array[Vector2]=[]
	for x in range(-1,2):
		for z in range(6,8):
			var p:=Vector2(x,z)
			ok(G.adicionar_celula(e,c.id,0,p)=="","Adicionar quadrado "+str(p))
			pontos.append(p)
	ok(c.talhoes[0].celulas.size()==6,"Seis células independentes e adjacentes")
	ok(c.talhoes[0].celulas.all(func(u): return not u.plantada),"Preparar terrenos não planta automaticamente")
	ok(G.semear_selecao(e,c.talhoes[0].celulas.map(G.chave_celula),"milho")=="","Semear seleção de terrenos preparados")
	ok(G.adicionar_celula(e,c.id,0,pontos[0])!="","Não duplica célula")
	ok(G.adicionar_celula(e,c.id,1,pontos[0])!="","Não sobrepõe áreas de culturas diferentes")
	ok(G.adicionar_celula(e,c.id,0,Vector2(-5,-4))!="","Não planta dentro da oca")
	ok(G.adicionar_celula(e,c.id,0,Vector2(17,0))!="","Não planta na água")
	ok(G.adicionar_celula(e,c.id,0,Vector2(-12,10))!="","Não planta na pedra")
	ok(e.impedimento("coleta",Vector2(0,7))!="","Não constrói sobre plantação")
	e.atribuir(e.habitantes[0].id,c.id)
	passo(e,100)
	ok(c.talhoes[0].celulas[0].progresso==100,"Crescimento de célula com agricultor")
	ok(G.adicionar_celula(e,c.id,0,Vector2(2,6))=="","Amplia enquanto plantas antigas crescem")
	ok(c.talhoes[0].celulas[-1].progresso==0 and c.talhoes[0].celulas[0].progresso==100,"Nova célula começa do zero sem apagar anterior")
	G.semear_selecao(e,[G.chave_celula(c.talhoes[0].celulas[-1])],"milho")
	var clone=E.desserializar(e.serializar())
	ok(clone!=null and clone.construcoes[-1].talhoes[0].celulas.size()==7,"Células, idades e orientação persistem")
	var antes: float=c.talhoes[0].celulas[0].progresso
	passo(e,1000)
	for i in range(200): passo(clone,5)
	ok(is_equal_approx(c.talhoes[0].celulas[0].progresso,clone.construcoes[-1].talhoes[0].celulas[0].progresso),"Grade independente do tamanho do passo")
	ok(c.talhoes[0].celulas[0].progresso>antes and c.talhoes[0].celulas[0].progresso<1080,"Área maior reparte trabalho do agricultor")
	G.escolher(e,c.id,0,"mandioca")
	ok(c.talhoes[0].celulas[0].cultivo=="milho" and c.talhoes[0].celulas[0].proximo=="mandioca","Troca respeita safra individual em curso")
	e.atribuir(e.habitantes[0].id,"")
	antes=c.talhoes[0].celulas[0].progresso
	passo(e,100)
	ok(c.talhoes[0].celulas[0].progresso==antes,"Liberar agricultor pausa plantas")
	valida(e,"Plantação válida")
	var dados: Dictionary=e.serializar()
	dados.construcoes[-1].talhoes[1].celulas=[dados.construcoes[-1].talhoes[0].celulas[0].duplicate(true)]
	ok(E.validar(dados)!="","Duplicação de células rejeitada ao carregar")
	e=aldeia()
	e.construir("agricultura",Vector2(-5.5,5.5))
	passo(e,60)
	c=e.construcoes[-1]
	for x in range(-1,2):
		for z in range(6,8): G.adicionar_celula(e,c.id,0,Vector2(x,z))
	G.semear_selecao(e,c.talhoes[0].celulas.map(G.chave_celula),"milho")
	e.atribuir(e.habitantes[0].id,c.id)
	passo(e,1080)
	ok(e.habitantes[0].habilidades.agricultura==6,"Seis plantas concedem XP aprovado da área equivalente")
	var colheita:=0
	for lote: Dictionary in e.alimentos.lotes:
		if lote.origem=="milho": colheita+=int(lote.quantidade)
	ok(colheita==6,"Seis plantas de milho rendem seis alimentos")
	# Expansão de partida anterior conserva a produção já existente.
	var legado: Dictionary=c.talhoes[1]
	legado.erase("celulas")
	legado.progresso=300
	ok(G.adicionar_celula(e,c.id,1,Vector2(2,8))=="","Expansão de talhão legado")
	ok(legado.legado.progresso==300,"Não apaga progresso de save anterior")
	valida(e,"Legado expandido válido")

func capturar(nome: String) -> void:
	if not grafico: return
	for i in range(30): await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_construcao_modular")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_construcao_modular/"+nome+".png")==OK,"Captura "+nome)

func tecla(codigo: Key) -> void:
	var evento:=InputEventKey.new()
	evento.physical_keycode=codigo
	evento.pressed=true
	root.push_input(evento)
	evento=InputEventKey.new()
	evento.physical_keycode=codigo
	root.push_input(evento)
	await process_frame

func clique(p: Vector2) -> void:
	var movimento:=InputEventMouseMotion.new()
	movimento.position=p
	root.push_input(movimento)
	for pressionado in [true,false]:
		var evento:=InputEventMouseButton.new()
		evento.position=p
		evento.button_index=MOUSE_BUTTON_LEFT
		evento.pressed=pressionado
		root.push_input(evento)
	await process_frame

func ui() -> void:
	cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=S.new(pasta)
	root.add_child(cena)
	cena.set_process(false)
	var vertices: PackedVector3Array=cena.get_node("Clareira1500/Rio").mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var coincide:=true
	for i in range(0,vertices.size(),240):
		var v:=vertices[i]
		if absf(absf(v.x-T.centro_rio(v.z))-T.meia_largura_rio(v.z))>.0001: coincide=false
	ok(coincide,"Validação usa as margens da malha de água realmente carregada")
	cena.iniciar_obra("oca")
	var angulo: float=cena.aldeia.rotacao_previa
	if grafico: await tecla(KEY_X)
	else: cena.aldeia.girar_previa(1)
	ok(is_equal_approx(cena.aldeia.previa.rotation.y,angulo+PI/12),"Giro da prévia")
	if grafico:
		for i in range(8): await process_frame
		for b: Button in cena.painel.controles.find_children("*","Button",true,false):
			if b.text=="X ↷":
				await clique(b.get_global_rect().get_center())
				break
	else: cena.painel.giro_solicitado.emit(1)
	ok(is_equal_approx(cena.aldeia.rotacao_previa,PI/6),"Botão gira a prévia")
	cena.painel.atualizar(true)
	ok(cena.painel.angulo_obra.text=="30°","Indicador mantém rotação após atualizar interface")
	cena.confirmar_obra(Vector2(-5,-4))
	cena._process(18)
	var e=cena.estado
	ok(is_equal_approx(cena.aldeia.locais["obra_1"].rotation.y,PI/6),"Modelo construído corresponde à rotação da prévia")
	var ponto_oca: Vector3=cena.aldeia.locais["obra_1"].position+Vector3.UP
	ok(cena.aldeia.escolher(root.get_camera_3d().unproject_position(ponto_oca))=="obra_1","Seleção acompanha construção girada")
	cena.iniciar_obra("agricultura")
	cena.aldeia.girar_previa(6)
	cena.confirmar_obra(Vector2(-5.5,5.5))
	cena._process(60)
	cena.painel.plantio_solicitado.emit("obra_2",0)
	ok(cena.aldeia.modo=="plantio" and cena.painel.colocando=="plantio","UI ativa colocação modular")
	cena._controle.restaurar({"x":-1,"z":7,"angulo":1.0,"fov":28})
	if grafico:
		for i in range(8): await process_frame
		var p:=Vector2(-.5,6.5)
		await clique(root.get_camera_3d().unproject_position(cena.aldeia.no_solo(p)))
	else: cena.confirmar_obra(Vector2(-1,6))
	ok(e.construcoes[1].talhoes[0].celulas.size()==1,"Clique no terreno planta uma única célula")
	for x in range(-1,2):
		for z in range(6,8):
			if x==-1 and z==6: continue
			cena.confirmar_obra(Vector2(x,z))
	ok(cena.aldeia.celulas_visuais.size()==6,"Uma instância visual por quadrado")
	for item: Dictionary in cena.aldeia.celulas_visuais.values():
		ok(item.no.planta==null and item.no.get_child_count()==2,"Terreno vazio sem planta antes de escolher cultivo")
	if grafico: await tecla(KEY_ESCAPE)
	else: cena.cancelar_obra()
	ok(cena.aldeia.modo=="" and cena.painel.colocando=="","Esc encerra plantio repetido")
	cena.aldeia.selecionar_terrenos(cena.aldeia.celulas_visuais.keys())
	cena.painel.plantar_selecao_solicitado.emit("milho")
	cena.mudar_setor(e.habitantes[0].id,"obra_2")
	cena._process(750)
	cena.iniciar_obra("pesca")
	cena.aldeia.girar_previa(6)
	cena.confirmar_obra(Vector2(8,1.2))
	cena._process(45)
	ok(e.construcoes.size()==3 and e.construcoes[-1].tipo=="pesca","Pesca girada junto da água")
	cena._process(fposmod(13.5-e.relogio.obter_hora(),24)*e.relogio.duracao_dia_segundos/24)
	cena.estado.relogio.pausado=true
	cena._controle.restaurar({"x":-1,"z":7,"angulo":1.0,"fov":28})
	cena.painel.abrir("inicio")
	await capturar("plantacao_quadrada")
	var cam: Camera3D=root.get_camera_3d()
	var v: Node3D=cena.aldeia.celulas_visuais.values()[0].no
	ok(cena.aldeia.escolher(cam.unproject_position(v.position+Vector3.UP*.3))=="obra_2","Clique na célula seleciona abrigo responsável")
	cena.painel.abrir("obra_2")
	await capturar("gerenciar_plantacao")
	ok(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Salvamento em arquivo da grade e rotação")
	ok(cena.aldeia.celulas_visuais.size()==6,"Reconstrói visual completo ao carregar")
	for c: Dictionary in cena.estado.construcoes:
		ok(is_equal_approx(cena.aldeia.locais[c.id].rotation.y,c.rotacao),"Orientação visual recuperada "+c.id)
	cena.queue_free()
	await process_frame

func executar() -> void:
	pasta="user://testes_construcao_modular/"+Crypto.new().generate_random_bytes(8).hex_encode()
	grafico=DisplayServer.get_name()!="headless"
	terreno_e_rotacao()
	cultivos()
	await ui()
	print("CONSTRUCAO_MODULAR: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
