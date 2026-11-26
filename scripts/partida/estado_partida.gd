extends "res://scripts/partida/aldeia.gd"
## Somente dados: sem referências a nós, materiais ou objetos da cena.
const Relogio = preload("res://scripts/partida/relogio.gd")
const Regioes = preload("res://scripts/partida/regioes.gd")
const Expedicoes = preload("res://scripts/partida/expedicoes.gd")
const MODO_PADRAO := "padrao"
const MODO_IRONMAN := "ironman" # Contrato persistente reservado; seleção/restrições na etapa 23.
const RECURSOS := ["vegetais", "carne", "peixe", "madeira", "pedra", "fibras_vegetais", "couro", "plantas_medicinais"]

var id_partida: String = ""
var modo: String = MODO_PADRAO
var relogio := Relogio.new()
var nivel_fogueira: int = 1
var camera: Dictionary = {}
var conhecimento: Dictionary = Regioes.iniciais()
var expedicoes: Array = []
var sequencia_expedicao: int = 0

static func nova(configuracao: Resource) -> RefCounted:
	var estado = load("res://scripts/partida/estado_partida.gd").new()
	estado.id_partida = Crypto.new().generate_random_bytes(16).hex_encode()
	estado.relogio.duracao_dia_segundos = configuracao.duracao_dia_segundos
	estado.relogio.tempo_total = configuracao.hora_inicial / 24.0 * configuracao.duracao_dia_segundos
	estado.estoque = configuracao.estoque_inicial.duplicate(true)
	estado.tempo_economia=estado.relogio.tempo_total
	Alimentacao.assegurar(estado)
	return estado

func serializar() -> Dictionary:
	Alimentacao.assegurar(self)
	return {"id_partida": id_partida, "modo": modo, "relogio": relogio.serializar(),
		"fogueira": {"nivel": nivel_fogueira}, "habitantes": habitantes.duplicate(true),
		"construcoes": construcoes.duplicate(true), "estoque": estoque.duplicate(true), "camera": camera.duplicate(true),
		"conhecimento":conhecimento.duplicate(true),"expedicoes":expedicoes.duplicate(true),"sequencia_expedicao":sequencia_expedicao,
		"tempo_economia":tempo_economia,"alimentos":alimentos.duplicate(true)}

static func numero(valor: Variant, minimo: float, maximo: float, inteiro: bool = false) -> bool:
	if typeof(valor) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var n := float(valor)
	return is_finite(n) and n >= minimo and n <= maximo and (not inteiro or n == floor(n))

