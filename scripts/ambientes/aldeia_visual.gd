extends Node3D
## O mapa de passos acompanha as obras; a circulação nunca controla o relógio da aldeia.
signal selecionado(id: String)
signal posicionar(pos: Vector2)
signal cancelar
signal rotacao_alterada(valor: float)
signal selecao_terrenos_alterada(chaves: Array)
const Aldeia = preload("res://scripts/partida/aldeia.gd")
const OCA = preload("res://scenes/construcoes/oca_nivel_1.tscn")
const PASSO := .65
var estado
var locais := {}
var atores := {}
var grade := AStarGrid2D.new()
var previa: Node3D
var modo := ""
var material_previa := StandardMaterial3D.new()
var alvo_previa := Vector2.ZERO
var cache_modelos := {}
var tempo := 0.0
var rotacao_previa:=0.0
var centro_plantio:=""
var indice_plantio:=0
var celulas_visuais: Dictionary={}
var terrenos_selecionados: Array=[]
var inicio_arraste:=Vector2.ZERO
var selecionando_terrenos:=false
var camada_selecao: CanvasLayer
var retangulo_selecao: Control
const CelulaVisual=preload("res://scripts/ambientes/celula_cultivo_visual.gd")

static func altura(p: Vector2) -> float:
	var x:=p.x
	var y:=-p.y
	return .06+(.30*sin(x*.16)*cos(y*.13)+.14*sin(y*.39+x*.17))*minf(1,p.length()/14)+1.8*exp(-((x+22)*(x+22)+(y-22)*(y-22))/300)

static func no_solo(p: Vector2) -> Vector3:
	return Vector3(p.x,altura(p),p.y)

func _ready() -> void:
	camada_selecao=CanvasLayer.new()
	camada_selecao.layer=3
	add_child(camada_selecao)
	retangulo_selecao=preload("res://scripts/ambientes/selecao_terrenos_visual.gd").new()
	camada_selecao.add_child(retangulo_selecao)
	get_window().focus_exited.connect(cancelar_arraste)
	material_previa.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material_previa.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	grade.region=Rect2i(-28,-28,57,57)
	grade.cell_size=Vector2.ONE*PASSO
	grade.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grade.update()

func reiniciar(novo) -> void:
	estado=novo
	selecionar_terrenos([])
	cancelar_arraste()
	encerrar_previa()
	for obj in get_children():
		if obj==camada_selecao: continue
		remove_child(obj)
		obj.queue_free()
	locais.clear()
	atores.clear()
	celulas_visuais.clear()
	tempo=0
	atualizar_grade()
	sincronizar()

func modelo_estrutura(tipo: String) -> Node3D:
	if tipo=="plantio": return CelulaVisual.new()
	if tipo=="oca": return OCA.instantiate()
	if tipo=="agricultura": return load("res://scenes/construcoes/centro_agricola_nivel_1.tscn").instantiate()
	if tipo=="pesca": return load("res://scenes/construcoes/centro_pesca_nivel_1.tscn").instantiate()
	if tipo=="caca": return load("res://scenes/construcoes/centro_caca_nivel_1.tscn").instantiate()
	return load("res://scenes/construcoes/centro_coleta.tscn").instantiate()

func iniciar_previa(tipo: String) -> void:
	selecionar_terrenos([])
	cancelar_arraste()
	encerrar_previa()
	modo=tipo
	rotacao_previa=0
	previa=modelo_estrutura(tipo)
	add_child(previa)
	if tipo=="agricultura":
		for nome in ["Mandioca","Milho"]: previa.get_node(nome).hide()
		for m: MeshInstance3D in previa.find_children("Oca_Terra*","MeshInstance3D",true,false): m.hide()
	for m: MeshInstance3D in previa.find_children("*","MeshInstance3D",true,false):
		m.material_override=material_previa
	deslocar_previa(get_viewport().get_mouse_position())
	rotacao_alterada.emit(rotacao_previa)

func girar_previa(sentido: int) -> void:
	if modo=="" or not is_instance_valid(previa): return
	rotacao_previa=wrapf(rotacao_previa+sentido*PI/12,-PI,PI)
	if modo!="plantio": previa.rotation.y=rotacao_previa
	deslocar_previa(get_viewport().get_mouse_position())
	rotacao_alterada.emit(rotacao_previa)

func erro_previa() -> String:
	if modo=="plantio": return Aldeia.Agricultura.erro_celula(estado,centro_plantio,indice_plantio,alvo_previa)
	return estado.impedimento(modo,alvo_previa,rotacao_previa)

