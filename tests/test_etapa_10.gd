extends SceneTree
const Estado=preload("res://scripts/partida/estado_partida.gd")
const Exp=Estado.Expedicoes
const Regras=Exp.Caca.Combate
var cena
var total:=0
var falhas:=0
var grafico:=false
func _initialize() -> void: executar.call_deferred()
func ok(valor: bool,nome: String) -> void:
	total+=1
	if not valor: falhas+=1;push_error(nome)
func esperar(frames:=5) -> void:
	for i in range(frames): await process_frame
func foto(nome: String) -> void:
	if not grafico: return
	await esperar(12);await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_etapa_10")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_etapa_10/"+nome+".png")==OK,"Captura "+nome)
func avancar(e,segundos: float) -> void:
	e.relogio.tempo_total+=segundos
	e.avancar_simulacao(segundos)
func clique(pos: Vector2) -> void:
	var mover:=InputEventMouseMotion.new();mover.position=pos;root.push_input(mover)
	for pressionado in [true,false]:
		var evento:=InputEventMouseButton.new();evento.position=pos;evento.button_index=MOUSE_BUTTON_LEFT;evento.pressed=pressionado;root.push_input(evento)
	await process_frame
func clicar(botao: Button) -> void:
	if grafico:
		await esperar(3)
		await clique(botao.get_global_rect().get_center())
	else: botao.pressed.emit()
func movimento(b) -> void:
	var prazo:=Time.get_ticks_msec()+8000
	while b.em_movimento and Time.get_ticks_msec()<prazo: await process_frame
	ok(not b.em_movimento,"Animação encerra e devolve controle")
func fixture(tamanho:=2):
	var e=Estado.nova(load("res://scripts/partida/configuracao_partida.gd").new())
	e.id_partida="0123456789abcdef0123456789abcdef"
	e.estoque.madeira=300;e.estoque.fibras_vegetais=200
	e.construir("oca",Vector2(-5,-4));e.avancar_aldeia(60)
	e.construir("caca",Vector2(-6,5.5));e.avancar_aldeia(60)
	var ids: Array=e.habitantes.map(func(h):return h.id)
	Exp.enviar(e,"obra_2","caca",14,ids.slice(0,tamanho),"manual")
	avancar(e,1500)
	return e
func desfechos() -> void:
	for resultado in ["vitoria","retirada","derrota","animal_fugiu"]:
		var e=fixture();var viagem: Dictionary=e.expedicoes[-1];var c: Dictionary=viagem.combate
		var h: Dictionary=c.atores[0];var animal:=Regras.ator(c,"animal")
		c.cursor=c.ordem.find(h.id);Regras.iniciar_turno(c)
		if resultado=="vitoria":
			animal.x=2;animal.z=3;animal.vida=1;h.equipamento="lanca";h.alcance=1;h.atributo_ataque=100
			while Regras.dado(c.duplicate(true))==1: Regras.dado(c)
			ok(Exp.comando_manual(e,viagem.id,h.id,"atacar","animal")=="","Vitória pelo comando real")
		elif resultado=="retirada":
			h.agilidade=100
			ok(Exp.comando_manual(e,viagem.id,h.id,"fugir")=="","Retirada pelo comando real")
		elif resultado=="animal_fugiu":
			c.cursor=c.ordem.find("animal");Regras.iniciar_turno(c);animal.x=7;animal.z=3;animal.agilidade=100
			ok(Exp.comando_manual(e,viagem.id,"animal","fugir")=="","Fuga pelo comando real")
		else:
			for a: Dictionary in c.atores:
				if a.lado=="equipe": a.vida=0
			Regras.verificar_fim(c);Exp.terminar_confronto(e,viagem,[])
		ok(c.resultado==resultado and c.aplicado and viagem.fase=="retorno","Consequências de "+resultado)
		ok(Estado.validar(e.serializar())=="","Snapshot consistente de "+resultado+": "+Estado.validar(e.serializar()))
		var carga: Dictionary=viagem.carga.duplicate(true);var xp: int=viagem.xp
		avancar(e,viagem.viagem*.5)
		var restante: float=viagem.restante
		Exp.terminar_confronto(e,viagem,[])
		ok(viagem.restante==restante and carga==viagem.carga and xp==viagem.xp,"Repetição não duplica XP/carga nem reinicia retorno: "+resultado)
		var salvo=Estado.desserializar(JSON.parse_string(JSON.stringify(e.serializar())))
		ok(salvo!=null,"Recarrega "+resultado)
		if salvo!=null:
			avancar(salvo,restante)
			ok(salvo.expedicoes[-1].fase in ["concluida","aguardando_descarga"],"Retorno persistido de "+resultado)
