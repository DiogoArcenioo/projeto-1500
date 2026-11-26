extends "res://scripts/partida/principal.gd"
## Partida jogável de inspeção: mesmas regras, slots separados e sem editar saves reais.
## Região 14 (Arredores): capivara. Região 6 (Encosta oeste): queixada.
@export var regiao_caca:=14
## Segundos iniciais do relógio (o encontro acontece 1.500 s depois).
@export var tempo_inicial:=305.0
## Só para inspeção: troca o animal sorteado (ex.: jacaré num rio onde também há capivara).
@export var animal_forcado:=""
func _ready() -> void:
	salvamento=Salvamento.new("user://inspecao_etapa_10" if regiao_caca==14 else "user://inspecao_animal_%d"%regiao_caca)
	super._ready()
	estado.id_partida="0123456789abcdef0123456789abcdef"
	estado.relogio.tempo_total=tempo_inicial
	estado.tempo_economia=tempo_inicial
	if regiao_caca!=14:
		for k in estado.conhecimento: estado.conhecimento[k]=maxi(2,int(estado.conhecimento[k]))
		# O relógio para no instante do encontro: parte num horário que leva a ~14h.
		var viagem:=Estado.Regioes.viagem(regiao_caca,estado.conhecimento)
		var chegada: float=3+viagem+Estado.Expedicoes.duracao_planejada("caca",viagem)
		var dia: float=estado.relogio.duracao_dia_segundos
		estado.relogio.tempo_total=dia+fposmod(dia*14.0/24.0-chegada,dia)
		estado.tempo_economia=estado.relogio.tempo_total
	estado.estoque.madeira=200;estado.estoque.fibras_vegetais=100
	estado.construir("oca",Vector2(-5,-4));estado.avancar_aldeia(60)
	estado.construir("caca",Vector2(-6,5.5));estado.avancar_aldeia(60)
	var ids: Array=estado.habitantes.map(func(h):return h.id)
	Estado.Expedicoes.enviar(estado,"obra_2","caca",regiao_caca,ids,"manual",{ids[0]:"lanca",ids[1]:"arco"})
	estado.relogio.tempo_total+=1500
	estado.avancar_simulacao(1500)
	aldeia.sincronizar();painel.atualizar(true)
	var pendente:=Estado.Expedicoes.manual_pendente(estado)
	if animal_forcado!="" and not pendente.is_empty() and pendente.combate.animal!=animal_forcado:
		Estado.Expedicoes.Caca.criar(estado,pendente,animal_forcado)
	abrir_combate_pendente()
