extends RefCounted
## Fonte única de tempo estratégico. Segundos nesta classe correspondem a tempo a 1x.
signal dia_iniciado(dia: int)

var duracao_dia_segundos: float = 600.0
var tempo_total: float = 400.0
var velocidade: int = 1
var pausado: bool = false

func avancar(delta: float) -> float:
	if pausado or not is_finite(delta) or delta <= 0.0:
		return 0.0
	var dia_anterior := obter_dia()
	var decorrido := delta * velocidade
	tempo_total += decorrido
	if obter_dia() != dia_anterior:
		dia_iniciado.emit(obter_dia())
	return decorrido

func obter_dia() -> int:
	return 1 + floori(tempo_total / duracao_dia_segundos)

func obter_hora() -> float:
	return fposmod(tempo_total, duracao_dia_segundos) / duracao_dia_segundos * 24.0

func definir_velocidade(valor: int) -> void:
	if valor in [1, 2, 3]:
		velocidade = valor

func serializar() -> Dictionary:
	return {"duracao_dia_segundos": duracao_dia_segundos, "tempo_total": tempo_total,
		"velocidade": velocidade, "pausado": pausado}
