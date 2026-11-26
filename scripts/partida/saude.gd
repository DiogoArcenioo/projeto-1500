extends RefCounted
## Etapa 13 — saúde, ferimentos, fadiga, centro de cura e morte. Regras puras: só
## dados do estado, sem nós da cena. A saúde (0-100) define a gravidade; o "descanso"
## (0-100) é o inverso da fadiga. Os dois reduzem produção e rolagens.
##
## Tratamento: cuidado e repouso, plantas medicinais do estoque e a experiência de quem
## cuida. Nada de práticas ou rituais atribuídos a povos reais (validação pendente).
static var p: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/configuracoes/saude.json"))
const GRAVIDADES:=["saudavel","leve","moderado","grave","morto"]
const NOMES:={"saudavel":"Saudável","leve":"Ferimento leve","moderado":"Ferimento moderado","grave":"Ferimento grave","morto":"Morto"}
const NOMES_CANSACO:={"descansado":"Descanso em dia","cansado":"Cansaço","exausto":"Exaustão"}
## Estados em que o morador está na aldeia e fora do trabalho por causa da saúde.
const AFASTADOS:=["convalescente","em_tratamento"]

static func gravidade(h: Dictionary) -> String:
	if h.get("estado")=="morto" or float(h.get("saude",0))<=0: return "morto"
	var s:=float(h.saude)
	if s>=float(p.limites.saudavel): return "saudavel"
	if s>=float(p.limites.leve): return "leve"
	if s>=float(p.limites.moderado): return "moderado"
	return "grave"

static func cansaco(h: Dictionary) -> String:
	var d:=float(h.get("descanso",100))
	if d>=float(p.cansaco.cansado): return "descansado"
	if d>=float(p.cansaco.exausto): return "cansado"
	return "exausto"

## Multiplicador de produção (centros, roça).
static func fator(h: Dictionary) -> float:
	return float(p.fator_saude[gravidade(h)])*float(p.fator_descanso[cansaco(h)])

## Penalidade nas rolagens de ataque do combate.
static func penalidade(h: Dictionary) -> int:
	return int(p.penalidade_saude[gravidade(h)])+int(p.penalidade_descanso[cansaco(h)])

## "" quando pode sair em expedição; senão o motivo.
static func impedimento_expedicao(h: Dictionary) -> String:
	if h.is_empty() or h.get("estado")=="morto": return "Morador indisponível."
	if h.estado=="em_tratamento": return "%s está em tratamento."%h.nome
	if gravidade(h)=="grave" or h.estado=="convalescente": return "%s tem um ferimento grave."%h.nome
	if cansaco(h)=="exausto": return "%s está em exaustão e precisa descansar."%h.nome
	return ""

## Texto curto para o painel comunitário.
static func elegibilidade(h: Dictionary) -> String:
	match h.get("estado"):
		"morto": return "Falecido"
		"em_tratamento": return "Em tratamento · alta prevista em %s"%dias_texto(dias_para_alta(h))
		"convalescente": return "Indisponível · precisa de tratamento"
		"em_expedicao": return "Em expedição"
	if cansaco(h)=="exausto": return "Só trabalhos na aldeia · exaustão"
	if gravidade(h)=="moderado": return "Disponível com penalidade · ferimento"
	if cansaco(h)=="cansado" or gravidade(h)=="leve": return "Disponível com penalidade"
	return "Disponível"

static func dias_texto(d: float) -> String:
	if d<0: return "—"
	if d<1: return "menos de 1 dia"
	return "%d dia%s"%[ceili(d),"" if ceili(d)==1 else "s"]

static func dias_para_alta(h: Dictionary) -> float:
	var taxa:=float(h.get("taxa_cura",0.0))
	if taxa<=0: return -1.0
	return maxf(0.0,float(p.tratamento.alta)-float(h.saude))/taxa

static func noite(hora: float) -> bool:
	return hora>=float(p.descanso.noite_inicio) or hora<float(p.descanso.noite_fim)

## Saúde e fadiga mudam em ticks de uma hora de jogo: a simulação para em cada virada
## de hora, e o resultado não depende do tamanho do passo.
static func proximo_evento(e) -> float:
	var hora: float=e.relogio.duracao_dia_segundos/24.0
	var resto:=hora-fposmod(e.tempo_economia,hora)
	return hora if resto<.000001 else resto

static func taxa_descanso(e,h: Dictionary,de_noite: bool) -> float:
	var d: Dictionary=p.descanso
	if h.estado=="em_expedicao":
		if de_noite: return float(d.acampamento)
		var viagem: Dictionary=e.Expedicoes.buscar(e,h.get("expedicao",""))
		return float(d.expedicao_esforco) if viagem.get("fase","") in ["exploracao","alerta","confronto"] else float(d.expedicao_viagem)
	if de_noite: return float(d.sono)
	match h.estado:
		"trabalhando": return float(d.trabalho)
		"construindo": return float(d.obra)
	return float(d.repouso)

