@tool
extends Node3D
## Apresentação do cenário. O tempo estratégico pertence ao estado da partida.

var _tempo_visual: float = 0.0
var intensidade_fogo_base: float = 3.1
@export_enum("Geral", "Fogueira", "Rio") var enquadramento_inicial: String = "Geral"
@export_enum("Completa", "Leve") var qualidade_de_inspecao: String = "Completa"

func _ready() -> void:
	var paisagem := get_node_or_null("Paisagem")
	if paisagem != null:
		preparar_folhas(paisagem)
	var camera := get_node_or_null("Enquadramentos/" + enquadramento_inicial) as Camera3D
	if camera != null:
		camera.make_current()
	var atmosfera := get_node_or_null("Atmosfera") as WorldEnvironment
	if atmosfera != null and qualidade_de_inspecao == "Leve":
		atmosfera.environment = atmosfera.environment.duplicate()
		atmosfera.environment.volumetric_fog_enabled = false
		atmosfera.environment.ssao_enabled = false
		atmosfera.environment.ssil_enabled = false
		var sol := get_node_or_null("SolDourado") as DirectionalLight3D
		if sol != null:
			sol.light_angular_distance = 0.0

func preparar_folhas(no: Node) -> void:
	if no is MeshInstance3D:
		var malha := no as MeshInstance3D
		var nome := String(no.name)
		if nome in ["Lenha", "Lenha_Miolo", "Pedras_Fogueira", "Brasas"]:
			malha.layers = 3
		if nome == "Solo_TerraViva":
			var solo := ShaderMaterial.new()
			solo.shader = load("res://assets/shaders/solo_vivo.gdshader")
			malha.material_override = solo
		if nome.begins_with("Copas") or nome in ["Folhas_Largas", "Samambaias", "Bromelias", "Palmeiras_Folhas", "Capim", "Flores_Coral", "Flores_Ouro"]:
			var original := malha.mesh.surface_get_material(0) as StandardMaterial3D
			if original != null:
				var mat := ShaderMaterial.new()
				mat.shader = load("res://assets/shaders/vegetacao_vento.gdshader")
				mat.set_shader_parameter("cor_folha", original.albedo_color)
				mat.set_shader_parameter("amplitude", 0.035 if nome.begins_with("Copas") else 0.065)
				malha.set_surface_override_material(0, mat)
		if nome == "Brasas":
			var brasa := StandardMaterial3D.new()
			brasa.albedo_color = Color("ad3923")
			brasa.emission_enabled = true
			brasa.emission = Color("ff5a15")
			brasa.emission_energy_multiplier = 2.5
			malha.material_override = brasa
	for filho in no.get_children():
		preparar_folhas(filho)

func _process(delta: float) -> void:
	_tempo_visual += delta
	RenderingServer.global_shader_parameter_set("tempo_visual", _tempo_visual)
	var luz := get_node_or_null("Fogueira/LuzDoFogo") as OmniLight3D
	if luz != null:
		luz.light_energy = intensidade_fogo_base + sin(_tempo_visual * 6.3) * 0.22 + sin(_tempo_visual * 10.1) * 0.10
