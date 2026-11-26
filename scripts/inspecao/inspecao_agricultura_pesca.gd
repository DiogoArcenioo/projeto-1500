extends Node3D
const Luz=preload("res://scripts/ambientes/iluminacao_diurna.gd")
const Terreno=preload("res://scripts/ambientes/aldeia_visual.gd")
var luz:=Luz.new()
var noite:=false
var vista:="Roca"

func _ready() -> void:
	add_child(luz)
	luz.configurar($Clareira1500)
	$CentroAgricola.position=Terreno.no_solo(Vector2(-5.8,-3.8))
	$CentroPesca.position=Terreno.no_solo(Vector2(9.2,1.2))
	for centro in [$CentroAgricola,$CentroPesca]:
		for m: MeshInstance3D in centro.find_children("*","MeshInstance3D",true,false): m.layers=3
	luz.aplicar(16)
	enquadrar("Roca")
	print("[Arte etapa 8] 1: câmera do jogo | 2: roça | 3: pesca | 4: costas da pesca | Z/X/C: broto/jovem/maduro | N: dia/noite")
	print("[Arte etapa 8] Cena de avaliação visual dos assets aprovados em conceito.")

func enquadrar(nome: String) -> void:
	vista=nome
	if nome=="Geral":
		$Clareira1500/Enquadramentos/Geral.make_current()
		return
	var camera: Camera3D=$CameraAvaliacao
	var alvo: Vector3=$CentroAgricola.position+Vector3(0,.75,.2)
	var deslocamento:=Vector3(-6,5.2,7.3)
	if nome=="Pesca":
		alvo=$CentroPesca.position+Vector3(0,1,.3)
		deslocamento=Vector3(-4.6,3.4,5.7)
	elif nome=="Costas":
		alvo=$CentroPesca.position+Vector3(0,1,0)
		deslocamento=Vector3(4.3,3.4,-5.7)
	camera.position=alvo+deslocamento
	camera.look_at(alvo)
	camera.make_current()

func definir_estagio(valor: int) -> void:
	$CentroAgricola/Mandioca.definir_estagio(valor)
	$CentroAgricola/Milho.definir_estagio(valor)

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	match e.physical_keycode:
		KEY_1: enquadrar("Geral")
		KEY_2: enquadrar("Roca")
		KEY_3: enquadrar("Pesca")
		KEY_4: enquadrar("Costas")
		KEY_Z: definir_estagio(0)
		KEY_X: definir_estagio(1)
		KEY_C: definir_estagio(2)
		KEY_N:
			noite=not noite
			luz.aplicar(23 if noite else 16)
		_: return
	get_viewport().set_input_as_handled()
