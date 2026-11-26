extends "res://scripts/partida/principal.gd"
## Pescaria jogável de inspeção (etapa 12): mesmas regras, slots separados e sem editar
## saves reais. Envia uma pescaria "à mão" e abre a cena assim que a equipe chega ao rio.
@export var regiao_pesca:=21
@export var automatico:=false
@export var especie_forcada:=""
@export var peso_forcado:=0.0
@export var z_rio:=-5.0
func _ready() -> void:
	salvamento=Salvamento.new("user://inspecao_pesca")
	super._ready()
	estado.id_partida="0123456789abcdef0123456789abcdef"
	for k in estado.conhecimento: estado.conhecimento[k]=maxi(2,int(estado.conhecimento[k]))
	var viagem:=Estado.Regioes.viagem(regiao_pesca,estado.conhecimento)
	var chegada: float=3+viagem+1
	# Chega ao rio por volta das 14h.
	var dia: float=estado.relogio.duracao_dia_segundos
	estado.relogio.tempo_total=dia+fposmod(dia*14.0/24.0-chegada,dia)
	estado.tempo_economia=estado.relogio.tempo_total
	estado.estoque.madeira=200;estado.estoque.fibras_vegetais=100
	estado.construir("oca",Vector2(-5,-4));estado.avancar_aldeia(60)
	estado.construir("pesca",Vector2(8,1.2));estado.avancar_aldeia(60)
	var ids: Array=estado.habitantes.map(func(h):return h.id)
	var r:=Estado.Expedicoes.enviar(estado,"obra_2","pesca",regiao_pesca,ids,"manual")
	if not r.ok: push_error(r.erro)
	estado.relogio.tempo_total+=chegada
	estado.avancar_simulacao(chegada)
	aldeia.sincronizar();painel.atualizar(true)
	abrir_pesca_pendente()

func configurar_pesca(cena: Node) -> void:
	cena.automatico=automatico
	cena.z_local=z_rio
	if especie_forcada!="": cena.peixe_forcado={"especie":especie_forcada,"peso":peso_forcado}
