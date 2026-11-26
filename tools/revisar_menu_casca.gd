extends SceneTree
var cena
var total:=0
var falhas:=0
var imagens:=false
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func capturar(nome: String) -> void:
	for i in range(22): await process_frame
	if not imagens: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://exports/revisao_menu_casca")
	ok(root.get_texture().get_image().save_png("res://exports/revisao_menu_casca/"+nome+".png")==OK,"Captura "+nome)
func clicar(b: Button) -> void:
	if not imagens:
		b.pressed.emit()
		return
	for i in range(8): await process_frame
	var p:=b.get_global_rect().get_center()
	var mover:=InputEventMouseMotion.new()
	mover.position=p
	root.push_input(mover)
	for pressionado in [true,false]:
		var e:=InputEventMouseButton.new()
		e.position=p
		e.button_index=MOUSE_BUTTON_LEFT
		e.pressed=pressionado
		root.push_input(e)
	await process_frame
func verificar_area_clara(painel: PanelContainer, contexto: String) -> void:
	# Retângulo interno conservador, conferido na arte: exclui os relevos
	# irregulares e a sombra da casca. Independente das margens do layout.
	var r:=painel.get_global_rect()
	var segura:=Rect2(r.position+r.size*Vector2(.09,.125),r.size*Vector2(.82,.75)).grow(1)
	var fora: Array[String]=[]
	var cortados: Array[String]=[]
	for c: Control in painel.find_children("*","Control",true,false):
		if not c.is_visible_in_tree() or not (c is Label or c is Button): continue
		if not segura.encloses(c.get_global_rect()): fora.append(c.text)
		if c is Label and c.autowrap_mode!=TextServer.AUTOWRAP_OFF: continue
		var fonte:=c.get_theme_font("font")
		var largura:=fonte.get_string_size(c.text,HORIZONTAL_ALIGNMENT_LEFT,-1,c.get_theme_font_size("font_size")).x
		if largura>c.size.x+1: cortados.append(c.text)
	ok(fora.is_empty(),contexto+" · textos e botões dentro da área clara: "+str(fora))
	ok(cortados.is_empty(),contexto+" · textos cabem nos componentes: "+str(cortados))
func executar() -> void:
	imagens=DisplayServer.get_name()!="headless"
	cena=load("res://scenes/inspecao/menu_expedicoes_casca.tscn").instantiate()
	root.add_child(cena)
	await process_frame
	var m=cena.get_node("MenuCasca")
	var textura: Texture2D=load("res://assets/ui/expedicoes/casca_interna_painel.png")
	var img:=textura.get_image()
	ok(img.get_pixel(0,0).a<.01,"Fundo externo realmente transparente")
	ok(m.estado.habitantes.size()==8,"Oito moradores na demonstração")
	for h: Dictionary in m.estado.habitantes: ok(ResourceLoader.exists("res://assets/ui/retratos/%s.png"%h.visual),"Retrato do modelo "+h.visual)
	ok(m.mini.visible and not m.quadro.visible,"Menu inicial compacto")
	await capturar("01_menu_compacto")
	verificar_area_clara(m.mini,"Menu compacto")
	for fonte: Font in [m.FONTE_TITULO,m.FONTE_TEXTO]:
		var acentos:=true
		for letra in "ÁáÃãÂâÇçÉéÊêÍíÓóÔôÕõÚú": acentos=acentos and fonte.has_char(letra.unicode_at(0))
		ok(acentos,"Fonte possui acentos do português: "+fonte.resource_path)
	await clicar(m.botao_abrir)
	ok(m.etapa==1 and m.frente.disabled,"Equipe vazia bloqueia Seguinte")
	await clicar(m.cards[m.estado.habitantes[0].id])
	await clicar(m.cards[m.estado.habitantes[1].id])
	ok(m.equipe.size()==2 and not m.frente.disabled,"Seleciona equipe de dois")
	ok(m.cards[m.estado.habitantes[2].id].disabled,"Limite de vagas visual")
	await capturar("02_escolher_equipe")
	verificar_area_clara(m.quadro,"Equipe")
	ok(m.quadro.position.y+m.quadro.size.y<=m.superficie.size.y-18,"Equipe cabe na tela")
	await clicar(m.frente)
	ok(m.etapa==2,"Seguinte abre equipamentos")
	await clicar(m.cards.lanca)
	ok(m.armas[m.equipando]=="lanca","Escolha visual de arma")
	await capturar("03_escolher_armas")
	verificar_area_clara(m.quadro,"Equipamentos")
	ok(m.quadro.position.y+m.quadro.size.y<=m.superficie.size.y-18,"Armas cabem na tela")
	await clicar(m.frente)
	ok(m.etapa==3 and m.frente.disabled,"Confirmação apresentada sem envio real")
	await capturar("04_confirmacao")
	verificar_area_clara(m.quadro,"Confirmação")
	ok(m.estado.expedicoes.is_empty(),"Nenhuma regra de envio executada")
	await clicar(m.voltar)
	ok(m.etapa==2 and m.equipe.size()==2 and m.armas[m.equipando]=="lanca","Voltar preserva escolhas da prévia")
	for tipo in ["pesca","coleta"]:
		m.mudar_tipo(tipo)
		ok(m.etapa==0 and m.equipe.is_empty(),"Trocar atividade reinicia prévia: "+tipo)
		ok(m.botao_abrir.text==("Pescar" if tipo=="pesca" else "Enviar expedição"),"Ação contextual: "+tipo)
		await clicar(m.botao_abrir)
		await clicar(m.cards[m.estado.habitantes[0].id])
		await clicar(m.frente)
		ok(m.etapa==2 and m.cards.is_empty(),"Equipamento básico sem armas inventadas: "+tipo)
		await capturar("05_kit_"+tipo)
		verificar_area_clara(m.quadro,"Kit de "+tipo)
		await clicar(m.frente)
		ok(m.etapa==3 and m.seletor_destino.item_count>0,"Destino compatível: "+tipo)
		if tipo=="pesca":
			for i in range(m.seletor_destino.item_count):
				ok(m.Regioes.definicoes()[m.seletor_destino.get_item_id(i)].recursos.has("peixe"),"Destino de pesca possui peixes")
		ok(m.frente.disabled and m.estado.expedicoes.is_empty(),"Prévia não envia "+tipo)
	cena.queue_free()
	await process_frame
	print("MENU_CASCA: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
