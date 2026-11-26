extends "res://scripts/inspecao/inspecao_mapa_regional.gd"
signal fechar
signal pausa_solicitada
signal velocidade_solicitada(valor: int)
signal expedicoes_solicitadas(regiao: int)
var _conhecimento_anterior:=""

func _ready() -> void:
	layer=3
	super._ready()
	var arte_completa:=rodape.get_child(rodape.get_child_count()-1)
	rodape.remove_child(arte_completa)
	arte_completa.queue_free()
	acao(rodape,"Voltar à aldeia · M",func(): fechar.emit())
	acao(rodape,"Expedições",func(): expedicoes_solicitadas.emit(mapa.selecionada))

func configurar(novo) -> void:
	estado=novo
	barra.configurar(estado)
	mapa.mostrar_tudo=false
	mapa.aplicar_conhecimento(estado.conhecimento)
	_conhecimento_anterior=str(estado.conhecimento)
	selecionar(mapa.selecionada)

func selecionar(indice: int) -> void:
	for no in conteudo.get_children():
		conteudo.remove_child(no)
		no.queue_free()
	var linhas:=mapa.Regioes.informacoes(indice,estado.conhecimento).split("\n")
	for i in range(linhas.size()):
		var l:=texto(conteudo,linhas[i],22 if i==0 else 16)
		l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var total:=0
	for valor in estado.conhecimento.values():
		if int(valor)>0: total+=1
	texto(conteudo,"%d de 30 regiões conhecidas"%total,16,Casca.TINTA_SUAVE)
	var ajuda:=texto(conteudo,"Roda · zoom\nArraste / WASD · mover\nR · recentrar\nM / Esc · voltar",15,Casca.TINTA_SUAVE)
	ajuda.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func alterar_pausa() -> void:
	pausa_solicitada.emit()

func alterar_velocidade(valor: int) -> void:
	velocidade_solicitada.emit(valor)

func alternar_inspecao() -> void:
	pass

func _unhandled_key_input(e: InputEvent) -> void:
	if not visible or not e is InputEventKey or not e.pressed or e.echo: return
	match e.physical_keycode:
		KEY_ESCAPE,KEY_M:
			fechar.emit()
		KEY_V:
			return
		KEY_H:
			alternar_interface()
		_:
			super._unhandled_key_input(e)
			return
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if visible:
		super._process(delta)
		var topo:=104.0
		if not barra.avisos.is_empty():
			topo=clampf(barra.feed.position.y+barra.feed.get_combined_minimum_size().y+12,104,_superficie.size.y*.42)
		ficha.position.y=topo
		ficha.size.y=maxf(120,_superficie.size.y-64-topo)
		if str(estado.conhecimento)!=_conhecimento_anterior:
			mapa.aplicar_conhecimento(estado.conhecimento)
			_conhecimento_anterior=str(estado.conhecimento)
			selecionar(mapa.selecionada)
