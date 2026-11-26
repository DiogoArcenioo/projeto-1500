extends Node3D
## Revisão da onça B na iluminação do jogo, com controles de pose e escala.
const Solo = preload("res://scripts/ambientes/aldeia_visual.gd")
const Orientacao = preload("res://scripts/encontros/orientacao_encontro.gd")
const Recortes = preload("res://scripts/encontros/recortes_visuais.gd")
const Animador = preload("res://scripts/ambientes/animador_morador.gd")
const POS_ONCA := Vector2(7.5,-3.5)
const POS_MORADOR := Vector2(7.5,-.9)
const CLIPES := ["parada", "andar", "correr", "investida", "errar_ataque", "receber_golpe", "esquivar"]
var luz = preload("res://scripts/ambientes/iluminacao_diurna.gd").new()
var animador: AnimationPlayer
var morador: RefCounted
var noite := false
var legenda: Label
@onready var onca: Node3D = $Onca
@onready var humano: Node3D = $Morador
@onready var camera: Camera3D = $CameraAvaliacao

func _ready() -> void:
	add_child(luz)
	luz.configurar($Clareira1500)
	luz.aplicar(15.5)
	preparar_mata()
	onca.position = Solo.no_solo(POS_ONCA)
	humano.position = Solo.no_solo(POS_MORADOR)
	Orientacao.preparar(onca, [humano])
	for ator in [onca, humano]:
		for m: MeshInstance3D in ator.find_children("*", "MeshInstance3D", true, false):
			m.layers = 3
	var players := onca.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animador = players[0]
	morador = Animador.new(humano, "homem_01")
	morador.tocar("parado", 0)
	var camada := CanvasLayer.new()
	add_child(camada)
	legenda = Label.new()
	camada.add_child(legenda)
	legenda.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	legenda.offset_top = -36
	legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legenda.text = "1 três quartos  ·  2 frente  ·  3 perfil  ·  4 tática  ·  5 costas  ·  P parada  ·  C andar  ·  F correr  ·  6–9 reações  ·  N noite"
	legenda.add_theme_color_override("font_shadow_color", Color.BLACK)
	legenda.add_theme_constant_override("shadow_offset_x", 1)
	legenda.add_theme_constant_override("shadow_offset_y", 2)
	enquadrar(1)
	animar("parada")

func preparar_mata() -> void:
	$Clareira1500/Fogueira.hide()
	var area := AABB(Vector3(3.7,-3,-7.3), Vector3(7.6,8,7.6))
	for m: MeshInstance3D in $Clareira1500/Paisagem.find_children("*", "MeshInstance3D", true, false):
		if str(m.name) in ["Lenha", "Lenha_Miolo", "Pedras_Fogueira", "Brasas", "Solo_Cinzas"]:
			m.hide()
		elif str(m.name) in ["Capim", "Folhas_Largas", "Samambaias", "Bromelias", "Flores_Coral", "Flores_Ouro"]:
			m.mesh = Recortes.recortar(m, area, false)

func enquadrar(vista: int) -> void:
	humano.visible = vista == 4
	var alvo := onca.position + Vector3(0,.39,-.10)
	var deslocamento: Vector3 = {
		1: Vector3(1.95,.58,2.37), 2: Vector3(0,.41,2.25), 3: Vector3(3.18,.33,0),
		4: Vector3(5.8,10.5,11.7), 5: Vector3(1.96,.48,-2.38)
	}.get(vista, Vector3(1.95,.58,2.37))
	if vista == 4:
		alvo = onca.position.lerp(humano.position,.52)
	camera.global_position = alvo + deslocamento
	camera.look_at(alvo)
	camera.make_current()

func animar(clipe: String) -> void:
	if animador == null or not animador.has_animation(clipe):
		return
	animador.get_animation(clipe).loop_mode = Animation.LOOP_LINEAR if clipe in CLIPES.slice(0, 3) else Animation.LOOP_NONE
	animador.play(clipe, .12)

func _process(delta: float) -> void:
	if morador != null and humano.visible:
		morador.avancar(delta)

func _unhandled_key_input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	match evento.physical_keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			enquadrar(evento.physical_keycode - KEY_1 + 1)
		KEY_P: animar("parada")
		KEY_C: animar("andar")
		KEY_F: animar("correr")
		KEY_6: animar("investida")
		KEY_7: animar("errar_ataque")
		KEY_8: animar("receber_golpe")
		KEY_9: animar("esquivar")
		KEY_N:
			noite = not noite
			luz.aplicar(23 if noite else 15.5)
		_: return
	get_viewport().set_input_as_handled()
