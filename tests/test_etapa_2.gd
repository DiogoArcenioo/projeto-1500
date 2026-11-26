extends SceneTree
const Estado = preload("res://scripts/partida/estado_partida.gd")
const Relogio = preload("res://scripts/partida/relogio.gd")
const Salvamento = preload("res://scripts/partida/salvamento.gd")
const Configuracao = preload("res://scripts/partida/configuracao_partida.gd")
var falhas: int = 0
var verificacoes: int = 0
var pasta: String

func _initialize() -> void:
	root.size = Vector2i(1280,720)
	pasta = "user://testes_etapa_2/" + Crypto.new().generate_random_bytes(8).hex_encode()
	call_deferred("executar")

func verificar(condicao: bool, descricao: String) -> void:
	verificacoes += 1
	if not condicao:
		falhas += 1
		push_error("FALHOU: " + descricao)

func escrever(caminho: String, texto: String) -> void:
	var arquivo := FileAccess.open(caminho,FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()

func documento(dados: Dictionary, versao: int = 1) -> String:
	return JSON.stringify({"versao_formato":versao,"gravado_em_unix":1000,"estado":dados})

func testar_relogio() -> void:
	var a := Relogio.new()
	var b := Relogio.new()
	for i in range(30*600):
		a.avancar(1.0/30)
	for i in range(144*600):
		b.avancar(1.0/144)
	verificar(absf(a.tempo_total-b.tempo_total)<0.00001,"Mesmo tempo a 30 e 144 FPS")
	verificar(a.obter_dia()==2 and absf(a.obter_hora()-16)<0.001,"Um dia tem 600 segundos a 1x")
	b.tempo_total=0
	b.definir_velocidade(2)
	b.avancar(10)
	verificar(b.tempo_total==20,"2x")
	b.definir_velocidade(3)
	b.avancar(10)
	verificar(b.tempo_total==50,"3x")
	b.pausado=true
	b.avancar(900)
	verificar(b.tempo_total==50 and b.velocidade==3,"Pausa conserva tempo e velocidade")
	b.pausado=false
	b.avancar(1)
	verificar(b.tempo_total==53,"Retomada preserva 3x")
	b.avancar(-1)
	b.avancar(NAN)
	verificar(b.tempo_total==53,"Deltas negativos e não finitos não alteram o relógio")
	b.tempo_total=599.9
	b.definir_velocidade(1)
	b.avancar(.2)
	verificar(b.obter_dia()==2 and b.obter_hora()<.01,"Passagem da meia-noite")

func testar_estados_e_arquivos() -> void:
	var config := Configuracao.new()
	var a := Estado.nova(config) as Estado
	var b := Estado.nova(config) as Estado
	a.estoque.madeira=1
	verificar(b.estoque.madeira==120 and config.estoque_inicial.madeira==120,"Nova partida não compartilha estoque")
	verificar(a.id_partida!=b.id_partida and b.nivel_fogueira==1 and b.habitantes.is_empty(),"Nova identidade, fogueira 1 e zero habitantes")
	b.relogio.tempo_total=812.5
	b.relogio.pausado=true
	b.relogio.definir_velocidade(3)
	b.camera={"x":4.0,"z":-3.0,"angulo":1.2,"fov":30.0}
	var copia := Estado.desserializar(b.serializar()) as Estado
	verificar(copia!=null and copia.relogio.tempo_total==812.5 and copia.relogio.pausado and copia.relogio.velocidade==3,"Snapshot conserva relógio, velocidade e pausa")
	verificar(copia.camera==b.camera and copia.estoque==b.estoque,"Snapshot conserva câmera e estoque")
	var servico := Salvamento.new(pasta)
	verificar(not servico.carregar("manual").ok,"Arquivo ausente informado")
	verificar(servico.salvar(b,"manual").ok,"Primeira gravação local")
	b.estoque.madeira=37
	verificar(servico.salvar(b,"manual").ok,"Substituição de arquivo existente no Windows")
	verificar(servico.carregar("manual").estado.estoque.madeira==37,"Leitura recupera versão mais recente")
	verificar(servico.carregar("manual",true).estado.estoque.madeira==120,"Backup conserva gravação anterior")
	var hash_anterior := FileAccess.get_sha256(servico.caminho("manual"))
	b.relogio.tempo_total=NAN
	verificar(not servico.salvar(b,"manual").ok and FileAccess.get_sha256(servico.caminho("manual"))==hash_anterior,"Estado inválido não sobrescreve save saudável")
	b.relogio.tempo_total=812.5
	verificar(not servico.salvar(b,"../manual").ok,"Slot inválido recusado")
	b.modo=Estado.MODO_IRONMAN
	verificar(not servico.salvar(b,"manual").ok,"Contrato Ironman não libera um modo incompleto")
	b.modo=Estado.MODO_PADRAO
	var c := b.serializar()
	var casos: Array[String] = ["{quebrado", documento(c,99)]
	var negativo := c.duplicate(true)
	negativo.estoque.madeira=-2
	casos.append(documento(negativo))
	var velocidade := c.duplicate(true)
	velocidade.relogio.velocidade=1.5
	casos.append(documento(velocidade))
	var sem_campo := c.duplicate(true)
	sem_campo.erase("relogio")
	casos.append(documento(sem_campo))
	var backup_hash := FileAccess.get_sha256(servico.caminho("manual")+".bak")
	for i in range(casos.size()):
		escrever(servico.caminho("manual"),casos[i])
		var hash_ruim := FileAccess.get_sha256(servico.caminho("manual"))
		verificar(not servico.carregar("manual").ok,"Arquivo malformado/incompatível recusado: "+str(i))
		verificar(FileAccess.get_sha256(servico.caminho("manual"))==hash_ruim,"Carregar não altera arquivo inválido: "+str(i))
	verificar(servico.salvar(b,"manual").ok and FileAccess.get_sha256(servico.caminho("manual")+".bak")==backup_hash,"Regravação não troca backup bom por arquivo corrompido")
	escrever(pasta.path_join("bloqueio"),"arquivo, não diretório")
	var bloqueado := Salvamento.new(pasta.path_join("bloqueio"))
	verificar(not bloqueado.salvar(b,"manual").ok,"Falha de escrita informada")
	verificar(servico.carregar("manual").ok,"Falha em outro destino não afeta partida saudável")

func tecla(codigo: Key, shift: bool=false, ctrl: bool=false) -> void:
	var evento := InputEventKey.new()
	evento.physical_keycode=codigo
	evento.keycode=codigo
	evento.pressed=true
	evento.shift_pressed=shift
	evento.ctrl_pressed=ctrl
	Input.parse_input_event(evento)
	evento=evento.duplicate()
	evento.pressed=false
	Input.parse_input_event(evento)

func botao_mouse(codigo: MouseButton, posicao: Vector2, pressionado: bool=true) -> void:
	var evento := InputEventMouseButton.new()
	evento.position=posicao
	evento.button_index=codigo
	evento.pressed=pressionado
	root.push_input(evento)

func testar_integracao() -> void:
	var cena: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	cena.set("salvamento",Salvamento.new(pasta))
	var config := Configuracao.new()
	config.duracao_dia_segundos=6
	config.intervalo_autosave=.2
	cena.set("configuracao",config)
	root.add_child(cena)
	cena.set_process(false)
	var controle: Node = cena.get_node("ControleDaCamera")
	var mundo: Node3D = cena.get_node("Clareira1500")
	await process_frame
	tecla(KEY_3)
	await process_frame
	verificar(cena.estado.relogio.velocidade==3,"Atalho 3 escolhe 3x")
	tecla(KEY_SPACE)
	await process_frame
	var hora_parada: float = cena.estado.relogio.tempo_total
	var visual_parado: float = mundo._tempo_visual
	cena._process(100)
	await process_frame
	await process_frame
	verificar(paused and cena.estado.relogio.tempo_total==hora_parada,"Espaço pausa a árvore e o relógio")
	verificar(mundo._tempo_visual==visual_parado and not mundo.get_node("Fogueira/Faiscas").can_process(),"Pausa também congela shaders, oscilação da luz e partículas")
	verificar(controle.can_process(),"Câmera continua utilizável com mundo pausado")
	tecla(KEY_F6)
	await process_frame
	verificar(FileAccess.file_exists(pasta.path_join("manual.json")),"Atalho F6 grava mesmo em pausa")
	tecla(KEY_SPACE)
	await process_frame
	verificar(not paused and cena.estado.relogio.velocidade==3,"Espaço retoma em 3x")
	cena.estado.relogio.avancar(2)
	tecla(KEY_F7)
	await process_frame
	verificar(paused and absf(cena.estado.relogio.tempo_total-hora_parada)<.00001,"F7 restaura horário, pausa e velocidade")
	var id_salvo: String = cena.estado.id_partida
	tecla(KEY_N,false,true)
	await process_frame
	verificar(not paused and cena.estado.id_partida!=id_salvo and cena.estado.relogio.velocidade==1,"Ctrl+N cria uma partida independente")
	verificar(cena.estado.estoque.madeira==120 and cena.estado.habitantes.is_empty(),"Nova partida restaura dados iniciais")
	cena._process(.3)
	verificar(cena.salvamento.carregar("automatico").ok,"Autosave por intervalo")
	var hash_auto := FileAccess.get_sha256(pasta.path_join("automatico.json"))
	tecla(KEY_SPACE)
	await process_frame
	cena._process(300)
	verificar(FileAccess.get_sha256(pasta.path_join("automatico.json"))==hash_auto,"Pausa não avança intervalo de autosave")
	tecla(KEY_F7,true)
	await process_frame
	verificar(not paused,"Shift+F7 carrega autosave sem disparar F7 manual pausado")
	cena.configuracao.intervalo_autosave=1000
	cena.estado.relogio.tempo_total=5.99
	cena._process(.02)
	verificar(cena.salvamento.carregar("automatico").estado.relogio.obter_dia()==2,"Novo dia provoca autosave")
	var identidade: String = cena.estado.id_partida
	escrever(pasta.path_join("manual.json"),"{corrompido")
	verificar(not cena.carregar_partida("manual") and cena.estado.id_partida==identidade,"Falha de leitura preserva a partida em memória")
	var iluminacao: Node = cena.iluminacao
	iluminacao.aplicar(16)
	verificar(is_equal_approx(iluminacao.sol.light_energy,2.6) and iluminacao.sol.light_color.is_equal_approx(Color("ffd18c")),"16h preserva a iluminação aprovada")
	iluminacao.aplicar(0)
	verificar(iluminacao.sol.light_energy==0 and iluminacao.luar.light_energy>0 and mundo.intensidade_fogo_base>3.1,"Noite sem sol; luar e fogueira visíveis")
	var energia_meia_noite: float = iluminacao.ambiente.ambient_light_energy
	iluminacao.aplicar(23.99999)
	verificar(absf(iluminacao.ambiente.ambient_light_energy-energia_meia_noite)<.0001,"Luz contínua na passagem de dia")
	iluminacao.aplicar(12)
	verificar(iluminacao.sol.light_energy>2,"Luz diurna")
	var foco_anterior: Vector3 = controle.foco_alvo
	Input.action_press("camera_direita")
	controle._process(1)
	Input.action_release("camera_direita")
	verificar(controle.foco_alvo.distance_to(foco_anterior)>1,"WASD desloca a câmera")
	Input.action_press("camera_girar_direita")
	var angulo_anterior: float = controle.angulo_alvo
	controle._process(.5)
	Input.action_release("camera_girar_direita")
	verificar(controle.angulo_alvo>angulo_anterior,"Q/E gira a câmera")
	controle.foco_alvo=Vector3(1000,1,-1000)
	controle._process(1)
	verificar(controle.foco_alvo.x<=controle.limites.end.x and controle.foco_alvo.z>=controle.limites.position.y,"Deslocamento limitado ao cenário")
	controle.recentrar()
	controle._process(1)
	for i in range(50):
		botao_mouse(MOUSE_BUTTON_WHEEL_UP,Vector2(600,400))
	verificar(controle.fov_alvo==controle.zoom_minimo,"Limite de aproximação")
	for i in range(50):
		botao_mouse(MOUSE_BUTTON_WHEEL_DOWN,Vector2(600,400))
	verificar(controle.fov_alvo==controle.zoom_maximo,"Limite de afastamento")
	controle._process(1)
	verificar(controle.camera.position.y>=33 and controle.camera.near<1,"Órbita se mantém acima das copas")
	var antes: Vector3=controle.foco_alvo
	botao_mouse(MOUSE_BUTTON_LEFT,Vector2(600,400))
	botao_mouse(MOUSE_BUTTON_LEFT,Vector2(610,410),false)
	verificar(controle.foco_alvo==antes,"Clique esquerdo não arrasta o mundo")
	botao_mouse(MOUSE_BUTTON_MIDDLE,Vector2(600,400))
	var movimento := InputEventMouseMotion.new()
	movimento.position=Vector2(720,400)
	movimento.relative=Vector2(120,0)
	movimento.button_mask=MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(movimento)
	botao_mouse(MOUSE_BUTTON_MIDDLE,Vector2(720,400),false)
	verificar(controle.foco_alvo.distance_to(antes)>.1,"Arraste do botão central")
	var bloqueio := Control.new()
	root.add_child(bloqueio)
	bloqueio.position=Vector2.ZERO
	bloqueio.size=Vector2(1280,720)
	bloqueio.mouse_filter=Control.MOUSE_FILTER_STOP
	var sobre_interface := InputEventMouseMotion.new()
	sobre_interface.position=Vector2(100,100)
	root.push_input(sobre_interface)
	await process_frame
	var antes_ui: float = controle.fov_alvo
	botao_mouse(MOUSE_BUTTON_WHEEL_UP,Vector2(100,100))
	botao_mouse(MOUSE_BUTTON_MIDDLE,Vector2(100,100))
	if DisplayServer.get_name() != "headless":
		verificar(controle.fov_alvo==antes_ui and not controle._arrastando,"Interface bloqueia zoom e início de arraste")
	else:
		print("GUI: verificação de sobreposição executada somente com janela gráfica; o driver headless usa janela fictícia.")
	botao_mouse(MOUSE_BUTTON_MIDDLE,Vector2(100,100),false)
	bloqueio.queue_free()
	await process_frame
	# O mesmo caminho usado pelo fechamento normal da janela grava antes de sair.
	cena._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	verificar(cena.salvamento.carregar("automatico").estado.id_partida==cena.estado.id_partida,"Fechamento normal grava a partida atual")
	cena.queue_free()

func executar() -> void:
	testar_relogio()
	testar_estados_e_arquivos()
	await testar_integracao()
	print("ETAPA_2: ", verificacoes," verificações; ",falhas," falhas")
	# Limpeza somente dos arquivos da pasta exclusiva criada por esta execução.
	if falhas==0 and pasta.begins_with("user://testes_etapa_2/"):
		var diretorio := DirAccess.open(pasta)
		for arquivo: String in diretorio.get_files():
			DirAccess.remove_absolute(pasta.path_join(arquivo))
		DirAccess.remove_absolute(pasta)
	quit(0 if falhas==0 else 1)