func encerrar_previa() -> void:
	modo=""
	if is_instance_valid(previa): previa.queue_free()
	previa=null

func projecao(mouse: Vector2) -> Variant:
	var cam:=get_viewport().get_camera_3d()
	if cam==null: return null
	var origem:=cam.project_ray_origin(mouse)
	var direcao:=cam.project_ray_normal(mouse)
	var hit: Variant=Plane(Vector3.UP,0).intersects_ray(origem,direcao)
	if hit==null: return null
	for i in range(2):
		hit=Plane(Vector3.UP,altura(Vector2(hit.x,hit.z))).intersects_ray(origem,direcao)
		if hit==null: return null
	return Vector2(hit.x,hit.z)

func deslocar_previa(mouse: Vector2) -> void:
	var pos: Variant=projecao(mouse)
	if pos==null:
		previa.hide()
		return
	previa.show()
	alvo_previa=Vector2(floorf(pos.x)+.5,floorf(pos.y)+.5) if modo=="plantio" else Vector2(pos).snapped(Vector2.ONE*.25)
	previa.position=no_solo(alvo_previa)
	if modo=="plantio":
		previa.configurar("",0,rotacao_previa)
	material_previa.albedo_color=Color(.35,.88,.50,.53) if erro_previa()=="" else Color(.98,.28,.16,.53)

func _process(_delta: float) -> void:
	if previa: deslocar_previa(get_viewport().get_mouse_position())

func cancelar_arraste() -> void:
	selecionando_terrenos=false
	if is_instance_valid(retangulo_selecao):
		retangulo_selecao.ativo=false
		retangulo_selecao.queue_redraw()

func selecionar_terrenos(chaves: Array) -> void:
	terrenos_selecionados=chaves.duplicate()
	for chave in celulas_visuais:
		celulas_visuais[chave].no.definir_selecionada(chave in terrenos_selecionados)
	selecao_terrenos_alterada.emit(terrenos_selecionados)

func celula_em(mouse: Vector2) -> String:
	var cam:=get_viewport().get_camera_3d()
	if not cam: return ""
	var origem:=cam.project_ray_origin(mouse)
	var direcao:=cam.project_ray_normal(mouse)
	var menor:=INF
	var escolhida:=""
	for chave in celulas_visuais:
		var obj: Node3D=celulas_visuais[chave].no
		var altura_caixa:=1.8 if is_instance_valid(obj.planta) else .12
		var hit: Variant=AABB(obj.position-Vector3(.5,0,.5),Vector3(1,altura_caixa,1)).intersects_ray(origem,direcao)
		if hit!=null and origem.distance_squared_to(hit)<menor:
			menor=origem.distance_squared_to(hit)
			escolhida=chave
	return escolhida

func concluir_selecao(fim: Vector2) -> void:
	var arrastou:=inicio_arraste.distance_to(fim)>=6
	cancelar_arraste()
	if not arrastou:
		var chave:=celula_em(fim)
		selecionar_terrenos([chave] if chave!="" else [])
		if chave=="":
			var id:=escolher(fim)
			if id!="": selecionado.emit(id)
		return
	var caixa:=Rect2(inicio_arraste,fim-inicio_arraste).abs()
	var cam:=get_viewport().get_camera_3d()
	var chaves: Array=[]
	for chave in celulas_visuais:
		var obj: Node3D=celulas_visuais[chave].no
		if not cam.is_position_behind(obj.position) and caixa.has_point(cam.unproject_position(obj.position)): chaves.append(chave)
	selecionar_terrenos(chaves)

func _input(e: InputEvent) -> void:
	if not selecionando_terrenos: return
	if e is InputEventKey and e.pressed and e.physical_keycode==KEY_ESCAPE:
		cancelar_arraste()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_RIGHT:
		cancelar_arraste()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseMotion:
		retangulo_selecao.fim=e.position
		retangulo_selecao.ativo=inicio_arraste.distance_to(e.position)>=6
		retangulo_selecao.queue_redraw()
	elif e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and not e.pressed:
		concluir_selecao(e.position)
		get_viewport().set_input_as_handled()

func _unhandled_input(e: InputEvent) -> void:
	if estado==null: return
	if modo!="" and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_Z,KEY_X]:
		girar_previa(-1 if e.physical_keycode==KEY_Z else 1)
		get_viewport().set_input_as_handled()
		return
	if modo!="" and (e.is_action_pressed("ui_cancel") or (e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_RIGHT)):
		cancelar.emit()
	elif e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
		if modo!="":
			deslocar_previa(e.position)
			if previa.visible: posicionar.emit(alvo_previa)
		else:
			selecionando_terrenos=true
			inicio_arraste=e.position
			retangulo_selecao.inicio=e.position
			retangulo_selecao.fim=e.position
	else: return
	get_viewport().set_input_as_handled()

