extends Node3D
## Apresentação dos cultivos; a aldeia fornece espécie e estágio do estado persistido.
@export_enum("Mandioca","Milho") var especie: int = 0
@export_enum("Broto","Jovem","Maduro") var estagio: int = 2
var plantas: Array[Node3D]=[]

func _ready() -> void:
	definir_estagio(estagio)

func definir_estagio(valor: int) -> void:
	estagio=clampi(valor,0,2)
	for planta in plantas:
		remove_child(planta)
		planta.queue_free()
	plantas.clear()
	var nome: String=["mandioca","milho"][especie]
	var fase: String=["broto","jovem","maduro"][estagio]
	var modelo: PackedScene=load("res://assets/models/%s_%s.glb"%[nome,fase])
	for j in range(3):
		for i in range(3 if especie==0 else 2):
			var planta: Node3D=modelo.instantiate()
			add_child(planta)
			for malha: MeshInstance3D in planta.find_children("*","MeshInstance3D",true,false):
				var material:=malha.mesh.surface_get_material(0) as StandardMaterial3D
				if material: material.vertex_color_use_as_albedo=true
			planta.position=Vector3(i*(.70 if especie==0 else .90),.04,-j*.85)
			planta.scale=Vector3.ONE*(.84 if especie==0 else .94)
			plantas.append(planta)
