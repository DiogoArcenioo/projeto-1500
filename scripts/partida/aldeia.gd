extends RefCounted
## Regras independentes da cena. Posições persistidas usam o plano XZ em metros.
const CUSTOS := {"oca":{"madeira":30,"fibras_vegetais":20}, "coleta":{"madeira":8,"fibras_vegetais":4},
	"agricultura":{"madeira":20,"fibras_vegetais":10},"pesca":{"madeira":15,"fibras_vegetais":8},"caca":{"madeira":25,"fibras_vegetais":12}}
const DURACAO := {"oca":18.0, "coleta":10.0,"agricultura":60.0,"pesca":45.0,"caca":60.0}
const RAIO := {"oca":4.05, "coleta":1.85,"agricultura":4.2,"pesca":2.8,"caca":2.9}
const NOMES_CONSTRUCOES:={"oca":"Oca","coleta":"Centro de coleta","agricultura":"Roça","pesca":"Centro de pesca","caca":"Centro de caça"}
const SETORES:=["coleta","agricultura","pesca","caca"]
const Alimentacao=preload("res://scripts/partida/alimentacao.gd")
const Agricultura=preload("res://scripts/partida/agricultura.gd")
const Terreno=preload("res://scripts/partida/terreno_construcao.gd")
const ATRIBUTOS := ["forca","agilidade","inteligencia","resistencia","percepcao"]
const HABILIDADES := ["caca","pesca","agricultura","coleta","construcao","combate","artesanato","cura"]
const TRACOS := ["observador","corajoso","cauteloso","trabalhador","resistente","sortudo","frágil","aprendiz rápido"]
const NOMES := ["Canela","Garça","Cedro","Andorinha","Jatobá","Arara","Ingá","Pitanga","Araçá","Sabiá","Saíra","Ipê"]
const LIMITE_ESTOQUE := 500
var habitantes: Array = []
var construcoes: Array = []
var estoque: Dictionary = {}
var alimentos: Dictionary = {}
var tempo_economia:=0.0

static func ponto(c: Dictionary) -> Vector2:
	return Vector2(c.x,c.z)

static func rio(z: float) -> float:
	return Terreno.centro_rio(z)

static func terreno_valido(p: Vector2, raio: float,margem:=false) -> bool:
	if p.length()+raio > 17.8 or p.x+raio > rio(p.y)-(3.3 if margem else 5.7):
		return false
	if margem and p.x<rio(p.y)-9: return false
	for rocha: Vector2 in [Vector2(-13,-8),Vector2(-17,-4),Vector2(-9,-12),Vector2(11,-9),Vector2(-12,10),Vector2(-12,-11),Vector2(-17,2)]:
		if p.distance_to(rocha) < raio+1.5:
			return false
	return p.length()>raio+1.7

func livre_no_mapa(p: Vector2, raio: float,margem:=false) -> bool:
	if not terreno_valido(p,raio,margem):
		return false
	for c: Dictionary in construcoes:
		if Terreno.distancia_caixa(p,ponto(c),Terreno.TAMANHOS[c.tipo]*.5,c.get("rotacao",0)) < raio+.20:
			return false
	return true

func estrutura(id: String) -> Dictionary:
	for c: Dictionary in construcoes:
		if c.id==id: return c
	return {}

func pessoa(id: String) -> Dictionary:
	for h: Dictionary in habitantes:
		if h.id==id: return h
	return {}

func moradores_vivos() -> Array:
	return habitantes.filter(func(h): return h.estado!="morto")

func populacao() -> int:
	return moradores_vivos().size()

func ocupacao(id: String) -> int:
	var total := 0
	for h: Dictionary in habitantes:
		if h.setor==id: total+=1
	return total

func vagas(c: Dictionary) -> int:
	return 2*int(c.nivel) if c.pronta else 0

