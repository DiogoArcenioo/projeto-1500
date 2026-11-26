extends Node3D
const Estado = preload("res://scripts/partida/estado_partida.gd")
const Salvamento = preload("res://scripts/partida/salvamento.gd")
const Iluminacao = preload("res://scripts/ambientes/iluminacao_diurna.gd")
@export var configuracao: Resource = preload("res://assets/configuracoes/partida_inicial.tres")
var estado: Estado
var salvamento: RefCounted # Pode ser injetado pelos testes, sem tocar nos saves reais.
var iluminacao: Node
var _tempo_autosave: float = 0.0
var _hora_informada: int = -1
var _controle: Node
var aldeia := preload("res://scripts/ambientes/aldeia_visual.gd").new()
var painel := preload("res://scripts/partida/painel_aldeia.gd").new()
var _tempo_painel := 0.0
var mapa_regional := preload("res://scripts/partida/tela_mapa.gd").new()
var painel_expedicoes := preload("res://scripts/partida/painel_expedicoes.gd").new()
var combate_manual: Node3D
var _ambiente_aldeia: Environment

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	if salvamento == null:
		salvamento = Salvamento.new()
	_controle = $ControleDaCamera
	iluminacao = Iluminacao.new()
	iluminacao.name = "IluminacaoDiurna"
	add_child(iluminacao)
	iluminacao.configurar($Clareira1500)
	aldeia.name="Aldeia"
	painel.name="PainelDaAldeia"
	add_child(aldeia)
	add_child(painel)
	add_child(mapa_regional)
	mapa_regional.hide()
	mapa_regional.fechar.connect(fechar_mapa)
	mapa_regional.pausa_solicitada.connect(alternar_pausa)
	mapa_regional.velocidade_solicitada.connect(definir_velocidade)
	painel.mapa_solicitado.connect(abrir_mapa)
	add_child(painel_expedicoes)
	painel.expedicoes_solicitadas.connect(func(centro: String): abrir_expedicoes(centro))
	mapa_regional.expedicoes_solicitadas.connect(func(regiao: int): abrir_expedicoes("",regiao))
	painel_expedicoes.enviar_solicitado.connect(enviar_expedicao)
	painel_expedicoes.retorno_solicitado.connect(retornar_expedicao)
	painel_expedicoes.fechar_solicitado.connect(fechar_expedicoes)
	painel_expedicoes.regiao_apontada.connect(func(regiao: int):
		mapa_regional.mapa.selecionada=regiao
		mapa_regional.mapa.queue_redraw()
		mapa_regional.selecionar(regiao))
	painel_expedicoes.hud_alternado.connect(func(visivel: bool):
		if mapa_regional.visible: mapa_regional.alternar_interface()
		else: painel.visible=visivel)
	aldeia.selecionado.connect(func(id: String):
		var c:=estado.estrutura(id)
		if c.get("pronta",false) and c.get("tipo","") in ["caca","pesca","coleta"]: abrir_expedicoes(id)
		else:
			fechar_expedicoes()
			painel.abrir(id))
	painel_expedicoes.gerenciar_solicitado.connect(func(id: String):
		fechar_expedicoes()
		painel.abrir(id))
	aldeia.posicionar.connect(confirmar_obra)
	aldeia.cancelar.connect(cancelar_obra)
	painel.iniciar_obra.connect(iniciar_obra)
	painel.cancelar_obra.connect(cancelar_obra)
	painel.mudar_setor.connect(mudar_setor)
	painel.plantio_solicitado.connect(iniciar_plantio)
	painel.plantar_selecao_solicitado.connect(plantar_selecao)
	painel.limpar_selecao_solicitado.connect(func():
		aldeia.cancelar_arraste()
		aldeia.selecionar_terrenos([]))
	aldeia.selecao_terrenos_alterada.connect(func(chaves: Array):
		painel.terrenos_selecionados=chaves.duplicate()
		if not chaves.is_empty(): painel.abrir("terrenos")
		elif painel.contexto=="terrenos": painel.abrir("inicio"))
	painel.giro_solicitado.connect(aldeia.girar_previa)
	aldeia.rotacao_alterada.connect(func(valor: float):
		painel.rotacao_graus=roundi(rad_to_deg(valor))
		if is_instance_valid(painel.angulo_obra): painel.angulo_obra.text="%d°"%painel.rotacao_graus)
	painel.cultivo_solicitado.connect(func(centro: String,indice: int,cultivo: String):
		var erro:=Estado.Agricultura.escolher(estado,centro,indice,cultivo)
		painel.notificar(erro if erro!="" else "Próximo plantio atualizado.")
		painel.atualizar(true))
	painel.pausa_solicitada.connect(alternar_pausa)
	painel.velocidade_solicitada.connect(definir_velocidade)
	painel.topo_hud.alerta_assumir.connect(assumir_alerta)
	painel.topo_hud.alerta_simular.connect(simular_alerta)
	if mapa_regional.barra.has_signal("alerta_assumir"):
		mapa_regional.barra.alerta_assumir.connect(assumir_alerta)
		mapa_regional.barra.alerta_simular.connect(simular_alerta)
	nova_partida(false)
	if OS.is_debug_build():
		print("[1500] WASD: deslocar | scroll: zoom | meio+arraste: deslocar | Q/E: girar | R: recentrar")
		print("[1500] Espaço: pausa | 1/2/3: velocidade | F6: salvar | F7: carregar | Shift+F7: autosave | Ctrl+N: nova partida | F9: estado")
		print("[1500] Pasta local: ", ProjectSettings.globalize_path(salvamento.pasta))

