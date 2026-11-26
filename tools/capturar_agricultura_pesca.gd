extends SceneTree
const PASTA:="res://exports/revisao_agricultura_pesca/"
var cena
var falhas:=0
var verificacoes:=0

func _initialize() -> void:
	call_deferred("executar")

func conferir(valor: bool,msg: String) -> void:
	verificacoes+=1
	if not valor:
		falhas+=1
		push_error(msg)

func capturar(nome: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in range(55): await process_frame
	await RenderingServer.frame_post_draw
	conferir(root.get_texture().get_image().save_png(PASTA+nome+".png")==OK,"Captura "+nome)

func executar() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	cena=load("res://scenes/inspecao/agricultura_pesca_etapa_8.tscn").instantiate()
	root.add_child(cena)
	await process_frame
	for especie in ["Mandioca","Milho"]:
		var talhao=cena.get_node("CentroAgricola/"+especie)
		conferir(talhao.plantas.size()==(9 if especie=="Mandioca" else 6),"Talhão "+especie)
		for i in range(3):
			talhao.definir_estagio(i)
			for planta in talhao.plantas:
				var malhas: Array=planta.find_children("*","MeshInstance3D",true,false)
				conferir(malhas.size()==1 and malhas[0].mesh.get_surface_count()==1,"Cultivo com uma superfície")
				conferir(malhas[0].mesh.surface_get_material(0).vertex_color_use_as_albedo,"Cor do cultivo importada")
	cena.definir_estagio(2)
	for vista in ["Roca","Pesca","Costas","Geral"]:
		cena.enquadrar(vista)
		await capturar(vista.to_lower())
	cena.enquadrar("Roca")
	cena.definir_estagio(0)
	await capturar("brotos")
	cena.definir_estagio(1)
	await capturar("jovens")
	cena.definir_estagio(2)
	cena.luz.aplicar(23)
	await capturar("noite")
	cena.queue_free()
	await process_frame
	print("ARTE_ETAPA_8: %d verificações; %d falhas"%[verificacoes,falhas])
	quit(1 if falhas else 0)
