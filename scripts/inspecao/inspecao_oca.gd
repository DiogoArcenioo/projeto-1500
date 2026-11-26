extends Node3D
## Cena de aprovação do asset. Não constrói casas nem altera a partida ou os saves.
const Iluminacao = preload("res://scripts/ambientes/iluminacao_diurna.gd")
@export_enum("Geral", "Frente", "Lateral", "Costas") var enquadramento_inicial: String = "Frente"
@export var iniciar_a_noite: bool = false
var iluminacao: Node
var enquadramento_atual: String
var _noite: bool = false

func _ready() -> void:
	iluminacao = Iluminacao.new()
	iluminacao.name = "IluminacaoDeInspecao"
	add_child(iluminacao)
	iluminacao.configurar($Clareira1500)
	preparar_sombras($OcaNivel1)
	definir_noite(iniciar_a_noite)
	definir_enquadramento(enquadramento_inicial)
	print("[Inspeção da oca] 1: câmera do jogo (WASD, zoom, meio+arraste, Q/E, R) | 2: frente | 3: lateral | 4: costas | N: dia/noite")
	print("[Inspeção da oca] Modelo visual no portão B; nenhuma construção ou gravação de partida é realizada.")

func preparar_sombras(no: Node) -> void:
	if no is MeshInstance3D:
		(no as MeshInstance3D).layers = 3
	for filho in no.get_children():
		preparar_sombras(filho)

func definir_enquadramento(nome: String) -> void:
	enquadramento_atual = nome
	if nome == "Geral":
		($Clareira1500/Enquadramentos/Geral as Camera3D).make_current()
		return
	var camera := $CameraAvaliacao as Camera3D
	var alvo: Vector3 = $OcaNivel1.position + Vector3(0,1.7,0)
	var deslocamento := Vector3(-6.4,4.8,8.0)
	if nome == "Lateral":
		deslocamento = Vector3(10.5,4.5,-.7)
	elif nome == "Costas":
		deslocamento = Vector3(-6.4,4.8,-8.0)
	camera.position = $OcaNivel1.position + deslocamento
	camera.look_at(alvo)
	camera.make_current()

func definir_noite(valor: bool) -> void:
	_noite = valor
	iluminacao.aplicar(23.0 if _noite else 16.0)

func _unhandled_key_input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	match evento.physical_keycode:
		KEY_1: definir_enquadramento("Geral")
		KEY_2: definir_enquadramento("Frente")
		KEY_3: definir_enquadramento("Lateral")
		KEY_4: definir_enquadramento("Costas")
		KEY_N: definir_noite(not _noite)
		_: return
	get_viewport().set_input_as_handled()
