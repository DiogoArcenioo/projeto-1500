extends Node
## Órbita elevada: o zoom muda o FOV sem atravessar as copas ou o terreno.
@export var caminho_camera: NodePath = NodePath("../Clareira1500/Enquadramentos/Geral")
@export var limites: Rect2 = Rect2(-8, -8, 26, 18)
@export_range(10.0, 50.0) var zoom_minimo: float = 22.0
@export_range(40.0, 70.0) var zoom_maximo: float = 50.0
@export var velocidade_deslocamento: float = 15.0
@export var velocidade_rotacao: float = 1.2
@export var suavidade: float = 10.0
var camera: Camera3D
var foco := Vector3(1.5, 1.0, -2.5)
var foco_alvo := Vector3(1.5, 1.0, -2.5)
var angulo: float = 0.0
var angulo_alvo: float = 0.0
var fov_alvo: float = 40.0
var _raio: float = 0.0
var _altura: float = 33.0
var _arrastando: bool = false
var _mouse_anterior := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = get_node(caminho_camera) as Camera3D
	var deslocamento := camera.position - foco
	_raio = Vector2(deslocamento.x, deslocamento.z).length()
	_altura = deslocamento.y
	angulo = atan2(deslocamento.x, deslocamento.z)
	angulo_alvo = angulo
	fov_alvo = camera.fov
	get_window().focus_exited.connect(_cancelar_arraste)

func _cancelar_arraste() -> void:
	_arrastando = false

func _input(evento: InputEvent) -> void:
	# A liberação precisa chegar mesmo quando o cursor termina sobre uma interface.
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_MIDDLE and not evento.pressed:
		_arrastando = false

func _unhandled_input(evento: InputEvent) -> void:
	if not camera.current:
		return
	if evento is InputEventMouse:
		var interface := get_viewport().gui_get_hovered_control()
		if interface != null and interface.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			if evento is InputEventMouseMotion:
				_mouse_anterior = evento.position
			return
	if evento is InputEventMouseButton:
		if evento.button_index == MOUSE_BUTTON_MIDDLE:
			_arrastando = evento.pressed
			_mouse_anterior = evento.position
			get_viewport().set_input_as_handled()
		elif evento.pressed and evento.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var sinal := -1.0 if evento.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			fov_alvo = clampf(fov_alvo + sinal * 2.0 * maxf(evento.factor, 1.0), zoom_minimo, zoom_maximo)
			get_viewport().set_input_as_handled()
	elif evento is InputEventMouseMotion and _arrastando:
		var plano := Plane(Vector3.UP, foco.y)
		var antes: Variant = plano.intersects_ray(camera.project_ray_origin(_mouse_anterior), camera.project_ray_normal(_mouse_anterior))
		var depois: Variant = plano.intersects_ray(camera.project_ray_origin(evento.position), camera.project_ray_normal(evento.position))
		if antes != null and depois != null:
			foco_alvo += antes - depois
			_limitar()
		_mouse_anterior = evento.position
		get_viewport().set_input_as_handled()
	elif evento.is_action_pressed("camera_recentrar"):
		recentrar()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not camera.current:
		return
	if get_viewport().gui_get_focus_owner() == null:
		var eixo := Input.get_vector("camera_esquerda", "camera_direita", "camera_cima", "camera_baixo")
		var direita := camera.global_basis.x
		var frente := -camera.global_basis.z
		direita.y = 0.0
		frente.y = 0.0
		foco_alvo += (direita.normalized() * eixo.x - frente.normalized() * eixo.y) * velocidade_deslocamento * delta * fov_alvo / 40.0
		angulo_alvo += Input.get_axis("camera_girar_esquerda", "camera_girar_direita") * velocidade_rotacao * delta
	_limitar()
	var fator := 1.0 - exp(-suavidade * delta)
	foco = foco.lerp(foco_alvo, fator)
	angulo = lerp_angle(angulo, angulo_alvo, fator)
	camera.fov = lerpf(camera.fov, fov_alvo, fator)
	camera.position = foco + Vector3(sin(angulo) * _raio, _altura, cos(angulo) * _raio)
	camera.look_at(foco)

func _limitar() -> void:
	angulo_alvo = wrapf(angulo_alvo, -PI, PI)
	foco_alvo.x = clampf(foco_alvo.x, limites.position.x, limites.end.x)
	foco_alvo.z = clampf(foco_alvo.z, limites.position.y, limites.end.y)

func recentrar() -> void:
	foco_alvo = Vector3(1.5, 1.0, -2.5)
	angulo_alvo = atan2(22.5, 33.5)
	fov_alvo = 40.0
	camera.make_current()

func serializar() -> Dictionary:
	return {"x": foco_alvo.x, "z": foco_alvo.z, "angulo": angulo_alvo, "fov": fov_alvo}

func restaurar(dados: Dictionary) -> void:
	camera.make_current()
	if dados.is_empty():
		recentrar()
	else:
		foco_alvo = Vector3(float(dados.x), 1.0, float(dados.z))
		angulo_alvo = float(dados.angulo)
		fov_alvo = clampf(float(dados.fov), zoom_minimo, zoom_maximo)
	_limitar()
	foco = foco_alvo
	angulo = angulo_alvo
	camera.fov = fov_alvo
	_arrastando = false
	_process(0.0)
