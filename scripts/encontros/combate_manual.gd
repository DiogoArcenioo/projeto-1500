extends "res://scripts/inspecao/inspecao_animacoes_batalha.gd"
## Apresentação do estado persistente; nenhuma rolagem ou recompensa é criada aqui.
signal concluido
const Exp=preload("res://scripts/partida/expedicoes.gd")
const Regras=preload("res://scripts/partida/combate.gd")
var estado
var expedicao_id: String
var viagem: Dictionary
var combate: Dictionary
var nomes: Dictionary={}
var cartoes: Dictionary={}
var acao_selecionada:="mover"
var titulo_turno: Label
var detalhe: Label
var dados: RichTextLabel
var sair: Button
var pular: Button
var destaques: Node3D
var arcos: Array=[]
var som: AudioStreamPlayer
var iniciou:=false
var abriu_tabuleiro:=false
var revelou:=false

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	viagem=Exp.buscar(estado,expedicao_id)
	combate=viagem.combate
	var humanos:=0
	for a: Dictionary in combate.atores:
		var nome: String="Capivara" if a.lado=="animal" else ("Cacador" if humanos==0 else "Cacadora")
		if a.lado=="equipe": humanos+=1
		nomes[a.id]=nome
		var antigo:=get_node(nome)
		remove_child(antigo);antigo.queue_free()
		# O nó do animal mantém o nome "Capivara" da cena; o modelo segue a espécie sorteada.
		var caminho: String="res://assets/models/animais/batalha/%s.glb"%combate.animal if a.lado=="animal" else "res://assets/models/habitantes/batalha/"+estado.pessoa(a.id).visual+".glb"
		var modelo: Node3D=load(caminho).instantiate()
		modelo.name=nome;add_child(modelo);atores[nome]=modelo
		if a.lado=="equipe": equipe.append(modelo)
	if humanos==1:
		var extra: Node3D=$Cacadora
		remove_child(extra);extra.queue_free()
	add_child(luz);luz.configurar($Clareira1500);luz.aplicar(estado.relogio.obter_hora())
	preparar_mata()
	sincronizar_atores()
	for a: Dictionary in combate.atores:
		if a.lado=="equipe":
			# A ferramenta básica (coleta, pesca, reconhecimento) usa a lança como pau de cavar.
			armar(atores[nomes[a.id]],"lanca" if a.equipamento=="ferramenta" else a.equipamento)
			if a.equipamento=="arco": arcos.append({"nome":nomes[a.id],"suporte":arco_suporte,"corda":corda})
		for m: MeshInstance3D in atores[nomes[a.id]].find_children("*","MeshInstance3D",true,false): m.layers=3
	criar_grade()
	criar_legendas();ajuda.hide()
	destaques=Node3D.new();$Grade.add_child(destaques)
	interface_real()
	som=AudioStreamPlayer.new();add_child(som)
	Orientacao.preparar($Capivara,equipe)
	revelar(true)
	# Abertura guarda apenas apresentação. Iniciativa e animal já vieram do save.
	transicao.kill()
	$Capivara.hide();$Grade.hide()
	fichas.hide();dados.hide()
	em_movimento=true
	transicao=create_tween()
	transicao.tween_interval(1.1)
	transicao.tween_callback(func():
		$Capivara.show();revelou=true;fichas.show();dados.show();legenda.text=Regras.nome_animal(combate.animal);atualizar_interface();sinal_sonoro(false))
	transicao.tween_interval(1.4)
	transicao.tween_callback(func():iniciar_decisoes(false))
	atualizar_interface()

func posicao_casa(p: Vector2i) -> Vector3:
	return Solo.no_solo(ORIGEM+Vector2(p)+Vector2.ONE*.5)

func sincronizar_atores() -> void:
	for a: Dictionary in combate.atores:
		var nome: String=nomes[a.id]
		var modelo: Node3D=atores[nome]
		modelo.position=posicao_casa(Regras.pos(a))
		modelo.visible=a.vida>0
		tocar(nome,"parada" if a.lado=="animal" else "pronto",true)

