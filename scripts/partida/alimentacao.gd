extends RefCounted
const TIPOS:=["vegetais","carne","peixe"]
static var parametros: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/configuracoes/alimentacao.json"))

static func assegurar(e) -> void:
	if not e.alimentos.is_empty(): return
	e.alimentos={"lotes":[],"historico":[],"fracao":0.0,"inicio_populacao":-1.0,"consumo_dia":0,
		"faltas_dia":0,"perdas_dia":0,"dia_registro":1+floori(e.tempo_economia/e.relogio.duracao_dia_segundos)}
	for tipo in TIPOS:
		var q:=int(e.estoque.get(tipo,0))
		if q>0:
			e.alimentos.lotes.append({"tipo":tipo,"quantidade":q,"origem":"reserva",
				"vence":e.tempo_economia+parametros.validade_dias[tipo]*e.relogio.duracao_dia_segundos})
	e.alimentos.lotes.sort_custom(func(a,b): return a.vence<b.vence)

static func total(e) -> int:
	var q:=0
	for r in TIPOS: q+=int(e.estoque.get(r,0))
	return q

static func receber(e,tipo: String,quantidade: int,origem: String="",vence: float=-1) -> int:
	assegurar(e)
	var recebido:=clampi(int(parametros.capacidade)-total(e),0,quantidade)
	if recebido<=0: return 0
	var lote: Dictionary={"tipo":tipo,"quantidade":recebido,"origem":origem if origem!="" else tipo,
		"vence":vence if vence>=0 else e.tempo_economia+parametros.validade_dias[tipo]*e.relogio.duracao_dia_segundos}
	e.alimentos.lotes.append(lote)
	e.alimentos.lotes.sort_custom(func(a,b): return a.vence<b.vence)
	e.estoque[tipo]+=recebido
	return recebido

static func eficiencia(e) -> float:
	var dieta:=qualidade(e)
	var fome:=0.0
	if not e.moradores_vivos().is_empty():
		var media:=0.0
		for h: Dictionary in e.moradores_vivos(): media+=float(h.alimentacao)
		media/=e.populacao()
		if media<30: fome=-.25
		elif media<60: fome=-.10
	return clampf(1.0+float(dieta.modificador)+fome,.5,1.1)

static func qualidade(e) -> Dictionary:
	assegurar(e)
	var fontes:={}
	var quantidade:=0
	for item: Dictionary in e.alimentos.historico:
		if item.tempo>e.tempo_economia-parametros.dieta.janela_dias*e.relogio.duracao_dia_segundos+.000001:
			fontes[item.origem]=int(fontes.get(item.origem,0))+int(item.quantidade)
			quantidade+=int(item.quantidade)
	var relevantes:=0
	for q in fontes.values():
		if quantidade>0 and float(q)/quantidade>=.10: relevantes+=1
	if relevantes>=3: return {"nome":"Variada","modificador":.10}
	if relevantes>=2: return {"nome":"Diversificada","modificador":0.0}
	var dias:=0.0
	if e.alimentos.inicio_populacao>=0:
		dias=(e.tempo_economia-e.alimentos.inicio_populacao)/e.relogio.duracao_dia_segundos
	if quantidade==0: return {"nome":"Sem alimentação recente" if dias>=3 else "Em formação","modificador":0.0}
	if dias>=parametros.dieta.carencia_grave_dias: return {"nome":"Monotonia prolongada","modificador":-.25}
	if dias>=parametros.dieta.carencia_media_dias: return {"nome":"Pouco variada","modificador":-.10}
	if dias>=parametros.dieta.carencia_leve_dias: return {"nome":"Repetitiva","modificador":-.05}
	return {"nome":"Em formação","modificador":0.0}

static func resistencia_efetiva(e,h: Dictionary) -> float:
	return float(h.atributos.resistencia)*minf(1,eficiencia(e))

static func proximo_evento(e,populacao: int) -> float:
	assegurar(e)
	var tempo:=INF
	for lote: Dictionary in e.alimentos.lotes:
		tempo=minf(tempo,maxf(0,lote.vence-e.tempo_economia))
	for item: Dictionary in e.alimentos.historico:
		var restante: float=item.tempo+parametros.dieta.janela_dias*e.relogio.duracao_dia_segundos-e.tempo_economia
		if restante>.000001: tempo=minf(tempo,restante)
	if e.alimentos.inicio_populacao>=0:
		for dias in [parametros.dieta.carencia_leve_dias,parametros.dieta.carencia_media_dias,parametros.dieta.carencia_grave_dias]:
			var restante: float=e.alimentos.inicio_populacao+dias*e.relogio.duracao_dia_segundos-e.tempo_economia
			if restante>.000001: tempo=minf(tempo,restante)
	if populacao>0:
		var taxa: float=populacao*float(parametros.consumo_por_adulto_dia)/e.relogio.duracao_dia_segundos
		tempo=minf(tempo,maxf(0,(1.0-e.alimentos.fracao)/taxa))
	return tempo

