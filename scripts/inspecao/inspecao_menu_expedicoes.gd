extends Node3D
var luz:=preload("res://scripts/ambientes/iluminacao_diurna.gd").new()
func _ready() -> void:
	add_child(luz)
	luz.configurar($Clareira1500)
	luz.aplicar(15.5)
	var solo=load("res://scripts/ambientes/aldeia_visual.gd")
	$CentroCaca.position=solo.no_solo(Vector2(6,-1))
	$Oca.position=solo.no_solo(Vector2(-5,-4))
	print("[Menu de casca] Prévia sem envio ou salvamento. F1 caça / F2 pesca / F3 coleta. 1 compacto, 2 equipe, 3 equipamento, 4 confirmação, Esc recolhe.")

func mostrar_centro(tipo: String) -> void:
	$CentroCaca.visible=tipo=="caca"
	var anterior:=get_node_or_null("CentroAlternativo")
	if anterior:
		remove_child(anterior)
		anterior.queue_free()
	if tipo=="caca": return
	var caminho: String={"pesca":"res://scenes/construcoes/centro_pesca_nivel_1.tscn","coleta":"res://scenes/construcoes/centro_coleta.tscn"}[tipo]
	var centro: Node3D=load(caminho).instantiate()
	centro.name="CentroAlternativo"
	add_child(centro)
	centro.position=load("res://scripts/ambientes/aldeia_visual.gd").no_solo(Vector2(9.2,1.2) if tipo=="pesca" else Vector2(6,-1))
