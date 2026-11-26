extends SceneTree
## Registra os atalhos iniciais uma vez, preservando remapeamentos existentes.
func _initialize() -> void:
	var acoes := {
		"camera_cima": [KEY_W], "camera_baixo": [KEY_S], "camera_esquerda": [KEY_A],
		"camera_direita": [KEY_D], "camera_girar_esquerda": [KEY_Q], "camera_girar_direita": [KEY_E],
		"camera_recentrar": [KEY_R], "partida_pausar": [KEY_SPACE],
		"partida_velocidade_1": [KEY_1], "partida_velocidade_2": [KEY_2], "partida_velocidade_3": [KEY_3],
		"partida_salvar": [KEY_F6], "partida_carregar": [KEY_F7],
		"partida_carregar_auto": [KEY_F7, "shift"], "partida_nova": [KEY_N, "ctrl"], "debug_estado": [KEY_F9],
	}
	for nome: String in acoes:
		if ProjectSettings.has_setting("input/"+nome):
			continue
		var tecla := InputEventKey.new()
		tecla.physical_keycode = acoes[nome][0]
		tecla.shift_pressed = acoes[nome].size()>1 and acoes[nome][1]=="shift"
		tecla.ctrl_pressed = acoes[nome].size()>1 and acoes[nome][1]=="ctrl"
		ProjectSettings.set_setting("input/"+nome, {"deadzone":0.2,"events":[tecla]})
	print("ENTRADAS: ", error_string(ProjectSettings.save()))
	quit()