func escolher(mouse: Vector2) -> String:
	var cam:=get_viewport().get_camera_3d()
	if not cam: return ""
	var origem:=cam.project_ray_origin(mouse)
	var dir:=cam.project_ray_normal(mouse)
	var menor:=INF
	var escolhido:=""
	for id in ["fogueira"]+locais.keys():
		var base:=Vector3.ZERO
		var caixa:=Vector3(3.6,2.2,3.6)
		if id!="fogueira":
			base=locais[id].position
			caixa=Vector3(5.4,3.9,6.2) if estado.estrutura(id).tipo=="oca" else Vector3(3.5,1.7,3.5)
			if estado.estrutura(id).tipo=="agricultura": caixa=Vector3(7.6,3.5,8)
			elif estado.estrutura(id).tipo=="pesca": caixa=Vector3(5.2,3.4,5.2)
			elif estado.estrutura(id).tipo=="caca": caixa=Vector3(4.4,3.1,3.7)
		var angulo: float=estado.estrutura(id).get("rotacao",0) if id!="fogueira" else 0
		var inv:=Transform3D(Basis(Vector3.UP,angulo),base).affine_inverse()
		var hit: Variant=AABB(Vector3(-caixa.x*.5,0,-caixa.z*.5),caixa).intersects_ray(inv*origem,inv.basis*dir)
		if hit!=null and (inv*origem).distance_squared_to(hit)<menor:
			menor=(inv*origem).distance_squared_to(hit)
			escolhido=id
	for chave in celulas_visuais:
		var obj: Node3D=celulas_visuais[chave].no
		var hit: Variant=AABB(obj.position-Vector3(.5,0,.5),Vector3(1,1.8,1)).intersects_ray(origem,dir)
		if hit!=null and origem.distance_squared_to(hit)<menor:
			menor=origem.distance_squared_to(hit)
			escolhido=celulas_visuais[chave].centro
	return escolhido

func sincronizar() -> void:
	var mudou:=false
	for c: Dictionary in estado.construcoes:
		if not locais.has(c.id):
			var obj:=modelo_estrutura(c.tipo)
			add_child(obj)
			obj.position=no_solo(Aldeia.ponto(c))
			locais[c.id]=obj
			mudou=true
		locais[c.id].scale.y=1.0 if c.pronta else lerpf(.18,.92,1.0-float(c.restante)/Aldeia.DURACAO[c.tipo])
		locais[c.id].rotation.y=c.get("rotacao",0)
		if c.tipo=="agricultura": atualizar_talhoes(locais[c.id],c)
	if mudou: atualizar_grade()
	for h: Dictionary in estado.habitantes:
		if atores.has(h.id):
			atores[h.id].modelo.visible=h.estado not in ["em_expedicao","morto"]
			continue
		if h.estado=="morto": continue
		if not cache_modelos.has(h.visual):
			cache_modelos[h.visual]=load("res://assets/models/habitantes/%s.glb"%h.visual)
		var modelo: Node3D=cache_modelos[h.visual].instantiate()
		add_child(modelo)
		modelo.visible=h.estado!="em_expedicao"
		var casa: Dictionary=estado.estrutura(h.casa)
		var porta:=Aldeia.ponto(casa)+Vector2(.54 if h.visual.begins_with("homem") else -.54,5.2).rotated(-float(casa.get("rotacao",0)))
		modelo.position=no_solo(Vector2(celula_livre(porta))*PASSO)
		var malha:=modelo.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		atores[h.id]={"modelo":modelo,"malha":malha,"rota":PackedVector2Array(),"vinculo":"?","espera":0.0,"fase":float(atores.size())*1.7,"visitas":0}