static func validar(dados: Variant) -> String:
	if not dados is Dictionary:
		return "Estado da partida ausente ou inválido."
	var id: Variant = dados.get("id_partida")
	if not id is String or id.length() != 32 or not id.is_valid_hex_number(false):
		return "Identificador da partida inválido."
	if dados.get("modo") not in [MODO_PADRAO, MODO_IRONMAN]:
		return "Modo de partida desconhecido."
	var tempo: Variant = dados.get("relogio")
	if not tempo is Dictionary:
		return "Relógio ausente."
	if not numero(tempo.get("duracao_dia_segundos"), 1, 86400):
		return "Duração do dia inválida."
	if not numero(tempo.get("tempo_total"), 0, 86400.0 * 365000.0):
		return "Tempo de jogo inválido."
	if not numero(tempo.get("velocidade"), 1, 3, true) or not tempo.get("pausado") is bool:
		return "Velocidade ou pausa inválida."
	var fogueira: Variant = dados.get("fogueira")
	if not fogueira is Dictionary or not numero(fogueira.get("nivel"), 1, 1, true):
		return "Fogueira incompatível com a etapa 2."
	var erro_aldeia := validar_aldeia(dados)
	if not erro_aldeia.is_empty():
		return erro_aldeia
	var conhecimento_regional: Variant=dados.get("conhecimento",Regioes.iniciais())
	if not conhecimento_regional is Dictionary or conhecimento_regional.size()!=30:
		return "Conhecimento regional inválido."
	for i in range(30):
		if not numero(conhecimento_regional.get(str(i)),0,3,true):
			return "Nível de conhecimento regional inválido."
	if int(conhecimento_regional["20"])<2:
		return "A aldeia precisa ser conhecida."
	var recursos: Variant = dados.get("estoque")
	if not recursos is Dictionary or recursos.size() != RECURSOS.size():
		return "Estoque incompleto ou incompatível."
	for chave: String in RECURSOS:
		if not numero(recursos.get(chave), 0, 1000000000, true):
			return "Quantidade inválida de " + chave + "."
	if not numero(dados.get("tempo_economia",tempo.tempo_total),0,1e12): return "Tempo econômico inválido."
	var erro_alimentacao:=Alimentacao.validar(dados,numero)
	if erro_alimentacao!="": return erro_alimentacao
	var erro_expedicoes:=Expedicoes.validar(dados,numero)
	if erro_expedicoes!="": return erro_expedicoes
	var visao: Variant = dados.get("camera")
	if not visao is Dictionary:
		return "Estado da câmera inválido."
	if not visao.is_empty():
		for chave: String in ["x", "z", "angulo", "fov"]:
			if not numero(visao.get(chave), -10000, 10000):
				return "Enquadramento da câmera inválido."
		if not numero(visao.get("fov"), 5, 120):
			return "Zoom inválido."
	return ""

