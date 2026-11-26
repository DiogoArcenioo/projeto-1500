extends "res://scripts/inspecao/inspecao_encontro_capivara.gd"
## Demonstrações visuais controladas; não usa rolagens ou altera partidas.
const FONTE_CORPO=preload("res://assets/ui/fonts/alegreya_sans/AlegreyaSans-Medium.ttf")
var atores: Dictionary={}
var em_movimento:=false
var movimento: Tween
var fase_atual:="pronto"
var historico: Label
var titulo_ator: Label
var ui: Control
var botoes: Dictionary={}
var efeito: Label3D
var flecha: Node3D
var tempo_animacao:=1.0
var ultimo_evento: Dictionary={}
var arco_suporte: Node3D
var corda: MeshInstance3D
var material_corda: StandardMaterial3D
var painel_interface: PanelContainer
var fichas: HBoxContainer
func _ready() -> void:
	for nome in ["Cacador","Cacadora","Capivara"]:
		var caminho: String={"Cacador":"res://assets/models/habitantes/batalha/homem_01.glb","Cacadora":"res://assets/models/habitantes/batalha/mulher_01.glb","Capivara":"res://assets/models/animais/batalha/capivara.glb"}[nome]
		var velho:=get_node(nome)
		remove_child(velho)
		velho.queue_free()
		var novo: Node3D=load(caminho).instantiate()
		novo.name=nome
		add_child(novo)
		atores[nome]=novo
	automatico=false
	super._ready()
	legenda.hide()
	ajuda.hide()
	interface_batalha()
	repor()
func armar(pessoa: Node3D,tipo: String) -> void:
	super.armar(pessoa,tipo)
	var suportes: Array[Node]=pessoa.find_children("Lanca" if tipo=="lanca" else "Arco","Node3D",false,false)
	if suportes.is_empty(): return
	var suporte: Node3D=suportes[0]
	var skeletons: Array[Node]=pessoa.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty(): return
	var sk: Skeleton3D=skeletons[0]
	var nome:="mao_D" if tipo=="lanca" else "mao_E"
	var i:=sk.find_bone(nome)
	if i<0: return
	var fixacao:=BoneAttachment3D.new()
	fixacao.bone_name=nome
	sk.add_child(fixacao)
	var origem:=sk.get_bone_global_rest(i)
	var base:=Basis.IDENTITY if tipo=="lanca" else Basis(Vector3.UP,-PI*.5)
	var transformacao:=Transform3D(base,origem.origin+origem.basis.y*.035)
	suporte.reparent(fixacao,false)
	suporte.transform=origem.affine_inverse()*transformacao
	if tipo=="arco":
		arco_suporte=suporte
		for m: MeshInstance3D in suporte.find_children("*","MeshInstance3D",false,false):
			if str(m.get_active_material(0).resource_name).contains("Fibras"):
				m.mesh=Recortes.recortar(m,AABB(Vector3(-.265,-.9,-.025),Vector3(.05,1.8,.05)),false)
		corda=MeshInstance3D.new();add_child(corda)
		material_corda=StandardMaterial3D.new()
		material_corda.albedo_color=Color("d7b76c")
		material_corda.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
func mao_global(pessoa: String,lado: String) -> Vector3:
	var sk: Skeleton3D=atores[pessoa].find_children("*","Skeleton3D",true,false)[0]
	var pose:=sk.get_bone_global_pose(sk.find_bone("mao_"+lado))
	return sk.to_global(pose.origin+pose.basis.y*.035)
func _process(_delta: float) -> void:
	if not is_instance_valid(corda) or not is_instance_valid(arco_suporte): return
	var topo:=arco_suporte.to_global(Vector3(-.24,.825,0))
	var base:=arco_suporte.to_global(Vector3(-.24,-.825,0))
	var meio:=arco_suporte.to_global(Vector3(-.24,0,0))
	var p:=player("Cacadora")
	if fase_atual.begins_with("arco") and p and p.current_animation_position>.22 and p.current_animation_position<.77:
		meio=mao_global("Cacadora","D")
	var malha:=ImmediateMesh.new()
	malha.surface_begin(Mesh.PRIMITIVE_LINES,material_corda)
	for v in [topo,meio,meio,base]: malha.surface_add_vertex(v)
	malha.surface_end()
	corda.mesh=malha