func atualizar_talhoes(obj: Node3D,c: Dictionary) -> void:
	if c.talhoes.all(func(t): return t.has("celulas") and not t.has("legado")):
		for m: MeshInstance3D in obj.find_children("Oca_Terra*","MeshInstance3D",true,false): m.hide()
	for i in range(2):
		var t: Dictionary=c.talhoes[i]
		if t.has("celulas"):
			obj.get_node(["Mandioca","Milho"][i]).visible=t.has("legado")
			for celula: Dictionary in t.celulas:
				var chave:=Aldeia.Agricultura.chave_celula(celula)
				if not celulas_visuais.has(chave):
					var visual:=CelulaVisual.new()
					add_child(visual)
					visual.position=no_solo(Aldeia.Agricultura.centro_celula(celula))
					celulas_visuais[chave]={"no":visual,"centro":c.id}
				var fase:=clampi(floori(3*celula.progresso/float(Aldeia.Alimentacao.parametros.cultivos[celula.cultivo].duracao)),0,2)
				celulas_visuais[chave].no.configurar(celula.cultivo if celula.get("plantada",true) else "",fase,celula.get("rotacao",0))
				celulas_visuais[chave].no.definir_selecionada(chave in terrenos_selecionados)
			if not t.has("legado"): continue
			t=t.legado
		var especie: int=0 if t.cultivo=="mandioca" else 1
		var duracao: float=Aldeia.Alimentacao.parametros.cultivos[t.cultivo].duracao
		var estagio:=clampi(floori(3*t.progresso/duracao),0,2) if c.pronta else 0
		var no: Node3D=obj.get_node(["Mandioca","Milho"][i])
		var assinatura:=str([especie,estagio])
		if no.get_meta("cultivo_visual","")==assinatura: continue
		no.especie=especie
		no.definir_estagio(estagio)
		no.set_meta("cultivo_visual",assinatura)

func atualizar_grade() -> void:
	for x in range(-28,29):
		for z in range(-28,29):
			var id:=Vector2i(x,z)
			grade.set_point_solid(id,not estado.livre_no_mapa(Vector2(id)*PASSO,.20))
	for ator: Dictionary in atores.values(): ator.vinculo="?"

func celula_livre(p: Vector2) -> Vector2i:
	var centro:=Vector2i((p/PASSO).round())
	for r in range(0,30):
		var melhor:=Vector2i.ZERO
		var distancia:=INF
		for x in range(-r,r+1):
			for y in range(-r,r+1):
				if maxi(absi(x),absi(y))!=r: continue
				var c:=centro+Vector2i(x,y)
				if grade.is_in_boundsv(c) and not grade.is_point_solid(c):
					var d:=(Vector2(c)*PASSO).distance_squared_to(p)
					if d<distancia:
						distancia=d
						melhor=c
		if distancia<INF: return melhor
	return Vector2i(0,4)

func mover(segundos: float) -> void:
	tempo+=segundos
	for h: Dictionary in estado.habitantes:
		if h.estado in ["em_expedicao","morto"]: continue
		var a: Dictionary=atores[h.id]
		var modelo: Node3D=a.modelo
		var p:=Vector2(modelo.position.x,modelo.position.z)
		var vinculo: String=h.estado+h.setor+h.obra
		a.espera-=segundos
		if vinculo!=a.vinculo or (h.estado=="livre" and a.rota.is_empty() and a.espera<=0):
			a.vinculo=vinculo
			a.visitas+=1
			var ang:=float(a.fase)+float(a.visitas)*2.39
			var destino:=Vector2.from_angle(ang)*(4.3+1.6*sin(ang))
			if h.estado!="livre":
				var c: Dictionary=estado.estrutura(h.setor if h.estado=="trabalhando" else h.obra)
				destino=Aldeia.ponto(c)+Vector2.from_angle(float(a.fase))*(float(Aldeia.RAIO[c.tipo])+1.35)
			var inicio:=celula_livre(p)
			var fim:=celula_livre(destino)
			a.rota=grade.get_point_path(inicio,fim,true)
			a.espera=3.8+fmod(float(a.fase),3.0)
		var rota: PackedVector2Array=a.rota
		var andando:=not rota.is_empty()
		if andando:
			var proximo:=rota[0]
			var direcao:=proximo-p
			if direcao.length()>.03: modelo.rotation.y=lerp_angle(modelo.rotation.y,atan2(direcao.x,direcao.y),minf(1,segundos*9))
			p=p.move_toward(proximo,segundos*1.45)
			if p.is_equal_approx(proximo): rota.remove_at(0)
			a.rota=rota
			modelo.position=no_solo(p)
			if rota.is_empty(): a.espera=3.8+fmod(float(a.fase),3.0)
		var passo:=sin(tempo*7+a.fase) if andando else 0.0
		var trabalho:=0.0 if andando or h.estado=="livre" else .52+.40*sin(tempo*2.2+a.fase)
		a.malha.set("blend_shapes/Passo_E",maxf(0,passo))
		a.malha.set("blend_shapes/Passo_D",maxf(0,-passo))
		a.malha.set("blend_shapes/Coletar",trabalho)
