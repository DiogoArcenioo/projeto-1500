extends SceneTree
var total:=0
func _initialize() -> void: executar.call_deferred()
func executar() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Retratos precisam de renderização gráfica.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://assets/ui/retratos")
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(256,300)
	viewport.transparent_bg=true
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d=Viewport.MSAA_4X
	root.add_child(viewport)
	var ambiente:=WorldEnvironment.new()
	var env:=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color(0,0,0,0)
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("e4efdc")
	env.ambient_light_energy=.8
	ambiente.environment=env
	viewport.add_child(ambiente)
	var sol:=DirectionalLight3D.new()
	sol.rotation_degrees=Vector3(-25,-25,0)
	sol.light_energy=2.0
	sol.light_color=Color("ffe5bb")
	viewport.add_child(sol)
	var camera:=Camera3D.new()
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.size=.90
	camera.position=Vector3(0,1.63,3)
	viewport.add_child(camera)
	camera.look_at(Vector3(0,1.58,0))
	for sexo in ["homem","mulher"]:
		for n in range(1,5):
			var nome:="%s_%02d"%[sexo,n]
			var modelo: Node3D=load("res://assets/models/habitantes/%s.glb"%nome).instantiate()
			viewport.add_child(modelo)
			modelo.rotation.y=-.12
			for i in range(12): await process_frame
			await RenderingServer.frame_post_draw
			var r:=viewport.get_texture().get_image().save_png("res://assets/ui/retratos/%s.png"%nome)
			if r!=OK:
				push_error("Falha no retrato "+nome)
				quit(1)
				return
			total+=1
			viewport.remove_child(modelo)
			modelo.queue_free()
	viewport.queue_free()
	await process_frame
	print("RETRATOS: %d imagens dos modelos reais"%total)
	quit()
