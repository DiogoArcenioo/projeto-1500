extends Node3D
## Etapa 12 — pescaria jogada. Apresentação e entrada; as regras (sorteio, mordida,
## física da briga, carga, XP e registro) ficam em pesca.gd e expedicoes.gd.
##
## Controles: segurar o botão esquerdo (ou Espaço) arma o arremesso e, na briga, puxa
## a linha; soltar cede. O mouse (ou A/D) aponta a vara para os lados. Na espera,
## clicar fisga. O tamanho do peixe aparece antes de vê-lo: na sombra que ronda a isca,
## na força dos toques na boia, na curva da vara, no som da linha e no tremor da câmera.
signal concluido
const Exp=preload("res://scripts/partida/expedicoes.gd")
const Pesca=preload("res://scripts/partida/pesca.gd")
const Solo=preload("res://scripts/ambientes/aldeia_visual.gd")
const Terreno=preload("res://scripts/partida/terreno_construcao.gd")
const FONTE_TITULO=preload("res://assets/ui/fonts/alegreya_sc/AlegreyaSC-Bold.ttf")
const FONTE=preload("res://assets/ui/fonts/alegreya_sans/AlegreyaSans-Medium.ttf")
const PEIXES:="res://assets/models/peixes/peixes.glb"
const AGUA:=-0.5
const N_LINHA:=30
const N_VARA:=14
const VARA_COMP:=1.7
const AMOSTRAS:=22050.0

var estado
var expedicao_id: String
## Inspeção/capturas: um robô joga os lances (mesmas regras do jogador).
var automatico:=false
## Inspeção: força espécie e peso do próximo peixe ({"especie":..,"peso":..}).
var peixe_forcado: Dictionary={}
## Ponto da margem (z do mundo) onde a equipe pesca.
var z_local:=-5.0
## Distância máxima útil (m) até perto da outra margem.
var limite_rio:=7.0
var viagem: Dictionary
var luz:=preload("res://scripts/ambientes/iluminacao_diurna.gd").new()
var rng:=RandomNumberGenerator.new()
var fase:=""
var tempo_fase:=0.0
var tempo:=0.0
var tempo_agua:=0.0
var exibindo_peixe:=false
# Geometria do local: F aponta para o rio, L para a direita da câmera.
var F:=Vector3(1,0,0)
var L:=Vector3(0,0,1)
var origem: Vector3
var pe_pescador: Vector3
var pescador: Node3D
var esqueleto: Skeleton3D
var arvore: AnimationTree
var cabo: MeshInstance3D
var eixo_cabo:=Vector3.UP
var ponta_cabo:=.55
var vara_malha:=ImmediateMesh.new()
var vara_material:=StandardMaterial3D.new()
var vara_ponta:=Vector3.ZERO
var curva_vara:=0.0
var vel_curva:=0.0
var linha_malha:=ImmediateMesh.new()
var linha_material:=StandardMaterial3D.new()
var nos:=PackedVector3Array()
var nos_ant:=PackedVector3Array()
var linha_comp:=.6
var linha_presa:=false
var linha_solta:=false
var boia: Node3D
var boia_pos:=Vector3()
var boia_vel:=Vector3()
var boia_prof:=0.0
var boia_deriva:=Vector3()
var peixe_no: Node3D
var peixe_mat: ShaderMaterial
var peixe_fase:=0.0
var peixe_pos:=Vector3()
var peixe_dir:=Vector3(1,0,0)
var peixe_altura:=0.0
var sombra: MeshInstance3D
var sombra_mat: StandardMaterial3D
var sombra_alfa:=0.0
var ondas: Array=[]
var respingos: Array=[]
var cam: Camera3D
var cam_alvo:=Vector3()
var cam_pos:=Vector3()
var tremor:=0.0
# Lance atual.
var peixe: Dictionary={}
var mordida: Dictionary={}
var briga: Dictionary={}
var tentativa:=0
var evento_idx:=0
var t_espera:=0.0
var fim_janela:=-1.0
var carga:=0.0
var distancia_lance:=6.0
var lado:=0.0
var puxando:=false
var botao:=false
var mistura:=0.0
var ja_no_ar:=false
var recorde:=false
var resultado_lance:=""
var recorde_mostrado:=false
var no_salto:=false
var arrasto:=Vector3()
var aproximar:=Vector3()
var ultimo_respingo:=0.0
# Interface.
var ui: Control
var cartao: Label
var dica: Label
var aviso: Label
var aviso_tempo:=0.0
var barra_fundo: Panel
var barra: ColorRect
var marca: ColorRect
var barra_rotulo: Label
var painel_peixe: PanelContainer
var painel_texto: RichTextLabel
var painel_botao: Button
var encerrar: Button
# Som sintetizado: zumbido da linha, respingos, toques na boia e estalo.
var reprodutor: AudioStreamGeneratorPlayback
var ruido:=1
var bp_baixo:=0.0
var bp_banda:=0.0
var lp:=0.0
var zumbido:=0.0
var respingo_amp:=0.0
var plique_amp:=0.0
var plique_fase:=0.0
var estalo_amp:=0.0

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	viagem=Exp.buscar(estado,expedicao_id)
	Exp.preparar_pesca(estado,viagem)
	add_child(luz)
	luz.configurar($Clareira1500)
	luz.aplicar(estado.relogio.obter_hora())
	$Clareira1500/Fogueira.hide()
	montar_local()
	montar_pescador()
	montar_vara_e_linha()
	montar_boia()
	montar_peixe()
	montar_efeitos()
	montar_audio()
	montar_interface()
	cam=$Camera
	cam.make_current()
	cam_alvo=origem+F*4.0
	cam_pos=pe_pescador-F*2.6+L*1.0+Vector3(0,2.0,0)
	cam.global_position=cam_pos+Vector3(-1.5,1.2,1.5)
	cam.look_at(cam_alvo)
	for i in range(N_LINHA):
		nos.append(vara_ponta+Vector3(0,-.02*i,0))
		nos_ant.append(nos[i])
	mudar_fase("inicio")

# ------------------------------------------------------------------ montagem

func montar_local() -> void:
	var margem:=Terreno.margem_rio(z_local)
	pe_pescador=Solo.no_solo(Vector2(margem-.85,z_local))
	origem=Vector3(margem+.95,AGUA,z_local)
	limite_rio=Terreno.centro_rio(z_local)+Terreno.meia_largura_rio(z_local)-1.1-origem.x

func modelo_morador(pasta: String,id: String) -> Node3D:
	var h: Dictionary=estado.pessoa(id)
	return load("res://assets/models/habitantes/%s/%s.glb"%[pasta,h.get("visual","homem_01")]).instantiate()

