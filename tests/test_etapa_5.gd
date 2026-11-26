extends SceneTree
var cena
var falhas:=0
var verificacoes:=0
const PASTA:="res://exports/revisao_etapa_5/"

func _initialize() -> void:
	call_deferred("executar")

func verificar(valor: bool, descricao: String) -> void:
	verificacoes+=1
	if not valor:
		falhas+=1
		push_error(descricao)

func estabilizar() -> void:
	for i in range(6): await process_frame

func clicar(pos: Vector2, botao:=MOUSE_BUTTON_LEFT, pressionado:=true) -> void:
	var movimento:=InputEventMouseMotion.new()
	movimento.position=pos
	root.push_input(movimento)
	var evento:=InputEventMouseButton.new()
	evento.position=pos
	evento.button_index=botao
	evento.pressed=pressionado
	root.push_input(evento)

func tecla(valor: Key) -> void:
	var e:=InputEventKey.new()
	e.physical_keycode=valor
	e.pressed=true
	root.push_input(e)
	e=InputEventKey.new()
	e.physical_keycode=valor
	e.pressed=false
	root.push_input(e)

func captura(nome: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await estabilizar()
	await RenderingServer.frame_post_draw
	verificar(root.get_texture().get_image().save_png(PASTA+nome+".png")==OK,"Captura "+nome)

func executar() -> void:
	DirAccess.make_dir_recursive_absolute(PASTA)
	cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=preload("res://scripts/partida/salvamento.gd").new("user://testes_etapa_5")
	root.add_child(cena)
	cena.set_process(false)
	var p=cena.painel
	var hud=p.topo_hud
	await estabilizar()
	verificar(hud.numeros.size()==8,"Oito recursos na barra")
	for recurso in hud.RECURSOS:
		verificar(hud.numeros[recurso].text==str(cena.estado.estoque[recurso]),"Estoque real "+recurso)
	verificar(hud.populacao.text=="0/0","População inicial")
	var pausa_anterior: bool=cena.estado.relogio.pausado
	hud.pausa.pressed.emit()
	verificar(cena.estado.relogio.pausado!=pausa_anterior and paused,"Botão pausa atua no relógio e na árvore")
	for v in range(1,4):
		hud.velocidade_solicitada.emit(v)
		verificar(cena.estado.relogio.velocidade==v and cena.estado.relogio.pausado,"Velocidade funciona durante pausa")
	hud.pausa.pressed.emit()
	verificar(not paused and not cena.estado.relogio.pausado,"Retoma pelo HUD")
	cena.estado.relogio.tempo_total+=600
	hud.atualizar()
	verificar(hud.horario.text.begins_with("Dia 2"),"Dia do estado refletido no HUD")
	cena.estado.construir("oca",Vector2(-5,-4))
	cena._process(18)
	cena.estado.construir("coleta",Vector2(6,-1))
	cena._process(10)
	cena.estado.construir("coleta",Vector2(-13,3))
	cena._process(10)
	cena.estado.atribuir(cena.estado.habitantes[0].id,"obra_2")
	cena.estado.atribuir(cena.estado.habitantes[1].id,"obra_2")
	p.atualizar(true)
	cena.iluminacao.aplicar(16)
	verificar(hud.populacao.text=="2/2","População após moradia")
	p.abrir("obra_2")
	var pessoa: Dictionary=cena.estado.habitantes[0]
	var xp: int=pessoa.xp
	p.mudar_setor.emit(pessoa.id,"obra_3")
	verificar(pessoa.setor=="obra_3" and pessoa.xp==xp,"Transferência pelo painel preserva XP")
	p.abrir("comunidade")
	verificar(p.contexto=="comunidade" and cena.estado.ocupacao("obra_3")==1,"Comunidade reflete transferência")
	p.selecionar_pessoa(pessoa.id)
	verificar(p.escolha==pessoa.id,"Ficha individual")
	p.selecionar_pessoa(pessoa.id)
	cena.aldeia.selecionado.emit("obra_1")
	verificar(p.contexto=="obra_1","Clique em construção abre painel contextual")
	p.abrir("inicio")
	for i in range(7): hud.notificar("Registro de teste %d"%i)
	verificar(hud.avisos.size()==3,"Feed limita mensagens simultâneas")
	hud._process(10)
	verificar(hud.avisos.is_empty(),"Feed remove notificações antigas")
	hud.notificar("Oca concluída · 2 moradores chegaram")
	root.content_scale_size=Vector2i.ZERO
	for resolucao in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(960,540)]:
		root.size=resolucao
		await estabilizar()
		for escala in [.85,1.0,1.15]:
			p.definir_escala(escala)
			await estabilizar()
			var r: Rect2=hud.barra.get_global_rect()
			verificar(r.position.x>=-.1 and r.end.x<=root.size.x+.1,"Barra cabe em %s escala %s"%[resolucao,escala])
			var y: float=hud.numeros.madeira.get_global_rect().get_center().y
			verificar(absf(y-hud.horario.get_global_rect().get_center().y)<2,"Estoque e tempo na mesma linha")
		p.definir_escala(1)
		p.abrir("inicio")
		await estabilizar()
		var botoes: Array=p.controles.find_children("*","Button",true,false)
		verificar(botoes.size()==4 and p.rolagem.get_global_rect().encloses(botoes[-1].get_global_rect()),"Ações recolhidas visíveis e acessíveis")
		await captura("recolhido_%dx%d"%[resolucao.x,resolucao.y])
		p.abrir("comunidade")
		await estabilizar()
		var fundo: Rect2=p.conteiner.get_global_rect()
		verificar(fundo.position.x>=0 and fundo.end.x<=root.size.x+1 and fundo.position.y>hud.barra.get_global_rect().end.y,"Painel inferior cabe em "+str(resolucao))
		await captura("expandido_%dx%d"%[resolucao.x,resolucao.y])
	root.size=Vector2i(1280,720)
	p.definir_escala(1)
	await estabilizar()
	if DisplayServer.get_name()!="headless":
		var controle=cena._controle
		var zoom: float=controle.fov_alvo
		var pos: Vector2=hud.pausa.get_global_rect().get_center()
		clicar(pos,MOUSE_BUTTON_WHEEL_UP)
		clicar(pos,MOUSE_BUTTON_MIDDLE)
		verificar(controle.fov_alvo==zoom and not controle._arrastando,"Barra bloqueia zoom e arraste da câmera")
		clicar(pos,MOUSE_BUTTON_MIDDLE,false)
		clicar(pos)
		clicar(pos,MOUSE_BUTTON_LEFT,false)
		verificar(cena.estado.relogio.pausado,"Clique real em pausa")
		var tempo: float=cena.estado.relogio.tempo_total
		cena._process(3)
		verificar(cena.estado.relogio.tempo_total==tempo,"Mundo parado enquanto pausado")
		tecla(KEY_H)
		verificar(not p.visible,"H oculta durante pausa")
		tecla(KEY_H)
		verificar(p.visible,"H restaura durante pausa")
		clicar(pos)
		clicar(pos,MOUSE_BUTTON_LEFT,false)
		verificar(not cena.estado.relogio.pausado,"Clique real retoma")
		var scroll: Vector2=p.rolagem.get_global_rect().get_center()
		clicar(scroll,MOUSE_BUTTON_WHEEL_DOWN)
		verificar(controle.fov_alvo==zoom,"Scroll do menu preserva zoom")
		tecla(KEY_ESCAPE)
		verificar(p.contexto=="inicio","Esc recolhe o painel")
	p.abrir("obra_2")
	await captura("setor")
	p.abrir("comunidade")
	p.selecionar_pessoa(pessoa.id)
	await captura("ficha")
	p.alternar_hud()
	await captura("hud_oculto")
	p.alternar_hud()
	verificar(p.visible and p.escolha==pessoa.id,"Ocultar preserva seleção")
	cena.queue_free()
	await process_frame
	print("ETAPA_5: %d verificações; %d falhas"%[verificacoes,falhas])
	quit(1 if falhas else 0)
