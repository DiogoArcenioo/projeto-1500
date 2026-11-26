extends RefCounted
const Combate=preload("res://scripts/partida/combate.gd")
const Alimentacao=preload("res://scripts/partida/alimentacao.gd")

static func fauna(regiao: int) -> Array:
	if regiao==20: return []
	if regiao in [14,21]: return ["capivara"]
	if regiao in [3,8,9,15,27,28]: return ["capivara","jacare_papo_amarelo"]
	if regiao in [0,6,12,22]: return ["queixada"]
	if regiao in [10,18,19,24,25]: return ["queixada","anta","onca_pintada"]
	return ["queixada","anta"]
static func criar(estado,e: Dictionary) -> void:
	var rng:=RandomNumberGenerator.new()
	rng.state=int(e.rng)
	var opcoes:=fauna(int(e.regiao)).duplicate()
	var experiente: bool=estado.expedicoes.any(func(x): return x.tipo=="caca" and not x.get("combate",{}).is_empty() and x.combate.get("resultado","")!="")
	if not experiente: opcoes.erase("onca_pintada")
	# Predador raro nas matas remotas. O encontro é defensivo, não alvo inicial de caça.
	var animal: String=opcoes[rng.randi_range(0,opcoes.size()-1)]
	if animal=="onca_pintada" and rng.randf()>.15: animal="queixada"
	var equipe: Array=[]
	for i in range(e.equipe.size()):
		var h: Dictionary=estado.pessoa(e.equipe[i]).duplicate(true)
		h.especialista_caca=(h.setor==e.centro or h.habilidades.caca>0)
		equipe.append(Combate.humano(h,e.armas.get(h.id,"arco"),1,3+i,Alimentacao.resistencia_efetiva(estado,h)))
	var aguas: Array=[]
	if animal=="jacare_papo_amarelo":
		for z in range(8): aguas.append({"x":7,"z":z})
	e.combate=Combate.novo(equipe,animal,rng.randi(),[{"x":3,"z":5},{"x":4,"z":1}],[{"x":4,"z":4}],aguas)
	e.rng=str(rng.state)

static func aplicar(estado,e: Dictionary) -> Array[String]:
	var c: Dictionary=e.combate
	var mensagens: Array[String]=[]
	if c.resultado=="" or c.aplicado: return mensagens
	var xp_total:=0
	for a: Dictionary in c.atores:
		if a.lado!="equipe": continue
		var h: Dictionary=estado.pessoa(a.id)
		if a.morto:
			h.saude=0
			h.estado="morto"
			h.obra=""
			h.setor=""
			h.expedicao=""
			mensagens.append(h.nome+" morreu no encontro.")
		else:
			var saude:=20 if a.vida<=0 else maxi(1,ceili(100.0*a.vida/a.vida_max))
			h.saude=minf(h.saude,saude)
			var xp_caca:=3 if c.resultado=="vitoria" else 0
			var xp_combate:=mini(int(a.xp),8-xp_caca)
			estado.experiencia(h,"combate",xp_combate)
			estado.experiencia(h,"caca",xp_caca)
			xp_total+=xp_caca+xp_combate
			if h.saude<50: mensagens.append(h.nome+" retornará ferido.")
	e.xp=xp_total
	for r in c.recursos:
		e.carga[r]=int(c.recursos[r])
		if r in Alimentacao.TIPOS: e.vencimentos[r]=estado.tempo_economia+Alimentacao.parametros.validade_dias[r]*estado.relogio.duracao_dia_segundos
	c.aplicado=true
	mensagens.append("%s · %s"%[Combate.nome_animal(c.animal),c.resultado.replace("_"," ")])
	return mensagens

static func validar(e: Dictionary,numero: Callable) -> String:
	if not e.get("armas") is Dictionary: return "Equipamento de caça ausente."
	for id in e.armas:
		if id not in e.equipe or e.armas[id] not in ["arco","lanca"]: return "Kit de caça inválido."
	var c: Variant=e.get("combate",{})
	if not c is Dictionary: return "Confronto de caça inválido."
	if c.is_empty():
		return "Fase sem confronto." if e.fase=="confronto" else ""
	if e.get("modo","simulado")=="manual" and c.get("animal")!="capivara": return "Animal sem apresentação manual aprovada."
	var erro:=Combate.validar(c,numero)
	if erro!="": return erro
	var ids: Array=c.atores.filter(func(a): return a.lado=="equipe").map(func(a): return a.id)
	if ids.size()!=e.equipe.size() or ids.any(func(id): return id not in e.equipe): return "Equipe do confronto difere da viagem."
	if e.fase=="confronto" and (c.resultado!="" or c.aplicado): return "Confronto ativo já encerrado."
	if e.fase in ["retorno","aguardando_descarga","concluida"] and not c.aplicado: return "Resultado da caça não aplicado."
	return ""