func montar_pescador() -> void:
	pescador=modelo_morador("pesca",viagem.equipe[0])
	add_child(pescador)
	pescador.position=pe_pescador
	pescador.rotation.y=PI/2
	var player: AnimationPlayer=pescador.find_children("*","AnimationPlayer",true,false)[0]
	for nome in ["pesca_espera","pesca_puxar","pesca_ceder"]:
		player.get_animation(nome).loop_mode=Animation.LOOP_LINEAR
	arvore=AnimationTree.new()
	player.get_parent().add_child(arvore)
	arvore.anim_player=arvore.get_path_to(player)
	arvore.root_node=arvore.get_path_to(player.get_node(player.root_node))
	arvore.tree_root=criar_arvore()
	arvore.active=true
	esqueleto=pescador.find_children("*","Skeleton3D",true,false)[0]
	cabo=pescador.find_children("Prop_Vara*","MeshInstance3D",true,false)[0]
	var caixa: AABB=cabo.mesh.get_aabb()
	var eixo:=0
	for i in range(3):
		if caixa.size[i]>caixa.size[eixo]: eixo=i
	eixo_cabo=Vector3.ZERO
	var fim: float=caixa.end[eixo]
	var ini: float=caixa.position[eixo]
	eixo_cabo[eixo]=1.0 if absf(fim)>=absf(ini) else -1.0
	ponta_cabo=maxf(absf(fim),absf(ini))
	if viagem.equipe.size()>1:
		var ajudante:=modelo_morador("aldeia",viagem.equipe[1])
		add_child(ajudante)
		ajudante.position=Solo.no_solo(Vector2(pe_pescador.x-2.1,z_local-1.7))
		ajudante.rotation.y=PI*.36
		for p: Node3D in ajudante.find_children("Prop_*","Node3D",true,false): p.hide()
		var pa: AnimationPlayer=ajudante.find_children("*","AnimationPlayer",true,false)[0]
		for nome in pa.get_animation_list():
			if str(nome).contains("olhar"):
				pa.get_animation(nome).loop_mode=Animation.LOOP_LINEAR
				pa.play(nome)

func criar_arvore() -> AnimationNodeBlendTree:
	var bt:=AnimationNodeBlendTree.new()
	for n in ["pesca_espera","pesca_puxar","pesca_ceder","pesca_lancar","pesca_fisgar","pesca_erguer"]:
		var a:=AnimationNodeAnimation.new()
		a.animation=StringName(n)
		bt.add_node(n,a)
	bt.add_node("briga",AnimationNodeBlend2.new())
	bt.connect_node("briga",0,"pesca_ceder")
	bt.connect_node("briga",1,"pesca_puxar")
	var base:=AnimationNodeTransition.new()
	base.xfade_time=.3
	base.input_count=3
	for i in range(3): base.set_input_name(i,["espera","briga","erguer"][i])
	bt.add_node("base",base)
	bt.connect_node("base",0,"pesca_espera")
	bt.connect_node("base",1,"briga")
	bt.connect_node("base",2,"pesca_erguer")
	var gesto:=AnimationNodeTransition.new()
	gesto.input_count=2
	gesto.set_input_name(0,"lancar")
	gesto.set_input_name(1,"fisgar")
	bt.add_node("gesto",gesto)
	bt.connect_node("gesto",0,"pesca_lancar")
	bt.connect_node("gesto",1,"pesca_fisgar")
	var acao:=AnimationNodeOneShot.new()
	acao.fadein_time=.06
	acao.fadeout_time=.22
	bt.add_node("acao",acao)
	bt.connect_node("acao",0,"base")
	bt.connect_node("acao",1,"gesto")
	bt.connect_node("output",0,"acao")
	return bt

func pose(nome: String) -> void:
	arvore.set("parameters/base/transition_request",nome)

func gesto(nome: String) -> void:
	arvore.set("parameters/gesto/transition_request",nome)
	arvore.set("parameters/acao/request",AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func montar_vara_e_linha() -> void:
	var vara:=MeshInstance3D.new()
	vara.mesh=vara_malha
	vara_material.albedo_color=Color("a88a52")
	vara_material.roughness=.55
	vara.material_override=vara_material
	vara.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(vara)
	var linha:=MeshInstance3D.new()
	linha.mesh=linha_malha
	linha_material.albedo_color=Color("e8dfc4")
	linha_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	linha_material.cull_mode=BaseMaterial3D.CULL_DISABLED
	linha.material_override=linha_material
	linha.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(linha)

func montar_boia() -> void:
	# Boia de madeira leve com a ponta tingida de urucum.
	boia=Node3D.new()
	add_child(boia)
	for parte in [[.0,.07,"d9c79a"],[.07,.05,"b5432a"]]:
		var m:=MeshInstance3D.new()
		var c:=CapsuleMesh.new()
		c.radius=.022
		c.height=parte[1]+.044
		m.mesh=c
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color(parte[2])
		mat.roughness=.7
		m.material_override=mat
		m.position.y=parte[0]
		boia.add_child(m)

func montar_peixe() -> void:
	sombra=MeshInstance3D.new()
	var plano:=PlaneMesh.new()
	plano.size=Vector2(.34,1.0)
	sombra.mesh=plano
	sombra_mat=StandardMaterial3D.new()
	sombra_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	sombra_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	sombra_mat.albedo_texture=textura_radial([Color(0,0,0,1),Color(0,0,0,.75),Color(0,0,0,0)],[0,.45,1])
	sombra_mat.albedo_color=Color(.04,.07,.06,0)
	sombra_mat.render_priority=1
	sombra.material_override=sombra_mat
	sombra.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sombra)
	peixe_mat=ShaderMaterial.new()
	peixe_mat.shader=load("res://assets/shaders/peixe_nado.gdshader")

func trocar_peixe(especie: String,comprimento: float) -> void:
	if is_instance_valid(peixe_no): peixe_no.queue_free()
	var todos: Node3D=load(PEIXES).instantiate()
	var malha: MeshInstance3D
	for m: MeshInstance3D in todos.find_children("*","MeshInstance3D",true,false):
		if str(m.name).begins_with(especie): malha=m
	peixe_no=Node3D.new()
	add_child(peixe_no)
	if malha:
		var copia:=MeshInstance3D.new()
		copia.mesh=malha.mesh
		copia.material_override=peixe_mat
		peixe_no.add_child(copia)
	todos.free()
	peixe_no.scale=Vector3.ONE*comprimento
	peixe_no.hide()
	(sombra.mesh as PlaneMesh).size=Vector2(.3,1.05)*comprimento

func textura_radial(cores: Array,pos: Array) -> GradientTexture2D:
	var g:=Gradient.new()
	g.colors=PackedColorArray(cores)
	g.offsets=PackedFloat32Array(pos)
	var t:=GradientTexture2D.new()
	t.gradient=g
	t.fill=GradientTexture2D.FILL_RADIAL
	t.fill_from=Vector2(.5,.5)
	t.fill_to=Vector2(1,.5)
	t.width=128
	t.height=128
	return t

func montar_efeitos() -> void:
	var anel:=textura_radial([Color(1,1,1,0),Color(1,1,1,0),Color(1,1,1,.9),Color(1,1,1,0)],[0,.72,.86,1])
	for i in range(28):
		var m:=MeshInstance3D.new()
		var p:=PlaneMesh.new()
		p.size=Vector2.ONE
		m.mesh=p
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture=anel
		mat.albedo_color=Color(.86,.93,.9,0)
		mat.render_priority=2
		m.material_override=mat
		m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.hide()
		add_child(m)
		ondas.append({"no":m,"mat":mat,"idade":9.0,"vida":1.0,"tam":1.0})
	for i in range(8):
		var p:=CPUParticles3D.new()
		p.emitting=false
		p.one_shot=true
		p.explosiveness=.92
		p.amount=28
		p.lifetime=.8
		p.direction=Vector3.UP
		p.spread=38
		p.gravity=Vector3(0,-9.8,0)
		p.initial_velocity_min=1.0
		p.initial_velocity_max=2.4
		p.scale_amount_min=.5
		p.scale_amount_max=1.2
		var gota:=SphereMesh.new()
		gota.radius=.014
		gota.height=.028
		gota.radial_segments=6
		gota.rings=3
		p.mesh=gota
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color(.85,.93,.95,.85)
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness=.05
		p.material_override=mat
		var curva:=Curve.new()
		curva.add_point(Vector2(0,1))
		curva.add_point(Vector2(1,.2))
		p.scale_amount_curve=curva
		add_child(p)
		respingos.append(p)