static func validar_aldeia(dados: Dictionary) -> String:
	var pessoas: Variant=dados.get("habitantes")
	var obras: Variant=dados.get("construcoes",[])
	if not pessoas is Array or not obras is Array: return "Aldeia inválida."
	var locais := {}
	var moradores := {}
	var postos := {}
	var construtores := {}
	var celulas_ocupadas:={}
	for c in obras:
		if not c is Dictionary or not c.get("id") is String or c.id.is_empty() or locais.has(c.id): return "ID de obra inválido."
		if c.get("tipo") not in CUSTOS or not numero(c.get("nivel"),1,1,true) or not numero(c.get("variante"),1,1,true): return "Tipo de construção inválido."
		if not numero(c.get("x"),-18,18) or not numero(c.get("z"),-18,18) or not c.get("pronta") is bool: return "Local de construção inválido."
		if not numero(c.get("rotacao",0),-PI,PI): return "Rotação de construção inválida."
		if not numero(c.get("restante"),0,DURACAO[c.tipo]) or not numero(c.get("ciclo"),0,60) or not c.get("ocupantes") is Array: return "Progresso de obra inválido."
		if not numero(c.get("ciclos_coleta",0),0,1e9,true): return "Progresso de coleta inválido."
		if c.tipo=="agricultura":
			var erro_cultivo:=Agricultura.validar(c,numero)
			if erro_cultivo!="": return erro_cultivo
		if c.pronta != (c.restante==0) or c.ocupantes.size()!=(2 if c.pronta and c.tipo=="oca" else 0): return "Ocupação incompatível."
		if c.id!="obra_%d"%(locais.size()+1) or (locais.is_empty() and c.tipo!="oca"): return "Sequência de obras inválida."
		if c.has("rotacao"):
			if not Terreno.terreno(ponto(c),Terreno.TAMANHOS[c.tipo]*.5,c.rotacao): return "Terreno da construção inválido."
			if c.tipo=="pesca" and Terreno.distancia_agua(ponto(c),Terreno.TAMANHOS[c.tipo]*.5,c.rotacao)>2: return "Pesca distante da água."
		elif not terreno_valido(ponto(c),RAIO[c.tipo],c.tipo=="pesca"): return "Terreno inválido."
		for outra: Dictionary in locais.values():
			if Terreno.sobrepoe(ponto(c),Terreno.TAMANHOS[c.tipo]*.5,c.get("rotacao",0),ponto(outra),Terreno.TAMANHOS[outra.tipo]*.5,outra.get("rotacao",0)): return "Construções sobrepostas."
		locais[c.id]=c
	for c: Dictionary in locais.values():
		for t: Dictionary in c.get("talhoes",[]):
			for celula: Dictionary in t.get("celulas",[]):
				var chave:=str([int(celula.x),int(celula.z)])
				if celulas_ocupadas.has(chave): return "Célula plantada duas vezes."
				celulas_ocupadas[chave]=true
				var p:=Agricultura.centro_celula(celula)
				if p.distance_to(ponto(c))>14 or not Terreno.terreno(p,Vector2.ONE*.5,0): return "Terreno da plantação inválido."
				for obra: Dictionary in locais.values():
					if Terreno.sobrepoe(p,Vector2.ONE*.5,0,ponto(obra),Terreno.TAMANHOS[obra.tipo]*.5,obra.get("rotacao",0),0): return "Plantação sobreposta à construção."
	for h in pessoas:
		if not h is Dictionary or not h.get("id") is String or moradores.has(h.id) or h.id.is_empty(): return "ID de morador inválido."
		if not h.get("nome") is String or h.nome.is_empty() or not numero(h.get("idade"),1,120,true): return "Perfil inválido."
		if h.get("visual") not in ["homem_01","homem_02","homem_03","homem_04","mulher_01","mulher_02","mulher_03","mulher_04"]: return "Aparência inválida."
		if not numero(h.get("nivel"),1,10000000,true) or not numero(h.get("xp"),0,1000000000,true): return "Experiência inválida."
		if not h.get("tracos") is Array or h.tracos.size()<1 or h.tracos.size()>3 or not h.get("equipamentos") is Array: return "Perfil incompleto."
		for t in h.tracos:
			if t not in TRACOS: return "Traço inválido."
		for v in ["saude","descanso","alimentacao"]:
			if not numero(h.get(v),0,100): return "Condição inválida."
		if not h.get("atributos") is Dictionary or not h.get("habilidades") is Dictionary: return "Ficha incompleta."
		for a in ATRIBUTOS:
			if not numero(h.atributos.get(a),0,100,true): return "Atributo inválido."
		for a in HABILIDADES:
			if not numero(h.habilidades.get(a),0,1000000000,true): return "Habilidade inválida."
		if not locais.has(h.get("casa")) or not h.id in locais[h.casa].ocupantes: return "Moradia inválida."
		if not h.get("setor") is String or not h.get("obra") is String: return "Vínculo inválido."
		match h.get("estado"):
			"morto":
				if h.saude!=0 or h.setor!="" or h.obra!="" or h.get("expedicao","")!="": return "Morador falecido com atividade."
			"livre":
				if h.setor!="" or h.obra!="": return "Morador indisponível."
			"trabalhando","em_expedicao":
				if h.estado=="em_expedicao" and h.setor=="":
					if h.obra!="": return "Integrante ocupado em obra."
					moradores[h.id]=h
					continue
				if not locais.has(h.setor) or locais[h.setor].tipo not in SETORES or not locais[h.setor].pronta or h.obra!="": return "Setor inválido."
				postos[h.setor]=int(postos.get(h.setor,0))+1
				if postos[h.setor]>2*locais[h.setor].nivel: return "Setor lotado."
			"construindo":
				if not locais.has(h.obra) or locais[h.obra].pronta or h.setor!="" or construtores.has(h.obra): return "Obra inválida."
				construtores[h.obra]=h.id
			_: return "Estado desconhecido."
		moradores[h.id]=h
	for c: Dictionary in locais.values():
		if c.tipo=="agricultura":
			for t: Dictionary in c.talhoes:
				if t.trabalhador!="" and (not moradores.has(t.trabalhador) or moradores[t.trabalhador].setor!=c.id):
					return "Agricultor fora do talhão."
			for h: Dictionary in moradores.values():
				if h.setor==c.id and not c.talhoes.any(func(t): return t.trabalhador==h.id): return "Agricultor sem talhão."
		if not c.pronta and c.id!="obra_1" and not construtores.has(c.id): return "Obra sem trabalhador."
		var vistos := {}
		for id in c.ocupantes:
			if not moradores.has(id) or moradores[id].casa!=c.id or vistos.has(id): return "Ocupante inválido."
			vistos[id]=true
	return ""

