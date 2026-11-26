extends Node3D
## Aprovação de modelos/animações e protótipo de UI; não usa partida ou salvamento.
const Iluminacao = preload("res://scripts/ambientes/iluminacao_diurna.gd")
var jogadores: Array[AnimationPlayer] = []
var animacao: String = "Parado"
var vista: String = "Frente"
var iluminacao: Node
var noite: bool = false
var malhas: Array[MeshInstance3D] = []
var fase := 0.0

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
	definir_animacao("Parado")
	definir_vista("Frente")
	print("[Revisão ETAPA 4] 1 geral (controles habituais) | 2 frente | 3 costas | 4 rosto | P parado | C caminhada | T trabalho | Tab painel | H ocultar painel | N dia/noite")
	print("[Revisão ETAPA 4] Propostas visuais no portão B, dados ilustrativos. Nenhuma regra ou gravação de partida.")

func preparar(no: Node) -> void:
	if no is MeshInstance3D:
		(no as MeshInstance3D).layers = 3
		if no.get_blend_shape_count()==3: malhas.append(no)
	if no is AnimationPlayer:
		jogadores.append(no as AnimationPlayer)
	for filho in no.get_children():
		preparar(filho)

func definir_animacao(nome: String) -> void:
	animacao = nome
	fase=0
	for jogador in jogadores:
		for chave: String in jogador.get_animation_list():
			if chave == nome or chave.ends_with("/" + nome):
				jogador.get_animation(chave).loop_mode = Animation.LOOP_LINEAR
				jogador.play(chave)
				break

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
	fase+=delta
	for i in range(malhas.size()):
		var passo:=sin(fase*7+i*.7) if animacao=="Andar" else 0.0
		malhas[i].set("blend_shapes/Passo_E",maxf(0,passo))
		malhas[i].set("blend_shapes/Passo_D",maxf(0,-passo))
		malhas[i].set("blend_shapes/Coletar",.52+.4*sin(fase*2.2+i) if animacao=="Trabalhar" else 0.0)

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
