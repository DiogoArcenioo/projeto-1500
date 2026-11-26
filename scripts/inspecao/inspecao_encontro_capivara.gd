extends Node3D
## Portão B da apresentação: composição e câmeras, sem simulação da partida.
const Solo=preload("res://scripts/ambientes/aldeia_visual.gd")
const Orientacao=preload("res://scripts/encontros/orientacao_encontro.gd")
const Recortes=preload("res://scripts/encontros/recortes_visuais.gd")
const ORIGEM:=Vector2(3,-5)
const FONTE=preload("res://assets/ui/fonts/alegreya_sc/AlegreyaSC-Bold.ttf")
var luz:=preload("res://scripts/ambientes/iluminacao_diurna.gd").new()
var equipe: Array=[]
var transicao: Tween
var etapa:="revelacao"
var legenda: Label
var ajuda: Label
var noite:=false
var automatico:=true
func _ready() -> void:
	add_child(luz)
	luz.configurar($Clareira1500)
	luz.aplicar(16)
	equipe=[$Cacador,$Cacadora]
	preparar_mata()
	$Cacador.position=Solo.no_solo(Vector2(5.5,1.5))
	$Cacadora.position=Solo.no_solo(Vector2(7.5,1.5))
	$Capivara.position=Solo.no_solo(Vector2(7.5,-3.5))
	for modelo in equipe+[$Capivara]:
		for m: MeshInstance3D in modelo.find_children("*","MeshInstance3D",true,false): m.layers=3
		animar(modelo,"parada")
	armar($Cacador,"lanca")
	armar($Cacadora,"arco")
	criar_grade()
	criar_legendas()
	revelar(automatico)
func animar(modelo: Node3D,trecho: String) -> void:
	for p: AnimationPlayer in modelo.find_children("*","AnimationPlayer",true,false):
		for nome in p.get_animation_list():
			if str(nome).to_lower().contains(trecho):
				p.get_animation(nome).loop_mode=Animation.LOOP_LINEAR
				p.play(nome)
				return
func preparar_mata() -> void:
	$Clareira1500/Fogueira.hide()
	for m: MeshInstance3D in $Clareira1500/Paisagem.find_children("*","MeshInstance3D",true,false):
		if str(m.name) in ["Lenha","Lenha_Miolo","Pedras_Fogueira","Brasas","Solo_Cinzas"]: m.hide()
		if str(m.name) in ["Capim","Folhas_Largas","Samambaias","Bromelias","Flores_Coral","Flores_Ouro"]:
			var recorte:=Recortes.recortar(m,AABB(Vector3(2.6,-3,-5.4),Vector3(8.8,9,8.8)),false)
			m.mesh=recorte
		if str(m.name)=="Solo_TerraViva":
			var material:=m.material_override.duplicate() as ShaderMaterial
			material.set_shader_parameter("centro_clareira",Vector2(7,-1))
			m.material_override=material
	# Complemento da borda com a bromélia já aprovada, sem ocupar as casas.
	for p in [Vector2(2,-5),Vector2(1.7,-1.5),Vector2(2,3.4),Vector2(5,4.3),Vector2(9,4.7),Vector2(4,-6.2),Vector2(8,-6.3),Vector2(11.8,-5.3)]:
		var planta: Node3D=load("res://assets/models/bromelia_clareira.glb").instantiate()
		add_child(planta)
		planta.position=Solo.no_solo(p)
		planta.scale=Vector3.ONE*.65
		planta.rotation.y=p.x*1.7
		$Clareira1500.preparar_folhas(planta)
func armar(pessoa: Node3D,tipo: String) -> void:
	# Extrai os mesmos arcos/lanças já aprovados no centro de caça.
	var centro: Node3D=load("res://assets/models/centro_caca_nivel_1.glb").instantiate()
	var area:=AABB(Vector3(-.015,.105,-.30),Vector3(.33,1.73,.10)) if tipo=="arco" else AABB(Vector3(.87,-.02,-.28),Vector3(.11,1.95,.12))
	var pivot:=Vector3(.27,.965,-.25) if tipo=="arco" else Vector3(.92,.85,-.23)
	var suporte:=Node3D.new()
	suporte.name="Arco" if tipo=="arco" else "Lanca"
	pessoa.add_child(suporte)
	var palma:=Vector3(.34,.84,.035)
	var inversa:=pessoa.global_transform.affine_inverse()
	var extremo:=-INF
	for m: MeshInstance3D in pessoa.find_children("*","MeshInstance3D",true,false):
		for s in range(m.mesh.get_surface_count()):
			for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p: Vector3=inversa*m.global_transform*v
				if p.y>.70 and p.y<1.0 and absf(p.z)<.15 and p.x>extremo:
					extremo=p.x
					palma=p+Vector3(-.018,.045,0)
	suporte.position=palma
	suporte.rotation.z=-.12 if tipo=="arco" else -.08
	for m: MeshInstance3D in centro.find_children("*","MeshInstance3D",true,false):
		var malha:=Recortes.recortar(m,area,true,pivot)
		if malha.get_surface_count()==0: continue
		var objeto:=MeshInstance3D.new()
		objeto.mesh=malha
		objeto.layers=3
		suporte.add_child(objeto)
	centro.free()
func ponto(p: Vector2) -> Vector3:
	return Solo.no_solo(p)+Vector3(0,.024,0)