func nova_partida(recentrar: bool = true) -> void:
	fechar_combate()
	estado = Estado.nova(configuracao) as Estado
	aldeia.reiniciar(estado)
	painel.reiniciar(estado)
	painel_expedicoes.reiniciar(estado)
	mapa_regional.configurar(estado)
	fechar_mapa()
	_tempo_autosave = 0.0
	_hora_informada = -1
	get_tree().paused = false
	if recentrar:
		_controle.restaurar({})
	iluminacao.aplicar(estado.relogio.obter_hora())
	informar_estado("Nova partida; valores iniciais de estoque provisórios")

func _process(delta: float) -> void:
	if estado == null:
		return
	if is_instance_valid(combate_manual): return
	if abrir_combate_pendente(): return
	var dia_anterior: int = estado.relogio.obter_dia()
	var decorrido: float = estado.relogio.avancar(delta)
	if decorrido <= 0.0:
		return
	var avisos := estado.avancar_simulacao(decorrido)
	abrir_combate_pendente()
	aldeia.sincronizar()
	aldeia.mover(decorrido)
	for aviso in avisos:
		painel.notificar(aviso)
		painel.topo_hud.notificar(aviso)
		mapa_regional.barra.notificar(aviso)
	_tempo_painel+=delta
	if _tempo_painel>.24 or not avisos.is_empty():
		painel.atualizar()
		_tempo_painel=0
	iluminacao.aplicar(estado.relogio.obter_hora())
	_tempo_autosave += decorrido
	if estado.relogio.obter_dia() != dia_anterior or _tempo_autosave >= configuracao.intervalo_autosave:
		salvar_partida("automatico")
		_tempo_autosave = 0.0 # Uma falha não pode disparar escrita e mensagens a cada frame.
	if OS.is_debug_build() and floori(estado.relogio.obter_hora()) != _hora_informada:
		_hora_informada = floori(estado.relogio.obter_hora())
		informar_estado("Relógio")