## Evolução natural (fora do tratamento): o leve sara, o moderado sara devagar,
## o grave piora até a morte.
static func taxa_natural(h: Dictionary) -> float:
	match gravidade(h):
		"leve":
			if h.estado!="em_expedicao" and float(h.alimentacao)>=float(p.recuperacao.alimentacao_minima): return float(p.recuperacao.leve)
		"moderado":
			if h.estado!="em_expedicao": return float(p.recuperacao.moderado)
		"grave": return -float(p.recuperacao.piora_grave)
	return 0.0

static func leitos(c: Dictionary) -> int:
	return int(p.tratamento.leitos_por_nivel)*int(c.nivel) if c.get("pronta",false) else 0

static func pacientes(e,c: Dictionary) -> Array:
	return e.habitantes.filter(func(h): return h.estado=="em_tratamento" and h.get("tratamento","")==c.id)

static func cuidadores(e,c: Dictionary) -> Array:
	return e.habitantes.filter(func(h): return h.setor==c.id and h.estado=="trabalhando")

## Pontos de saúde por dia para um paciente deste centro agora.
static func taxa_tratamento(e,c: Dictionary) -> float:
	var t: Dictionary=p.tratamento
	var quem:=cuidadores(e,c)
	if quem.is_empty(): return float(t.sem_cuidador)
	var xp:=0.0
	for h: Dictionary in quem: xp=maxf(xp,float(h.habilidades.get("cura",0)))
	var taxa:=float(t.base)+minf(float(t.bonus_cuidador_max),xp/float(t.xp_por_bonus))
	if int(e.estoque.get("plantas_medicinais",0))>0 or float(c.get("remedio",0.0))>0: taxa+=float(t.plantas)
	return taxa

static func voltar_ao_trabalho(h: Dictionary) -> void:
	h.estado="trabalhando" if h.setor!="" else "livre"
	h.tratamento=""
	h.erase("taxa_cura")

static func cronica(e,texto: String) -> void:
	var dia:=1+floori(e.tempo_economia/e.relogio.duracao_dia_segundos)
	e.cronica.append({"dia":dia,"texto":texto})
	while e.cronica.size()>int(p.cronica_maxima): e.cronica.pop_front()

## Morte permanente: libera trabalho, talhão, obra e tratamento; a carga fica com a
## expedição e as ferramentas pessoais voltam para a aldeia. O registro fica na crônica.
static func morrer(e,h: Dictionary,causa: String) -> String:
	if h.estado=="morto": return ""
	for c: Dictionary in e.construcoes:
		for t: Dictionary in c.get("talhoes",[]):
			if t.trabalhador==h.id: t.trabalhador=""
	if h.obra!="":
		var obra: String=h.obra
		var outro: Dictionary=e.trabalhador_livre()
		if not outro.is_empty() and outro.id!=h.id:
			outro.estado="construindo"
			outro.obra=obra
	h.saude=0
	h.estado="morto"
	h.setor=""
	h.obra=""
	h.expedicao=""
	h.tratamento=""
	h.erase("taxa_cura")
	h.equipamentos=[]
	var msg:="%s morreu (%s)."%[h.nome,causa]
	cronica(e,msg)
	return msg

