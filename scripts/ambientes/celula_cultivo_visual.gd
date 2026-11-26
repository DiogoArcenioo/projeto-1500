extends Node3D
var planta: Node3D
var assinatura:=""
var destaque: Node3D
func _ready() -> void:
	var borda:=MeshInstance3D.new()
	borda.name="SoloQuadrado"
	var forma:=BoxMesh.new()
	forma.size=Vector3(1,.045,1)
	borda.mesh=forma
	var terra:=StandardMaterial3D.new()
	terra.albedo_color=Color("68402a")
	terra.roughness=1
	borda.material_override=terra
	add_child(borda)
	var centro:=MeshInstance3D.new()
	var caixa:=BoxMesh.new()
	caixa.size=Vector3(.92,.055,.92)
	centro.mesh=caixa
	var revolvida:=StandardMaterial3D.new()
	revolvida.albedo_color=Color("a9673b")
	revolvida.roughness=1
	centro.material_override=revolvida
	add_child(centro)
	configurar("",0,0)

func configurar(especie: String,estagio: int,angulo: float) -> void:
	var chave:=str([especie,estagio])
	if chave!=assinatura:
		if is_instance_valid(planta):
			remove_child(planta)
			planta.queue_free()
		planta=null
		if especie=="":
			assinatura=chave
			return
		planta=load("res://assets/models/%s_%s.glb"%[especie,["broto","jovem","maduro"][clampi(estagio,0,2)]]).instantiate()
		add_child(planta)
		planta.position.y=.04
		planta.scale=Vector3.ONE*.85
		for m: MeshInstance3D in planta.find_children("*","MeshInstance3D",true,false):
			var mat:=m.mesh.surface_get_material(0) as StandardMaterial3D
			if mat: mat.vertex_color_use_as_albedo=true
		assinatura=chave
	if is_instance_valid(planta): planta.rotation.y=angulo

func definir_selecionada(valor: bool) -> void:
	if not is_instance_valid(destaque):
		if not valor: return
		destaque=Node3D.new()
		add_child(destaque)
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=Color("ffe08b")
		for i in range(4):
			var linha:=MeshInstance3D.new()
			var malha:=BoxMesh.new()
			malha.size=Vector3(1,.025,.045) if i<2 else Vector3(.045,.025,1)
			linha.mesh=malha
			linha.material_override=mat
			linha.position=Vector3(0,.065,-.48 if i==0 else .48) if i<2 else Vector3(-.48 if i==2 else .48,.065,0)
			destaque.add_child(linha)
	destaque.visible=valor