static func desserializar(dados: Dictionary) -> RefCounted:
	if not validar(dados).is_empty():
		return null
	var estado = load("res://scripts/partida/estado_partida.gd").new()
	estado.id_partida = dados.id_partida
	estado.modo = dados.modo
	estado.relogio.duracao_dia_segundos = float(dados.relogio.duracao_dia_segundos)
	estado.relogio.tempo_total = float(dados.relogio.tempo_total)
	estado.relogio.velocidade = int(dados.relogio.velocidade)
	estado.relogio.pausado = dados.relogio.pausado
	estado.nivel_fogueira = int(dados.fogueira.nivel)
	estado.habitantes = dados.habitantes.duplicate(true)
	estado.construcoes = dados.get("construcoes", []).duplicate(true)
	for chave: String in RECURSOS:
		estado.estoque[chave] = int(dados.estoque[chave])
	estado.camera = dados.camera.duplicate(true)
	estado.conhecimento = dados.get("conhecimento",Regioes.iniciais()).duplicate(true)
	estado.expedicoes = dados.get("expedicoes",[]).duplicate(true)
	estado.sequencia_expedicao = int(dados.get("sequencia_expedicao",0))
	estado.tempo_economia=float(dados.get("tempo_economia",dados.relogio.tempo_total))
	estado.alimentos=dados.get("alimentos",{}).duplicate(true)
	Alimentacao.assegurar(estado)
	return estado

func avancar_simulacao(segundos: float) -> Array[String]:
	var avisos: Array[String]=[]
	if segundos<=0 or not is_finite(segundos): return avisos
	tempo_economia=maxf(0,relogio.tempo_total-segundos)
	Alimentacao.assegurar(self)
	var saldo:=segundos
	while saldo>.000001:
		if not Expedicoes.manual_pendente(self).is_empty():
			relogio.tempo_total-=saldo
			break
		var populacao:=populacao()
		var eficiencia:=Alimentacao.eficiencia(self)
		var passo:=minf(saldo,Alimentacao.proximo_evento(self,populacao))
		passo=minf(passo,Agricultura.proximo_evento(self))
		var dia:=relogio.duracao_dia_segundos
		passo=minf(passo,dia-fposmod(tempo_economia,dia))
		for c: Dictionary in construcoes:
			if not c.pronta: passo=minf(passo,c.restante)
			elif c.tipo=="coleta" and habitantes.any(func(h): return h.setor==c.id and h.estado=="trabalhando"):
				passo=minf(passo,(Alimentacao.parametros.coleta_local.intervalo-c.ciclo)/eficiencia)
		for e: Dictionary in expedicoes:
			for r in e.get("vencimentos",{}):
				if e.carga.has(r): passo=minf(passo,maxf(0,e.vencimentos[r]-tempo_economia))
			if e.fase not in Expedicoes.ATIVAS: continue
			passo=minf(passo,e.restante)
			if e.fase=="exploracao":
				passo=minf(passo,(e.ciclos+1)*Expedicoes.intervalo(e)-e.explorado)
		passo=minf(saldo,maxf(.00001,passo))
		tempo_economia+=passo
		avisos.append_array(Agricultura.avancar(self,passo,eficiencia))
		avisos.append_array(avancar_aldeia(passo,eficiencia))
		avisos.append_array(Expedicoes.avancar(self,passo))
		avisos.append_array(Alimentacao.avancar(self,passo,populacao))
		saldo-=passo
	return avisos