func onda(pos: Vector3,tamanho: float,vida:=1.1) -> void:
	var livre: Dictionary=ondas[0]
	for o: Dictionary in ondas:
		if o.idade>=o.vida:
			livre=o
			break
	livre.idade=0.0
	livre.vida=vida
	livre.tam=tamanho
	livre.no.global_position=Vector3(pos.x,altura_agua(pos)+.03,pos.z)
	livre.no.show()

func respingo(pos: Vector3,forca: float) -> void:
	var p: CPUParticles3D=respingos[0]
	for r: CPUParticles3D in respingos:
		if not r.emitting:
			p=r
			break
	p.global_position=Vector3(pos.x,altura_agua(pos)+.02,pos.z)
	p.amount=int(clampf(10+forca*40,10,60))
	p.initial_velocity_min=.6+forca*1.2
	p.initial_velocity_max=1.2+forca*2.6
	p.scale_amount_max=.8+forca*1.6
	p.restart()
	p.emitting=true
	respingo_amp=maxf(respingo_amp,.25+forca*.6)
	onda(pos,.35+forca*1.2,1.2+forca*.6)

func montar_audio() -> void:
	var g:=AudioStreamGenerator.new()
	g.mix_rate=AMOSTRAS
	g.buffer_length=.12
	var a:=AudioStreamPlayer.new()
	a.stream=g
	a.volume_db=-6
	add_child(a)
	a.play()
	reprodutor=a.get_stream_playback()

# ------------------------------------------------------------------ interface

func estilo(fundo: String,borda: String,raio:=10) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(fundo)
	s.border_color=Color(borda)
	s.set_border_width_all(2)
	s.set_corner_radius_all(raio)
	s.content_margin_left=14
	s.content_margin_right=14
	s.content_margin_top=8
	s.content_margin_bottom=8
	return s

func ancorar(c: Control,ancora: Vector2,r: Rect2) -> void:
	c.anchor_left=ancora.x
	c.anchor_right=ancora.x
	c.anchor_top=ancora.y
	c.anchor_bottom=ancora.y
	c.offset_left=r.position.x
	c.offset_top=r.position.y
	c.offset_right=r.position.x+r.size.x
	c.offset_bottom=r.position.y+r.size.y

func rotulo(pai: Node,texto: String,tamanho: int,cor:="3a2614",fonte: Font=FONTE) -> Label:
	var l:=Label.new()
	l.text=texto
	l.add_theme_font_override("font",fonte)
	l.add_theme_font_size_override("font_size",tamanho)
	l.add_theme_color_override("font_color",Color(cor))
	pai.add_child(l)
	return l

func montar_interface() -> void:
	var camada:=CanvasLayer.new()
	camada.layer=10
	add_child(camada)
	ui=Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	camada.add_child(ui)
	var topo:=PanelContainer.new()
	topo.add_theme_stylebox_override("panel",estilo("e9d3a6ee","8a6a3c"))
	topo.position=Vector2(18,14)
	ui.add_child(topo)
	cartao=rotulo(topo,"",19)
	encerrar=Button.new()
	encerrar.text="Encerrar pescaria"
	encerrar.add_theme_font_override("font",FONTE_TITULO)
	encerrar.add_theme_font_size_override("font_size",17)
	encerrar.add_theme_stylebox_override("normal",estilo("e9d3a6","8a6a3c",8))
	encerrar.add_theme_stylebox_override("hover",estilo("f4e2bd","8a6a3c",8))
	encerrar.add_theme_color_override("font_color",Color("3a2614"))
	encerrar.add_theme_color_override("font_hover_color",Color("3a2614"))
	ancorar(encerrar,Vector2(1,0),Rect2(-214,16,196,40))
	encerrar.pressed.connect(encerrar_pescaria)
	ui.add_child(encerrar)
	dica=rotulo(ui,"",21,"fff6e0")
	dica.add_theme_color_override("font_shadow_color",Color(0,0,0,.75))
	dica.add_theme_constant_override("shadow_offset_x",2)
	dica.add_theme_constant_override("shadow_offset_y",2)
	dica.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ancorar(dica,Vector2(.5,1),Rect2(-460,-60,920,32))
	aviso=rotulo(ui,"",40,"fff3d6",FONTE_TITULO)
	aviso.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	aviso.add_theme_constant_override("shadow_offset_x",3)
	aviso.add_theme_constant_override("shadow_offset_y",3)
	aviso.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ancorar(aviso,Vector2(.5,0),Rect2(-500,96,1000,56))
	barra_fundo=Panel.new()
	barra_fundo.add_theme_stylebox_override("panel",estilo("2a1d12aa","e9d3a6",6))
	ancorar(barra_fundo,Vector2(.5,1),Rect2(-200,-108,400,20))
	ui.add_child(barra_fundo)
	barra=ColorRect.new()
	barra.position=Vector2(3,3)
	barra.size=Vector2(0,14)
	barra_fundo.add_child(barra)
	marca=ColorRect.new()
	marca.color=Color("fff0c8")
	marca.size=Vector2(3,22)
	marca.position=Vector2(3+394/1.3,-1)
	barra_fundo.add_child(marca)
	barra_rotulo=rotulo(barra_fundo,"",16,"fff6e0")
	barra_rotulo.position=Vector2(0,-26)
	barra_rotulo.size=Vector2(400,20)
	barra_rotulo.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	painel_peixe=PanelContainer.new()
	painel_peixe.add_theme_stylebox_override("panel",estilo("efdcb3f2","7b5a33",12))
	ancorar(painel_peixe,Vector2(1,.5),Rect2(-430,-170,400,10))
	painel_peixe.custom_minimum_size=Vector2(390,0)
	ui.add_child(painel_peixe)
	var col:=VBoxContainer.new()
	painel_peixe.add_child(col)
	painel_texto=RichTextLabel.new()
	painel_texto.bbcode_enabled=true
	painel_texto.fit_content=true
	painel_texto.scroll_active=false
	painel_texto.add_theme_font_override("normal_font",FONTE)
	painel_texto.add_theme_font_override("bold_font",FONTE_TITULO)
	painel_texto.add_theme_font_size_override("normal_font_size",19)
	painel_texto.add_theme_font_size_override("bold_font_size",30)
	painel_texto.add_theme_color_override("default_color",Color("3a2614"))
	painel_texto.custom_minimum_size=Vector2(360,0)
	col.add_child(painel_texto)
	painel_botao=Button.new()
	painel_botao.add_theme_font_override("font",FONTE_TITULO)
	painel_botao.add_theme_font_size_override("font_size",19)
	painel_botao.add_theme_stylebox_override("normal",estilo("8a5a2b","5a3a1a",8))
	painel_botao.add_theme_stylebox_override("hover",estilo("a06a35","5a3a1a",8))
	painel_botao.add_theme_color_override("font_color",Color("fff3d6"))
	painel_botao.add_theme_color_override("font_hover_color",Color("ffffff"))
	painel_botao.pressed.connect(continuar)
	col.add_child(painel_botao)
	painel_peixe.hide()
	atualizar_cartao()

func atualizar_cartao() -> void:
	var p: Dictionary=viagem.get("pesca",{})
	var regiao: String=Exp.Regioes.definicoes()[int(viagem.regiao)].nome
	var h: Dictionary=estado.pessoa(viagem.equipe[0])
	cartao.text="Pescaria · %s · %s\nIsca %d de %d · %d peixe(s) · %s"%[regiao,h.get("nome",""),mini(int(p.get("feitos",0))+1,int(p.get("lances",0))),
		int(p.get("lances",0)),p.get("capturas",[]).size(),Pesca.formatar_peso(float(p.get("kg",0.0)))]