func criar_grade() -> void:
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color("a99c68");mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	for i in range(9):
		for j in range(8):
			linha(ponto(ORIGEM+Vector2(i,j)),ponto(ORIGEM+Vector2(i,j+1)),.018,mat)
			linha(ponto(ORIGEM+Vector2(j,i)),ponto(ORIGEM+Vector2(j+1,i)),.018,mat)
	# Indicam o mesmo terreno definido pelo motor: pedras bloqueiam, tronco dá cobertura.
	for tipo in ["bloqueios","coberturas"]:
		for p: Dictionary in combate[tipo]:
			var objeto:=MeshInstance3D.new()
			var material:=StandardMaterial3D.new()
			if tipo=="bloqueios":
				var pedra:=SphereMesh.new();pedra.radial_segments=6;pedra.rings=3;pedra.radius=.4;pedra.height=.75
				objeto.mesh=pedra;material.albedo_color=Color("766e60")
			else:
				var tronco:=CylinderMesh.new();tronco.top_radius=.16;tronco.bottom_radius=.20;tronco.height=.8;tronco.radial_segments=7
				objeto.mesh=tronco;objeto.rotation.z=PI*.5;material.albedo_color=Color("755235")
			objeto.material_override=material;add_child(objeto)
			objeto.position=posicao_casa(Vector2i(p.x,p.z))+Vector3(0,.3,0)

func interface_real() -> void:
	var camada:=CanvasLayer.new();camada.layer=10;add_child(camada)
	ui=Control.new();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;camada.add_child(ui)
	var casca:=StyleBoxTexture.new();casca.texture=load("res://assets/ui/expedicoes/casca_interna_painel.png")
	casca.content_margin_left=66;casca.content_margin_right=66;casca.content_margin_top=24;casca.content_margin_bottom=24
	painel_interface=PanelContainer.new();painel_interface.add_theme_stylebox_override("panel",casca);ui.add_child(painel_interface)
	var col:=VBoxContainer.new();painel_interface.add_child(col)
	var topo:=HBoxContainer.new();col.add_child(topo)
	titulo_turno=texto(topo,"",21);titulo_turno.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	pular=botao(topo,"Pular introdução",func():iniciar_decisoes(true))
	sair=botao(topo,"Voltar à aldeia",func():concluido.emit());sair.hide()
	var linha_acoes:=HBoxContainer.new();col.add_child(linha_acoes)
	for item in [["mover","Mover · 1 PA"],["atacar","Atacar · 1 PA"],["mirar","Mirar · 1 PA"],["defender","Defender · 1 PA"],["proteger","Proteger · 1 PA"],["fugir","Fugir · 2 PA"],["passar","Encerrar turno"]]:
		var chave: String=item[0]
		botoes[chave]=botao(linha_acoes,item[1],func():selecionar_acao(chave))
	detalhe=texto(col,"",17);detalhe.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dados=RichTextLabel.new();dados.custom_minimum_size.y=62;dados.scroll_active=true;dados.bbcode_enabled=false
	dados.add_theme_font_override("normal_font",FONTE_CORPO);dados.add_theme_font_size_override("normal_font_size",16)
	dados.add_theme_color_override("default_color",Color("35271b"));col.add_child(dados)
	fichas=HBoxContainer.new();fichas.position=Vector2(16,12);fichas.add_theme_constant_override("separation",10);ui.add_child(fichas)
	for a: Dictionary in combate.atores:
		var quadro:=PanelContainer.new();var fundo:=casca.duplicate() as StyleBoxTexture
		fundo.content_margin_left=26;fundo.content_margin_right=26;fundo.content_margin_top=20;fundo.content_margin_bottom=20
		quadro.add_theme_stylebox_override("panel",fundo);fichas.add_child(quadro)
		var linha_card:=HBoxContainer.new();quadro.add_child(linha_card)
		if a.lado=="equipe":
			var retrato:=TextureRect.new();retrato.texture=load("res://assets/ui/retratos/"+estado.pessoa(a.id).visual+".png")
			retrato.custom_minimum_size=Vector2(48,64);retrato.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;retrato.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;linha_card.add_child(retrato)
		var coluna:=VBoxContainer.new();linha_card.add_child(coluna)
		var nome:=texto(coluna,a.nome,20)
		var vida:=texto(coluna,"",17)
		var turno:=texto(coluna,"",16)
		cartoes[a.id]={"nome":nome,"vida":vida,"turno":turno}
	get_viewport().size_changed.connect(ajustar_ui)
	ajustar_ui()

