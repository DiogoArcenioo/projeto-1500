extends Control
var inicio:=Vector2.ZERO
var fim:=Vector2.ZERO
var ativo:=false
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	if not ativo: return
	var ret:=Rect2(inicio,fim-inicio).abs()
	draw_rect(ret,Color(.45,.85,.65,.14),true)
	draw_rect(ret,Color("efd391"),false,2)
