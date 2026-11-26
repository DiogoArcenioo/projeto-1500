extends SceneTree
## Miniaturas dos menus renderizadas a partir dos modelos reais (modo gráfico).
## Uso: godot --path . -s tools/gerar_miniaturas_construcoes.gd
const PASTA:="res://assets/ui/construcoes/"
const MODELOS:={
	"oca":"res://scenes/construcoes/oca_nivel_1.tscn",
	"coleta":"res://scenes/construcoes/centro_coleta.tscn",
	"agricultura":"res://scenes/construcoes/centro_agricola_nivel_1.tscn",
	"pesca":"res://scenes/construcoes/centro_pesca_nivel_1.tscn",
	"caca":"res://scenes/construcoes/centro_caca_nivel_1.tscn",
	"expedicao":"res://assets/models/animais/capivara.glb",
}
const TAMANHO:=Vector2i(320,224)

func _initialize() -> void: executar.call_deferred()

func caixa(no: Node) -> AABB:
	var total:=AABB()
	var primeiro:=true
	for v: VisualInstance3D in no.find_children("*","VisualInstance3D",true,false):
		if v is Light3D or not v.visible: continue
		var b:=v.global_transform*v.get_aabb()
		if b.size.length()<.001: continue
		total=b if primeiro else total.merge(b)
		primeiro=false
	return total

func executar() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Miniaturas precisam de renderização gráfica.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(PASTA)
	var vp:=SubViewport.new()
	vp.size=TAMANHO
	vp.transparent_bg=true
	vp.own_world_3d=true
	vp.msaa_3d=Viewport.MSAA_8X
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var mundo:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0,0,0,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("c9d9e6")
	env.ambient_light_energy=.75
	env.tonemap_mode=Environment.TONE_MAPPER_ACES
	env.adjustment_enabled=true
	env.adjustment_saturation=1.12
	mundo.environment=env
	vp.add_child(mundo)
	var sol:=DirectionalLight3D.new()
	sol.rotation_degrees=Vector3(-42,-30,0)
	sol.light_energy=2.3
	sol.light_color=Color("ffe2b4")
	sol.shadow_enabled=true
	vp.add_child(sol)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(camera)
	for nome: String in MODELOS:
		var modelo: Node3D=load(MODELOS[nome]).instantiate()
		vp.add_child(modelo)
		if nome=="expedicao": modelo.rotation_degrees.y=-55
		await process_frame
		var b:=caixa(modelo)
		var centro:=b.get_center()
		var direcao:=Vector3(1.0,.85,1.25).normalized()
		camera.position=centro+direcao*(b.size.length()*2+5)
		camera.look_at(centro)
		# Tamanho ortográfico pela maior projeção da caixa na tela.
		var base:=camera.global_transform.basis
		var w:=0.0
		var h:=0.0
		for i in 8:
			var canto:=b.get_endpoint(i)-centro
			w=maxf(w,absf(canto.dot(base.x)))
			h=maxf(h,absf(canto.dot(base.y)))
		camera.size=maxf(h*2,w*2*float(TAMANHO.y)/TAMANHO.x)*1.08
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(PASTA+nome+".png")
		print("Miniatura ",nome," ",b.size)
		modelo.queue_free()
		await process_frame
	# Comunidade: dois retratos reais lado a lado.
	var img:=Image.create(TAMANHO.x,TAMANHO.y,false,Image.FORMAT_RGBA8)
	for par in [["mulher_02",Vector2i(20,0)],["homem_01",Vector2i(150,0)]]:
		var r:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/retratos/%s.png"%par[0]))
		r.convert(Image.FORMAT_RGBA8)
		r.resize(int(r.get_width()*TAMANHO.y/float(r.get_height())),TAMANHO.y,Image.INTERPOLATE_LANCZOS)
		img.blend_rect(r,Rect2i(Vector2i.ZERO,r.get_size()),par[1])
	img.save_png(PASTA+"comunidade.png")
	# Mapa: recorte da arte regional.
	var mapa:=Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/mapa/regiao_ilustrada.png"))
	var lado:=mini(mapa.get_width(),mapa.get_height())
	var recorte:=mapa.get_region(Rect2i((mapa.get_width()-lado)/2,(mapa.get_height()-lado)/2,lado,int(lado*.7)))
	recorte.resize(TAMANHO.x,TAMANHO.y,Image.INTERPOLATE_LANCZOS)
	recorte.convert(Image.FORMAT_RGBA8)
	arredondar(recorte,26)
	recorte.save_png(PASTA+"mapa.png")
	print("Miniaturas prontas")
	quit()

func arredondar(img: Image,raio: float) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c:=Vector2(clampf(x+.5,raio,img.get_width()-raio),clampf(y+.5,raio,img.get_height()-raio))
			var d:=Vector2(x+.5,y+.5).distance_to(c)-raio
			var p:=img.get_pixel(x,y)
			if d>-3: p=p.lerp(Color("4f2f18"),.85)
			p.a=clampf(.5-d,0,1)
			img.set_pixel(x,y,p)
