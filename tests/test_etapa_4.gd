extends SceneTree
const Estado=preload("res://scripts/partida/estado_partida.gd")
const Salvar=preload("res://scripts/partida/salvamento.gd")
var cena
var erros:=0
var total:=0
var pasta: String
var gravar_imagens:=false

func verificar(valor: bool, descricao: String) -> void:
	total+=1
	if not valor:
		erros+=1
		push_error(descricao)

func _initialize() -> void:
	call_deferred("executar")

func captura(nome:String) -> void:
	if not gravar_imagens: return
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var destino:="res://exports/revisao_variacoes/"
	DirAccess.make_dir_recursive_absolute(destino)
	verificar(root.get_texture().get_image().save_png(destino+nome+".png")==OK,"Captura "+nome)

func obra(tipo: String,p: Vector2) -> void:
	cena.iniciar_obra(tipo)
	cena.confirmar_obra(p)
	verificar(cena.aldeia.modo=="","Confirmação de "+tipo+" em "+str(p))

func avancar(s: float) -> void:
	cena._process(s)

func executar() -> void:
	gravar_imagens="--capturas" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	pasta="user://testes_etapa_4/"+Crypto.new().generate_random_bytes(8).hex_encode()
	cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=Salvar.new(pasta)
	root.add_child(cena)
	cena.set_process(false)
	var e=cena.estado
	verificar(e.habitantes.is_empty() and e.construcoes.is_empty(),"Partida com zero habitantes e construções")
	var cam: Camera3D=root.get_camera_3d()
	verificar(cena.aldeia.escolher(cam.unproject_position(Vector3(0,.7,0)))=="fogueira","Seleção real da fogueira")
	var p:=Vector2(-5,-4)
	cena.aldeia.selecionado.emit("fogueira")
	verificar(cena.painel.contexto=="fogueira","Painel da fogueira")
	cena.iniciar_obra("oca")
	cena.confirmar_obra(Vector2(17,0))
	verificar(e.construcoes.is_empty() and e.estoque.madeira==120,"Rio bloqueado")
	cena.cancelar_obra()
	verificar(e.estoque.fibras_vegetais==80,"Cancelamento sem cobrança")
	obra("oca",p)
	verificar(e.estoque.madeira==90 and e.estoque.fibras_vegetais==60,"Custo único")
	verificar(e.impedimento("oca",p)!="" and e.impedimento("oca",Vector2(4,-8))!="","Bloqueio de sobreposição e de segunda obra fundadora")
	avancar(7)
	verificar(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Persistência da obra fundadora")
	e=cena.estado
	verificar(is_equal_approx(e.construcoes[0].restante,11),"Progresso preservado")
	avancar(11)
	avancar(1)
	verificar(e.habitantes.size()==2 and e.capacidade_residencial()==2,"Chegada única dos dois primeiros adultos")
	verificar(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Recarga após chegada")
	e=cena.estado
	var a: Dictionary=e.habitantes[0]
	var b: Dictionary=e.habitantes[1]
	obra("coleta",Vector2(6,-1))
	verificar(a.estado=="construindo" and e.atribuir(a.id,"")!="","Construtor indisponível para dupla alocação")
	verificar(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Vínculo do construtor persistido")
	e=cena.estado
	a=e.habitantes[0]
	b=e.habitantes[1]
	avancar(10)
	verificar(a.estado=="livre" and a.habilidades.construcao==5,"Conclusão libera construtor e concede XP")
	var setor: String=e.construcoes[1].id
	var centro: Vector3=cena.aldeia.locais[setor].position
	verificar(cena.aldeia.escolher(cam.unproject_position(centro+Vector3.UP*.5))==setor,"Clique no setor do mundo")
	cena.painel.abrir(setor)
	cena.painel.mudar_setor.emit(a.id,setor)
	cena.painel.abrir("comunidade")
	cena.painel.mudar_setor.emit(b.id,setor)
	verificar(e.ocupacao(setor)==2 and a.casa==b.casa,"Mesma regra nos dois painéis")
	avancar(120)
	verificar(a.habilidades.coleta==2 and b.habilidades.coleta==2 and e.estoque.vegetais==8,"Trabalho e XP no intervalo rebalanceado de 60 s, sem alimento fácil")
	cena.mudar_setor(b.id,"")
	obra("oca",Vector2(4,-8))
	avancar(18)
	verificar(e.habitantes.size()==4,"Segunda moradia recebe dois novos adultos")
	var h: Dictionary=e.habitantes[2]
	cena.mudar_setor(b.id,setor)
	verificar(e.atribuir(h.id,setor)!="" and h.estado=="livre","Não ultrapassa as vagas")
	obra("coleta",Vector2(-13,3))
	avancar(10)
	var outro: String=e.construcoes.back().id
	var xp: int=a.xp
	cena.mudar_setor(a.id,outro)
	verificar(a.xp==xp and e.ocupacao(setor)==1 and e.ocupacao(outro)==1,"Transferência preserva XP e libera vaga")
	avancar(600)
	obra("oca",Vector2(-6,5.5))
	avancar(18)
	obra("oca",Vector2(4,7))
	avancar(18)
	var visuais:={}
	for morador in e.habitantes:
		visuais[morador.visual]=true
		var anim=cena.aldeia.atores[morador.id].anim
		var clipes:=["parado","andar","coletar","capinar","plantar","pescar","artesanato","construir","conversar","olhar"]
		verificar(clipes.all(func(c): return anim.tem(c)) and anim.velocidade_andar>.4,"GLB e animações de "+morador.visual)
	verificar(visuais.size()==8 and e.capacidade_residencial()==8,"Oito aparências nas quatro primeiras ocas")
	var validado: Dictionary=e.serializar()
	verificar(Estado.validar(validado)=="","Snapshot íntegro")
	validado.habitantes[1].casa="inexistente"
	verificar(Estado.validar(validado)!="","Rejeição de relação residencial inválida")
	var antigo: Dictionary=Estado.nova(cena.configuracao).serializar()
	antigo.erase("construcoes")
	verificar(Estado.desserializar(antigo)!=null,"Compatibilidade com saves vazios da etapa 2")
	verificar(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Recarga da população e dos setores")
	e=cena.estado
	verificar(e.habitantes[0].setor==outro and e.habitantes.size()==8,"Vínculos estáveis após carregar")
	for i in range(200): cena.aldeia.mover(.05)
	cena.iluminacao.aplicar(16)
	cena.painel.abrir("inicio")
	await captura("aldeia_godot")
	cena.painel.abrir("comunidade")
	await captura("comunidade_godot")
	cena.queue_free()
	await process_frame
	if gravar_imagens:
		var galeria=load("res://scenes/inspecao/moradores_etapa_4.tscn").instantiate()
		root.add_child(galeria)
		await captura("familia_godot")
		galeria.queue_free()
	var d:=DirAccess.open(pasta)
	if d:
		for f in d.get_files(): DirAccess.remove_absolute(pasta.path_join(f))
		DirAccess.remove_absolute(pasta)
	print("ETAPA_4: %d verificações; %d falhas"%[total,erros])
	quit(1 if erros else 0)