func avisar(texto: String,duracao:=2.2) -> void:
	aviso.text=texto
	aviso_tempo=duracao

# ------------------------------------------------------------------ fluxo

func mudar_fase(nova: String) -> void:
	fase=nova
	tempo_fase=0.0
	match nova:
		"inicio":
			pose("espera")
			dica.text=""
		"pronto":
			pose("espera")
			exibindo_peixe=false
			briga={}
			carga=0.0
			linha_presa=false
			linha_solta=false
			linha_comp=.6
			boia.show()
			if is_instance_valid(peixe_no): peixe_no.hide()
			sombra_alfa=0.0
			atualizar_cartao()
			var erro:=Exp.iniciar_lance(estado,viagem)
			if erro=="perigo":
				avisar("Perigo! A equipe larga as linhas.",3.0)
				dica.text="Um animal ameaça a equipe na margem."
				mudar_fase("saindo")
				return
			if erro!="":
				mostrar_resumo()
				return
			dica.text="Segure para armar o arremesso e solte para lançar · o mouse mira"
		"armando":
			dica.text="Solte para lançar"
		"lancando":
			gesto("lancar")
			dica.text=""
		"voando":
			linha_presa=true
		"espera":
			preparar_mordida()
			dica.text="Observe a boia. Clique quando ela afundar de verdade."
		"briga":
			pose("briga")
			dica.text="Segure: puxar · Solte: dar linha · Vara para o lado oposto ao do peixe"
		"capturado":
			pose("erguer")
			exibindo_peixe=true
			recorde_mostrado=false
			dica.text="Clique para continuar"
		"perdido":
			dica.text=""
		"resultado":
			dica.text=""
		"saindo":
			encerrar.disabled=true

func _unhandled_input(evento: InputEvent) -> void:
	if automatico: return
	if evento is InputEventMouseButton and evento.button_index==MOUSE_BUTTON_LEFT:
		apertar(evento.pressed)
		get_viewport().set_input_as_handled()
	elif evento is InputEventKey and evento.physical_keycode==KEY_SPACE and not evento.echo:
		apertar(evento.pressed)
		get_viewport().set_input_as_handled()

func apertar(baixo: bool) -> void:
	botao=baixo
	if not baixo:
		if fase=="armando": soltar_arremesso()
		return
	match fase:
		"pronto": mudar_fase("armando")
		"espera": tentar_fisgar()
		"resultado": continuar()
		"capturado":
			if painel_peixe.visible: continuar()

func soltar_arremesso() -> void:
	distancia_lance=lerpf(2.2,limite_rio,carga)
	mudar_fase("lancando")

func tentar_fisgar() -> void:
	var r:=Pesca.fisgar(mordida,t_espera)
	match r.resultado:
		"cedo":
			gesto("fisgar")
			onda(boia_pos,.4)
			if Pesca.assustou(mordida,rng):
				avisar("Cedo demais. O peixe desconfiou.")
				fugir_sombra()
				perder_lance("O peixe desconfiou da isca.")
			else:
				avisar("Cedo demais…",1.2)
		"tarde":
			pass
		"fisgou":
			gesto("fisgar")
			fisgou(float(r.firmeza))

func fisgou(firmeza: float) -> void:
	var distancia:=Vector2((boia_pos-origem).dot(L),(boia_pos-origem).dot(F))
	briga=Pesca.criar_briga(peixe,firmeza,habilidade(),distancia.length(),rng)
	briga.limite=limite_rio+.4
	briga.pos=Vector2(distancia.x,maxf(distancia.y,Pesca.MARGEM+.5))
	briga.linha=briga.pos.length()+.05
	peixe_pos=boia_pos+Vector3(0,-.3,0)
	tremor=.25+.5*briga.porte
	respingo(boia_pos,.3+briga.porte*.9)
	estalo_amp=.4
	if firmeza>.85: avisar("Fisgada firme!",1.2)
	mudar_fase("briga")

func habilidade() -> float:
	var h: Dictionary=estado.pessoa(viagem.equipe[0])
	return Pesca.habilidade(int(h.get("habilidades",{}).get("pesca",0)))

func preparar_mordida() -> void:
	if not peixe_forcado.is_empty():
		peixe=Pesca.sortear(int(viagem.regiao),rng)
		peixe.merge(peixe_forcado,true)
		var esp:=Pesca.especie(peixe.especie)
		var u:=inverse_lerp(float(esp.peso[0]),float(esp.peso[1]),float(peixe.peso))
		peixe.comprimento=lerpf(esp.comprimento[0],esp.comprimento[1],pow(clampf(u,0,1),.45))
	elif tentativa==0:
		peixe=Pesca.sortear(int(viagem.regiao),rng)
	mordida=Pesca.mordida(peixe,habilidade(),rng)
	evento_idx=0
	t_espera=0.0
	trocar_peixe(peixe.especie,float(peixe.comprimento))
	# A sombra se aproxima da isca pelo lado de fora, rondando.
	var ang:=rng.randf_range(-1.2,1.2)
	aproximar=(F.rotated(Vector3.UP,ang))*(1.4+float(peixe.comprimento))
	peixe_pos=boia_pos+aproximar
	peixe_pos.y=AGUA-.45

func perder_lance(motivo: String) -> void:
	resultado_lance=motivo
	if fase=="briga" or fase=="espera": mudar_fase("perdido")

func fugir_sombra() -> void:
	aproximar=(peixe_pos-boia_pos).normalized()*4.0

func encerrar_pescaria() -> void:
	if fase in ["saindo","resumo"]: return
	if fase=="briga": registrar(false)
	Exp.encerrar_pesca(estado,viagem,[])
	mostrar_resumo()

func registrar(capturado: bool) -> Dictionary:
	var indice:=int(viagem.get("pesca",{}).get("feitos",0))
	var info:=Exp.registrar_lance(estado,viagem,indice,peixe,capturado)
	tentativa=0
	peixe_forcado={}
	rng.seed=hash(str(viagem.id)+":pesca:"+str(viagem.get("pesca",{}).get("feitos",0)))
	atualizar_cartao()
	return info

func mostrar_peixe() -> void:
	var esp:=Pesca.especie(peixe.especie)
	var linhas: Array[String]=["[b]%s[/b]"%esp.nome,"%s · %d cm"%[Pesca.formatar_peso(float(peixe.peso)),roundi(float(peixe.comprimento)*100)]]
	if recorde: linhas.append("[color=#8a3b12]Novo recorde da aldeia nesta espécie![/color]")
	linhas.append(DESCRICOES.get(peixe.especie,""))
	painel_texto.text="\n".join(linhas)
	painel_botao.text="Continuar"
	painel_peixe.show()

func mostrar_perda() -> void:
	painel_texto.text="[b]Escapou[/b]\n%s\n%s"%[resultado_lance,("Parecia um peixe grande…" if briga.get("porte",0.0)>.55 else "")]
	painel_botao.text="Continuar"
	painel_peixe.show()

func mostrar_resumo() -> void:
	fase="resumo"
	dica.text=""
	encerrar.disabled=true
	var p: Dictionary=viagem.get("pesca",{})
	var linhas: Array[String]=["[b]Fim da pescaria[/b]"]
	var regs: Array[String]=[]
	for c: Dictionary in p.get("capturas",[]): regs.append("%s · %s"%[Pesca.nome(c.especie),Pesca.formatar_peso(float(c.peso))])
	linhas.append("\n".join(regs) if not regs.is_empty() else "Nenhum peixe desta vez.")
	linhas.append("Total %s · %d porção(ões) de peixe na carga"%[Pesca.formatar_peso(float(p.get("kg",0.0))),int(viagem.carga.get("peixe",0))])
	linhas.append("A equipe volta para a aldeia.")
	painel_texto.text="\n".join(linhas)
	painel_botao.text="Voltar à aldeia"
	painel_peixe.show()

