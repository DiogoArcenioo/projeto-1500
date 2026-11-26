extends RefCounted
## Gravação síncrona: temporário validado, backup saudável e substituição por rename.
const Estado = preload("res://scripts/partida/estado_partida.gd")
const VERSAO_FORMATO: int = 1
const LIMITE_BYTES: int = 1048576
const SLOTS := ["manual", "automatico"]
var pasta: String
var _gravando: bool = false

func _init(diretorio: String = "user://partidas") -> void:
	pasta = diretorio

func caminho(slot: String) -> String:
	return pasta.path_join(slot + ".json") if slot in SLOTS else ""

func falha(mensagem: String) -> Dictionary:
	return {"ok": false, "erro": mensagem}

func ler_arquivo(arquivo: String) -> Dictionary:
	if not FileAccess.file_exists(arquivo):
		return falha("Arquivo de partida não encontrado: " + arquivo)
	var entrada := FileAccess.open(arquivo, FileAccess.READ)
	if entrada == null:
		return falha("Não foi possível abrir a partida: " + error_string(FileAccess.get_open_error()))
	if entrada.get_length() > LIMITE_BYTES:
		return falha("Arquivo excede o limite do formato desta etapa.")
	var texto := entrada.get_as_text()
	entrada.close()
	var json := JSON.new()
	if json.parse(texto) != OK or not json.data is Dictionary:
		return falha("Arquivo corrompido ou JSON inválido.")
	var envelope: Dictionary = json.data
	if not Estado.numero(envelope.get("versao_formato"), VERSAO_FORMATO, VERSAO_FORMATO, true):
		return falha("Versão de salvamento incompatível; arquivo preservado.")
	if not Estado.numero(envelope.get("gravado_em_unix"), 0, 1000000000000):
		return falha("Metadados da gravação inválidos.")
	var erro: String = Estado.validar(envelope.get("estado"))
	if not erro.is_empty():
		return falha(erro)
	return {"ok": true, "estado": Estado.desserializar(envelope.estado)}

func carregar(slot: String, backup: bool = false) -> Dictionary:
	var destino := caminho(slot)
	if destino.is_empty():
		return falha("Slot desconhecido.")
	return ler_arquivo(destino + ".bak" if backup else destino)

func salvar(estado: RefCounted, slot: String) -> Dictionary:
	if _gravando:
		return falha("Já existe uma gravação em andamento.")
	var destino := caminho(slot)
	if destino.is_empty():
		return falha("Slot desconhecido.")
	# Ironman fica registrado no contrato de dados; sua política será entregue na etapa 23.
	if estado.modo != Estado.MODO_PADRAO:
		return falha("Salvamento Ironman ainda não habilitado nesta etapa.")
	var dados: Dictionary = estado.serializar()
	var erro := Estado.validar(dados)
	if not erro.is_empty():
		return falha("Gravação cancelada: " + erro)
	_gravando = true
	var resultado := _gravar(dados, destino)
	_gravando = false
	return resultado

func _gravar(dados: Dictionary, destino: String) -> Dictionary:
	var erro := DirAccess.make_dir_recursive_absolute(pasta)
	if erro != OK:
		return falha("Não foi possível criar a pasta de partidas: " + error_string(erro))
	var temporario := destino + ".tmp"
	var saida := FileAccess.open(temporario, FileAccess.WRITE)
	if saida == null:
		return falha("Não foi possível criar o temporário: " + error_string(FileAccess.get_open_error()))
	saida.store_string(JSON.stringify({"versao_formato": VERSAO_FORMATO,
		"gravado_em_unix": floori(Time.get_unix_time_from_system()), "estado": dados}, "\t"))
	saida.flush()
	erro = saida.get_error()
	saida.close()
	if erro != OK:
		return falha("Falha ao gravar o temporário; partida anterior preservada.")
	if not ler_arquivo(temporario).ok:
		return falha("Temporário não passou na validação; partida anterior preservada.")
	# Nunca substituir um backup saudável pela cópia de um arquivo corrompido.
	if FileAccess.file_exists(destino) and ler_arquivo(destino).ok:
		var backup_temporario := destino + ".bak.tmp"
		erro = DirAccess.copy_absolute(destino, backup_temporario)
		if erro == OK:
			erro = DirAccess.rename_absolute(backup_temporario, destino + ".bak")
		if erro != OK:
			return falha("Não foi possível preservar o backup; gravação cancelada.")
	erro = DirAccess.rename_absolute(temporario, destino)
	if erro != OK:
		return falha("Não foi possível substituir a partida: " + error_string(erro))
	return {"ok": true, "caminho": destino}
