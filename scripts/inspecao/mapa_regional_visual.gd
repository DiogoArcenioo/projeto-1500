extends Control
## Prévia visual isolada. A revelação V serve à inspeção do asset.
signal regiao_selecionada(indice: int)
const Regioes=preload("res://scripts/partida/regioes.gd")
const TAMANHO:=Regioes.TAMANHO
var conhecimento: Dictionary=Regioes.iniciais()
const SEMENTE:=1506
var arte: Texture2D
var nevoa:=NoiseTexture2D.new()
var regioes: Array[Dictionary]=[]
var zoom:=1.0
var centro:=Vector2(.45,.59)*TAMANHO
var mostrar_tudo:=false
var selecionada:=21
var apontada:=-1
var arrastando:=false
var inicio_clique:=Vector2.ZERO
var distancia_arraste:=0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	arte=load("res://assets/ui/mapa/regiao_ilustrada.png")
	var ruido:=FastNoiseLite.new()
	ruido.seed=SEMENTE
	ruido.frequency=.012
	ruido.fractal_octaves=4
	nevoa.noise=ruido
	nevoa.width=512
	nevoa.height=512
	nevoa.seamless=true
	var gradiente:=Gradient.new()
	gradiente.set_color(0,Color("112c26"))
	gradiente.set_color(1,Color("294e3c"))
	nevoa.color_ramp=gradiente
	nevoa.changed.connect(queue_redraw)
	gerar_regioes()
	resized.connect(limitar)
	gui_input.connect(entrada)
	limitar()

func gerar_regioes() -> void:
	regioes=Regioes.definicoes().duplicate(true)
	aplicar_conhecimento(conhecimento)

func aplicar_conhecimento(novo: Dictionary) -> void:
	conhecimento=novo
	for r: Dictionary in regioes:
		r.conhecida=int(conhecimento[str(r.id)])>0
	queue_redraw()

func transformar(p: Vector2) -> Vector2:
	return (p-centro)*zoom+size*.5

func mundo(p: Vector2) -> Vector2:
	return (p-size*.5)/zoom+centro

func zoom_em(fator: float,pos: Vector2) -> void:
	var antes:=mundo(pos)
	zoom=clampf(zoom*fator,zoom_minimo(),1.5)
	centro=antes-(pos-size*.5)/zoom
	limitar()

func zoom_minimo() -> float:
	return minf(size.x/TAMANHO.x,size.y/TAMANHO.y)

func enquadrar_completo() -> void:
	zoom=zoom_minimo()
	centro=TAMANHO*.5
	limitar()

func centralizar() -> void:
	centro=Vector2(.45,.59)*TAMANHO
	zoom=maxf(zoom_minimo(),minf(size.x/1250,size.y/850))
	limitar()

func limitar() -> void:
	zoom=clampf(zoom,zoom_minimo(),1.5)
	for eixo in range(2):
		var margem: float=size[eixo]/(2*zoom)
		centro[eixo]=clampf(centro[eixo],minf(margem,TAMANHO[eixo]*.5),maxf(TAMANHO[eixo]-margem,TAMANHO[eixo]*.5))
	queue_redraw()

func regiao_em(p: Vector2) -> int:
	var local:=mundo(p)
	if not Rect2(Vector2.ZERO,TAMANHO).has_point(local): return -1
	for r: Dictionary in regioes:
		if Geometry2D.is_point_in_polygon(local,r.poligono): return r.id
	return -1

func cancelar_arraste() -> void:
	arrastando=false

func entrada(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and e.pressed:
			zoom_em(1.18 if e.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.18,e.position)
		elif e.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
			if e.pressed:
				arrastando=true
				inicio_clique=e.position
				distancia_arraste=0
			else:
				if arrastando and distancia_arraste<5 and e.button_index==MOUSE_BUTTON_LEFT:
					var indice:=regiao_em(e.position)
					if indice>=0:
						selecionada=indice
						regiao_selecionada.emit(indice)
				arrastando=false
	elif e is InputEventMouseMotion:
		if arrastando:
			distancia_arraste+=e.relative.length()
			centro-=e.relative/zoom
			limitar()
		apontada=regiao_em(e.position)
		tooltip_text=dica(apontada)
	queue_redraw()
	accept_event()

func dica(indice: int) -> String:
	if indice<0: return ""
	if mostrar_tudo and int(conhecimento[str(indice)])==0:
		return regioes[indice].nome+"\nRegião apresentada para inspeção da arte."
	return Regioes.informacoes(indice,conhecimento)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("102e27"))
	if not arte: return
	var destino:=Rect2(transformar(Vector2.ZERO),TAMANHO*zoom)
	draw_texture_rect(arte,destino,false)
	for r: Dictionary in regioes:
		var pontos:=PackedVector2Array()
		var uv:=PackedVector2Array()
		for p in r.poligono:
			pontos.append(transformar(p))
			uv.append(p/TAMANHO)
		var fechado:=pontos.duplicate()
		fechado.append(pontos[0])
		if not mostrar_tudo and not r.conhecida:
			draw_polygon(pontos,PackedColorArray([Color.WHITE]),uv,nevoa)
			# Sombras suaves dentro da área encoberta, sem revelar o terreno.
			for j in range(5):
				draw_polyline(fechado,Color(.055,.12,.09,.05),float(5-j)*8*zoom,true)
		else:
			draw_polyline(fechado,Color(.85,.73,.40,.40),1.2,true)
			if r.id==selecionada:
				draw_colored_polygon(pontos,Color(.94,.71,.24,.10))
				draw_polyline(fechado,Color("f2c775"),2.3,true)
	for r: Dictionary in regioes:
		var visivel: bool=mostrar_tudo or r.conhecida
		if not visivel and not vizinha_conhecida(r): continue
		var texto: String=r.nome if visivel else "?"
		if zoom<.38 and not visivel: continue
		etiqueta(transformar(r.pos),texto,visivel,r.id==selecionada)
	# Rotas são visíveis apenas entre os pontos locais conhecidos.
	for par in [[20,14],[20,21]]:
		var a:=transformar(regioes[par[0]].pos)
		var b:=transformar(regioes[par[1]].pos)
		for i in range(1,13):
			draw_circle(a.lerp(b,float(i)/13),1.5,Color("e6d5a2"))

func vizinha_conhecida(r: Dictionary) -> bool:
	for outra: Dictionary in regioes:
		if outra.conhecida and r.pos.distance_to(outra.pos)<TAMANHO.x*.235:
			return true
	return false

func etiqueta(p: Vector2,valor: String,conhecida: bool,ativa: bool) -> void:
	var fonte:=get_theme_default_font()
	var tamanho: int=(14 if zoom<.45 else 17) if conhecida else 22
	var medida:=fonte.get_string_size(valor,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho)
	var ret:=Rect2(p-Vector2(medida.x*.5+12,15),Vector2(medida.x+24,32))
	if not ret.intersects(Rect2(Vector2.ZERO,size)): return
	if conhecida:
		# Plaquinha de casca interna; a ativa recebe a lasca clara.
		draw_style_box(get_theme_stylebox("hover" if ativa else "normal","Button"),ret)
	else:
		var estilo:=StyleBoxFlat.new()
		estilo.bg_color=Color("14352d")
		estilo.set_corner_radius_all(14)
		draw_style_box(estilo,ret)
	draw_string(fonte,ret.position+Vector2(12,23),valor,HORIZONTAL_ALIGNMENT_LEFT,-1,tamanho,Color("35271b") if conhecida else Color("f2e6c9"))