func continuar() -> void:
	painel_peixe.hide()
	if fase=="resumo" or fase=="saindo":
		fase="fechado"
		concluido.emit()
		return
	if fase=="resultado" or fase=="capturado" or fase=="perdido":
		if not Exp.pesca_ativa(viagem):
			mostrar_resumo()
			return
		mudar_fase("pronto")

const DESCRICOES:={
	"lambari":"Pequeno e esperto: belisca a isca muitas vezes antes de morder.",
	"acara":"Teimoso: sacode a cabeça e procura as pedras.",
	"piau":"Ladrão de isca: toca de leve e puxa de lado.",
	"traira":"Ataca de emboscada; os dentes castigam a linha.",
	"jundia":"Vai para o fundo e pesa como pedra.",
	"robalo":"Corredor: dá arrancadas longas rio afora.",
	"camurupim":"O rei prateado: salta alto para cuspir o anzol."}

# ------------------------------------------------------------------ quadro a quadro

func altura_agua(p: Vector3) -> float:
	return AGUA+.025*sin(p.z*1.8+p.x*1.2+tempo_agua*1.1)

func _process(dt: float) -> void:
	dt=minf(dt,1.0/20.0)
	tempo+=dt
	var tv: Variant=RenderingServer.global_shader_parameter_get(&"tempo_visual")
	tempo_agua=float(tv) if tv!=null else tempo
	tempo_fase+=dt
	ler_entrada(dt)
	match fase:
		"inicio":
			if tempo_fase>1.2: mudar_fase("pronto")
		"armando":
			carga=minf(1.0,carga+dt/1.1)
			if automatico and carga>=.62: soltar_arremesso()
		"lancando":
			# A linha sai no chicote da vara (55% do clipe).
			if tempo_fase>=.74:
				var alvo:=origem+F*distancia_lance+L*(lado*distancia_lance*.32)
				var voo:=.7+distancia_lance*.055
				boia_pos=nos[N_LINHA-1]
				boia_vel=(alvo-boia_pos-.5*Vector3(0,-9.8,0)*voo*voo)/voo
				mudar_fase("voando")
		"voando":
			boia_vel.y-=9.8*dt
			boia_pos+=boia_vel*dt
			if boia_pos.y<=altura_agua(boia_pos):
				boia_pos.y=altura_agua(boia_pos)
				boia_vel=Vector3.ZERO
				respingo(boia_pos,.12)
				plique_amp=.5
				mudar_fase("espera")
		"espera":
			processar_espera(dt)
		"briga":
			processar_briga(dt)
		"capturado":
			processar_captura(dt)
		"perdido":
			if tempo_fase>1.6:
				registrar(false)
				mostrar_perda()
				mudar_fase("resultado")
		"resultado":
			if automatico and tempo_fase>1.2: continuar()
		"saindo":
			if tempo_fase>2.4:
				fase="fechado"
				concluido.emit()
	if fase=="resumo" and automatico and tempo_fase>2.0:
		fase="fechado"
		concluido.emit()
	if fase in ["pronto","armando"] and not linha_presa:
		boia_pos=nos[N_LINHA-1]
	atualizar_boia(dt)
	atualizar_vara(dt)
	atualizar_linha(dt)
	atualizar_peixe_visual(dt)
	atualizar_ondas(dt)
	atualizar_camera(dt)
	atualizar_interface(dt)
	gerar_som()

func ler_entrada(dt: float) -> void:
	var alvo_lado:=0.0
	if automatico:
		alvo_lado=lado_robo()
		puxando=puxar_robo()
		if fase=="pronto" and tempo_fase>.8: mudar_fase("armando")
		if fase=="espera" and mordida.has("inicio") and t_espera>=float(mordida.inicio)+float(mordida.janela)*.3: tentar_fisgar()
	else:
		var vp:=get_viewport().get_visible_rect().size
		var m:=get_viewport().get_mouse_position()
		alvo_lado=clampf((m.x/maxf(vp.x,1.0)-.5)*2.6,-1.0,1.0)
		if Input.is_physical_key_pressed(KEY_A): alvo_lado=-1.0
		if Input.is_physical_key_pressed(KEY_D): alvo_lado=1.0
		puxando=botao
	lado=lerpf(lado,alvo_lado,1.0-exp(-dt*6.0))
	mistura=lerpf(mistura,1.0 if puxando else 0.0,1.0-exp(-dt*7.0))
	arvore.set("parameters/briga/blend_amount",mistura)
	# A vara vira para o lado com o corpo do pescador.
	pescador.rotation.y=lerp_angle(pescador.rotation.y,PI/2-lado*.42,1.0-exp(-dt*5.0))

## Robô de inspeção: mesma entrada que um jogador cuidadoso.
func puxar_robo() -> bool:
	if fase!="briga": return false
	if briga.get("no_ar",false) or briga.get("modo","")=="salto": return false
	if briga.get("modo","")=="cansado": return true
	return briga.get("modo","")!="corrida" and float(briga.get("tensao",0.0))<.78

func lado_robo() -> float:
	if fase=="briga": return -signf(briga.get("dir",Vector2.ZERO).x)
	return .15

func processar_espera(dt: float) -> void:
	t_espera+=dt
	var eventos: Array=mordida.eventos
	while evento_idx<eventos.size() and float(eventos[evento_idx].t)<=t_espera:
		aplicar_evento(eventos[evento_idx])
		evento_idx+=1
	# A sombra chega devagar, ronda e encosta na isca.
	var chegada:=clampf((t_espera-(float(mordida.inicio)-3.2))/3.0,0.0,1.0)
	if evento_idx>0 or chegada>0:
		var ronda:=Vector3(sin(tempo*1.7),0,cos(tempo*1.3))*.25*(1.0-chegada)
		var alvo:=boia_pos+aproximar*(1.0-chegada)*.9+ronda
		peixe_pos=peixe_pos.lerp(Vector3(alvo.x,AGUA-.4,alvo.z),1.0-exp(-dt*1.6))
		sombra_alfa=lerpf(sombra_alfa,clampf(.15+.5*Pesca.porte(float(peixe.peso)),0,.6)*chegada,1.0-exp(-dt*3.0))
	if t_espera>float(mordida.inicio)+float(mordida.janela):
		# Passou a janela: a isca foi levada (alguns voltam uma vez).
		boia_prof=0.0
		boia_deriva=Vector3.ZERO
		if Pesca.insiste(mordida,tentativa):
			tentativa+=1
			avisar("Ele voltou para a isca…",1.4)
			var antigo:=peixe
			preparar_mordida()
			peixe=antigo
			t_espera=-.5
		else:
			avisar("Tarde demais. Levou a isca.",1.8)
			fugir_sombra()
			perder_lance("A isca foi levada.")