func capacidade_residencial() -> int:
	var total := 0
	for c: Dictionary in construcoes:
		if c.tipo=="oca": total+=vagas(c)
	return total

func receber(recurso: String, quantidade: int,origem: String="",vence: float=-1) -> int:
	if not estoque.has(recurso) or quantidade<=0: return 0
	if recurso in Alimentacao.TIPOS: return Alimentacao.receber(self,recurso,quantidade,origem,vence)
	var recebido := clampi(LIMITE_ESTOQUE-int(estoque[recurso]),0,quantidade)
	estoque[recurso]+=recebido
	return recebido

func pode_pagar(custo: Dictionary) -> bool:
	for tipo in custo:
		if int(estoque.get(tipo,0))<int(custo[tipo]): return false
	return true

func impedimento(tipo: String, pos: Vector2,rotacao: float=0) -> String:
	if not RAIO.has(tipo): return "Tipo de obra desconhecido."
	if not pos.is_finite(): return "Posição inválida."
	if not is_finite(rotacao): return "Rotação inválida."
	var metade: Vector2=Terreno.TAMANHOS[tipo]*.5
	if not Terreno.terreno(pos,metade,rotacao): return "A construção precisa ficar em terreno livre, sem ocupar água, pedras ou a fogueira."
	if tipo=="pesca" and Terreno.distancia_agua(pos,metade,rotacao)>2.0: return "A pesca precisa ficar a até 2 metros da água. Aproxime o abrigo da margem."
	for c: Dictionary in construcoes:
		if Terreno.sobrepoe(pos,metade,rotacao,ponto(c),Terreno.TAMANHOS[c.tipo]*.5,c.get("rotacao",0)):
			return "Esta posição sobrepõe outra construção."
	for c: Dictionary in construcoes:
		for t: Dictionary in c.get("talhoes",[]):
			for celula: Dictionary in t.get("celulas",[]):
				if Terreno.sobrepoe(pos,metade,rotacao,Agricultura.centro_celula(celula),Vector2.ONE*.5,0): return "Esta posição ocupa uma célula de plantio."
	if construcoes.is_empty() and tipo!="oca": return "Construa a primeira oca para receber dois moradores."
	if not pode_pagar(CUSTOS[tipo]): return "O estoque é insuficiente para esta obra."
	if not construcoes.is_empty() and trabalhador_livre().is_empty(): return "Libere um morador para trabalhar na obra."
	return ""

func trabalhador_livre() -> Dictionary:
	for h: Dictionary in habitantes:
		if h.estado=="livre": return h
	return {}

func construir(tipo: String, pos: Vector2,rotacao: float=0) -> String:
	var erro := impedimento(tipo,pos,rotacao)
	if not erro.is_empty(): return erro
	var id := "obra_%d" % (construcoes.size()+1)
	var h := trabalhador_livre()
	for r in CUSTOS[tipo]: estoque[r]-=CUSTOS[tipo][r]
	construcoes.append({"id":id,"tipo":tipo,"nivel":1,"variante":1,"x":pos.x,"z":pos.y,
		"pronta":false,"restante":DURACAO[tipo],"ciclo":0.0,"ocupantes":[]})
	construcoes.back().rotacao=wrapf(rotacao,-PI,PI)
	if tipo=="agricultura": construcoes.back().talhoes=Agricultura.talhoes_iniciais()
	if not h.is_empty():
		h.estado="construindo"
		h.obra=id
	return ""

