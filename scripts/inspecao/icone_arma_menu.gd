extends Control
var tipo:="arco"
func _ready() -> void:
	custom_minimum_size=Vector2(180,76)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var c:=size*.5
	var madeira:=Color("92603a")
	var claro:=Color("ebc987")
	if tipo=="arco":
		var pontos:=PackedVector2Array()
		for i in range(25):
			var t:=float(i)/24
			pontos.append(c+Vector2(sin(PI*t)*37-12,(t-.5)*88))
		draw_polyline(pontos,madeira,7,true)
		draw_line(pontos[0],pontos[-1],claro,2,true)
		draw_line(c+Vector2(-26,8),c+Vector2(75,8),madeira,3,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(75,8),c+Vector2(62,1),c+Vector2(62,15)]),claro)
	else:
		draw_line(c+Vector2(-78,24),c+Vector2(66,-19),madeira,8,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(88,-26),c+Vector2(62,-28),c+Vector2(69,-8)]),claro)
		for i in range(5): draw_line(c+Vector2(46+i*4,-18),c+Vector2(49+i*4,-8),claro,2,true)
