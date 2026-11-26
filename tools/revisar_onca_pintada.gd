extends SceneTree
## Verifica o GLB importado e captura o modelo na iluminação real do jogo.
const Cena = preload("res://scenes/inspecao/onca_pintada.tscn")
const Pasta := "res://exports/revisao_onca_pintada/"
var total := 0
var falhas := 0

func _initialize() -> void:
	revisar.call_deferred()

func verificar(condicao: bool, verificacao: String) -> void:
	total += 1
	if not condicao:
		falhas += 1
		push_error(verificacao)

func capturar(nome: String) -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	var resultado := root.get_texture().get_image().save_png(Pasta + nome + ".png")
	verificar(resultado == OK, "Captura " + nome)

func posar(animador: AnimationPlayer, clipe: String, fracao: float) -> void:
	animador.play(clipe, 0)
	animador.advance(0)
	animador.seek(animador.get_animation(clipe).length * fracao, true)
	animador.pause()

func revisar() -> void:
	var cena := Cena.instantiate()
	root.add_child(cena)
	var animal: Node3D = cena.onca
	var player: AnimationPlayer = cena.animador
	if player == null:
		push_error("Onça importada sem AnimationPlayer")
		quit(1)
		return
	for clipe: String in cena.CLIPES:
		verificar(player.has_animation(clipe), "Clipe importado: " + clipe)
	var encontrados := animal.find_children("*", "Skeleton3D", true, false)
	verificar(encontrados.size() == 1, "Um esqueleto articula corpo e detalhes")
	if encontrados.size() != 1 or falhas > 0:
		quit(1)
		return
	var sk: Skeleton3D = encontrados[0]
	verificar(sk.get_bone_count() == 21, "21 ossos importados")
	var pelagem: Texture2D
	var caixa := AABB()
	var primeiro := true
	var triangulos := 0
	for m: MeshInstance3D in animal.find_children("*", "MeshInstance3D", true, false):
		var limites := (animal.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		caixa = limites if primeiro else caixa.merge(limites)
		primeiro = false
		for i in range(m.mesh.get_surface_count()):
			var mat := m.get_active_material(i) as StandardMaterial3D
			if mat != null and mat.albedo_texture != null:
				pelagem = mat.albedo_texture
			var indices: PackedInt32Array = m.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX]
			triangulos += indices.size() / 3
	verificar(pelagem != null and pelagem.get_width() >= 1024, "Textura UV incorporada e importada")
	verificar(caixa.size.y > .72 and caixa.size.y < .91 and caixa.size.z > 2.08 and caixa.size.z < 2.43, "Proporções de onça adulta")
	verificar(absf(caixa.position.y) < .042, "Patas no nível do solo")
	verificar(triangulos > 0 and triangulos < 100000, "Malha dentro do orçamento da inspeção")
	var alvo: Vector3 = cena.humano.global_position - animal.global_position
	alvo.y = 0
	verificar(animal.global_basis.z.normalized().dot(alvo.normalized()) > .99, "Focinho começa orientado ao morador")
	posar(player,"andar",.10)
	var pata := sk.find_bone("frente_D")
	var antes := sk.get_bone_pose_rotation(pata)
	posar(player,"andar",.68)
	verificar(antes.angle_to(sk.get_bone_pose_rotation(pata)) > .12, "Caminhada articula a pata")
	posar(player,"parada",.00)
	var cauda := sk.find_bone("cauda_3")
	antes = sk.get_bone_pose_rotation(cauda)
	posar(player,"parada",.25)
	verificar(antes.angle_to(sk.get_bone_pose_rotation(cauda)) > .10, "Cauda articula durante o repouso")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(Pasta)
		cena.legenda.hide()
		posar(player,"parada",.0)
		for vista in [[1,"01_onca_natural"],[2,"02_focinho"],[3,"03_perfil"],[4,"04_escala_visao_tatica"],[5,"05_costas"]]:
			cena.enquadrar(vista[0])
			await capturar(vista[1])
		cena.enquadrar(1)
		posar(player,"investida",.43)
		await capturar("06_investida")
	print("ONCA: %d verificações, %d falhas | caixa %s | %d triângulos" % [total, falhas, caixa.size, triangulos])
	cena.queue_free()
	await process_frame
	quit(1 if falhas else 0)
