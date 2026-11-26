extends SceneTree
const O=preload("res://scripts/encontros/orientacao_encontro.gd")
var cena
var total:=0
var falhas:=0
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,t: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(t)
func esperar(n:=24) -> void:
	for i in range(n): await process_frame
func captura(nome: String) -> void:
	await esperar()
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_encontro_capivara")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_encontro_capivara/"+nome+".png")==OK,"Captura "+nome)
func olhando() -> bool:
	var animal: Node3D=cena.get_node("Capivara")
	var delta: Vector3=O.centro_equipe(cena.equipe)-animal.global_position
	delta.y=0
	var frente:=animal.global_basis.z
	frente.y=0
	return frente.normalized().dot(delta.normalized())>.9999
func executar() -> void:
	cena=load("res://scenes/inspecao/encontro_capivara_etapa_10.tscn").instantiate()
	if cena.get_script()==null:
		push_error("Cena de encontro sem script válido")
		quit(1)
		return
	cena.automatico=false
	root.add_child(cena)
	await esperar()
	ok(olhando(),"Focinho voltado à equipe antes da revelação")
	ok(not cena.get_node("Grade").visible,"Revelação sem tabuleiro")
	await captura("01_revelacao")
	var a: Node3D=cena.get_node("Capivara")
	var esqueletos:=a.find_children("*","Skeleton3D",true,false)
	var s: Skeleton3D=esqueletos[0]
	var direcao_real:=s.global_basis*s.get_bone_global_rest(s.find_bone("cabeca")).basis.y
	direcao_real.y=0
	var esperado: Vector3=O.centro_equipe(cena.equipe)-a.global_position
	esperado.y=0
	ok(direcao_real.normalized().dot(esperado.normalized())>.98,"Eixo real da cabeça importada aponta para as pessoas")
	var antigos: Array=[]
	for p: Node3D in cena.equipe: antigos.append(p.global_transform)
	var original:=a.global_transform
	# O animal não depende de uma rotação fixa nem da posição original da dupla.
	for i in range(12):
		var angulo:=TAU*i/12
		a.global_position=Vector3(7,3,-1)
		for j in range(2):
			cena.equipe[j].global_position=a.global_position+Vector3(cos(angulo+j*.12)*4,j*2-1,sin(angulo+j*.12)*4)
		ok(O.preparar(a,cena.equipe) and olhando(),"Orientação horizontal em ângulo "+str(i))
	for i in range(2): cena.equipe[i].global_transform=antigos[i]
	a.global_transform=original
	ok(O.preparar(a,[cena.equipe[0]]),"Orientação para apenas uma pessoa")
	var rotacao:=a.global_rotation
	ok(not O.preparar(a,[]) and a.global_rotation.is_equal_approx(rotacao),"Equipe vazia preserva orientação sem erro")
	ok(not O.encarar(a,a.global_position+Vector3.UP*4),"Posição coincidente não gera look_at inválido")
	cena.revelar(false)
	cena.abrir_visao(true)
	await captura("02_visao_tatica")
	ok(cena.etapa=="tatica" and cena.get_node("Grade").visible and olhando(),"Vista tática preserva orientação")
	var camera: Camera3D=cena.get_node("CameraEncontro")
	var cabem:=true
	for canto in [Vector2(3,-5),Vector2(11,-5),Vector2(3,3),Vector2(11,3)]:
		var posicao: Vector3=cena.ponto(canto)
		var pixel:=camera.unproject_position(posicao)
		if camera.is_position_behind(posicao) or not root.get_visible_rect().grow(-12).has_point(pixel): cabem=false
	ok(cabem,"Tabuleiro inteiro enquadrado na visão tática")
	ok(cena.get_node("Grade").get_child_count()==152,"Grade de 8 × 8 casas com destaques visuais")
	var final: Transform3D=cena.get_node("CameraEncontro").global_transform
	cena.revelar(true)
	# Avança o Tween com tempo controlado; não depende de duração real do teste.
	cena.transicao.custom_step(2)
	ok(cena.etapa=="revelacao" and olhando(),"Animal encara a equipe durante a introdução")
	cena.abrir_visao()
	cena.transicao.custom_step(3)
	ok(cena.etapa=="tatica" and cena.get_node("CameraEncontro").global_transform.is_equal_approx(final),"Pular e assistir chegam ao mesmo enquadramento")
	# Exercita a sequência automática completa, inclusive a troca de Tween.
	cena.revelar(true)
	cena.transicao.pause()
	cena.transicao.custom_step(4.1)
	ok(cena.etapa=="abrindo","Introdução automática inicia a abertura")
	cena.transicao.pause()
	cena.transicao.custom_step(1.4)
	ok(not cena.get_node("CameraEncontro").global_transform.is_equal_approx(final),"Abertura possui enquadramento intermediário")
	await captura("04_transicao")
	cena.transicao.custom_step(3)
	ok(cena.etapa=="tatica" and olhando(),"Sequência automática termina com focinho voltado à equipe")
	cena.luz.aplicar(18)
	await captura("03_entardecer")
	cena.queue_free()
	await process_frame
	print("ENCONTRO_CAPIVARA: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
