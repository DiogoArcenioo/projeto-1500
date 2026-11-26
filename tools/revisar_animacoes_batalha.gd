extends SceneTree
var cena
var total:=0
var falhas:=0
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,t: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(t)
func esperar(n:=14) -> void:
	for i in range(n): await process_frame
func clicar(b: Button) -> void:
	if DisplayServer.get_name()=="headless":
		b.pressed.emit()
		return
	await esperar(4)
	var ponto:=b.get_global_rect().get_center()
	var mover:=InputEventMouseMotion.new();mover.position=ponto;root.push_input(mover)
	for baixo in [true,false]:
		var e:=InputEventMouseButton.new();e.position=ponto;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=baixo;root.push_input(e)
	await process_frame
func captura(nome: String) -> void:
	await esperar()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_animacoes_batalha")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_animacoes_batalha/"+nome+".png")==OK,"Captura "+nome)
func executar() -> void:
	cena=load("res://scenes/inspecao/batalha_animacoes_etapa_10.tscn").instantiate()
	if cena.get_script()==null:
		quit(1)
		return
	root.add_child(cena)
	await esperar()
	for pessoa in ["Cacador","Cacadora"]:
		var p: AnimationPlayer=cena.player(pessoa)
		for a in ["atacar_arco","errar_arco","atacar_lanca","errar_lanca","receber_golpe","esquivar"]:
			ok(p.has_animation(a),pessoa+" possui "+a)
		var esqueletos: Array[Node]=cena.atores[pessoa].find_children("*","Skeleton3D",true,false)
		ok(esqueletos.size()==1 and esqueletos[0].get_bone_count()==17,"Rig articulado de "+pessoa)
		p.play("atacar_lanca");p.seek(.60,true)
		ok(esqueletos[0].get_bone_pose_rotation(esqueletos[0].find_bone("braco_D")).angle_to(Quaternion.IDENTITY)>.1,"Ataque articula o braço de "+pessoa)
	var animal: AnimationPlayer=cena.player("Capivara")
	for a in ["investida","errar_ataque","receber_golpe","esquivar"]: ok(animal.has_animation(a),"Animal possui "+a)
	await captura("00_interface")
	for chave in ["lanca_acerto","lanca_erro","arco_acerto","arco_erro","animal_acerto","animal_erro"]:
		await clicar(cena.botoes[chave])
		ok(cena.fase_atual==chave and cena.em_movimento,"Botão inicia a animação: "+chave)
		cena.movimento.pause()
		cena.movimento.custom_step(1.0)
		ok(cena.ultimo_evento.acertou==chave.ends_with("acerto"),"Resultado visual correto: "+chave)
		ok(cena.ultimo_evento.dano==(4 if chave.ends_with("acerto") else 0),"Erro não mostra dano: "+chave)
		for nome in cena.atores:
			var p: AnimationPlayer=cena.player(nome)
			p.play(p.current_animation,0)
			p.seek(.60 if nome==cena.ultimo_evento.atacante else .16,true)
			p.pause()
		await captura(chave)
		if chave=="lanca_acerto":
			var suporte: Node3D=cena.atores.Cacador.find_children("Lanca","Node3D",true,false)[0]
			var direcao: Vector3=(cena.atores.Capivara.global_position-cena.atores.Cacador.global_position).normalized()
			ok(suporte.global_basis.y.dot(direcao)>.8,"Ponta da lança acompanha a mão e mira no animal")
		cena.movimento.custom_step(5)
		ok(not cena.em_movimento,"Demonstração desbloqueia os controles: "+chave)
		cena.repor()
	cena.mostrar_interface()
	await captura("07_interface_tatica")
	ok(cena.painel_interface.visible and cena.fichas.get_child_count()==3,"Interface tática exibe equipe e animal")
	cena.queue_free()
	await process_frame
	print("ANIMACOES_BATALHA: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