func player(nome: String) -> AnimationPlayer:
	var lista: Array[Node]=atores[nome].find_children("*","AnimationPlayer",true,false)
	return lista[0] if not lista.is_empty() else null
func tocar(nome: String,acao: String,loop:=false) -> void:
	var p:=player(nome)
	if not p: return
	for a in p.get_animation_list():
		if a==acao:
			p.get_animation(a).loop_mode=Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
			p.speed_scale=1.0/tempo_animacao
			p.play(a,.08)
			return
func estilo(cor: String) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(cor)
	s.border_color=Color("a47c45")
	s.set_border_width_all(1)
	s.set_corner_radius_all(7)
	s.content_margin_left=12;s.content_margin_right=12
	s.content_margin_top=7;s.content_margin_bottom=7
	return s
func texto(p: Node,t: String,tamanho:=18) -> Label:
	var l:=Label.new();l.text=t
	l.add_theme_font_override("font",FONTE if tamanho>=20 else FONTE_CORPO)
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",Color("35271b"))
	p.add_child(l)
	return l
func botao(p: Node,t: String,acao: Callable) -> Button:
	var b:=Button.new();b.text=t
	b.add_theme_font_size_override("font_size",16)
	b.pressed.connect(acao)
	p.add_child(b)
	return b
func interface_batalha() -> void:
	var camada:=CanvasLayer.new();add_child(camada)
	ui=Control.new();ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;camada.add_child(ui)
	var casca:=StyleBoxTexture.new()
	casca.texture=load("res://assets/ui/expedicoes/casca_interna_painel.png")
	casca.content_margin_left=66;casca.content_margin_right=66
	casca.content_margin_top=23;casca.content_margin_bottom=24
	var painel:=PanelContainer.new();painel.name="Acoes";painel.add_theme_stylebox_override("panel",casca)
	ui.add_child(painel)
	var col:=VBoxContainer.new();painel.add_child(col)
	var topo:=HBoxContainer.new();col.add_child(topo)
	titulo_ator=texto(topo,"PRÉVIA · movimentos de batalha",21)
	titulo_ator.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	botao(topo,"Visão tática",func():camera_plano("tatica"))
	botao(topo,"Perto",func():camera_plano("perto"))
	botao(topo,"Interface",mostrar_interface)
	var acoes:=HBoxContainer.new();col.add_child(acoes)
	for item in [["lanca_acerto","1 · Lança acerta"],["lanca_erro","2 · Lança erra"],["arco_acerto","3 · Arco acerta"],["arco_erro","4 · Arco erra"],["animal_acerto","5 · Animal acerta"],["animal_erro","6 · Animal erra"]]:
		var chave: String=item[0]
		botoes[chave]=botao(acoes,item[1],func():demonstrar(chave))
	var rodape:=HBoxContainer.new();col.add_child(rodape)
	historico=texto(rodape,"Demonstração visual · dano ilustrativo · sem envio ou salvamento",16)
	historico.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	botao(rodape,"Câmera lenta",func():tempo_animacao=2.0 if tempo_animacao==1.0 else 1.0)
	botao(rodape,"Repor",repor)
	criar_interface_tatica(casca)
	get_viewport().size_changed.connect(ajustar_ui)
	ajustar_ui()
func ajustar_ui() -> void:
	var tam:=get_viewport().get_visible_rect().size
	var escala:=minf(1.0,tam.x/1280.0)
	ui.scale=Vector2.ONE*escala
	ui.size=tam/escala
	var painel: Control=ui.get_node("Acoes")
	painel.size=Vector2(ui.size.x-24,160)
	painel.position=Vector2(12,ui.size.y-painel.size.y-8)
	if painel_interface:
		painel_interface.size=painel.size
		painel_interface.position=painel.position