## Avança fadiga, ferimentos e tratamentos. Chamado a cada passo da simulação.
static func avancar(e,segundos: float) -> Array[String]:
	var avisos: Array[String]=[]
	if segundos<=0: return avisos
	var dia: float=e.relogio.duracao_dia_segundos
	var duracao_hora:=dia/24.0
	var indice:=floori((e.tempo_economia+.000001)/duracao_hora)
	if indice==floori((e.tempo_economia-segundos+.000001)/duracao_hora): return avisos
	# Aplica a hora que acabou de terminar.
	var fracao:=1.0/24.0
	var de_noite:=noite(float(posmod(indice-1,24)))
	# Triagem automática: os casos mais graves entram primeiro.
	var centros: Array=e.construcoes.filter(func(c): return c.tipo=="cura" and c.pronta)
	var fila: Array=e.habitantes.filter(func(h): return h.estado in ["livre","trabalhando","convalescente"] and gravidade(h) in ["moderado","grave"])
	fila.sort_custom(func(a,b): return float(a.saude)<float(b.saude))
	for h: Dictionary in fila:
		for c: Dictionary in centros:
			if pacientes(e,c).size()<leitos(c):
				h.estado="em_tratamento"
				h.tratamento=c.id
				avisos.append("%s entrou no centro de cura."%h.nome)
				break
	# Tratamento: plantas, experiência e alta.
	for c: Dictionary in centros:
		var lista:=pacientes(e,c)
		if lista.is_empty(): continue
		var taxa:=taxa_tratamento(e,c)
		var t: Dictionary=p.tratamento
		c.remedio=float(c.get("remedio",0.0))-lista.size()*float(t.plantas_por_paciente_dia)*fracao
		while c.remedio<0 and int(e.estoque.plantas_medicinais)>0:
			e.estoque.plantas_medicinais-=1
			c.remedio+=1.0
		if c.remedio<0:
			c.remedio=0.0
			if not c.get("sem_plantas",false): avisos.append("Faltam plantas medicinais no centro de cura. A recuperação fica mais lenta.")
			c.sem_plantas=true
		else: c.sem_plantas=false
		var quem:=cuidadores(e,c)
		if not quem.is_empty():
			c.fracao_xp=float(c.get("fracao_xp",0.0))+float(t.xp_cuidador_dia)*fracao
			var ganho:=floori(c.fracao_xp)
			c.fracao_xp-=ganho
			if ganho>0:
				for h: Dictionary in quem: e.experiencia(h,"cura",ganho)
		for h: Dictionary in lista:
			h.taxa_cura=taxa
			h.saude=minf(100.0,float(h.saude)+taxa*fracao)
			if float(h.saude)>=float(t.alta)-.000001:
				voltar_ao_trabalho(h)
				avisos.append("%s recebeu alta e voltou às atividades."%h.nome)
				cronica(e,"%s se recuperou no centro de cura."%h.nome)
	for h: Dictionary in e.habitantes:
		if h.estado=="morto": continue
		var antes_cansaco:=cansaco(h)
		h.descanso=clampf(float(h.descanso)+taxa_descanso(e,h,de_noite)*fracao,0.0,100.0)
		if cansaco(h)=="exausto" and antes_cansaco!="exausto":
			avisos.append("%s chegou à exaustão. Dê descanso antes da próxima expedição."%h.nome)
		if h.estado=="em_tratamento": continue
		var antes:=gravidade(h)
		h.saude=clampf(float(h.saude)+taxa_natural(h)*fracao,0.0,100.0)
		if float(h.saude)<=.000001 and h.estado!="em_expedicao":
			avisos.append(morrer(e,h,"ferimentos sem tratamento"))
			continue
		if h.estado=="em_expedicao": h.saude=maxf(1.0,float(h.saude))
		var agora:=gravidade(h)
		if agora=="grave" and antes!="grave":
			avisos.append("%s tem um ferimento grave.%s"%[h.nome,"" if not centros.is_empty() else " Sem centro de cura, pode morrer."])
			cronica(e,"%s sofreu um ferimento grave."%h.nome)
		if agora=="grave" and h.estado in ["livre","trabalhando"]: h.estado="convalescente"
		elif agora!="grave" and h.estado=="convalescente": voltar_ao_trabalho(h)
	return avisos

static func validar(dados: Dictionary,numero: Callable) -> String:
	var c: Variant=dados.get("cronica",[])
	if not c is Array or c.size()>int(p.cronica_maxima): return "Crônica inválida."
	for item in c:
		if not item is Dictionary or not numero.call(item.get("dia"),1,1e9,true) or not item.get("texto") is String: return "Registro da crônica inválido."
	var leitos_usados:={}
	var obras:={}
	for o: Dictionary in dados.get("construcoes",[]): obras[o.id]=o
	for o: Dictionary in obras.values():
		if o.tipo=="cura" and (not numero.call(o.get("remedio",0.0),0,1) or not numero.call(o.get("fracao_xp",0.0),0,1)): return "Centro de cura inválido."
	for h: Dictionary in dados.habitantes:
		if not h.get("tratamento","") is String: return "Tratamento inválido."
		if h.get("estado")!="morto" and float(h.get("saude",0))<=0: return "Morador vivo sem saúde."
		if h.get("estado")=="em_tratamento":
			var centro: Dictionary=obras.get(h.tratamento,{})
			if centro.get("tipo","")!="cura" or not centro.get("pronta",false): return "Paciente sem centro de cura."
			leitos_usados[h.tratamento]=int(leitos_usados.get(h.tratamento,0))+1
			if leitos_usados[h.tratamento]>leitos(centro): return "Centro de cura lotado."
			if not numero.call(h.get("taxa_cura",0.0),0,100): return "Ritmo de cura inválido."
		elif h.get("tratamento","")!="": return "Tratamento sem paciente."
		if h.get("estado")=="convalescente" and float(h.get("saude",0))>=float(p.limites.moderado): return "Convalescença incompatível."
	return ""
