extends RefCounted
const Alimentacao=preload("res://scripts/partida/alimentacao.gd")

static func talhoes_iniciais() -> Array:
	var lista: Array=[]
	for especie in ["milho","mandioca"]:
		var t:=unidade(especie)
		t.trabalhador=""
		t.celulas=[]
		t.fracao_xp=0.0
		lista.append(t)
	return lista

static func unidade(cultivo: String) -> Dictionary:
	return {"cultivo":cultivo,"proximo":cultivo,"progresso":0.0,"pendente":0,"fracao_rendimento":0.0}

static func centro_celula(c: Dictionary) -> Vector2:
	return Vector2(c.x+.5,c.z+.5)

static func chave_celula(c: Dictionary) -> String:
	return "%d:%d"%[int(c.x),int(c.z)]

static func encontrar_celula(e,chave: String) -> Dictionary:
	for c: Dictionary in e.construcoes:
		for t: Dictionary in c.get("talhoes",[]):
			for u: Dictionary in t.get("celulas",[]):
				if chave_celula(u)==chave: return u
	return {}

static func semear_selecao(e,chaves: Array,cultivo: String) -> String:
	if not Alimentacao.parametros.cultivos.has(cultivo): return "Cultivo desconhecido."
	if chaves.is_empty(): return "Selecione um ou mais terrenos."
	var unidades_selecionadas: Array[Dictionary]=[]
	var vistas:={}
	for chave in chaves:
		if not chave is String or vistas.has(chave): return "Seleção inválida."
		var u:=encontrar_celula(e,chave)
		if u.is_empty(): return "Um terreno selecionado não está mais disponível."
		vistas[chave]=true
		unidades_selecionadas.append(u)
	for u: Dictionary in unidades_selecionadas:
		u.proximo=cultivo
		if not u.get("plantada",true) or (u.progresso==0 and u.pendente==0):
			u.cultivo=cultivo
			u.progresso=0.0
			u.plantada=true
	return ""

static func referencia(t: Dictionary) -> int:
	return 6 if t.cultivo=="milho" else 9

static func unidades(t: Dictionary) -> Array:
	if not t.has("celulas"): return [t]
	return [t.legado]+t.celulas if t.has("legado") else t.celulas

static func ritmo(t: Dictionary) -> float:
	if not t.has("celulas"): return 1
	var carga:=0.0
	for u: Dictionary in unidades(t):
		if u.get("plantada",true): carga+=1.0 if u.get("talhao_legado",false) else 1.0/referencia(u)
	return minf(1,1.0/maxf(.00001,carga))

static func erro_celula(e,centro: String,indice: int,p: Vector2) -> String:
	var c: Dictionary=e.estrutura(centro)
	if c.is_empty() or c.tipo!="agricultura" or not c.pronta or indice not in [0,1]: return "Construa e selecione um abrigo agrícola pronto."
	if not p.is_finite(): return "Posição inválida."
	var alvo:=Vector2(floorf(p.x)+.5,floorf(p.y)+.5)
	if alvo.distance_to(e.ponto(c))>14: return "Plante a até 14 metros do abrigo agrícola."
	if not e.Terreno.terreno(alvo,Vector2.ONE*.5,0): return "Plante em terra livre, fora da água, das pedras e da fogueira."
	for obra: Dictionary in e.construcoes:
		if e.Terreno.sobrepoe(alvo,Vector2.ONE*.5,0,e.ponto(obra),e.Terreno.TAMANHOS[obra.tipo]*.5,obra.get("rotacao",0),0): return "A célula está ocupada por uma construção."
		for t: Dictionary in obra.get("talhoes",[]):
			for celula: Dictionary in t.get("celulas",[]):
				if int(celula.x)==floori(p.x) and int(celula.z)==floori(p.y): return "Este terreno já está preparado."
	return ""

static func adicionar_celula(e,centro: String,indice: int,p: Vector2,rotacao: float=0) -> String:
	var erro:=erro_celula(e,centro,indice,p)
	if erro!="": return erro
	if not is_finite(rotacao): return "Rotação inválida."
	var t: Dictionary=e.estrutura(centro).talhoes[indice]
	if not t.has("celulas"):
		var legado:=unidade(t.cultivo)
		for chave in legado: legado[chave]=t[chave]
		legado.talhao_legado=true
		t.legado=legado
		t.celulas=[]
		t.progresso=0.0
		t.pendente=0
	var celula:=unidade(t.proximo)
	celula.plantada=false
	celula.merge({"x":floori(p.x),"z":floori(p.y),"rotacao":wrapf(rotacao,-PI,PI)})
	t.celulas.append(celula)
	return ""

static func bonus(h: Dictionary) -> float:
	var nivel:=0
	for limite in Alimentacao.parametros.agricultura.patamares_xp:
		if h.habilidades.agricultura>=limite: nivel+=1
	return nivel*float(Alimentacao.parametros.agricultura.bonus_patamar)

static func proximo_evento(e) -> float:
	var proximo:=INF
	for c: Dictionary in e.construcoes:
		if c.tipo!="agricultura" or not c.pronta: continue
		for t: Dictionary in c.talhoes:
			var h: Dictionary=e.pessoa(t.trabalhador)
			if h.is_empty() or h.estado!="trabalhando": continue
			for u: Dictionary in unidades(t):
				if u.pendente>0 or not u.get("plantada",true): continue
				var duracao: float=Alimentacao.parametros.cultivos[u.cultivo].duracao
				proximo=minf(proximo,maxf(0,(duracao-u.progresso)/(Alimentacao.eficiencia(e)*ritmo(t))))
	return proximo