func criar_interface_tatica(casca: StyleBoxTexture) -> void:
	painel_interface=PanelContainer.new();painel_interface.add_theme_stylebox_override("panel",casca)
	ui.add_child(painel_interface)
	var col:=VBoxContainer.new();painel_interface.add_child(col)
	var topo:=HBoxContainer.new();col.add_child(topo)
	var titulo:=texto(topo,"PRÉVIA · Lanceiro · 2 pontos de ação",21)
	titulo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	botao(topo,"Ver animações",func():
		painel_interface.hide();fichas.hide();ui.get_node("Acoes").show();repor())
	var linha:=HBoxContainer.new();col.add_child(linha)
	var info:=texto(col,"Escolha uma ação e depois uma casa ou alvo · valores ilustrativos",16)
	for acao in ["Mover","Atacar","Mirar","Defender","Proteger","Fugir","Encerrar turno"]:
		botao(linha,acao,func():info.text="Prévia de "+acao.to_lower()+" · integração às regras após aprovação visual")
	fichas=HBoxContainer.new();fichas.position=Vector2(24,16);fichas.add_theme_constant_override("separation",14);ui.add_child(fichas)
	for dado in [["Lanceiro","40 / 40 HP · 2 PA","homem_01"],["Arqueira","38 / 38 HP · 2 PA","mulher_01"],["Capivara","16 / 16 HP · 2 PA",""]]:
		var quadro:=PanelContainer.new()
		var fundo:=casca.duplicate() as StyleBoxTexture
		fundo.content_margin_left=24;fundo.content_margin_right=24;fundo.content_margin_top=20;fundo.content_margin_bottom=20
		quadro.add_theme_stylebox_override("panel",fundo)
		quadro.custom_minimum_size=Vector2(260,110)
		fichas.add_child(quadro)
		var h:=HBoxContainer.new();quadro.add_child(h)
		if dado[2]!="":
			var img:=TextureRect.new();img.texture=load("res://assets/ui/retratos/"+dado[2]+".png")
			img.custom_minimum_size=Vector2(40,55);img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			h.add_child(img)
		var v:=VBoxContainer.new();v.size_flags_horizontal=Control.SIZE_EXPAND_FILL;h.add_child(v)
		texto(v,dado[0],20);texto(v,dado[1],16)
		var hp:=ProgressBar.new();hp.value=100;hp.show_percentage=false;hp.custom_minimum_size.y=10
		hp.add_theme_stylebox_override("background",estilo("b49062"));hp.add_theme_stylebox_override("fill",estilo("355447"));v.add_child(hp)
	painel_interface.hide();fichas.hide()
func mostrar_interface() -> void:
	repor()
	ui.get_node("Acoes").hide();painel_interface.show();fichas.show()
	camera_plano("tatica")
func camera_plano(nome: String) -> void:
	$CameraEncontro.v_offset=0
	if nome=="tatica":
		$CameraEncontro.global_transform=camera_tatica()
		$CameraEncontro.v_offset=-1.8
	else:
		var alvo: Vector3=$Capivara.global_position.lerp($Cacadora.global_position if nome=="arco" else $Cacador.global_position,.45)+Vector3(0,.78,0)
		$CameraEncontro.global_transform=pose_camera(alvo+Vector3(-3.2,2.2 if nome=="arco" else 1.6,5.5 if nome=="arco" else 4.6),alvo)
		$CameraEncontro.v_offset=-.6
func repor() -> void:
	if movimento and movimento.is_valid(): movimento.kill()
	em_movimento=false
	for p in atores.values():
		var ap: AnimationPlayer=p.find_children("*","AnimationPlayer",true,false)[0]
		ap.stop()
		for sk: Skeleton3D in p.find_children("*","Skeleton3D",true,false): sk.reset_bone_poses()
	$Cacador.position=Solo.no_solo(Vector2(6,-.5))
	$Cacadora.position=Solo.no_solo(Vector2(8.0,1.5))
	$Capivara.position=Solo.no_solo(Vector2(6,-1.65))
	Orientacao.preparar($Capivara,equipe)
	tocar("Cacador","pronto",true);tocar("Cacadora","pronto",true);tocar("Capivara","parada",true)
	$Grade.show()
	if is_instance_valid(efeito): efeito.queue_free()
	if is_instance_valid(flecha): flecha.queue_free()
	fase_atual="pronto"
	camera_plano("perto")
	for b in botoes.values(): b.disabled=false
