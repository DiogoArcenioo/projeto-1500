extends RefCounted
const Combate=preload("res://scripts/partida/combate.gd")
const Alimentacao=preload("res://scripts/partida/alimentacao.gd")
## Animais com apresentação manual aprovada (modelo, rig e clipes no Godot).
const APRESENTACAO_MANUAL:=["capivara","queixada","jacare_papo_amarelo","anta","onca_pintada"]
## Etapa 11: fração da carga perdida em retirada ou derrota (provisório, aprovado).
const PERDA_CARGA:=.5

static func fauna(regiao: int) -> Array:
	if regiao==20: return []
	if regiao in [14,21]: return ["capivara"]
	if regiao in [3,8,9,15,27,28]: return ["capivara","jacare_papo_amarelo"]
	if regiao in [0,6,12,22]: return ["queixada"]
	if regiao in [10,18,19,24,25]: return ["queixada","anta","onca_pintada"]
	return ["queixada","anta"]

## Regiões onde toda a fauna tem apresentação manual, inclusive encontros defensivos.
static func regioes_manuais() -> Array:
	var lista: Array=[]
	for r in range(30):
		var f:=fauna(r)
		if not f.is_empty() and f.all(func(a): return a in APRESENTACAO_MANUAL): lista.append(r)
	return lista

static func experiente(estado) -> bool:
	return estado.expedicoes.any(func(x): return x.tipo=="caca" and not x.get("combate",{}).is_empty() and x.combate.get("resultado","")!="")

## Escolhe o animal: onça só depois da primeira caça concluída e, mesmo assim, rara.
static func sortear_animal(estado,opcoes: Array,rng: RandomNumberGenerator) -> String:
	opcoes=opcoes.duplicate()
	if not experiente(estado): opcoes.erase("onca_pintada")
	if opcoes.is_empty(): return ""
	var animal: String=opcoes[rng.randi_range(0,opcoes.size()-1)]
	# Predador raro nas matas remotas. O encontro é defensivo, não alvo inicial de caça.
	if animal=="onca_pintada" and rng.randf()>.15: animal="queixada"
	return animal

## Cria o confronto da expedição. Fora da caça a equipe usa a ferramenta básica
## e só é especialista quem tem prática de caça.
static func criar(estado,e: Dictionary,animal:="") -> void:
	var rng:=RandomNumberGenerator.new()
	rng.state=int(e.rng)
	if animal=="": animal=sortear_animal(estado,fauna(int(e.regiao)),rng)
	var equipe: Array=[]
	for i in range(e.equipe.size()):
		var h: Dictionary=estado.pessoa(e.equipe[i]).duplicate(true)
		h.especialista_caca=(h.setor==e.centro and e.tipo=="caca") or h.habilidades.caca>0
		var arma: String=e.get("armas",{}).get(h.id,"arco") if e.tipo=="caca" else "ferramenta"
		equipe.append(Combate.humano(h,arma,1,3+i,Alimentacao.resistencia_efetiva(estado,h)))
	var aguas: Array=[]
	if animal=="jacare_papo_amarelo":
		for z in range(8): aguas.append({"x":7,"z":z})
	e.combate=Combate.novo(equipe,animal,rng.randi(),[{"x":3,"z":5},{"x":4,"z":1}],[{"x":4,"z":4}],aguas)
	e.combate.politica=e.get("politica","equilibrada")
	e.rng=str(rng.state)

static func aplicar(estado,e: Dictionary) -> Array[String]:
	var c: Dictionary=e.combate
	var mensagens: Array[String]=[]
	if c.resultado=="" or c.aplicado: return mensagens
	var relatorio:={"animal":c.animal,"resultado":c.resultado,"modo":e.get("modo","simulado"),
		"perdas":{},"feridos":[],"mortos":[],"xp":{}}
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
			relatorio.mortos.append(h.nome)
			mensagens.append(h.nome+" morreu no encontro.")
		else:
			var saude:=20 if a.vida<=0 else maxi(1,ceili(100.0*a.vida/a.vida_max))
			h.saude=minf(h.saude,saude)
			var xp_caca:=3 if c.resultado=="vitoria" else 0
			var xp_combate:=mini(int(a.xp),8-xp_caca)
			estado.experiencia(h,"combate",xp_combate)
			estado.experiencia(h,"caca",xp_caca)
			xp_total+=xp_caca+xp_combate
			relatorio.xp[h.nome]=xp_caca+xp_combate
			if h.saude<50:
				relatorio.feridos.append(h.nome)
				mensagens.append(h.nome+" retornará ferido.")
	# Na caça o XP do confronto é o XP da viagem; nas demais atividades o XP
	# da expedição continua contando ciclos de trabalho.
	if e.tipo=="caca": e.xp=xp_total
	else: e.xp_encontro=xp_total
	if c.resultado in ["retirada","derrota"]:
		for r in e.carga.keys():
			var perdido:=floori(int(e.carga[r])*PERDA_CARGA)
			if perdido<=0: continue
			e.carga[r]=int(e.carga[r])-perdido
			relatorio.perdas[r]=perdido
			if e.carga[r]==0: e.carga.erase(r)
		if not relatorio.perdas.is_empty(): mensagens.append("Parte da carga foi abandonada na fuga.")
	var capacidade: int=int(estado.Expedicoes.parametros.carga_por_pessoa)*e.equipe.size() if e.tipo!="caca" else 1000000
	for r in c.recursos:
		var livre:=capacidade-quantidade(e.carga)
		var valor:=mini(int(c.recursos[r]),maxi(0,livre))
		if valor<=0: continue
		e.carga[r]=int(e.carga.get(r,0))+valor
		if r in Alimentacao.TIPOS:
			if not e.has("vencimentos"): e.vencimentos={}
			if not e.vencimentos.has(r): e.vencimentos[r]=estado.tempo_economia+Alimentacao.parametros.validade_dias[r]*estado.relogio.duracao_dia_segundos
	c.aplicado=true
	e.relatorio=relatorio
	mensagens.append("%s · %s"%[Combate.nome_animal(c.animal),c.resultado.replace("_"," ")])
	return mensagens

static func quantidade(carga: Dictionary) -> int:
	var total:=0
	for q in carga.values(): total+=int(q)
	return total

static func validar(e: Dictionary,numero: Callable) -> String:
	if e.tipo=="caca" and not e.get("armas") is Dictionary: return "Equipamento de caça ausente."
	for id in e.get("armas",{}):
		if id not in e.equipe or e.armas[id] not in ["arco","lanca"]: return "Kit de caça inválido."
	var c: Variant=e.get("combate",{})
	if not c is Dictionary: return "Confronto de caça inválido."
	if c.is_empty():
		return "Fase sem confronto." if e.fase in ["confronto","alerta"] else ""
	if e.get("modo","simulado")=="manual" and c.get("animal") not in APRESENTACAO_MANUAL: return "Animal sem apresentação manual aprovada."
	var erro:=Combate.validar(c,numero)
	if erro!="": return erro
	var ids: Array=c.atores.filter(func(a): return a.lado=="equipe").map(func(a): return a.id)
	if ids.size()!=e.equipe.size() or ids.any(func(id): return id not in e.equipe): return "Equipe do confronto difere da viagem."
	if e.fase in ["confronto","alerta"] and (c.resultado!="" or c.aplicado): return "Confronto ativo já encerrado."
	if e.fase in ["retorno","aguardando_descarga","concluida"] and not c.aplicado: return "Resultado da caça não aplicado."
	if e.tipo!="caca" and e.fase=="exploracao" and not c.aplicado: return "Exploração retomada sem resolver o encontro."
	return ""