func aplicar_evento(ev: Dictionary) -> void:
	var forca: float=ev.forca
	var tam:=Pesca.porte(float(peixe.peso))
	match ev.tipo:
		"toque":
			boia_vel.y-=.55+forca*.9
			onda(boia_pos,.18+forca*.45,.8)
			plique_amp=.25+forca*.4
		"tremor":
			boia_vel+=Vector3(rng.randf_range(-.2,.2),-.25,rng.randf_range(-.2,.2))
			onda(boia_pos,.2,.6)
		"rodada":
			var lado_r:=L*(1 if rng.randf()<.5 else -1)*.45
			respingo(boia_pos+lado_r,.35+tam*.5)
			onda(boia_pos+lado_r,1.2+tam,1.8)
			sombra_alfa=.6
		"puxao":
			boia_vel+=L*(1 if rng.randf()<.5 else -1)*.9+Vector3(0,-.6,0)
			onda(boia_pos,.35,.8)
			plique_amp=.4
		"afundar":
			boia_prof=-.2-.15*forca
			boia_vel.y-=1.4+tam*1.5
			onda(boia_pos,.4+tam*1.1,1.3)
			if tam>.4: respingo(boia_pos,tam*.5)
		"arrasto":
			boia_prof=-.12
			boia_deriva=(F.rotated(Vector3.UP,rng.randf_range(-.8,.8)))*.35
			onda(boia_pos,.3,1.0)
		"corrida":
			boia_prof=-.2
			boia_deriva=(F.rotated(Vector3.UP,rng.randf_range(-.9,.9)))*1.3
			onda(boia_pos,.5+tam,1.2)
	tremor=maxf(tremor,forca*tam*.25)

func processar_briga(dt: float) -> void:
	var antes_modo: String=briga.modo
	Pesca.passo(briga,puxando,lado,dt,rng)
	if briga.modo!=antes_modo:
		match briga.modo:
			"corrida": avisar("Ele dispara!" if briga.porte>.4 else "",1.0)
			"salto": avisar("Salto! Dê linha!",1.0)
			"fundo": avisar("Foi para o fundo…",1.0)
			"cansado": avisar("Está cansando.",1.0)
	var tv: float=briga.tensao
	tremor=maxf(tremor,clampf(tv-.7,0,1)*.08+(.05 if briga.modo=="sacudida" else 0.0)*briga.porte)
	if briga.resultado!="":
		match briga.resultado:
			"capturado":
				recorde=registrar(true).get("recorde",false)
				respingo(peixe_pos,.4+briga.porte)
				mudar_fase("capturado")
			"linha_rompeu":
				avisar("A linha arrebentou!",2.4)
				estalo_amp=1.0
				vel_curva-=9.0
				linha_solta=true
				for i in range(N_LINHA):
					nos_ant[i]=nos[i]+(nos[i]-vara_ponta).normalized()*.06*float(i)/N_LINHA
				perder_lance(briga.motivo)
			"escapou":
				avisar("Escapou!",2.0)
				perder_lance(briga.motivo)

func processar_captura(_dt: float) -> void:
	if tempo_fase>.9 and not painel_peixe.visible and not recorde_mostrado:
		recorde_mostrado=true
		mostrar_peixe()
	if automatico and recorde_mostrado and tempo_fase>3.0: continuar()

func atualizar_boia(dt: float) -> void:
	var ondulacao:=altura_agua(boia_pos)-AGUA+.004*sin(tempo*3.1+boia_pos.z*2.2)
	match fase:
		"espera","perdido","resultado":
			if fase=="espera" or linha_presa:
				var alvo_y:=AGUA+ondulacao+boia_prof
				boia_vel.y+=(alvo_y-boia_pos.y)*70.0*dt
				boia_vel.y*=exp(-dt*7.0)
				var horiz:=Vector3(boia_vel.x,0,boia_vel.z)
				horiz=horiz.lerp(boia_deriva+Vector3(0,0,.03),1.0-exp(-dt*2.0))
				boia_vel.x=horiz.x
				boia_vel.z=horiz.z
				boia_pos+=boia_vel*dt
				if fase!="espera":
					boia_deriva=boia_deriva.lerp(Vector3.ZERO,1.0-exp(-dt*2.0))
					boia_prof=lerpf(boia_prof,0.0,1.0-exp(-dt*3.0))
		"briga":
			var rumo:=(Vector3(vara_ponta.x,0,vara_ponta.z)-Vector3(peixe_pos.x,0,peixe_pos.z)).normalized()
			var alvo:=Vector3(peixe_pos.x,0,peixe_pos.z)+rumo*.35
			var prof:=clampf(float(briga.profundidade)*.22,0,.16)
			alvo.y=AGUA+ondulacao-prof
			if briga.no_ar: alvo.y=maxf(alvo.y,peixe_pos.y-.3)
			boia_pos=boia_pos.lerp(alvo,1.0-exp(-dt*9.0))
		"capturado":
			boia_pos=boia_pos.lerp(vara_ponta+Vector3(0,-.5,0),1.0-exp(-dt*4.0))
	boia.global_position=boia_pos
	var inclina:=clampf(boia_vel.length()*.6,0,.9)
	boia.rotation=Vector3(clampf(boia_vel.z,-1,1)*inclina,0,-clampf(boia_vel.x,-1,1)*inclina)
	if fase in ["pronto","armando","lancando"] and not linha_presa:
		boia.rotation=Vector3.ZERO

func tensao_visual() -> float:
	match fase:
		"briga": return float(briga.tensao)
		"espera": return .04+(.25 if boia_prof<-.1 else 0.0)
		"capturado": return .45
		"armando": return .02
	return .02

func atualizar_vara(dt: float) -> void:
	var base: Transform3D=cabo.global_transform
	var dir0:=(base.basis*eixo_cabo).normalized()
	var p0:=base*(eixo_cabo*ponta_cabo)
	var alvo_dir:=dir0
	if nos.size()>2 and not linha_solta:
		var d:=nos[3]-vara_ponta
		if d.length()>.01: alvo_dir=d.normalized()
	var alvo:=tensao_visual()*1.05
	if linha_solta: alvo=0.0
	vel_curva+=(alvo-curva_vara)*60.0*dt
	vel_curva*=exp(-dt*3.6)
	curva_vara+=vel_curva*dt
	var limite:=dir0.angle_to(alvo_dir)
	var eixo_rot:=dir0.cross(alvo_dir)
	if eixo_rot.length()<.001: eixo_rot=dir0.cross(Vector3.UP)
	eixo_rot=eixo_rot.normalized()
	var queda:=dir0.cross(Vector3.DOWN)
	queda=queda.normalized() if queda.length()>.001 else Vector3.RIGHT
	var total:=clampf(curva_vara,-.5,minf(1.4,limite*1.02))
	if fase=="briga" and float(briga.tensao)>.75: total+=sin(tempo*47.0)*.012*float(briga.tensao)
	var pts:=PackedVector3Array([p0])
	var dir:=dir0
	var seg:=VARA_COMP/N_VARA
	var anterior:=0.0
	for i in range(N_VARA):
		var w:=pow(float(i+1)/N_VARA,1.7)
		dir=(Basis(eixo_rot,total*(w-anterior))*Basis(queda,.012)*dir).normalized()
		anterior=w
		pts.append(pts[i]+dir*seg)
	vara_ponta=pts[N_VARA]
	vara_malha.clear_surfaces()
	vara_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var lados:=6
	var aneis: Array=[]
	for i in range(pts.size()):
		var t:=float(i)/N_VARA
		var r:=lerpf(.012,.0032,t)
		var eixo:=(pts[mini(i+1,N_VARA)]-pts[maxi(i-1,0)]).normalized()
		var u:=eixo.cross(Vector3.UP)
		u=u.normalized() if u.length()>.01 else Vector3.RIGHT
		var v:=eixo.cross(u).normalized()
		var anel: Array=[]
		for k in range(lados):
			var a:=TAU*k/lados
			anel.append([pts[i]+(u*cos(a)+v*sin(a))*r,(u*cos(a)+v*sin(a))])
		aneis.append(anel)
	for i in range(N_VARA):
		for k in range(lados):
			var k2:=(k+1)%lados
			for c in [[i,k],[i+1,k],[i+1,k2],[i,k],[i+1,k2],[i,k2]]:
				vara_malha.surface_set_normal(aneis[c[0]][c[1]][1])
				vara_malha.surface_add_vertex(aneis[c[0]][c[1]][0])
	vara_malha.surface_end()