func _unhandled_key_input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	if is_instance_valid(combate_manual):
		if evento.physical_keycode==KEY_F6: salvar_partida("manual")
		elif evento.physical_keycode==KEY_F7: carregar_partida("automatico" if evento.shift_pressed else "manual")
		get_viewport().set_input_as_handled()
		return
	if evento.physical_keycode==KEY_ESCAPE and aldeia.modo!="":
		cancelar_obra()
		get_viewport().set_input_as_handled()
		return
	if evento.physical_keycode==KEY_M:
		fechar_expedicoes()
		if mapa_regional.visible: fechar_mapa()
		else: abrir_mapa()
		get_viewport().set_input_as_handled()
		return
	var tratada := true
	if evento.is_action_pressed("partida_pausar", false, true):
		alternar_pausa()
		informar_estado("Pausa alterada")
	elif evento.is_action_pressed("partida_velocidade_1", false, true):
		definir_velocidade(1)
		informar_estado("Velocidade alterada")
	elif evento.is_action_pressed("partida_velocidade_2", false, true):
		definir_velocidade(2)
		informar_estado("Velocidade alterada")
	elif evento.is_action_pressed("partida_velocidade_3", false, true):
		definir_velocidade(3)
		informar_estado("Velocidade alterada")
	elif evento.is_action_pressed("partida_salvar", false, true):
		salvar_partida("manual")
	elif evento.is_action_pressed("partida_carregar_auto", false, true):
		carregar_partida("automatico")
	elif evento.is_action_pressed("partida_carregar", false, true):
		carregar_partida("manual")
	elif evento.is_action_pressed("partida_nova", false, true):
		nova_partida()
	elif evento.is_action_pressed("debug_estado", false, true) and OS.is_debug_build():
		informar_estado("Inspeção")
	else:
		tratada = false
	if tratada:
		get_viewport().set_input_as_handled()

func salvar_partida(slot: String) -> bool:
	estado.camera = _controle.serializar()
	var resultado: Dictionary = salvamento.salvar(estado, slot)
	if not resultado.ok:
		painel.notificar("Falha ao salvar. " + resultado.erro)
		print("[1500] Falha ao salvar: ", resultado.erro)
		return false
	if slot == "automatico":
		_tempo_autosave = 0.0
	print("[1500] Partida salva (", slot, ").")
	if slot=="manual": painel.topo_hud.notificar("Partida salva.")
	return true

func carregar_partida(slot: String) -> bool:
	var resultado: Dictionary = salvamento.carregar(slot)
	if not resultado.ok:
		painel.notificar("Falha ao carregar. " + resultado.erro)
		print("[1500] Carregamento cancelado: ", resultado.erro, " A partida em andamento foi preservada.")
		return false
	var nova := resultado.estado as Estado
	if nova.modo != Estado.MODO_PADRAO:
		print("[1500] Ironman reservado para a etapa 23; partida atual preservada.")
		return false
	# Só trocar a fonte de verdade depois que todo o snapshot foi validado.
	fechar_combate()
	estado = nova
	aldeia.reiniciar(estado)
	painel.reiniciar(estado)
	painel_expedicoes.reiniciar(estado)
	fechar_expedicoes()
	mapa_regional.configurar(estado)
	painel.topo_hud.notificar("Partida carregada.")
	_controle.restaurar(estado.camera)
	_tempo_autosave = 0.0
	_hora_informada = -1
	get_tree().paused = estado.relogio.pausado
	iluminacao.aplicar(estado.relogio.obter_hora())
	informar_estado("Partida carregada (" + slot + ")")
	abrir_combate_pendente()
	return true

func iniciar_obra(tipo: String) -> void:
	aldeia.iniciar_previa(tipo)
	painel.colocando=tipo
	painel.notificar("")
	painel.atualizar(true)

func cancelar_obra() -> void:
	aldeia.encerrar_previa()
	painel.colocando=""
	painel.atualizar(true)

func iniciar_plantio(centro: String,indice: int) -> void:
	aldeia.centro_plantio=centro
	aldeia.indice_plantio=indice
	iniciar_obra("plantio")

func plantar_selecao(cultivo: String) -> void:
	var erro:=Estado.Agricultura.semear_selecao(estado,aldeia.terrenos_selecionados,cultivo)
	painel.notificar(erro if erro!="" else "Cultivo definido nos terrenos selecionados. Safras em andamento foram preservadas.")
	aldeia.sincronizar()
	painel.atualizar(true)