static func avancar(e,segundos: float,produtividade: float=-1) -> Array[String]:
	var avisos: Array[String]=[]
	var fator:=Alimentacao.eficiencia(e) if produtividade<0 else produtividade
	for c: Dictionary in e.construcoes:
		if c.tipo!="agricultura" or not c.pronta: continue
		for t: Dictionary in c.talhoes:
			var h: Dictionary=e.pessoa(t.trabalhador)
			var ativos: bool=not h.is_empty() and h.estado=="trabalhando"
			var velocidade:=fator*ritmo(t)
			var colhidos:=0
			var bloqueados:=0
			for u: Dictionary in unidades(t):
				if not u.get("plantada",true): continue
				if u.pendente>0:
					var recebido: int=e.receber("vegetais",int(u.pendente),u.cultivo)
					u.pendente-=recebido
					if u.pendente==0:
						u.cultivo=u.proximo
						u.progresso=0.0
					continue
				if not ativos: continue
				var def: Dictionary=Alimentacao.parametros.cultivos[u.cultivo]
				u.progresso+=segundos*velocidade
				if u.progresso+.000001<float(def.duracao): continue
				u.progresso=float(def.duracao)
				var escala: float=1.0/referencia(u) if t.has("celulas") and not u.get("talhao_legado",false) else 1.0
				var rendimento: float=float(def.rendimento)*escala*(1+bonus(h))+t.fracao_rendimento
				u.pendente=floori(rendimento+.000001)
				t.fracao_rendimento=maxf(0,rendimento-u.pendente)
				var xp: float=Alimentacao.parametros.agricultura.xp_colheita*escala+t.get("fracao_xp",0.0)
				var inteiro:=floori(xp+.000001)
				t.fracao_xp=maxf(0,xp-inteiro)
				if inteiro>0: e.experiencia(h,"agricultura",inteiro)
				var recebido: int=e.receber("vegetais",int(u.pendente),u.cultivo)
				u.pendente-=recebido
				colhidos+=recebido
				if u.pendente==0:
					u.progresso=0.0
					u.cultivo=u.proximo
				else: bloqueados+=1
			if colhidos>0: avisos.append("Roça %s · %d vegetais colhidos."%[c.id.get_slice("_",1),colhidos])
			if bloqueados>0: avisos.append("Colheita aguardando espaço no estoque.")
	return avisos

static func escolher(e,centro: String,indice: int,cultivo: String) -> String:
	var c: Dictionary=e.estrutura(centro)
	if c.is_empty() or c.tipo!="agricultura" or not c.pronta or indice not in [0,1]: return "Talhão indisponível."
	if not Alimentacao.parametros.cultivos.has(cultivo): return "Cultivo desconhecido."
	var t: Dictionary=c.talhoes[indice]
	t.proximo=cultivo
	for u: Dictionary in unidades(t):
		u.proximo=cultivo
		if u.progresso==0 and u.pendente==0: u.cultivo=cultivo
	if t.has("celulas"): t.cultivo=cultivo
	return ""

static func validar_unidade(t: Dictionary,numero: Callable) -> String:
	if not t.get("plantada",true) is bool: return "Estado do terreno inválido."
	if not t.get("plantada",true) and (t.get("progresso")!=0 or t.get("pendente")!=0): return "Terreno vazio com produção inválida."
	if not Alimentacao.parametros.cultivos.has(t.get("cultivo")) or not Alimentacao.parametros.cultivos.has(t.get("proximo")): return "Cultivo inválido."
	if not numero.call(t.get("progresso"),0,Alimentacao.parametros.cultivos[t.cultivo].duracao) or not numero.call(t.get("pendente"),0,1000,true): return "Colheita inválida."
	if not numero.call(t.get("fracao_rendimento"),0,1): return "Rendimento inválido."
	return ""

static func validar(c: Dictionary,numero: Callable) -> String:
	if not c.get("talhoes") is Array or c.talhoes.size()!=2: return "Área agrícola inválida."
	var vistos:={}
	for t in c.talhoes:
		if not t is Dictionary: return "Talhão inválido."
		var erro:=validar_unidade(t,numero)
		if erro!="": return erro
		if not t.get("trabalhador") is String or not numero.call(t.get("fracao_xp",0),0,1): return "Agricultor inválido."
		if t.has("legado"):
			if not t.legado is Dictionary or t.legado.get("talhao_legado")!=true: return "Talhão legado inválido."
			erro=validar_unidade(t.legado,numero)
			if erro!="": return erro
		if t.has("celulas"):
			if not t.celulas is Array or t.celulas.size()>1000: return "Células de plantio inválidas."
			for celula in t.celulas:
				if not celula is Dictionary or not numero.call(celula.get("x"),-18,17,true) or not numero.call(celula.get("z"),-18,17,true) or not numero.call(celula.get("rotacao",0),-PI,PI): return "Célula inválida."
				erro=validar_unidade(celula,numero)
				if erro!="": return erro
		if t.trabalhador!="":
			if vistos.has(t.trabalhador): return "Agricultor em dois talhões."
			vistos[t.trabalhador]=true
	return ""