func ajustar_ui() -> void:
	if not is_instance_valid(ui): return
	var tam:=get_viewport().get_visible_rect().size
	var escala:=minf(1.0,minf(tam.x/1280.0,tam.y/720.0))
	ui.scale=Vector2.ONE*escala;ui.size=tam/escala
	painel_interface.size=Vector2(ui.size.x-24,223)
	painel_interface.position=Vector2(12,ui.size.y-painel_interface.size.y-8)

func iniciar_decisoes(imediata: bool) -> void:
	if iniciou: return
	iniciou=true
	revelou=true;fichas.show();dados.show()
	cancelar_transicao();$Capivara.show();legenda.text=""
	if Regras.atual(combate).lado=="animal":
		em_movimento=false
		atualizar_interface();pular.hide();turno_animal()
		return
	abrir_tabuleiro(imediata)
	pular.hide()

func abrir_tabuleiro(imediata:=false) -> void:
	abriu_tabuleiro=true;$Grade.show();em_movimento=true
	$CameraEncontro.v_offset=-2.1
	if imediata:
		$CameraEncontro.global_transform=camera_tatica();em_movimento=false;atualizar_interface();turno_animal()
	else:
		transicao=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		transicao.tween_property($CameraEncontro,"global_transform",camera_tatica(),1.2)
		transicao.tween_callback(func():em_movimento=false;atualizar_interface();turno_animal())

func selecionar_acao(acao: String) -> void:
	if em_movimento or not iniciou or combate.resultado!="": return
	var a:=Regras.atual(combate)
	if a.lado!="equipe": return
	acao_selecionada=acao
	if acao in ["mirar","defender","fugir","passar"]: executar(a.id,acao)
	else: atualizar_interface()