func confirmar_obra(pos: Vector2) -> void:
	if aldeia.modo=="plantio":
		var erro_plantio:=Estado.Agricultura.adicionar_celula(estado,aldeia.centro_plantio,aldeia.indice_plantio,pos,aldeia.rotacao_previa)
		painel.notificar(erro_plantio if erro_plantio!="" else "Terreno preparado. Continue para expandir; Esc encerra. Depois selecione o que plantar.")
		aldeia.sincronizar()
		return
	var erro:=estado.construir(aldeia.modo,pos,aldeia.rotacao_previa)
	if not erro.is_empty():
		painel.notificar(erro)
		return
	cancelar_obra()
	aldeia.sincronizar()
	painel.abrir(estado.construcoes.back().id)
	painel.notificar("Obra iniciada. Os materiais foram retirados do estoque.")
	painel.topo_hud.notificar("Obra iniciada · "+estado.NOMES_CONSTRUCOES[estado.construcoes.back().tipo])

func mudar_setor(id: String,destino: String) -> void:
	var erro:=estado.atribuir(id,destino)
	painel.notificar(erro)
	painel.atualizar(true)

func alternar_pausa() -> void:
	estado.relogio.pausado=not estado.relogio.pausado
	get_tree().paused=estado.relogio.pausado
	painel.topo_hud.atualizar()

func definir_velocidade(valor: int) -> void:
	estado.relogio.definir_velocidade(valor)
	painel.topo_hud.atualizar()

func abrir_mapa() -> void:
	aldeia.cancelar_arraste()
	if aldeia.modo!="": cancelar_obra()
	mapa_regional.configurar(estado)
	mapa_regional.show()
	painel.hide()
	_controle.set_process(false)
	_controle.set_process_unhandled_input(false)
	_controle._cancelar_arraste()
	aldeia.set_process_unhandled_input(false)

func fechar_mapa() -> void:
	mapa_regional.hide()
	painel.show()
	_controle.set_process(not painel_expedicoes.aberto)
	_controle.set_process_unhandled_input(not painel_expedicoes.aberto)
	aldeia.set_process_unhandled_input(not painel_expedicoes.aberto)

func abrir_expedicoes(centro: String="",regiao: int=-1) -> void:
	aldeia.cancelar_arraste()
	if aldeia.modo!="": cancelar_obra()
	painel_expedicoes.escala_usuario=painel.escala_usuario
	painel_expedicoes.abrir(estado,centro,regiao)
	painel.conteiner.hide()
	_controle._cancelar_arraste()
	_controle.set_process(false)
	_controle.set_process_unhandled_input(false)
	aldeia.set_process_unhandled_input(false)

func fechar_expedicoes() -> void:
	painel_expedicoes.aberto=false
	painel_expedicoes.hide()
	painel.conteiner.show()
	painel.visible=not mapa_regional.visible
	_controle.set_process(not mapa_regional.visible)
	_controle.set_process_unhandled_input(not mapa_regional.visible)
	aldeia.set_process_unhandled_input(not mapa_regional.visible)

func enviar_expedicao(centro: String,tipo: String,regiao: int,equipe: Array) -> void:
	var armas: Dictionary={}
	if tipo=="caca":
		for id in equipe: armas[id]=painel_expedicoes.armas.get(id,"arco")
	var resultado:=Estado.Expedicoes.enviar(estado,centro,tipo,regiao,equipe,painel_expedicoes.modo_caca if tipo=="caca" else "simulado",armas,painel_expedicoes.politica)
	if not resultado.ok:
		painel_expedicoes.notificar(resultado.erro)
		painel_expedicoes.apresentar("preparar")
		return
	painel_expedicoes.notificar("")
	painel_expedicoes.equipe.clear()
	painel_expedicoes.apresentar("acompanhar")
	aldeia.sincronizar()
	painel.atualizar(true)
	painel.topo_hud.notificar("Expedição enviada · "+resultado.id)
	mapa_regional.barra.notificar("Expedição enviada · "+resultado.id)

