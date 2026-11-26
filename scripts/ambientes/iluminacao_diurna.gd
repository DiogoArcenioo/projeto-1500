extends Node
## Condições de luz dos mesmos assets aprovados; sem relógio próprio.
## Paleta pensada em horários: alvorada rosada com névoa baixa, manhã limpa,
## meio-dia de sombras azuladas, hora dourada longa e noite enluarada com
## a fogueira como centro de calor.
const HORAS := [0.0, 5.0, 6.0, 7.0, 9.0, 12.0, 16.0, 17.6, 18.4, 19.2, 24.0]
const ENERGIA := [0.0, 0.0, 0.3, 1.4, 2.4, 2.7, 2.6, 2.0, 1.0, 0.0, 0.0]
const COR_SOL := ["7183b1", "a593b3", "ffa070", "ffc98f", "ffecce", "fff4de", "ffd18c", "ffbd78", "ff9558", "8a7fb8", "7183b1"]
const AMBIENTE := ["3f5a8c", "566a99", "b39aa8", "a9bfc6", "9ec8d6", "a2cde2", "a0c4cf", "c2a79c", "a5829c", "5b6aa0", "3f5a8c"]
const ENERGIA_AMBIENTE := [0.34, 0.34, 0.42, 0.52, 0.58, 0.6, 0.57, 0.52, 0.44, 0.35, 0.34]
const TOPO_CEU := ["070f24", "1a2546", "4b5f8f", "5c95b8", "3f8fc0", "3584b8", "3d86b0", "5a7aa0", "4f4f86", "1a2244", "070f24"]
const HORIZONTE := ["1c2c48", "4a5578", "f0a478", "f3d1aa", "d9e6d6", "cfe2dc", "e6dcb0", "f5bb7d", "f08a5a", "5b4f78", "1c2c48"]
## Névoa: densa na alvorada, quase limpa ao meio-dia, dourada no fim da tarde.
const NEVOA := [0.0040, 0.0055, 0.0100, 0.0080, 0.0038, 0.0025, 0.0028, 0.0032, 0.0036, 0.0040, 0.0040]
const COR_NEVOA := ["4a6290", "6f7fa6", "eac0ac", "efd8bf", "c7d8c8", "bdd2c6", "e0d6b4", "ecc89e", "d8a690", "5d6290", "4a6290"]
const EXPOSICAO := [1.25, 1.2, 1.1, 1.05, 1.0, 0.98, 1.0, 1.04, 1.1, 1.2, 1.25]
var clareira: Node3D
var sol: DirectionalLight3D
var luar: DirectionalLight3D
var contorno: DirectionalLight3D
var ambiente: Environment
var ceu: ProceduralSkyMaterial

func configurar(cenario: Node3D) -> void:
	clareira = cenario
	sol = clareira.get_node("SolDourado") as DirectionalLight3D
	var atmosfera := clareira.get_node("Atmosfera") as WorldEnvironment
	atmosfera.environment = atmosfera.environment.duplicate(true)
	ambiente = atmosfera.environment
	ceu = ambiente.sky.sky_material as ProceduralSkyMaterial
	ceu.sun_angle_max = 18.0
	ceu.sun_curve = 0.08
	luar = DirectionalLight3D.new()
	luar.name = "Luar"
	luar.rotation_degrees = Vector3(-52, 95, 0)
	luar.light_color = Color("a3b8dd")
	luar.light_energy = 0.0
	luar.light_angular_distance = 1.5
	luar.shadow_enabled = true
	luar.shadow_blur = 2.0
	luar.shadow_opacity = 0.75
	luar.directional_shadow_max_distance = 70.0
	clareira.add_child(luar)
	# Luz de contorno fria, sem sombra: separa copas, ocas e pessoas do chão.
	contorno = DirectionalLight3D.new()
	contorno.name = "LuzDeContorno"
	contorno.light_color = Color("a9d4ff")
	contorno.light_energy = 0.0
	contorno.light_specular = 0.25
	contorno.shadow_enabled = false
	contorno.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	clareira.add_child(contorno)

func interpolar(tabela: Array, i: int, t: float):
	if tabela[0] is String: return Color(tabela[i]).lerp(Color(tabela[i+1]), t)
	return lerpf(tabela[i], tabela[i+1], t)

func aplicar(hora: float) -> void:
	var h := fposmod(hora, 24.0)
	var i := 0
	while i < HORAS.size()-2 and h > HORAS[i+1]:
		i += 1
	var t := smoothstep(HORAS[i], HORAS[i+1], h)
	sol.light_energy = interpolar(ENERGIA, i, t)
	sol.light_color = interpolar(COR_SOL, i, t)
	# Arco do sol entre 6h e 19h; perto do horizonte a altura mínima mantém
	# sombras longas e rasantes em vez de iluminar por baixo.
	var altitude := sin(clampf((h-6.0)/13.0, 0.0, 1.0)*PI)*66.0
	altitude = maxf(altitude, 8.0)
	var azimute := -38.0+(h-16.0)*8.0
	sol.rotation_degrees = Vector3(-altitude, azimute, 0)
	sol.light_volumetric_fog_energy = lerpf(1.0, 1.5, 1.0-clampf((altitude-8.0)/40.0, 0.0, 1.0))
	ambiente.ambient_light_color = interpolar(AMBIENTE, i, t)
	ambiente.ambient_light_energy = interpolar(ENERGIA_AMBIENTE, i, t)
	ambiente.tonemap_exposure = interpolar(EXPOSICAO, i, t)
	ceu.sky_top_color = interpolar(TOPO_CEU, i, t)
	ceu.sky_horizon_color = interpolar(HORIZONTE, i, t)
	ceu.ground_horizon_color = ceu.sky_horizon_color.darkened(0.12)
	var dia := clampf(sol.light_energy/2.6, 0.0, 1.0)
	var noite := 1.0-clampf(sol.light_energy/0.6, 0.0, 1.0)
	luar.light_energy = noite*0.55
	luar.visible = noite > 0.01
	contorno.rotation_degrees = Vector3(-24, azimute+180.0, 0)
	contorno.light_color = Color("7f95c4").lerp(Color("a9d4ff"), dia)
	contorno.light_energy = lerpf(0.16, 0.38, dia)
	clareira.set("intensidade_fogo_base", lerpf(6.2, 2.6, dia))
	var nevoa: Color = interpolar(COR_NEVOA, i, t)
	ambiente.fog_light_color = nevoa
	ambiente.volumetric_fog_albedo = nevoa.lerp(Color.WHITE, 0.25)
	ambiente.volumetric_fog_density = interpolar(NEVOA, i, t)
	ambiente.glow_intensity = lerpf(0.9, 0.55, dia)
	var raios := clareira.get_node("RaiosEntreAsCopas")
	for raio: MeshInstance3D in raios.get_children():
		(raio.material_override as ShaderMaterial).set_shader_parameter("intensidade_luz", dia)
