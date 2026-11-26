extends Node3D
const Solo=preload("res://scripts/ambientes/aldeia_visual.gd")
var luz:=preload("res://scripts/ambientes/iluminacao_diurna.gd").new()
var noite:=false
var animador: AnimationPlayer
func _ready() -> void:
	add_child(luz)
	luz.configurar($Clareira1500)
	luz.aplicar(16)
	$Capivara.position=Solo.no_solo(Vector2(-3,-1))
	$Morador.position=Solo.no_solo(Vector2(-4.1,-1.8))
	$Morador.hide()
	for modelo in [$Capivara,$Morador]:
		for m: MeshInstance3D in modelo.find_children("*","MeshInstance3D",true,false): m.layers=3
	var players: Array[Node]=$Capivara.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty(): animador=players[0]
	enquadrar("Frente")
	print("[Capivara A] 1 geral, 2 frente, 3 lateral, 4 costas, 5 escala com morador; P parada, C andar, F correr, N tarde/noite. Inspeção isolada, sem caça ou salvamento.")
	if animador: print("[Capivara] Animações importadas: ",animador.get_animation_list())
func enquadrar(vista: String) -> void:
	$Morador.visible=vista=="Escala"
	if vista=="Geral":
		$Clareira1500/Enquadramentos/Geral.make_current()
		return
	var cam: Camera3D=$CameraAvaliacao
	var alvo: Vector3=$Capivara.position+Vector3(0,.38,0)
	var deslocamento: Vector3={"Frente":Vector3(1.35,.55,1.8),"Lateral":Vector3(2.25,.35,0),"Costas":Vector3(1.3,.55,-1.8),"Escala":Vector3(2.7,1.4,4.3)}[vista]
	if vista=="Escala": alvo+=Vector3(-.55,.28,-.35)
	cam.position=alvo+deslocamento
	cam.look_at(alvo)
	cam.make_current()
func animar(nome: String) -> void:
	if not animador: return
	for a in animador.get_animation_list():
		if str(a).contains(nome):
			animador.get_animation(a).loop_mode=Animation.LOOP_LINEAR
			animador.play(a)
			return
func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	match e.physical_keycode:
		KEY_1: enquadrar("Geral")
		KEY_2: enquadrar("Frente")
		KEY_3: enquadrar("Lateral")
		KEY_4: enquadrar("Costas")
		KEY_5: enquadrar("Escala")
		KEY_P: animar("parada")
		KEY_C: animar("andar")
		KEY_F: animar("correr")
		KEY_N:
			noite=not noite
			luz.aplicar(23 if noite else 16)
		_: return
	get_viewport().set_input_as_handled()