func retornar_expedicao(id: String) -> void:
	var viagem:=Estado.Expedicoes.buscar(estado,id)
	var em_confronto: bool=not viagem.is_empty() and viagem.fase=="confronto"
	var erro:=Estado.Expedicoes.retornar(estado,id)
	var mensagem:=erro
	if erro=="" and em_confronto:
		mensagem="Retirada bem-sucedida. A equipe está retornando." if viagem.fase=="retorno" else "A retirada falhou. O confronto continua; consulte a rolagem abaixo."
	painel_expedicoes.notificar(mensagem)
	painel_expedicoes.apresentar("acompanhar")
	aldeia.sincronizar()
	painel.atualizar(true)

## Etapa 11: "Assumir combate" no cartão de alerta. O estado já sorteado é mantido;
## o combate manual abre no próximo quadro e congela a aldeia.
func assumir_alerta(id: String) -> void:
	var erro:=Estado.Expedicoes.assumir(estado,id)
	if erro!="":
		painel.topo_hud.notificar(erro)
		return
	abrir_combate_pendente()

## "Deixar simular": a equipe resolve sozinha com a sua política.
func simular_alerta(id: String) -> void:
	var avisos: Array[String]=[]
	var erro:=Estado.Expedicoes.simular(estado,id,avisos)
	if erro!="": painel.topo_hud.notificar(erro)
	Estado.Expedicoes.ajustar_velocidade(estado)
	painel.topo_hud.atualizar()

func abrir_combate_pendente() -> bool:
	if is_instance_valid(combate_manual): return true
	var e:=Estado.Expedicoes.manual_pendente(estado)
	if e.is_empty(): return false
	fechar_expedicoes()
	fechar_mapa()
	$Clareira1500.hide()
	_ambiente_aldeia=$Clareira1500/Atmosfera.environment
	$Clareira1500/Atmosfera.environment=null
	aldeia.hide()
	painel.hide()
	_controle.set_process(false)
	_controle.set_process_unhandled_input(false)
	aldeia.set_process_unhandled_input(false)
	combate_manual=load("res://scenes/encontros/combate_manual.tscn").instantiate()
	combate_manual.estado=estado
	combate_manual.expedicao_id=e.id
	combate_manual.concluido.connect(func():
		fechar_combate()
		aldeia.sincronizar()
		painel.atualizar(true)
		painel.topo_hud.notificar("Encontro concluído. A equipe está retornando."))
	add_child(combate_manual)
	return true

func fechar_combate() -> void:
	if not is_instance_valid(combate_manual): return
	remove_child(combate_manual)
	combate_manual.queue_free()
	combate_manual=null
	$Clareira1500.show()
	aldeia.show()
	painel.show()
	$Clareira1500/Atmosfera.environment=_ambiente_aldeia
	_controle.camera.make_current()
	_controle.set_process(true)
	_controle.set_process_unhandled_input(true)
	aldeia.set_process_unhandled_input(true)

func informar_estado(origem: String) -> void:
	if not OS.is_debug_build():
		return
	var minutos: int = floori(estado.relogio.obter_hora() * 60.0)
	print("[1500] %s | Dia %d · %02d:%02d | %dx | %s | fogueira %d | habitantes %d" % [origem,
		estado.relogio.obter_dia(), minutos / 60, minutos % 60, estado.relogio.velocidade,
		"PAUSADO" if estado.relogio.pausado else "em andamento", estado.nivel_fogueira, estado.populacao()])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and estado != null:
		if salvar_partida("automatico"):
			get_tree().quit()
		else:
			print("[1500] Fechamento cancelado para evitar perder progresso; salve novamente ou interrompa pelo editor.")

func _exit_tree() -> void:
	get_tree().paused = false
