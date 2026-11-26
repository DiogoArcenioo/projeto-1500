extends RefCounted
## Os GLBs aprovados usam +Z como frente. Orientação só no plano do chão.
static func centro_equipe(equipe: Array) -> Variant:
	var soma:=Vector3.ZERO
	var quantidade:=0
	for pessoa in equipe:
		if is_instance_valid(pessoa) and pessoa is Node3D:
			soma+=pessoa.global_position
			quantidade+=1
	return soma/quantidade if quantidade>0 else null
static func encarar(modelo: Node3D,alvo: Vector3) -> bool:
	var delta:=alvo-modelo.global_position
	delta.y=0
	if delta.length_squared()<.000001: return false
	modelo.look_at(modelo.global_position+delta,Vector3.UP,true)
	return true
static func preparar(animal: Node3D,equipe: Array) -> bool:
	var centro: Variant=centro_equipe(equipe)
	if centro==null: return false
	var orientou:=encarar(animal,centro)
	for pessoa in equipe:
		if is_instance_valid(pessoa) and pessoa is Node3D: encarar(pessoa,animal.global_position)
	return orientou