func interface_auxiliar() -> void:
	for tamanho in [1,2]:
		cena.estado=fixture(tamanho)
		cena.estado.relogio.velocidade=2;cena.estado.relogio.pausado=true;paused=true
		ok(cena.abrir_combate_pendente(),"Abre equipe de %d pessoa(s), com aldeia pausada"%tamanho)
		var b=cena.combate_manual
		var c: Dictionary=b.combate
		b.cancelar_transicao();b.iniciou=true;b.revelou=true;b.fichas.show();b.dados.show();b.abriu_tabuleiro=true;b.em_movimento=false
		b.get_node("CameraEncontro").global_transform=b.camera_tatica();b.get_node("CameraEncontro").v_offset=-2.1;b.get_node("Grade").show();b.legenda.hide();b.pular.hide()
		var a: Dictionary=c.atores[0]
		c.cursor=c.ordem.find(a.id);Regras.iniciar_turno(c)
		b.sincronizar_atores();b.atualizar_interface()
		await esperar()
		ok(b.equipe.size()==tamanho and b.arcos.size()==tamanho,"Uma pessoa ou dois arcos sem duplicar personagem/corda")
		await clicar(b.botoes.mirar);await movimento(b)
		ok(a.mira>0 and a.pa==1,"Mirar aplica bônus e gasta PA")
		# Repor o turno é exclusivo da fixture de teste.
		c.cursor=c.ordem.find(a.id);Regras.iniciar_turno(c)
		b.atualizar_interface();await clicar(b.botoes.defender);await movimento(b)
		ok(a.defesa_temp>0 and a.pa==1,"Defender aplica bônus e gasta PA")
		if tamanho==2:
			c.cursor=c.ordem.find(a.id);Regras.iniciar_turno(c);b.atualizar_interface()
			await clicar(b.botoes.proteger)
			var amigo: Dictionary=c.atores[1]
			if grafico: await clique(b.get_node("CameraEncontro").unproject_position(b.posicao_casa(Regras.pos(amigo))))
			else: b.executar(a.id,"proteger",amigo.id)
			await movimento(b)
			ok(a.protegendo==amigo.id,"Proteger seleciona aliado pelo tabuleiro")
		c.cursor=c.ordem.find(a.id);Regras.iniciar_turno(c);a.agilidade=100;b.atualizar_interface()
		var tempo: float=cena.estado.relogio.tempo_total
		await clicar(b.botoes.fugir);await movimento(b)
		ok(c.resultado=="retirada" and b.sair.visible,"Fugir resolve encontro e habilita retorno")
		await clicar(b.sair)
		ok(not is_instance_valid(cena.combate_manual),"Botão devolve à aldeia")
		ok(cena.estado.relogio.pausado and cena.estado.relogio.velocidade==2 and paused,"Retorno preserva pausa anterior e velocidade 2x")
		cena._process(1)
		ok(cena.estado.relogio.tempo_total==tempo,"Pausa anterior continua congelando a aldeia")
		paused=false
	await esperar()