func atualizar_interface() -> void:
	var atual:=Regras.atual(combate)
	var acabou: bool=combate.resultado!=""
	for a: Dictionary in combate.atores:
		cartoes[a.id].vida.text="%d / %d HP · %d PA"%[a.vida,a.vida_max,a.pa]
		cartoes[a.id].turno.text="Iniciativa %d%s"%[a.iniciativa,(" · SUA VEZ" if a.lado=="equipe" else " · AGINDO") if not atual.is_empty() and atual.id==a.id else ""]
		cartoes[a.id].nome.modulate=Color.WHITE if a.vida>0 else Color(.65,.65,.65)
	for chave in botoes:
		var b: Button=botoes[chave]
		b.disabled=em_movimento or not iniciou or acabou or atual.get("lado","")!="equipe"
		if not b.disabled:
			b.disabled=atual.pa<(2 if chave=="fugir" else 1) and chave!="passar"
			if chave=="atacar": b.disabled=b.disabled or atual.atacou
		b.modulate=Color("fff1c3") if chave==acao_selecionada else Color.WHITE
	if not revelou:
		titulo_turno.text="Adentrando a mata... · aldeia pausada"
		detalhe.text="Observe a mata ou pule a introdução com Espaço."
		return
	if acabou:
		titulo_turno.text={"vitoria":"Caça concluída","animal_fugiu":"%s escapou"%Regras.nome_animal(combate.animal),"retirada":"Equipe em retirada","derrota":"Equipe derrotada","impasse":"Confronto encerrado sem avanço"}.get(combate.resultado,"Confronto encerrado")
		var carga: Array[String]=[]
		for recurso in viagem.carga: carga.append("%d %s"%[viagem.carga[recurso],recurso.replace("_"," ")])
		var condicao: Array[String]=[]
		for a: Dictionary in combate.atores:
			if a.lado=="equipe": condicao.append(a.nome+": "+("morto" if a.morto else ("incapacitado" if a.vida==0 else "%d/%d HP"%[a.vida,a.vida_max])))
		detalhe.text="%d XP · %s · Carga: %s. Entrega no retorno."%[viagem.xp," · ".join(condicao),", ".join(carga) if not carga.is_empty() else "nenhuma"]
		sair.visible=not em_movimento
	else:
		titulo_turno.text="Rodada %d · %s · %d PA · aldeia pausada"%[combate.rodada,atual.get("nome",""),atual.get("pa",0)]
		detalhe.text={"mover":"Clique numa casa verde: até %d passos por PA. Pedras bloqueiam; troncos dão cobertura."%atual.get("movimento",3),"atacar":"Clique num alvo vermelho · %s · um ataque por turno."%("Arco: alcance %d casas"%atual.get("alcance",1) if atual.get("equipamento")=="arco" else "Alcance corpo a corpo: 1 casa"),"proteger":"Clique em um aliado vivo adjacente para interceptar o próximo golpe."}.get(acao_selecionada,"Escolha uma ação.")
	if not combate.registro.is_empty():
		dados.text="\n".join(combate.registro)
		dados.scroll_to_line(maxi(0,dados.get_line_count()-3))
	if is_instance_valid(destaques): marcar_casas()

func colorir(p: Vector2i,cor: Color) -> void:
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.albedo_color=cor
	var malha:=ImmediateMesh.new();malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
	var inicio:=ORIGEM+Vector2(p)+Vector2(.05,.05)
	for d in [Vector2.ZERO,Vector2.RIGHT*.9,Vector2.ONE*.9,Vector2.ZERO,Vector2.ONE*.9,Vector2.DOWN*.9]:
		malha.surface_add_vertex(ponto(inicio+d)+Vector3(0,.018,0))
	malha.surface_end();var m:=MeshInstance3D.new();m.mesh=malha;destaques.add_child(m)

func marcar_casas() -> void:
	for n in destaques.get_children(): destaques.remove_child(n);n.queue_free()
	if combate.resultado!="" or em_movimento or not iniciou: return
	var a:=Regras.atual(combate)
	colorir(Regras.pos(a),Color(1,.77,.3,.42))
	if a.lado!="equipe": return
	if acao_selecionada=="mover":
		for x in range(8):
			for z in range(8):
				var rota:=Regras.caminho(combate,a,Vector2i(x,z))
				if not rota.is_empty() and rota.size()<=int(a.movimento): colorir(Vector2i(x,z),Color(.25,.75,.45,.34))
	elif acao_selecionada=="atacar":
		for b: Dictionary in combate.atores:
			if Regras.pode_atacar(combate,a,b): colorir(Regras.pos(b),Color(.95,.3,.15,.48))
	elif acao_selecionada=="proteger":
		for b: Dictionary in combate.atores:
			if b.lado==a.lado and b.id!=a.id and b.vida>0 and Regras.distancia(a,b)==1: colorir(Regras.pos(b),Color(.4,.7,1,.4))