func fim_da_linha() -> Vector3:
	match fase:
		"voando","espera","perdido","resultado": return boia_pos
		"briga": return boia_pos
		"capturado": return peixe_pos+Vector3(0,.02,0)
	return boia_pos

func atualizar_linha(dt: float) -> void:
	var presa:=linha_presa and not linha_solta
	var fim:=fim_da_linha()
	var reta:=vara_ponta.distance_to(fim)
	if presa:
		match fase:
			"voando": linha_comp=reta*1.03
			"espera","perdido","resultado": linha_comp=lerpf(linha_comp,reta*1.03,1.0-exp(-dt*3.0))
			"briga":
				var folga:=maxf(0.0,float(briga.linha)-(briga.pos as Vector2).length())
				linha_comp=reta*.998+folga
			"capturado": linha_comp=reta*1.02
	elif not linha_solta:
		linha_comp=.6
	var n:=N_LINHA
	var seg:=linha_comp/(n-1)
	nos[0]=vara_ponta
	for i in range(1,n):
		var p:=nos[i]
		var v:=p-nos_ant[i]
		var molhado:=p.y<=AGUA+.015
		v*=.86 if molhado else .985
		var g:=Vector3(0,-6.0 if not molhado else -.4,0)
		nos_ant[i]=p
		var q:=p+v+g*dt*dt
		if q.y<AGUA-.01: q.y=AGUA-.01
		nos[i]=q
	for it in range(16):
		for i in range(n-1):
			var d:=nos[i+1]-nos[i]
			var dist:=d.length()
			if dist<1e-5: continue
			var dif:=(dist-seg)/dist
			if i==0:
				nos[i+1]-=d*dif
			elif i+1==n-1 and presa:
				nos[i]+=d*dif
			else:
				nos[i]+=d*dif*.5
				nos[i+1]-=d*dif*.5
		nos[0]=vara_ponta
		if presa: nos[n-1]=fim
	# Desenho: fita voltada para a câmera; vibra quando a linha "canta".
	linha_malha.clear_surfaces()
	var vib:=clampf(tensao_visual()-.55,0,1)*.006 if fase=="briga" else 0.0
	linha_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var olho:=cam.global_position if cam else Vector3.ZERO
	for i in range(n-1):
		var a:=nos[i]
		var b:=nos[i+1]
		if vib>0:
			var fator:=sin(float(i)/(n-1)*PI)
			a+=Vector3(0,sin(tempo*90.0+i)*vib*fator,0)
			b+=Vector3(0,sin(tempo*90.0+i+1)*vib*sin(float(i+1)/(n-1)*PI),0)
		var lado_v:=(b-a).cross(olho-a)
		lado_v=lado_v.normalized()*.0045 if lado_v.length()>1e-5 else Vector3(.0045,0,0)
		for p in [a-lado_v,a+lado_v,b+lado_v,a-lado_v,b+lado_v,b-lado_v]:
			linha_malha.surface_add_vertex(p)
	linha_malha.surface_end()

func atualizar_peixe_visual(dt: float) -> void:
	if not is_instance_valid(peixe_no):
		sombra_mat.albedo_color.a=0.0
		return
	var comp:=float(peixe.get("comprimento",.3))
	var freq:=8.0
	var amp:=.05
	var visivel:=false
	var arq:=0.0
	match fase:
		"espera":
			var dir:=(boia_pos-peixe_pos)
			dir.y=0
			if dir.length()>.05: peixe_dir=peixe_dir.slerp(dir.normalized(),1.0-exp(-dt*3.0))
			freq=6.0
		"perdido","resultado":
			if not briga.is_empty() or aproximar.length()>3.0:
				peixe_pos+=peixe_dir*dt*2.0
				peixe_pos.y=lerpf(peixe_pos.y,AGUA-.8,1.0-exp(-dt*2))
			sombra_alfa=lerpf(sombra_alfa,0.0,1.0-exp(-dt*1.5))
			freq=16.0
		"briga":
			var p2: Vector2=briga.pos
			var alvo:=origem+F*p2.y+L*p2.x
			var v2: Vector2=briga.vel
			var vel:=F*v2.y+L*v2.x
			if vel.length()>.05: peixe_dir=peixe_dir.slerp(vel.normalized(),1.0-exp(-dt*5.0))
			var prof: float=briga.profundidade
			var altura:=AGUA-prof
			if briga.modo=="salto":
				var f: float=briga.fase_modo
				if f>=Pesca.SALTO_SUBIDA and f<Pesca.SALTO_SUBIDA+Pesca.SALTO_AR:
					var k:=(f-Pesca.SALTO_SUBIDA)/Pesca.SALTO_AR
					altura=AGUA+(.35+.9*float(briga.porte))*sin(PI*k)
					if not ja_no_ar:
						ja_no_ar=true
						respingo(alvo,.5+briga.porte)
					arq=sin(tempo*22.0)
				elif ja_no_ar and f>=Pesca.SALTO_SUBIDA+Pesca.SALTO_AR:
					ja_no_ar=false
					respingo(alvo,.6+briga.porte)
					tremor=maxf(tremor,.2*briga.porte)
			peixe_pos=Vector3(alvo.x,altura,alvo.z)
			visivel=prof<.12 or altura>AGUA
			freq={"nadar":9.0,"corrida":18.0,"sacudida":24.0,"salto":20.0,"fundo":7.0,"cansado":3.5}[briga.modo]
			amp={"nadar":.06,"corrida":.1,"sacudida":.13,"salto":.12,"fundo":.05,"cansado":.03}[briga.modo]
			# Debate perto da superfície: respingos e ondas.
			if prof<.2 and tempo-ultimo_respingo>(.25 if briga.modo=="sacudida" else .6) and briga.modo in ["sacudida","corrida","cansado"]:
				ultimo_respingo=tempo
				if briga.modo=="cansado": onda(peixe_pos,comp*1.2,1.0)
				else: respingo(peixe_pos,.15+briga.porte*.5)
			elif prof<.6 and tempo-ultimo_respingo>.35:
				ultimo_respingo=tempo
				onda(peixe_pos,comp*(1.5-prof),1.1)
			sombra_alfa=clampf(.15+.5*float(briga.porte),0,.65)*clampf(1.2-prof*.6,0,1)
		"capturado","resultado" when exibindo_peixe:
			visivel=true
			var mao:=posicao_mao()
			if float(peixe.peso)>8.0:
				# Grande demais para erguer: arrastado para a areia ao lado do pescador.
				var areia:=pe_pescador-F*.45-L*1.15
				var chao:=Solo.no_solo(Vector2(areia.x,areia.z))
				peixe_pos=peixe_pos.lerp(chao+Vector3(0,.09*comp,0),1.0-exp(-dt*3.5))
				peixe_dir=peixe_dir.slerp(L,1.0-exp(-dt*3.0))
				arq=sin(tempo*9.0)*.6*exp(-tempo_fase*.3)
			else:
				peixe_pos=peixe_pos.lerp(mao+Vector3(0,-comp*.38,0),1.0-exp(-dt*(4.0+tempo_fase*8.0)))
				arq=sin(tempo*11.0)*.5*exp(-tempo_fase*.4)
			freq=10.0
			amp=.04
			sombra_alfa=0.0
	peixe_fase+=dt*freq
	peixe_mat.set_shader_parameter("fase",peixe_fase)
	peixe_mat.set_shader_parameter("amplitude",amp)
	peixe_mat.set_shader_parameter("arqueio",arq)
	peixe_mat.set_shader_parameter("molhado",1.0)
	peixe_no.visible=visivel
	peixe_no.global_position=peixe_pos
	if exibindo_peixe and float(peixe.peso)<=8.0:
		var olho:=(cam.global_position-peixe_pos)
		olho.y=0
		var yaw:=atan2(-olho.z,olho.x)
		peixe_no.global_basis=Basis(Vector3.UP,yaw)*Basis.from_euler(Vector3(-PI/2,0,0))*Basis.from_scale(Vector3.ONE*comp)
	else:
		var d:=peixe_dir
		d.y=0
		if d.length()<.01: d=F
		var b:=Basis.looking_at(-d.normalized(),Vector3.UP)
		if fase=="briga" and briga.modo=="salto" and peixe_pos.y>AGUA:
			var k:=clampf((float(briga.fase_modo)-Pesca.SALTO_SUBIDA)/Pesca.SALTO_AR,0,1)
			b=b*Basis(Vector3.RIGHT,lerpf(-.9,.9,k))*Basis(Vector3.FORWARD,sin(tempo*18.0)*.5)
		elif fase=="briga" and briga.modo=="cansado":
			b=b*Basis(Vector3.FORWARD,.9+sin(tempo*3.0)*.15)
		peixe_no.global_basis=b*Basis.from_scale(Vector3.ONE*comp)
	# Sombra na superfície (a água é quase opaca): tamanho real do peixe.
	sombra.global_position=Vector3(peixe_pos.x,altura_agua(peixe_pos)+.028,peixe_pos.z)
	var dd:=peixe_dir
	dd.y=0
	if dd.length()>.01: sombra.global_basis=Basis.looking_at(-dd.normalized(),Vector3.UP)
	var c:=sombra_mat.albedo_color
	c.a=sombra_alfa*(0.0 if peixe_no.visible and peixe_pos.y>AGUA else 1.0)
	sombra_mat.albedo_color=c

