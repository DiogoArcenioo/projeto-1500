extends Control
## Pictogramas vetoriais desenhados pelo Godot, com legenda no tooltip.
var tipo := ""

func _ready() -> void:
	custom_minimum_size=Vector2(25,25)
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var ouro:=Color("e9b867")
	var verde:=Color("a4bd53")
	# Medalhão escuro de casca: mantém o contraste sobre a fibra clara da barra.
	draw_circle(Vector2(12.5,12.5),13.5,Color("4a2d17"))
	draw_arc(Vector2(12.5,12.5),13.5,0,TAU,28,Color("8a5a31"),1.2,true)
	match tipo:
		"madeira":
			draw_line(Vector2(6,18),Vector2(18,7),ouro,9,true)
			draw_circle(Vector2(6,18),4,Color("bf7944"))
			draw_arc(Vector2(6,18),2,0,TAU,12,ouro,1,true)
		"pedra":
			draw_colored_polygon(PackedVector2Array([Vector2(3,16),Vector2(6,7),Vector2(16,4),Vector2(23,12),Vector2(18,21),Vector2(8,22)]),Color("bbc3bd"))
			draw_line(Vector2(6,7),Vector2(14,13),Color("e0e5da"),2,true)
		"fibras_vegetais":
			for i in range(4):
				draw_line(Vector2(4+i*3,22),Vector2(12+i*3,3),verde,2,true)
			draw_line(Vector2(5,13),Vector2(20,13),ouro,3,true)
		"vegetais","plantas_medicinais":
			var cor:=Color("dc7249") if tipo=="vegetais" else verde
			draw_colored_polygon(PackedVector2Array([Vector2(12,22),Vector2(3,15),Vector2(5,7),Vector2(13,4),Vector2(21,8),Vector2(22,15)]),cor)
			draw_line(Vector2(11,18),Vector2(15,3),verde,2,true)
		"carne":
			draw_circle(Vector2(13,13),9,Color("d47b68"))
			draw_circle(Vector2(15,11),4,Color("f5d7ad"))
			draw_arc(Vector2(13,13),9,.1,5.3,20,Color("f1b091"),2,true)
		"peixe":
			draw_colored_polygon(PackedVector2Array([Vector2(2,12),Vector2(8,6),Vector2(17,7),Vector2(20,11),Vector2(25,6),Vector2(25,20),Vector2(20,16),Vector2(9,20)]),Color("65bdb8"))
			draw_circle(Vector2(7,12),1.5,Color("143f35"))
		"couro":
			draw_colored_polygon(PackedVector2Array([Vector2(4,3),Vector2(10,6),Vector2(17,6),Vector2(23,3),Vector2(21,10),Vector2(21,17),Vector2(23,23),Vector2(15,20),Vector2(9,21),Vector2(3,23),Vector2(6,16),Vector2(6,9)]),Color("bd8850"))
		"populacao":
			draw_circle(Vector2(9,7),3,ouro)
			draw_circle(Vector2(18,8),2.5,ouro)
			draw_style_box(caixa_pessoa(),Rect2(4,12,10,10))
			draw_style_box(caixa_pessoa(),Rect2(15,13,7,8))

func caixa_pessoa() -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color("e9b867")
	s.set_corner_radius_all(3)
	return s
