extends Node3D
## Aprovação de modelos/animações e protótipo de UI; não usa partida ou salvamento.
const Iluminacao = preload("res://scripts/ambientes/iluminacao_diurna.gd")
const Animador = preload("res://scripts/ambientes/animador_morador.gd")
## T percorre os ofícios; cada pessoa começa num diferente.
const OFICIOS := ["coletar","capinar","plantar","pescar","artesanato","construir","conversar","olhar"]
var animadores: Array = []
var animacao: String = "Parado"
var oficio := 0
var vista: String = "Frente"
var iluminacao: Node
var noite: bool = false

func _ready() -> void:
	iluminacao = Iluminacao.new()
	add_child(iluminacao)
	iluminacao.configurar($Clareira1500)
	iluminacao.aplicar(16)
	$MenuVisual.hide()
	var rebatedor:=OmniLight3D.new()
	rebatedor.name="LuzDeInspecao"
	add_child(rebatedor)
	rebatedor.position=Vector3(-4.7,4.1,5.1)
	rebatedor.light_color=Color("ffebd9")
	rebatedor.light_energy=4.0
	rebatedor.omni_range=10
	rebatedor.omni_attenuation=.7
	preparar($Moradores)
	preparar($OcaNivel1)
	for pessoa: Node3D in $Moradores.get_children():
		animadores.append(Animador.new(pessoa,String(pessoa.name)))
	definir_animacao("Parado")
	definir_vista("Frente")
	print("[Revisão ETAPA 4] 1 geral (controles habituais) | 2 frente | 3 costas | 4 rosto | P parado | C caminhada | T ofícios (repetir troca) | Tab painel | H ocultar painel | N dia/noite")
	print("[Revisão ETAPA 4] Propostas visuais no portão B, dados ilustrativos. Nenhuma regra ou gravação de partida.")

func preparar(no: Node) -> void:
	if no is MeshInstance3D:
		(no as MeshInstance3D).layers = 3
	for filho in no.get_children():
		preparar(filho)

func definir_animacao(nome: String) -> void:
	if nome=="Trabalhar" and animacao=="Trabalhar": oficio+=1
	animacao = nome
	for i in range(animadores.size()):
		var clipe: String={"Parado":"parado","Andar":"andar"}.get(nome,OFICIOS[(oficio+i)%OFICIOS.size()])
		animadores[i].tocar(clipe,.4,i*1.3)

func definir_vista(nome: String) -> void:
	vista = nome
	for pessoa in $Moradores.get_children():
		pessoa.rotation.y=PI if nome=="Costas" else 0.0
	$LuzDeInspecao.visible=nome!="Geral" and not noite
	if nome == "Geral":
		($Clareira1500/Enquadramentos/Geral as Camera3D).make_current()
		return
	var camera := $CameraAvaliacao as Camera3D
	var centro := Vector3(-4.4, 1.05, 1.9)
	camera.fov = 36
	camera.position = centro + Vector3(-.30, 1.0, 8.7)
	if nome == "Rosto":
		centro = Vector3(-4.45, 1.57, 1.9)
		camera.position = centro + Vector3(-.25, .15, 2.6)
		camera.fov = 36
	camera.look_at(centro)
	camera.make_current()

func _process(delta: float) -> void:
	for animador in animadores: animador.avancar(delta)

func _unhandled_key_input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	match evento.physical_keycode:
		KEY_1: definir_vista("Geral")
		KEY_2: definir_vista("Frente")
		KEY_3: definir_vista("Costas")
		KEY_4: definir_vista("Rosto")
		KEY_P: definir_animacao("Parado")
		KEY_C: definir_animacao("Andar")
		KEY_T: definir_animacao("Trabalhar")
		KEY_TAB: $MenuVisual.definir_expandido(not $MenuVisual.expandido)
		KEY_H: $MenuVisual.visible = not $MenuVisual.visible
		KEY_N:
			noite = not noite
			iluminacao.aplicar(23 if noite else 16)
			$LuzDeInspecao.visible=vista!="Geral" and not noite
		_: return
	get_viewport().set_input_as_handled()
