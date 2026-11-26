extends SceneTree
const Estado = preload("res://scripts/partida/estado_partida.gd")
const Salvamento = preload("res://scripts/partida/salvamento.gd")
const Configuracao = preload("res://scripts/partida/configuracao_partida.gd")
const PASTA := "user://testes_etapa_2/entre_processos"

func _initialize() -> void:
	var servico := Salvamento.new(PASTA)
	if "--gravar" in OS.get_cmdline_user_args():
		var estado := Estado.nova(Configuracao.new()) as Estado
		estado.relogio.tempo_total=1571.5
		estado.relogio.pausado=true
		estado.relogio.definir_velocidade(2)
		estado.estoque.madeira=47
		estado.camera={"x":12.0,"z":4.0,"angulo":1.5,"fov":24.0}
		var resultado := servico.salvar(estado,"manual")
		print("PERSISTENCIA_GRAVAR: ",resultado.ok)
		quit(0 if resultado.ok else 1)
		return
	var leitura := servico.carregar("manual")
	if not leitura.ok:
		push_error(leitura.erro)
		quit(1)
		return
	var recuperado: RefCounted = leitura.estado
	var valido: bool = recuperado.relogio.tempo_total==1571.5 and recuperado.relogio.pausado and recuperado.relogio.velocidade==2
	valido = valido and recuperado.estoque.madeira==47 and recuperado.nivel_fogueira==1 and recuperado.habitantes.is_empty()
	valido = valido and recuperado.camera.fov==24.0 and recuperado.camera.x==12.0
	print("PERSISTENCIA_NOVO_PROCESSO: ",valido)
	if valido:
		for arquivo: String in DirAccess.open(PASTA).get_files():
			DirAccess.remove_absolute(PASTA.path_join(arquivo))
		DirAccess.remove_absolute(PASTA)
	quit(0 if valido else 1)
