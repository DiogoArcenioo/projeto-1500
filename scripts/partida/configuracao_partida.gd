extends Resource
## Parâmetros provisórios do início; a economia só será implementada na etapa 3.
@export_range(1.0, 86400.0, 1.0) var duracao_dia_segundos: float = 600.0
@export_range(0.0, 23.99, 0.01) var hora_inicial: float = 16.0
@export_range(1.0, 3600.0, 1.0) var intervalo_autosave: float = 60.0
@export var estoque_inicial: Dictionary = {
	"vegetais": 8, "carne": 0, "peixe": 0, "madeira": 120,
	"pedra": 80, "fibras_vegetais": 80, "couro": 0, "plantas_medicinais": 12,
}
