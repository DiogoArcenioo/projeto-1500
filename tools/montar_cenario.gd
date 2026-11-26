extends SceneTree
const Terreno=preload("res://scripts/partida/terreno_construcao.gd")
## Monta uma cena editável com os modelos originais do Blender.

var raiz: Node3D

func adicionar(no: Node, nome: String, pai: Node = null) -> void:
	no.name = nome
	(pai if pai != null else raiz).add_child(no)
	no.owner = raiz

func _initialize() -> void:
	call_deferred("montar")

func montar() -> void:
	raiz = Node3D.new()
	raiz.name = "Clareira1500"
	root.add_child(raiz)
	raiz.set_script(load("res://scripts/ambientes/clareira.gd"))
	var paisagem := load("res://assets/models/clareira_1500.glb").instantiate() as Node3D
	adicionar(paisagem, "Paisagem")
	criar_ambiente()
	criar_raios()
	criar_rio()
	criar_fogo()
	var enquadramentos := Node3D.new()
	adicionar(enquadramentos, "Enquadramentos")
	for nome: String in ["Geral", "Fogueira", "Rio"]:
		var camera := Camera3D.new()
		adicionar(camera, nome, enquadramentos)
		camera.near = 0.15
		camera.far = 160.0
		camera.fov = 43.0
		var alvo := Vector3(0, 1.0, 0)
		if nome == "Geral":
			camera.position = Vector3(24, 34, 31)
			camera.fov = 40.0
			alvo = Vector3(1.5, 1.0, -2.5)
			camera.current = true
		elif nome == "Fogueira":
			camera.position = Vector3(7, 5.2, 8.5)
			alvo = Vector3(0, 0.65, 0)
		else:
			camera.position = Vector3(24, 12.0, 12)
			alvo = Vector3(16, 0.0, -6)
		camera.look_at(alvo)
	var cena := PackedScene.new()
	var erro := cena.pack(raiz)
	if erro == OK:
		erro = ResourceSaver.save(cena, "res://scenes/ambientes/clareira.tscn")
	print("CENA_SALVA: ", error_string(erro))
	quit(erro)

func criar_ambiente() -> void:
	var mundo := WorldEnvironment.new()
	adicionar(mundo, "Atmosfera")
	var ambiente := Environment.new()
	mundo.environment = ambiente
	ambiente.background_mode = Environment.BG_SKY
	var ceu := Sky.new()
	var material_ceu := ProceduralSkyMaterial.new()
	material_ceu.sky_top_color = Color("387d99")
	material_ceu.sky_horizon_color = Color("d5d6ae")
	material_ceu.ground_bottom_color = Color("354a49")
	material_ceu.ground_horizon_color = Color("bac2a3")
	material_ceu.sun_angle_max = 5.0
	ceu.sky_material = material_ceu
	ambiente.sky = ceu
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.ambient_light_color = Color("8dbdb8")
	ambiente.ambient_light_energy = 0.60
	ambiente.ambient_light_sky_contribution = 0.3
	ambiente.tonemap_mode = Environment.TONE_MAPPER_ACES
	ambiente.tonemap_exposure = 1.05
	ambiente.tonemap_white = 5.5
	ambiente.ssao_enabled = true
	ambiente.ssao_radius = 1.4
	ambiente.ssao_intensity = 1.6
	ambiente.ssao_power = 1.3
	ambiente.glow_enabled = true
	ambiente.glow_intensity = 0.55
	ambiente.glow_strength = 0.85
	ambiente.glow_hdr_threshold = 1.3
	ambiente.fog_enabled = true
	ambiente.fog_light_color = Color("a1bdb0")
	ambiente.fog_density = 0.0008
	ambiente.fog_aerial_perspective = 0.35
	ambiente.fog_sun_scatter = 0.3
	ambiente.volumetric_fog_enabled = true
	ambiente.volumetric_fog_density = 0.0035
	ambiente.volumetric_fog_albedo = Color("b8cab0")
	ambiente.volumetric_fog_length = 100.0
	ambiente.volumetric_fog_anisotropy = 0.62
	ambiente.volumetric_fog_ambient_inject = 0.22
	var sol := DirectionalLight3D.new()
	adicionar(sol, "SolDourado")
	sol.rotation_degrees = Vector3(-34, -38, 0)
	sol.light_color = Color("ffd18c")
	sol.light_energy = 2.6
	sol.light_angular_distance = 0.8
	sol.shadow_blur = 1.5
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 105
	sol.shadow_bias = 0.14
	sol.shadow_normal_bias = 2.5
	sol.directional_shadow_blend_splits = true
	sol.light_volumetric_fog_energy = 1.3
	for posicao: Vector3 in [Vector3(-16,1.0,-26),Vector3(22,1.0,-32)]:
		var nevoa := FogVolume.new()
		adicionar(nevoa, "NevoaDaMata" + str(raiz.get_child_count()))
		nevoa.position = posicao
		nevoa.size = Vector3(27,4.0,17)
		var mat := FogMaterial.new()
		mat.density = 0.032
		mat.albedo = Color("91b6aa")
		mat.height_falloff = 1.2
		nevoa.material = mat

