extends Node3D
## Revisão visual isolada. Não cria partida nem acessa salvamentos.
const Luz=preload("res://scripts/ambientes/iluminacao_diurna.gd")
const Solo=preload("res://scripts/ambientes/aldeia_visual.gd")
var luz:=Luz.new()
var noite:=false
var vista:="Frente"

func _ready() -> void:
	add_child(luz)
	luz.configurar($Clareira1500)
	$CentroCaca.position=Solo.no_solo(Vector2(-5,-4))
	for m: MeshInstance3D in $CentroCaca.find_children("*","MeshInstance3D",true,false): m.layers=3
	luz.aplicar(16)
	enquadrar("Frente")
	print("[Centro de caça A1] 1: câmera do jogo | 2: frente | 3: lateral | 4: costas | 5: equipamentos | N: dia/noite")
	print("[Etapa 9] Somente avaliação do modelo; sem caça, combate ou salvamento.")

func enquadrar(nome: String) -> void:
	vista=nome
	if nome=="Geral":
		$Clareira1500/Enquadramentos/Geral.make_current()
		return
	var camera: Camera3D=$CameraAvaliacao
	var alvo: Vector3=$CentroCaca.position+Vector3(0,1.2,0)
	var deslocamento: Vector3={
		"Frente":Vector3(-4.5,2.6,6.3),
		"Lateral":Vector3(6,3.0,3.3),
		"Costas":Vector3(4.6,3.0,-6.3),
		"Detalhes":Vector3(-.2,.5,4.0)
	}.get(nome,Vector3(-4.5,2.6,6.3))
	if nome=="Detalhes": alvo+=Vector3(.3,-.25,0)
	camera.position=alvo+deslocamento
	camera.look_at(alvo)
	camera.make_current()

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	match e.physical_keycode:
		KEY_1: enquadrar("Geral")
		KEY_2: enquadrar("Frente")
		KEY_3: enquadrar("Lateral")
		KEY_4: enquadrar("Costas")
		KEY_5: enquadrar("Detalhes")
		KEY_N:
			noite=not noite
			luz.aplicar(23 if noite else 16)
		_: return
	get_viewport().set_input_as_handled()