func atribuir(id: String, destino: String) -> String:
	var h := pessoa(id)
	if h.is_empty(): return "Morador desconhecido."
	if h.estado not in ["livre","trabalhando"]: return "Este morador está ocupado."
	if h.setor==destino: return ""
	if not destino.is_empty():
		var c := estrutura(destino)
		if c.is_empty() or c.tipo not in SETORES or not c.pronta: return "Setor indisponível."
		if ocupacao(destino)>=vagas(c): return "As duas vagas deste centro estão ocupadas."
	if h.setor!="":
		var anterior:=estrutura(h.setor)
		if anterior.tipo=="agricultura":
			for t: Dictionary in anterior.talhoes:
				if t.trabalhador==id: t.trabalhador=""
	h.setor=destino
	h.estado="livre" if destino.is_empty() else "trabalhando"
	if destino!="" and estrutura(destino).tipo=="agricultura":
		for t: Dictionary in estrutura(destino).talhoes:
			if t.trabalhador=="":
				t.trabalhador=id
				break
	return ""

func chegada(casa: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=hash(str(get("id_partida"))+casa.id)
	for i in range(2):
		var n := habitantes.size()
		var atributos := {}
		var habilidades := {}
		for a in ATRIBUTOS: atributos[a]=rng.randi_range(4,8)
		for a in HABILIDADES: habilidades[a]=0
		var tracos := []
		for j in range(rng.randi_range(1,3)):
			var traco: String=TRACOS[rng.randi_range(0,TRACOS.size()-1)]
			if not tracos.has(traco): tracos.append(traco)
		var id := "pessoa_%d"%(n+1)
		var nome: String=NOMES[(n+absi(hash(get("id_partida")))%NOMES.size())%NOMES.size()]
		var visual := ("%s_%02d" % ["homem" if i==0 else "mulher",1+(floori(n/2.0)%4)])
		habitantes.append({"id":id,"nome":nome,"idade":rng.randi_range(19,52),"nivel":1,"xp":0,
			"atributos":atributos,"habilidades":habilidades,"tracos":tracos,"saude":100,"descanso":100,
			"alimentacao":100,"equipamentos":[],"estado":"livre","casa":casa.id,"setor":"","obra":"","visual":visual})
		casa.ocupantes.append(id)

func experiencia(h: Dictionary, habilidade: String, valor: int) -> void:
	h.habilidades[habilidade]+=valor
	h.xp+=valor
	h.nivel=1+floori(h.xp/100.0)

func avancar_aldeia(segundos: float,produtividade: float=-1) -> Array[String]:
	var avisos: Array[String]=[]
	var eficiencia:=Alimentacao.eficiencia(self) if produtividade<0 else produtividade
	for c: Dictionary in construcoes:
		if not c.pronta:
			c.restante=maxf(0,c.restante-segundos)
			if c.restante>0: continue
			c.pronta=true
			for h: Dictionary in habitantes:
				if h.obra==c.id:
					experiencia(h,"construcao",5)
					h.estado="livre"
					h.obra=""
			if c.tipo=="oca":
				chegada(c)
				avisos.append("Oca pronta. Chegaram %s e %s!" % [habitantes[-2].nome,habitantes[-1].nome])
			else: avisos.append(NOMES_CONSTRUCOES[c.tipo]+" pronto. Atribua moradores ao setor.")
		elif c.tipo=="coleta" and habitantes.any(func(h): return h.setor==c.id and h.estado=="trabalhando"):
			c.ciclo+=segundos*eficiencia
			var intervalo: float=Alimentacao.parametros.coleta_local.intervalo
			var ciclos := floori((c.ciclo+.000001)/intervalo)
			if ciclos<=0: continue
			c.ciclo=maxf(0,c.ciclo-ciclos*intervalo)
			var anterior:=int(c.get("ciclos_coleta",0))
			c.ciclos_coleta=anterior+ciclos
			var periodo:=int(Alimentacao.parametros.coleta_local.vegetal_cada_ciclos)
			var vegetais:=floori(float(c.ciclos_coleta)/periodo)-floori(float(anterior)/periodo)
			for h: Dictionary in habitantes:
				if h.setor==c.id and h.estado=="trabalhando":
					receber("vegetais",vegetais,"coleta")
					receber("madeira",ciclos)
					receber("fibras_vegetais",ciclos)
					experiencia(h,"coleta",ciclos)
	return avisos
