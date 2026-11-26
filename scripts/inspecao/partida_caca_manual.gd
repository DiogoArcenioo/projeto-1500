extends "res://scripts/partida/principal.gd"
## Partida jogável de inspeção: mesmas regras, slots separados e sem editar saves reais.
func _ready() -> void:
	salvamento=Salvamento.new("user://inspecao_etapa_10")
	super._ready()
	estado.id_partida="0123456789abcdef0123456789abcdef"
	estado.relogio.tempo_total=305
	estado.tempo_economia=305
	estado.estoque.madeira=200;estado.estoque.fibras_vegetais=100
	estado.construir("oca",Vector2(-5,-4));estado.avancar_aldeia(60)
	estado.construir("caca",Vector2(-6,5.5));estado.avancar_aldeia(60)
	var ids: Array=estado.habitantes.map(func(h):return h.id)
	Estado.Expedicoes.enviar(estado,"obra_2","caca",14,ids,"manual",{ids[0]:"lanca",ids[1]:"arco"})
	estado.relogio.tempo_total+=1500
	estado.avancar_simulacao(1500)
	aldeia.sincronizar();painel.atualizar(true)
	abrir_combate_pendente()