func posicao_mao() -> Vector3:
	var i:=esqueleto.find_bone("mao_E")
	if i<0: return pe_pescador+Vector3(0,1.2,0)
	return esqueleto.global_transform*esqueleto.get_bone_global_pose(i).origin

func atualizar_ondas(dt: float) -> void:
	for o: Dictionary in ondas:
		if o.idade>=o.vida:
			continue
		o.idade+=dt
		var k: float=o.idade/o.vida
		var m: MeshInstance3D=o.no
		var s: float=o.tam*(.25+k*1.3)
		m.scale=Vector3(s,1,s)
		var c: Color=o.mat.albedo_color
		c.a=(1.0-k)*(1.0-k)*.75
		o.mat.albedo_color=c
		if o.idade>=o.vida: m.hide()

func atualizar_camera(dt: float) -> void:
	var foco:=origem+F*4.0
	var pos:=pe_pescador-F*2.6+L*1.05+Vector3(0,2.0,0)
	match fase:
		"espera","voando":
			foco=boia_pos.lerp(vara_ponta,.25)
		"briga":
			# Mais alta e recuada: vara erguida, linha e peixe no mesmo quadro.
			foco=peixe_pos.lerp(vara_ponta,.45)
			foco.y=maxf(foco.y,AGUA+.3)
			var lateral:=(peixe_pos-origem).dot(L)
			pos=pe_pescador-F*3.4+L*(1.0-clampf(lateral*.2,-1.6,1.6))+Vector3(0,3.0,0)
		"capturado","resultado":
			if exibindo_peixe:
				foco=peixe_pos.lerp(pe_pescador+Vector3(0,1.1,0),.4)
				# A mão esquerda (que segura o peixe) fica do lado -L.
				pos=pe_pescador+F*.35-L*2.3+Vector3(0,1.45,0)
				if float(peixe.get("peso",0.0))>8.0:
					foco=peixe_pos.lerp(pe_pescador+Vector3(0,.8,0),.5)
					pos=pe_pescador+F*.6-L*4.2+Vector3(0,2.2,0)
			else:
				foco=boia_pos.lerp(vara_ponta,.4)
	cam_alvo=cam_alvo.lerp(foco,1.0-exp(-dt*2.2))
	cam_pos=cam_pos.lerp(pos,1.0-exp(-dt*1.6))
	tremor=maxf(0.0,tremor-dt*.6)
	var sacode:=Vector3(sin(tempo*37.0),sin(tempo*41.0+1.3),0)*tremor*.05
	cam.global_position=cam_pos+sacode
	cam.look_at(cam_alvo+sacode*.5)
	var fov:=(54.0-clampf(tensao_visual()-.6,0,.6)*10.0) if fase=="briga" else 48.0
	cam.fov=lerpf(cam.fov,fov,1.0-exp(-dt*2.0))

func atualizar_interface(dt: float) -> void:
	aviso_tempo-=dt
	aviso.modulate.a=clampf(aviso_tempo*2.0,0,1)
	var mostrar:=fase in ["armando","briga"]
	barra_fundo.visible=mostrar
	if fase=="armando":
		barra.size.x=394*carga
		barra.color=Color("e9c46a")
		marca.hide()
		barra_rotulo.text="Força do arremesso · %d m"%roundi(lerpf(2.2,limite_rio,carga))
	elif fase=="briga":
		var tv: float=briga.tensao
		marca.show()
		barra.size.x=394*clampf(tv/1.3,0,1)
		var cor:=Color("6f9b48").lerp(Color("e0a53a"),clampf((tv-.45)/.35,0,1))
		if tv>.92: cor=Color("c0432f")
		if float(briga.dano)>.25 and fmod(tempo,.25)<.12: cor=Color("ffffff")
		barra.color=cor
		var falta: float=Pesca.dados.linha.comprimento_maximo-float(briga.linha)
		var txt:="Tensão da linha"
		if falta<5.0: txt="A linha está acabando! %d m"%roundi(falta)
		elif briga.evento=="margem" or ((briga.pos as Vector2).length()<Pesca.MARGEM and float(briga.folego)<.3): txt="Puxe com calma para tirar da água"
		barra_rotulo.text=txt

# ------------------------------------------------------------------ som

func gerar_som() -> void:
	if reprodutor==null: return
	var n:=reprodutor.get_frames_available()
	if n<=0: return
	var alvo_z:=0.0
	var freq:=200.0
	if fase=="briga":
		var tv: float=briga.tensao
		alvo_z=pow(clampf((tv-.3)*1.3,0,1),1.5)*.35
		freq=170.0+tv*620.0
	var f:=2.0*sin(PI*freq/AMOSTRAS)
	var passo_plique:=TAU*1350.0/AMOSTRAS
	for i in range(n):
		ruido=(ruido*1103515245+12345)&0x7fffffff
		var w:=float(ruido)/1073741823.5-1.0
		zumbido+=(alvo_z-zumbido)*.0008
		# Filtro de variável de estado: banda estreita = linha "cantando".
		bp_baixo+=f*bp_banda
		var alto:=w-bp_baixo-.06*bp_banda
		bp_banda+=f*alto
		lp+=(w-lp)*.12
		var s:=bp_banda*zumbido*.6+lp*respingo_amp*.9+sin(plique_fase)*plique_amp*.3+w*estalo_amp*.8
		plique_fase+=passo_plique
		respingo_amp*=.99975
		plique_amp*=.9993
		estalo_amp*=.9965
		s=clampf(s,-1,1)
		reprodutor.push_frame(Vector2(s,s))