func executar() -> void:
	grafico=DisplayServer.get_name()!="headless"
	var codigo=load("res://scripts/encontros/combate_manual.gd")
	if codigo==null or not codigo.can_instantiate(): push_error("Script de combate não compila");quit(1);return
	cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=load("res://scripts/partida/salvamento.gd").new("user://teste_etapa_10/"+Crypto.new().generate_random_bytes(8).hex_encode())
	root.add_child(cena);cena.set_process(false)
	var e=cena.estado
	e.id_partida="0123456789abcdef0123456789abcdef"
	e.estoque.madeira=400;e.estoque.fibras_vegetais=300
	for obra in [["oca",Vector2(-5,-4)],["oca",Vector2(4,-8)],["caca",Vector2(-6,5.5)],["coleta",Vector2(-13,3)]]:
		ok(e.construir(obra[0],obra[1])=="","Construir "+obra[0]);e.avancar_aldeia(60)
	cena.aldeia.sincronizar()
	var ids: Array=e.habitantes.map(func(h):return h.id)
	ok(Exp.erro_envio(e,"obra_3","caca",0,ids.slice(0,2),"manual")!="","Caça manual requer região investigada")
	ok(Exp.enviar(e,"obra_4","coleta",14,ids.slice(2,4)).ok,"Expedição paralela enviada")
	var p=cena.painel_expedicoes
	cena.abrir_expedicoes("obra_3");p.equipe=ids.slice(0,2);p.armas={ids[0]:"lanca",ids[1]:"arco"};p.modo_caca="manual";p.mostrar_passo(3)
	ok(not p.confirmar.disabled,"Menu oferece caça manual real")
	p.confirmar.pressed.emit()
	var viagem: Dictionary=e.expedicoes[-1]
	ok(viagem.get("modo")=="manual","Modo chega à expedição")
	e.relogio.velocidade=3
	avancar(e,2000)
	ok(viagem.fase=="confronto" and viagem.combate.animal=="capivara","Avanço para exatamente no encontro sorteado")
	ok(not viagem.combate.aplicado,"Encontro não foi simulado")
	ok(Estado.validar(e.serializar())=="","Snapshot de encontro válido: "+Estado.validar(e.serializar()))
	var paralelo:=JSON.stringify(e.expedicoes[0])
	var tempo: float=e.relogio.tempo_total
	ok(cena.abrir_combate_pendente(),"Partida abre o encontro")
	await esperar()
	var b=cena.combate_manual
	ok(b.combate==viagem.combate,"Cena usa o confronto da expedição")
	ok(b.atores.size()==3 and b.cartoes.size()==3,"Equipe real e capivara na cena")
	ok(not b.revelou and not b.fichas.visible and not b.get_node("Capivara").visible,"Animal e fichas ocultos antes da revelação")
	var frente: Vector3=b.atores.Capivara.global_basis.z
	var alvo: Vector3=b.Orientacao.centro_equipe(b.equipe)-b.atores.Capivara.global_position;alvo.y=0
	ok(frente.normalized().dot(alvo.normalized())>.99,"Focinho começa voltado às pessoas")
	var rng: String=b.combate.rng
	await foto("01_revelacao")
	b.iniciar_decisoes(true)
	# Suspende só a apresentação para testar persistência sem aguardar IA.
	if b.movimento and b.movimento.is_valid(): b.movimento.kill();b.em_movimento=false;b.sincronizar_atores()
	ok(e.relogio.velocidade==3,"Velocidade preservada")
	for i in range(3): cena._process(1)
	ok(is_equal_approx(e.relogio.tempo_total,tempo) and paralelo==JSON.stringify(e.expedicoes[0]),"Relógio e viagem paralela congelados")
	ok(cena.salvar_partida("manual"),"Salvar confronto")
	var salvo:=JSON.stringify(e.expedicoes[-1].combate)
	ok(cena.carregar_partida("manual"),"Carregar confronto")
	e=cena.estado;viagem=e.expedicoes[-1];b=cena.combate_manual
	await esperar()
	ok(JSON.parse_string(salvo)==viagem.combate,"Carregar não sorteia animal, iniciativa ou dados novamente")
	b.iniciar_decisoes(true)
	if b.movimento and b.movimento.is_valid(): b.movimento.kill();b.em_movimento=false;b.sincronizar_atores()
	# Cenário de alcance controlado, mantendo o motor e os comandos reais.
	b.cancelar_transicao();b.em_movimento=false;b.iniciou=true;b.abriu_tabuleiro=true
	var c: Dictionary=viagem.combate
	var ativo: Dictionary=c.atores[0];var animal:=Regras.ator(c,"animal")
	c.cursor=c.ordem.find(ativo.id);Regras.iniciar_turno(c)
	ativo.x=1;ativo.z=3;ativo.atributo_ataque=100
	animal.x=2;animal.z=2
	while Regras.dado(c.duplicate(true)) in [1,20]: Regras.dado(c)
	b.sincronizar_atores();b.Orientacao.preparar(b.atores.Capivara,b.equipe)
	b.get_node("CameraEncontro").global_transform=b.camera_tatica();b.get_node("CameraEncontro").v_offset=-2.1;b.get_node("Grade").show();b.luz.aplicar(16)
	b.atualizar_interface();await esperar()
	var rejeitado:=JSON.stringify(c)
	ok(b.executar(ativo.id,"mover","",Vector2i(7,7))!="" and rejeitado==JSON.stringify(c),"Comando inválido não gasta PA nem sorteio")
	b.atualizar_interface()
	await foto("02_tabuleiro")
	await clicar(b.botoes.mover)
	var pos: Vector2=b.get_node("CameraEncontro").unproject_position(b.posicao_casa(Vector2i(1,2)))
	ok(b.casa_mouse(pos)==Vector2i(1,2),"Projeção do mouse identifica terreno")
	if grafico: await clique(pos)
	else: b.executar(ativo.id,"mover","",Vector2i(1,2))
	ok(ativo.x==1 and ativo.z==2 and ativo.pa==1,"Clique move com custo real de PA")
	await movimento(b)
	await clicar(b.botoes.atacar)
	var vida: int=animal.vida
	if grafico: await clique(b.get_node("CameraEncontro").unproject_position(b.posicao_casa(Regras.pos(animal))))
	else: b.executar(ativo.id,"atacar","animal")
	ok(animal.vida<vida,"Ataque por clique usa dado/dano do motor")
	ok(b.executar(ativo.id,"atacar","animal")!="","Segundo clique bloqueado durante animação")
	ok(cena.salvar_partida("manual"),"Salvamento durante animação guarda ação já resolvida")
	await foto("02_ataque")
	await movimento(b)
	# Termina pelo mesmo comando usado pela UI, com IA para ambos os lados no teste.
	for i in range(1500):
		if viagem.combate.resultado!="": break
		var a:=Regras.atual(c);var d:=Regras.decisao(c)
		var erro:=Exp.comando_manual(e,viagem.id,a.id,d.acao,d.get("alvo",""),Vector2i(d.get("x",-1),d.get("z",-1)))
		ok(erro=="","Comando de combate real: "+erro)
	ok(viagem.fase=="retorno" and viagem.combate.aplicado,"Resultado inicia retorno e aplica consequências")
	var carga:=JSON.stringify(viagem.carga);var xp: int=viagem.xp
	Exp.terminar_confronto(e,viagem,[])
	ok(carga==JSON.stringify(viagem.carga) and xp==viagem.xp,"Resultado idempotente")
	b.sincronizar_atores();b.atualizar_interface()
	await foto("03_resultado")
	ok(cena.salvar_partida("manual") and cena.carregar_partida("manual"),"Salvar resultado válido")
	ok(not is_instance_valid(cena.combate_manual),"Carregar resultado não reabre encontro")
	e=cena.estado;viagem=e.expedicoes[-1]
	avancar(e,viagem.viagem)
	ok(viagem.fase in ["concluida","aguardando_descarga"],"Retorno à aldeia")
	var estoque: Dictionary=e.estoque.duplicate(true)
	avancar(e,2)
	ok(estoque==e.estoque,"Retorno não duplica entrega")
	ok(e.relogio.velocidade==3,"Retoma 3x")
	for sexo in ["homem","mulher"]:
		for i in range(1,5):
			var modelo: Node3D=load("res://assets/models/habitantes/batalha/%s_%02d.glb"%[sexo,i]).instantiate()
			var ap: AnimationPlayer=modelo.find_children("*","AnimationPlayer",true,false)[0]
			for clipe in ["andar","atacar_lanca","errar_lanca","atacar_arco","errar_arco","receber_golpe","esquivar","defender"]:
				ok(ap.has_animation(clipe),"Variação %s_%02d: %s"%[sexo,i,clipe])
			modelo.free()
	desfechos()
	await interface_auxiliar()
	print("ETAPA 10: %d verificações, %d falhas"%[total,falhas])
	cena.queue_free();await process_frame;quit(1 if falhas else 0)