func linha(a: Vector3,b: Vector3,largura: float,material: Material) -> void:
	var m:=MeshInstance3D.new()
	var malha:=ImmediateMesh.new()
	var lateral: Vector3=(b-a).cross(Vector3.UP).normalized()*largura*.5
	malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES,material)
	for v in [a-lateral,a+lateral,b+lateral,a-lateral,b+lateral,b-lateral]: malha.surface_add_vertex(v)
	malha.surface_end()
	m.mesh=malha
	$Grade.add_child(m)
func criar_grade() -> void:
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color("c7b16c")
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	for i in range(9):
		for j in range(8):
			linha(ponto(ORIGEM+Vector2(i,j)),ponto(ORIGEM+Vector2(i,j+1)),.024,mat)
			linha(ponto(ORIGEM+Vector2(j,i)),ponto(ORIGEM+Vector2(j+1,i)),.024,mat)
	var destaque:=mat.duplicate() as StandardMaterial3D
	destaque.albedo_color=Color("f8d58c")
	var base:=ORIGEM+Vector2(2,6)
	for i in range(4):
		var cantos: Array[Vector2]=[base,base+Vector2.RIGHT,base+Vector2.ONE,base+Vector2.DOWN]
		linha(ponto(cantos[i])+Vector3(0,.01,0),ponto(cantos[(i+1)%4])+Vector3(0,.01,0),.035,destaque)
	var verde:=StandardMaterial3D.new()
	verde.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	verde.cull_mode=BaseMaterial3D.CULL_DISABLED
	verde.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	verde.albedo_color=Color(.34,.58,.25,.22)
	for celula in [Vector2(2,5),Vector2(3,5),Vector2(3,6),Vector2(4,5)]:
		var inicio: Vector2=ORIGEM+celula+Vector2.ONE*.035
		var m:=MeshInstance3D.new()
		var q:=ImmediateMesh.new()
		q.surface_begin(Mesh.PRIMITIVE_TRIANGLES,verde)
		for d in [Vector2.ZERO,Vector2.RIGHT*.93,Vector2.ONE*.93,Vector2.ZERO,Vector2.ONE*.93,Vector2.DOWN*.93]:
			q.surface_add_vertex(ponto(inicio+d)+Vector3(0,.005,0))
		q.surface_end()
		m.mesh=q
		$Grade.add_child(m)
func criar_legendas() -> void:
	var hud:=CanvasLayer.new()
	add_child(hud)
	var raiz:=Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hud.add_child(raiz)
	legenda=Label.new()
	legenda.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# Abaixo das fichas: com dois moradores e o animal elas ocupam o topo.
	legenda.offset_top=134
	legenda.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	legenda.add_theme_font_override("font",FONTE)
	legenda.add_theme_font_size_override("font_size",27)
	legenda.add_theme_color_override("font_color",Color("fff0ce"))
	legenda.add_theme_color_override("font_shadow_color",Color("18392a"))
	legenda.add_theme_constant_override("shadow_offset_x",2)
	legenda.add_theme_constant_override("shadow_offset_y",2)
	raiz.add_child(legenda)
	ajuda=Label.new()
	ajuda.text="INSPEÇÃO VISUAL · 1 revelar · 2 visão tática · Espaço pular · R repetir · N tarde/noite"
	ajuda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ajuda.offset_top=-32
	ajuda.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ajuda.add_theme_font_size_override("font_size",14)
	ajuda.add_theme_color_override("font_shadow_color",Color.BLACK)
	ajuda.add_theme_constant_override("shadow_offset_x",1)
	ajuda.add_theme_constant_override("shadow_offset_y",1)
	raiz.add_child(ajuda)
func pose_camera(posicao: Vector3,alvo: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(alvo-posicao,Vector3.UP),posicao)
func camera_revelacao() -> Transform3D:
	var centro: Vector3=Orientacao.centro_equipe(equipe)
	var frente: Vector3=($Capivara.global_position-centro).normalized()
	frente.y=0
	frente=frente.normalized()
	var pos:=centro-frente*3.7+Vector3(0,1.8,0)
	return pose_camera(pos,$Capivara.global_position+Vector3(0,.60,0))
func camera_tatica() -> Transform3D:
	var alvo:=ponto(Vector2(7,-1))+Vector3(0,.20,0)
	return pose_camera(alvo+Vector3(5.8,10.5,11.7),alvo)
func cancelar_transicao() -> void:
	if transicao and transicao.is_valid(): transicao.kill()
func revelar(sequencia:=true) -> void:
	cancelar_transicao()
	Orientacao.preparar($Capivara,equipe)
	$Grade.hide()
	$CameraEncontro.make_current()
	$CameraEncontro.global_transform=camera_revelacao()
	etapa="revelacao"
	legenda.text="Adentrando a mata..."
	if sequencia:
		transicao=create_tween()
		transicao.tween_interval(1.5)
		transicao.tween_callback(func(): legenda.text="Capivara")
		transicao.tween_interval(2.5)
		transicao.tween_callback(abrir_visao)
	else: legenda.text="Capivara"
func abrir_visao(imediata:=false) -> void:
	cancelar_transicao()
	$Grade.show()
	etapa="abrindo"
	legenda.text=""
	if imediata:
		$CameraEncontro.global_transform=camera_tatica()
		etapa="tatica"
		return
	transicao=create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transicao.tween_property($CameraEncontro,"global_transform",camera_tatica(),2.8)
	transicao.tween_callback(func(): etapa="tatica")
func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	match e.physical_keycode:
		KEY_1: revelar(false)
		KEY_2,KEY_SPACE: abrir_visao()
		KEY_R: revelar(true)
		KEY_N:
			noite=not noite
			luz.aplicar(23 if noite else 16)
		_: return
	get_viewport().set_input_as_handled()