func casa_mouse(mouse: Vector2) -> Vector2i:
	var cam: Camera3D=$CameraEncontro
	var inicio:=cam.project_ray_origin(mouse);var direcao:=cam.project_ray_normal(mouse)
	for x in range(8):
		for z in range(8):
			var p:=ORIGEM+Vector2(x,z)
			var a:=ponto(p);var b:=ponto(p+Vector2.RIGHT);var c:=ponto(p+Vector2.ONE);var d:=ponto(p+Vector2.DOWN)
			if Geometry3D.ray_intersects_triangle(inicio,direcao,a,b,c)!=null or Geometry3D.ray_intersects_triangle(inicio,direcao,a,c,d)!=null: return Vector2i(x,z)
	return Vector2i(-1,-1)

func _unhandled_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index==MOUSE_BUTTON_LEFT and iniciou and not em_movimento and combate.resultado=="":
		var casa:=casa_mouse(evento.position)
		if casa.x<0: return
		var a:=Regras.atual(combate)
		if a.lado!="equipe": return
		var alvo:=""
		for b: Dictionary in combate.atores:
			if Regras.pos(b)==casa: alvo=b.id
		if acao_selecionada=="mover": executar(a.id,"mover","",casa)
		elif acao_selecionada in ["atacar","proteger"]: executar(a.id,acao_selecionada,alvo)
		get_viewport().set_input_as_handled()

func _unhandled_key_input(evento: InputEvent) -> void:
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.physical_keycode==KEY_SPACE and not iniciou:
		iniciar_decisoes(true);get_viewport().set_input_as_handled()

func executar(id: String,acao: String,alvo: String="",destino:=Vector2i(-1,-1)) -> String:
	if em_movimento: return "Aguarde a animação."
	var antes:=combate.duplicate(true)
	var erro:=Exp.comando_manual(estado,expedicao_id,id,acao,alvo,destino)
	if erro!="": detalhe.text=erro;return erro
	em_movimento=true
	atualizar_interface()
	animar_resultado(antes,id,acao,alvo,destino)
	return ""

func animar_resultado(antes: Dictionary,id: String,acao: String,alvo: String,destino: Vector2i) -> void:
	var a:=Regras.ator(antes,id)
	var nome: String=nomes[id]
	movimento=create_tween()
	if acao=="mover":
		var rota:=Regras.caminho(antes,a,destino)
		tocar(nome,"andar",true)
		for p: Vector2i in rota:
			var fim:=posicao_casa(p)
			movimento.tween_callback(func():Orientacao.encarar(atores[nome],fim))
			movimento.tween_property(atores[nome],"position",fim,.24)
	elif acao=="atacar":
		var atingido:=alvo
		var dano:=0
		for b: Dictionary in combate.atores:
			var perda:=int(Regras.ator(antes,b.id).vida)-int(b.vida)
			if perda>0: atingido=b.id;dano=perda
		# O histórico pode atingir 80 entradas: o estado RNG/vida já está resolvido pelo motor.
		var ataque_texto:=""
		for s: String in combate.registro:
			if s.contains(" → "): ataque_texto=s
		var acertou:=ataque_texto.ends_with("acerto") or ataque_texto.ends_with("CRÍTICO")
		var animal: bool=a.lado=="animal"
		var arco: bool=a.equipamento=="arco"
		fase_atual="arco_acerto" if arco else "golpe"
		Orientacao.encarar(atores[nome],atores[nomes[alvo]].global_position)
		var centro: Vector3=atores[nome].position.lerp(atores[nomes[alvo]].position,.5)+Vector3(0,.8,0)
		var distancia: float=atores[nome].position.distance_to(atores[nomes[alvo]].position)
		var plano:=pose_camera(centro+Vector3(3,3.2+distancia*.25,4.5+distancia*.5),centro)
		cancelar_transicao();transicao=create_tween().set_parallel(true)
		transicao.tween_property($CameraEncontro,"global_transform",plano,.35)
		transicao.tween_property($CameraEncontro,"v_offset",-.9,.35)
		var clipe: String=("investida" if acertou else "errar_ataque") if animal else (("atacar_arco" if acertou else "errar_arco") if arco else ("atacar_lanca" if acertou else "errar_lanca"))
		tocar(nome,clipe)
		movimento.tween_interval(.72 if arco else .53)
		if arco:
			movimento.tween_callback(func():projetil(nome,nomes[atingido],acertou))
			movimento.tween_interval(.2)
		movimento.tween_callback(func():
			tocar(nomes[atingido],"receber_golpe" if acertou else "esquivar")
			mostrar_efeito(atores[nomes[atingido]],"−%d HP"%dano if acertou else "ERROU",acertou)
			sinal_sonoro(acertou))
		movimento.tween_interval(.9)
	elif acao in ["defender","proteger","mirar"]:
		tocar(nome,"defender" if acao!="mirar" else "pronto")
		movimento.tween_interval(.65)
	elif acao=="fugir":
		mostrar_efeito(atores[nome],"FUGA" if combate.resultado!="" else "FALHOU",false)
		movimento.tween_interval(.8)
	else: movimento.tween_interval(.15)
	movimento.tween_callback(func():
		if not is_inside_tree(): return
		fase_atual="pronto";sincronizar_atores()
		if acao=="atacar" and abriu_tabuleiro:
			cancelar_transicao();transicao=create_tween().set_parallel(true)
			transicao.tween_property($CameraEncontro,"global_transform",camera_tatica(),.4)
			transicao.tween_property($CameraEncontro,"v_offset",-2.1,.4)
			transicao.chain().tween_callback(concluir_animacao)
		else: concluir_animacao())

