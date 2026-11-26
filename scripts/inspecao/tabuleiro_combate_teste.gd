extends Control
signal celula_clicada(p: Vector2i)
var combate: Dictionary={}
var selecionada:=Vector2i(-1,-1)
const B=preload("res://scripts/partida/combate.gd")
const CELULA:=60.0
func _ready() -> void:
	custom_minimum_size=Vector2.ONE*CELULA*8
	mouse_filter=Control.MOUSE_FILTER_STOP
func _draw() -> void:
	for x in range(8):
		for z in range(8):
			var p:=Vector2i(x,z)
			var cor:=Color("223b31") if (x+z)%2==0 else Color("2d493b")
			if not combate.is_empty():
				if B.contem(combate.bloqueios,p): cor=Color("65716b")
				elif B.contem(combate.aguas,p): cor=Color("326c7b")
				elif B.contem(combate.coberturas,p): cor=Color("8a7d49")
			var caixa:=Rect2(Vector2(x,z)*CELULA,Vector2.ONE*(CELULA-1))
			draw_rect(caixa,cor)
			if p==selecionada: draw_rect(caixa.grow(-2),Color("f6d992"),false,3)
	if combate.is_empty(): return
	var ativo:=B.atual(combate)
	for i in range(combate.atores.size()):
		var a: Dictionary=combate.atores[i]
		var centro: Vector2=(Vector2(a.x,a.z)+Vector2.ONE*.5)*CELULA
		var cor:=Color("52b6ab") if a.lado=="equipe" else Color("d78950")
		if a.vida<=0: cor=Color("5e5f5e")
		draw_rect(Rect2(centro-Vector2.ONE*18,Vector2.ONE*36),cor)
		if not ativo.is_empty() and ativo.id==a.id: draw_rect(Rect2(centro-Vector2.ONE*23,Vector2.ONE*46),Color("f8d791"),false,2)
		draw_string(ThemeDB.fallback_font,centro+Vector2(-10,6),"A" if a.lado=="animal" else str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("101c17"))
		var barra:=Rect2(centro+Vector2(-22,24),Vector2(44,5))
		draw_rect(barra,Color("141c17"))
		draw_rect(Rect2(barra.position,Vector2(44*float(a.vida)/a.vida_max,5)),Color("99bc69"))
func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
		var p:=Vector2i((e.position/CELULA).floor())
		if B.dentro(p):
			selecionada=p
			celula_clicada.emit(p)
			queue_redraw()
			accept_event()