static func avancar(e,segundos: float,populacao: int) -> Array[String]:
	assegurar(e)
	var avisos: Array[String]=[]
	var dia:=1+floori((e.tempo_economia+.000001)/e.relogio.duracao_dia_segundos)
	if dia!=int(e.alimentos.dia_registro):
		e.alimentos.dia_registro=dia
		e.alimentos.consumo_dia=0
		e.alimentos.faltas_dia=0
		e.alimentos.perdas_dia=0
		var dieta:=qualidade(e)
		for h: Dictionary in e.moradores_vivos():
			if h.alimentacao<20 or dieta.modificador<=-.25: h.saude=maxf(1,float(h.saude)-1)
			elif h.alimentacao>=60 and dieta.modificador>=0: h.saude=minf(100,float(h.saude)+1)
	if populacao>0 and e.alimentos.inicio_populacao<0:
		e.alimentos.inicio_populacao=e.tempo_economia-segundos
	var estragados:=0
	for i in range(e.alimentos.lotes.size()-1,-1,-1):
		var lote: Dictionary=e.alimentos.lotes[i]
		if lote.vence<=e.tempo_economia+.000001:
			estragados+=int(lote.quantidade)
			e.estoque[lote.tipo]-=int(lote.quantidade)
			e.alimentos.lotes.remove_at(i)
	if estragados>0:
		e.alimentos.perdas_dia+=estragados
		avisos.append("%d alimentos estragaram. Consulte o estoque na Comunidade."%estragados)
	e.alimentos.fracao+=segundos*populacao*float(parametros.consumo_por_adulto_dia)/e.relogio.duracao_dia_segundos
	while e.alimentos.fracao>=1.0-.000001:
		e.alimentos.fracao=maxf(0,e.alimentos.fracao-1)
		if e.alimentos.lotes.is_empty():
			if e.alimentos.faltas_dia==0: avisos.append("Faltou alimento. Organize a produção ou envie uma equipe.")
			e.alimentos.faltas_dia+=1
			for h: Dictionary in e.moradores_vivos(): h.alimentacao=maxf(0,float(h.alimentacao)-10.0/maxi(1,populacao))
		else:
			var lote: Dictionary=e.alimentos.lotes[0]
			e.estoque[lote.tipo]-=1
			lote.quantidade-=1
			e.alimentos.consumo_dia+=1
			e.alimentos.historico.append({"origem":lote.origem,"tipo":lote.tipo,"quantidade":1,"tempo":e.tempo_economia})
			if lote.quantidade==0: e.alimentos.lotes.pop_front()
			for h: Dictionary in e.moradores_vivos(): h.alimentacao=minf(100,float(h.alimentacao)+4.0/maxi(1,populacao))
	var limite: float=e.tempo_economia-parametros.dieta.janela_dias*e.relogio.duracao_dia_segundos
	while not e.alimentos.historico.is_empty() and e.alimentos.historico[0].tempo<=limite+.000001:
		e.alimentos.historico.pop_front()
	var atual:=qualidade(e)
	var anterior: String=e.alimentos.get("ultima_dieta","Em formação")
	if atual.nome!=anterior:
		avisos.append("Dieta: %s. Varie as fontes de alimento para melhorar a produtividade."%atual.nome)
	e.alimentos.ultima_dieta=atual.nome
	return avisos

static func validar(dados: Dictionary,numero: Callable) -> String:
	if not dados.has("alimentos"): return ""
	var a: Variant=dados.alimentos
	if not a is Dictionary or not a.get("lotes") is Array or not a.get("historico") is Array: return "Alimentação inválida."
	if not a.get("ultima_dieta","") is String: return "Qualidade alimentar inválida."
	if not numero.call(a.get("fracao"),0,1) or not numero.call(a.get("inicio_populacao"),-1,1e12): return "Consumo alimentar inválido."
	for k in ["consumo_dia","faltas_dia","perdas_dia","dia_registro"]:
		if not numero.call(a.get(k),0,1e9,true): return "Histórico diário inválido."
	var quantidades:={"vegetais":0,"carne":0,"peixe":0}
	for lote in a.lotes:
		if not lote is Dictionary or lote.get("tipo") not in TIPOS or not lote.get("origem") is String: return "Lote de alimento inválido."
		if not numero.call(lote.get("quantidade"),1,1e9,true) or not numero.call(lote.get("vence"),0,1e12): return "Validade de alimento inválida."
		quantidades[lote.tipo]+=int(lote.quantidade)
	for r in TIPOS:
		if quantidades[r]!=int(dados.estoque[r]): return "Estoque alimentar difere dos lotes."
	for item in a.historico:
		if not item is Dictionary or item.get("tipo") not in TIPOS or not item.get("origem") is String: return "Histórico alimentar inválido."
		if not numero.call(item.get("tempo"),0,1e12) or not numero.call(item.get("quantidade"),1,1e9,true): return "Refeição inválida."
	return ""