func concluir_animacao() -> void:
	em_movimento=false
	if combate.resultado=="" and Regras.atual(combate).lado=="equipe" and not abriu_tabuleiro:
		abrir_tabuleiro()
		return
	atualizar_interface();turno_animal()

func turno_animal() -> void:
	if em_movimento or combate.resultado!="" or not iniciou: return
	var a:=Regras.atual(combate)
	if a.lado!="animal": return
	var decisao:=Regras.decisao(combate)
	executar(a.id,decisao.acao,decisao.get("alvo",""),Vector2i(decisao.get("x",-1),decisao.get("z",-1)))

func _process(_delta: float) -> void:
	for arco: Dictionary in arcos:
		var suporte: Node3D=arco.suporte
		var topo:=suporte.to_global(Vector3(-.24,.825,0));var base:=suporte.to_global(Vector3(-.24,-.825,0))
		var meio:=suporte.to_global(Vector3(-.24,0,0));var p:=player(arco.nome)
		if fase_atual.begins_with("arco") and p.current_animation.contains("arco") and p.current_animation_position>.22 and p.current_animation_position<.77: meio=mao_global(arco.nome,"D")
		var malha:=ImmediateMesh.new();malha.surface_begin(Mesh.PRIMITIVE_LINES,material_corda)
		for v in [topo,meio,meio,base]: malha.surface_add_vertex(v)
		malha.surface_end();arco.corda.mesh=malha

func sinal_sonoro(impacto: bool) -> void:
	# Sinais tonais originais curtos, sem arquivo ou dependência externa.
	var onda:=AudioStreamWAV.new();onda.format=AudioStreamWAV.FORMAT_16_BITS;onda.mix_rate=22050
	var amostras:=PackedByteArray();amostras.resize(4410)
	for i in range(2205):
		var t:=float(i)/22050
		var valor:=sin(t*TAU*(110 if impacto else 620))*exp(-t*45)*.24
		amostras.encode_s16(i*2,int(valor*32767))
	onda.data=amostras;som.stream=onda;som.play()

func mostrar_efeito(alvo: Node3D,t: String,acertou: bool) -> void:
	super.mostrar_efeito(alvo,t,acertou)
	var etiqueta:=efeito
	var desaparecer:=create_tween()
	desaparecer.tween_interval(.6)
	desaparecer.tween_property(etiqueta,"modulate:a",0.0,.3)
	desaparecer.tween_callback(func():if is_instance_valid(etiqueta): etiqueta.queue_free())