func criar_raios() -> void:
	var grupo := Node3D.new()
	adicionar(grupo, "RaiosEntreAsCopas")
	var sol := raiz.get_node("SolDourado") as DirectionalLight3D
	var direcao := -sol.transform.basis.z.normalized()
	var lateral := Vector3(0.79,0,-0.61)
	var pontos_iniciais: Array[Vector3] = [Vector3(-11,16,8),Vector3(-7,16,7),Vector3(-18,17,0)]
	for i in range(pontos_iniciais.size()):
		var topo := pontos_iniciais[i]
		var fim := topo + direcao * ((topo.y-.3)/-direcao.y)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pontos := [topo-lateral*.22,topo+lateral*.22,fim-lateral*.95,topo+lateral*.22,fim+lateral*.95,fim-lateral*.95]
		var uvs := [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
		for j in range(6):
			st.set_uv(uvs[j])
			st.add_vertex(pontos[j])
		var raio := MeshInstance3D.new()
		adicionar(raio,"RaioSolar"+str(i),grupo)
		raio.mesh = st.commit()
		raio.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/shaders/raio_solar.gdshader")
		raio.material_override = mat

func centro_rio(y: float) -> float:
	return Terreno.centro_rio(-y)

func criar_rio() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(400):
		var y0 := -100.0 + i * 0.5
		var y1 := y0 + 0.5
		var l0 := Terreno.meia_largura_rio(-y0)
		var l1 := Terreno.meia_largura_rio(-y1)
		var a := Vector3(centro_rio(y0)-l0, -0.50, -y0)
		var b := Vector3(centro_rio(y0)+l0, -0.50, -y0)
		var c := Vector3(centro_rio(y1)-l1, -0.50, -y1)
		var d := Vector3(centro_rio(y1)+l1, -0.50, -y1)
		var pontos := [a, b, c, b, d, c]
		var uvs := [Vector2(0,i*.03),Vector2(1,i*.03),Vector2(0,(i+1)*.03),Vector2(1,i*.03),Vector2(1,(i+1)*.03),Vector2(0,(i+1)*.03)]
		for j in range(6):
			st.set_uv(uvs[j])
			st.set_normal(Vector3.UP)
			st.add_vertex(pontos[j])
	var agua := MeshInstance3D.new()
	adicionar(agua, "Rio")
	agua.mesh = st.commit()
	agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/agua_tropical.gdshader")
	agua.material_override = mat

func criar_lingua_fogo(pai: Node3D, nome: String, pos: Vector3, altura: float, raio: float, fase: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(9):
		for i in range(10):
			for par: Vector2i in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i,j+1),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var t := par.y / 9.0
				var a := par.x * TAU / 10.0 + t * 1.8 + fase
				var r := raio * pow(1.0-t, 0.8) * (0.65+sin(t*PI)*0.4)
				st.set_uv(Vector2(par.x/10.0,t))
				st.add_vertex(Vector3(cos(a)*r + sin(t*4+fase)*t*.12, t*altura, sin(a)*r))
	st.generate_normals()
	var lingua := MeshInstance3D.new()
	adicionar(lingua, nome, pai)
	lingua.position = pos
	lingua.mesh = st.commit()
	lingua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/chama.gdshader")
	mat.set_shader_parameter("fase", fase)
	if nome == "Nucleo":
		mat.set_shader_parameter("cor_base", Color("fff4bf"))
		mat.set_shader_parameter("cor_ponta", Color("ffbd3e"))
	lingua.material_override = mat

func criar_fogo() -> void:
	var fogo := Node3D.new()
	adicionar(fogo, "Fogueira")
	fogo.position.y = 0.24
	criar_lingua_fogo(fogo,"ChamaCentral",Vector3.ZERO,1.65,.30,0)
	criar_lingua_fogo(fogo,"ChamaEsquerda",Vector3(-.3,.01,.05),1.04,.25,2.0)
	criar_lingua_fogo(fogo,"ChamaDireita",Vector3(.29,.02,-.15),1.25,.23,4.0)
	criar_lingua_fogo(fogo,"Nucleo",Vector3(.06,.02,.2),.9,.17,5.0)
	var luz := OmniLight3D.new()
	adicionar(luz,"LuzDoFogo",fogo)
	luz.position.y = 0.85
	luz.light_color = Color("ff9f3f")
	luz.light_energy = 3.1
	luz.omni_range = 7.0
	luz.omni_attenuation = 1.4
	luz.shadow_enabled = true
	luz.shadow_caster_mask = 2
	var material_particula := StandardMaterial3D.new()
	material_particula.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_particula.albedo_color = Color("ffd35c")
	material_particula.emission_enabled = true
	material_particula.emission = Color("ffb743")
	material_particula.emission_energy_multiplier = 2.0
	var ponto := SphereMesh.new()
	ponto.radius = 0.023
	ponto.height = 0.046
	ponto.radial_segments = 4
	ponto.rings = 2
	ponto.material = material_particula
	var faiscas := CPUParticles3D.new()
	adicionar(faiscas,"Faiscas",fogo)
	faiscas.position.y = .5
	faiscas.amount = 24
	faiscas.lifetime = 2.8
	faiscas.mesh = ponto
	faiscas.direction = Vector3.UP
	faiscas.spread = 24
	faiscas.gravity = Vector3(0,.10,0)
	faiscas.initial_velocity_min = 0.6
	faiscas.initial_velocity_max = 1.1
	faiscas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	faiscas.emission_sphere_radius = .32
