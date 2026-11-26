extends "res://scripts/ui/menu_expedicao_casca.gd"
func preencher_estado() -> void:
	estado=E.nova(Config.new())
	estado.id_partida="15000000000000000000000000000000"
	estado.estoque.madeira=250
	estado.estoque.fibras_vegetais=200
	for p in [Vector2(-5,-4),Vector2(4,-8),Vector2(-6,5.5),Vector2(4,7)]:
		estado.construir("oca",p)
		estado.avancar_aldeia(18)
	estado.construir("caca",Vector2(6,-1))
	estado.avancar_aldeia(60)
	for i in range(estado.habitantes.size()):
		var h: Dictionary=estado.habitantes[i]
		h.habilidades.caca=[24,12,8,36,4,18,42,6][i]
		h.habilidades.combate=[8,4,2,16,0,7,20,1][i]
		h.xp=h.habilidades.caca+h.habilidades.combate
		h.nivel=1+floori(h.xp/100.0)