func demonstrar(chave: String) -> void:
	if em_movimento: return
	repor()
	em_movimento=true
	fase_atual=chave
	for b in botoes.values(): b.disabled=true
	var arco:=chave.begins_with("arco")
	var animal:=chave.begins_with("animal")
	var acertou:=chave.ends_with("acerto")
	var atacante:="Capivara" if animal else ("Cacadora" if arco else "Cacador")
	var alvo:="Cacador" if animal else "Capivara"
	if arco:
		$Capivara.position=Solo.no_solo(Vector2(7.5,-2.4))
		$Cacador.position=Solo.no_solo(Vector2(5.5,1.5))
		camera_plano("arco")
	Orientacao.encarar(atores[atacante],atores[alvo].global_position)
	Orientacao.encarar(atores[alvo],atores[atacante].global_position)
	var acao: String=("investida" if acertou else "errar_ataque") if animal else (("atacar_arco" if acertou else "errar_arco") if arco else ("atacar_lanca" if acertou else "errar_lanca"))
	tocar(atacante,acao)
	ultimo_evento={"atacante":atacante,"alvo":alvo,"acertou":acertou,"dano":4 if acertou else 0,"acao":acao}
	titulo_ator.text=("Capivara" if animal else ("Arqueira" if arco else "Lanceiro"))+" · "+("acerto" if acertou else "erro")
	historico.text="Movimento de preparação, golpe e recuperação · dano ilustrativo"
	movimento=create_tween()
	movimento.tween_interval((.72 if arco else .53)*tempo_animacao)
	if arco:
		movimento.tween_callback(func():projetil(atacante,alvo,acertou))
		movimento.tween_interval(.2*tempo_animacao)
	movimento.tween_callback(func():
		tocar(alvo,"receber_golpe" if acertou else "esquivar")
		mostrar_efeito(atores[alvo],"−4 HP" if acertou else "ERROU",acertou)
		historico.text="Acerto: alvo reage ao impacto." if acertou else "Erro: alvo esquiva; nenhum dano.")
	movimento.tween_interval(1.35*tempo_animacao)
	movimento.tween_callback(func():
		em_movimento=false
		for b in botoes.values(): b.disabled=false
		tocar(atacante,"parada" if animal else "pronto",true)
		tocar(alvo,"parada" if alvo=="Capivara" else "pronto",true))
func mostrar_efeito(alvo: Node3D,t: String,acertou: bool) -> void:
	if is_instance_valid(efeito): efeito.queue_free()
	efeito=Label3D.new();efeito.text=t;efeito.font=FONTE
	efeito.font_size=70;efeito.pixel_size=.005
	efeito.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	efeito.modulate=Color("ffbc70") if acertou else Color("e8efdb")
	efeito.outline_size=10;efeito.no_depth_test=true
	add_child(efeito)
	efeito.global_position=alvo.global_position+Vector3(0,1.1 if alvo==atores.Capivara else 1.9,0)
	var subida:=create_tween()
	subida.tween_property(efeito,"position:y",efeito.position.y+.25,.7*tempo_animacao)
func projetil(atacante: String,alvo: String,acertou: bool) -> void:
	if is_instance_valid(flecha): flecha.queue_free()
	flecha=Node3D.new();add_child(flecha)
	var haste:=MeshInstance3D.new();var cilindro:=CylinderMesh.new()
	cilindro.top_radius=.006;cilindro.bottom_radius=.006;cilindro.height=.70;cilindro.radial_segments=6
	haste.mesh=cilindro
	var madeira:=StandardMaterial3D.new();madeira.albedo_color=Color("b17b42");haste.material_override=madeira
	flecha.add_child(haste)
	var inicio:=mao_global(atacante,"D")
	var fim: Vector3=atores[alvo].global_position+Vector3(0,.43,0)
	if not acertou: fim+=Vector3(.65,.15,-.25)
	flecha.global_position=inicio
	haste.rotation=Quaternion(Vector3.UP,(fim-inicio).normalized()).get_euler()
	var voo:=create_tween()
	voo.tween_property(flecha,"global_position",fim,.2*tempo_animacao)
	voo.tween_interval(.4)
	voo.tween_callback(func():if is_instance_valid(flecha): flecha.queue_free())
func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	var chaves:={KEY_1:"lanca_acerto",KEY_2:"lanca_erro",KEY_3:"arco_acerto",KEY_4:"arco_erro",KEY_5:"animal_acerto",KEY_6:"animal_erro"}
	if chaves.has(e.physical_keycode): demonstrar(chaves[e.physical_keycode])
	elif e.physical_keycode==KEY_R: repor()
	else: return
	get_viewport().set_input_as_handled()
