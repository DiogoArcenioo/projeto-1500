extends RefCounted
## Motor de dados. Toda duração usa segundos do relógio estratégico.
const Regioes=preload("res://scripts/partida/regioes.gd")
const Alimentacao=preload("res://scripts/partida/alimentacao.gd")
const Caca=preload("res://scripts/partida/caca.gd")
const ATIVAS:=["preparacao","ida","exploracao","confronto","retorno"]
static var parametros: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/configuracoes/expedicoes.json"))

static func erro_envio(estado,centro: String,tipo: String,regiao: int,equipe: Array,modo: String) -> String:
	if modo not in ["simulado","manual"]: return "Modo indisponível."
	if modo=="manual" and (tipo!="caca" or regiao not in [14,21]): return "Caça manual disponível nos Arredores e na Margem do rio (capivara)."
	if tipo not in ["coleta","reconhecimento","pesca","caca"]: return "Atividade desconhecida."
	if regiao<0 or regiao>=30 or regiao==20: return "Escolha uma região fora da aldeia."
	if tipo=="coleta" and int(estado.conhecimento[str(regiao)])<2: return "Investigue os recursos desta região primeiro."
	if tipo=="reconhecimento" and int(estado.conhecimento[str(regiao)])==0 and not Regioes.fronteira(regiao,estado.conhecimento):
		return "Escolha uma região conhecida ou uma fronteira próxima."
	if Regioes.viagem(regiao,estado.conhecimento)<0: return "Não há caminho conhecido até a região."
	var c: Dictionary=estado.estrutura(centro)
	if c.is_empty() or c.tipo not in ["coleta","pesca","caca"] or not c.pronta: return "Centro indisponível."
	if (tipo=="pesca")!=(c.tipo=="pesca"): return "Escolha um centro compatível com a atividade."
	if (tipo=="caca")!=(c.tipo=="caca"): return "Escolha um centro compatível com caça."
	if tipo=="caca" and (int(estado.conhecimento[str(regiao)])<2 or Caca.fauna(regiao).is_empty()): return "Investigue uma região com animais antes de caçar."
	if tipo=="pesca" and (int(estado.conhecimento[str(regiao)])<2 or not Regioes.definicoes()[regiao].recursos.has("peixe")):
		return "Escolha uma região investigada com peixes."
	if equipe.is_empty() or equipe.size()>int(parametros.integrantes_nivel_1): return "Escolha de um a dois integrantes."
	var ativas:=0
	for e: Dictionary in estado.expedicoes:
		if e.centro==centro and e.fase in ATIVAS: ativas+=1
	if ativas>=int(parametros.simultaneas_nivel_1): return "Este centro já possui uma expedição em andamento."
	var vistos:={}
	for id in equipe:
		if not id is String or vistos.has(id): return "Integrante repetido ou inválido."
		var h: Dictionary=estado.pessoa(id)
		if h.is_empty() or h.estado not in ["livre","trabalhando"] or h.saude<=0: return "Um integrante está indisponível."
		if h.estado=="trabalhando" and h.setor!=centro: return "Libere ou transfira o morador de outro centro."
		vistos[id]=true
	return ""

static func enviar(estado,centro: String,tipo: String,regiao: int,equipe: Array,modo: String="simulado",armas: Dictionary={}) -> Dictionary:
	var erro:=erro_envio(estado,centro,tipo,regiao,equipe,modo)
	if erro!="": return {"ok":false,"erro":erro}
	for id in armas:
		if id not in equipe or armas[id] not in ["arco","lanca"]: return {"ok":false,"erro":"Equipamento inválido."}
	estado.sequencia_expedicao+=1
	var id: String="exp_%d"%estado.sequencia_expedicao
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(estado.id_partida+id)
	var duracao: float=parametros.preparacao_segundos
	var viagem:=Regioes.viagem(regiao,estado.conhecimento)
	var exploracao:=duracao_planejada(tipo,viagem)
	var capturas:=0
	if tipo=="pesca":
		for _p in equipe:
			capturas+=int(Alimentacao.parametros.pesca.rendimento_base)
			if rng.randf()<Alimentacao.parametros.pesca.chance_segunda_unidade: capturas+=1
	var e: Dictionary={"id":id,"centro":centro,"tipo":tipo,"regiao":regiao,"equipe":equipe.duplicate(),
		"fase":"preparacao","restante":duracao,"duracao_fase":duracao,"viagem":viagem,
		"explorado":0.0,"ciclos":0,"carga":{},"entregue":{},"xp":0,"conhecimento":0,
		"rng":str(rng.state),"cancelada":false,"eventos":[],"duracao_exploracao":exploracao,
		"intervalo_atividade":float(Alimentacao.parametros.pesca.intervalo) if tipo=="pesca" else (60.0 if tipo=="coleta" else 12.0),
		"capturas_alvo":capturas,"equilibrada":true,"vencimentos":{}}
	if tipo=="caca":
		e.modo=modo
		e.armas=armas.duplicate()
		e.combate={}
		e.intervalo_atividade=exploracao
	estado.expedicoes.append(e)
	for pessoa in equipe:
		var h: Dictionary=estado.pessoa(pessoa)
		h.estado="em_expedicao"
		h.expedicao=id
	return {"ok":true,"id":id}

static func buscar(estado,id: String) -> Dictionary:
	for e: Dictionary in estado.expedicoes:
		if e.id==id: return e
	return {}

static func manual_pendente(estado) -> Dictionary:
	for e: Dictionary in estado.expedicoes:
		if e.get("modo","simulado")=="manual" and e.fase=="confronto": return e
	return {}

static func comando_manual(estado,id: String,ator: String,acao: String,alvo: String="",destino:=Vector2i(-1,-1)) -> String:
	var e:=buscar(estado,id)
	if e.is_empty() or e.get("modo","simulado")!="manual" or e.fase!="confronto": return "Caça manual indisponível."
	var atual:=Caca.Combate.atual(e.combate)
	if atual.is_empty() or atual.id!=ator: return "Fora do turno."
	var erro:=Caca.Combate.agir(e.combate,ator,acao,alvo,destino)
	if erro=="": terminar_confronto(estado,e,[])
	return erro

static func liberar(estado,e: Dictionary) -> void:
	for id in e.equipe:
		var h: Dictionary=estado.pessoa(id)
		if h.estado=="morto": continue
		h.estado="livre" if h.setor=="" else "trabalhando"
		h.expedicao=""

static func registrar(e: Dictionary,msg: String,avisos: Array[String]) -> void:
	e.eventos.append(msg)
	if e.eventos.size()>12: e.eventos.pop_front()
	avisos.append("%s · %s"%[e.id,msg])

static func iniciar_fase(e: Dictionary,fase: String,duracao: float) -> void:
	e.fase=fase
	e.duracao_fase=duracao
	e.restante=duracao

static func retornar(estado,id: String) -> String:
	var e:=buscar(estado,id)
	if not e.is_empty() and e.fase=="confronto":
		var a:=Caca.Combate.atual(e.combate)
		if a.is_empty() or a.lado!="equipe": return "Aguarde o turno de um caçador para tentar a retirada."
		var erro:=Caca.Combate.agir(e.combate,a.id,"fugir")
		if erro!="": return erro
		terminar_confronto(estado,e,[])
		return ""
	if e.is_empty() or e.fase not in ["preparacao","ida","exploracao"]: return "Retorno indisponível nesta fase."
	e.cancelada=true
	if e.fase=="preparacao":
		liberar(estado,e)
		iniciar_fase(e,"concluida",0)
	else:
		var distancia: float=e.viagem-e.restante if e.fase=="ida" else e.viagem
		iniciar_fase(e,"retorno",maxf(0,distancia))
	return ""

static func terminar_confronto(estado,e: Dictionary,avisos: Array[String]) -> void:
	if e.fase!="confronto" or e.combate.resultado=="": return
	for msg in Caca.aplicar(estado,e): registrar(e,msg,avisos)
	if e.combate.resultado in ["retirada","impasse"]: e.cancelada=true
	iniciar_fase(e,"retorno",e.viagem)

static func quantidade(carga: Dictionary) -> int:
	var total:=0
	for q in carga.values(): total+=int(q)
	return total

static func duracao_planejada(tipo: String,viagem: float) -> float:
	if tipo=="caca": return maxf(180,720-parametros.preparacao_segundos-2*viagem)
	if tipo=="pesca":
		return maxf(180,Alimentacao.parametros.pesca.duracao_total-parametros.preparacao_segundos-2*viagem)
	return 240.0 if tipo=="coleta" else float(parametros.exploracao_segundos)

static func intervalo(e: Dictionary) -> float:
	return float(e.get("intervalo_atividade",parametros.intervalo_atividade))

static func descarregar(estado,e: Dictionary,avisos: Array[String]) -> void:
	for r in e.carga.keys():
		var vence: float=e.get("vencimentos",{}).get(r,-1.0)
		var recebido: int=estado.receber(r,int(e.carga[r]),e.tipo,vence)
		e.carga[r]-=recebido
		e.entregue[r]=int(e.entregue.get(r,0))+recebido
		if e.carga[r]==0: e.carga.erase(r)
	if e.carga.is_empty():
		e.fase="concluida"
		registrar(e,"Retorno concluído. Carga entregue.",avisos)

static func praticar(estado,e: Dictionary,avisos: Array[String]) -> void:
	if e.tipo=="caca":
		e.ciclos+=1
		if e.combate.is_empty():
			Caca.criar(estado,e)
			iniciar_fase(e,"confronto",2)
			registrar(e,("Ataque defensivo · " if e.combate.tipo=="defensivo" else "Encontro de caça · ")+Caca.Combate.nome_animal(e.combate.animal),avisos)
		return
	var rng:=RandomNumberGenerator.new()
	rng.state=int(e.rng)
	var encontro: Dictionary
	if e.tipo=="pesca":
		var q:=mini(e.equipe.size(),maxi(0,int(e.get("capturas_alvo",1))-quantidade(e.carga)))
		encontro={"texto":"Peixe fisgado." if q>0 else "Um peixe escapou.","recursos":{"peixe":q}}
	else:
		encontro=Regioes.sortear(int(e.regiao),e.tipo,rng)
		if e.tipo=="coleta" and e.get("equilibrada",false) and encontro.recursos.has("vegetais"):
			encontro.recursos.vegetais=1 if rng.randf()<.5 else 0
			if encontro.recursos.vegetais==0: encontro.texto="A equipe procurou alimentos."
	e.rng=str(rng.state)
	e.ciclos+=1
	e.xp+=1
	for id in e.equipe:
		var h: Dictionary=estado.pessoa(id)
		if e.tipo in ["coleta","pesca"]: estado.experiencia(h,e.tipo,1)
		else:
			h.xp+=1
			h.nivel=1+floori(h.xp/100.0)
	if e.tipo=="reconhecimento":
		var anterior:=int(estado.conhecimento[str(int(e.regiao))])
		Regioes.revelar(estado.conhecimento,int(e.regiao),1)
		var ganho:=int(estado.conhecimento[str(int(e.regiao))])-anterior
		e.conhecimento+=ganho
		registrar(e,"Conhecimento regional ampliado." if ganho>0 else "A equipe observou a região.",avisos)
	else:
		var capacidade: int=int(parametros.carga_por_pessoa)*e.equipe.size()
		var coletado:=0
		for r in encontro.recursos:
			var multiplicador: int=1 if e.tipo=="pesca" else e.equipe.size()
			var valor:=mini(int(encontro.recursos[r])*multiplicador,capacidade-quantidade(e.carga))
			if valor>0:
				e.carga[r]=int(e.carga.get(r,0))+valor
				coletado+=valor
				if r in Alimentacao.TIPOS:
					if not e.has("vencimentos"): e.vencimentos={}
					if not e.vencimentos.has(r):
						e.vencimentos[r]=estado.tempo_economia+Alimentacao.parametros.validade_dias[r]*estado.relogio.duracao_dia_segundos
		var mensagem: String=encontro.texto
		if coletado>0:
			mensagem="%d %s na carga."%[coletado,str(encontro.recursos.keys()[0]).replace("_"," ")]
		registrar(e,mensagem,avisos)
		if quantidade(e.carga)>=capacidade:
			iniciar_fase(e,"retorno",e.viagem)
			registrar(e,"Carga cheia. Retornando.",avisos)

static func validar(dados: Dictionary,numero: Callable) -> String:
	var lista: Variant=dados.get("expedicoes",[])
	var sequencia: Variant=dados.get("sequencia_expedicao",0)
	if not lista is Array or not numero.call(sequencia,0,1000000000,true): return "Expedições inválidas."
	var ids:={}
	var ocupados:={}
	var centros:={}
	var pessoas:={}
	var obras:={}
	for h: Dictionary in dados.habitantes: pessoas[h.id]=h
	for c: Dictionary in dados.get("construcoes",[]): obras[c.id]=c
	for e in lista:
		if not e is Dictionary or not e.get("id") is String or not e.id.begins_with("exp_") or ids.has(e.id): return "ID de expedição inválido."
		var sufixo: String=e.id.trim_prefix("exp_")
		if not sufixo.is_valid_int() or int(sufixo)<1 or int(sufixo)>int(sequencia): return "Sequência de expedição inválida."
		if e.id!="exp_%d"%int(sufixo): return "Identificador de expedição inconsistente."
		ids[e.id]=true
		if not obras.has(e.get("centro")) or obras[e.centro].tipo not in ["coleta","pesca","caca"] or not obras[e.centro].pronta: return "Centro da expedição inválido."
		if e.get("tipo") not in ["coleta","reconhecimento","pesca","caca"] or e.get("fase") not in ATIVAS+["aguardando_descarga","concluida"]: return "Fase ou atividade inválida."
		if (e.tipo=="pesca")!=(obras[e.centro].tipo=="pesca"): return "Atividade incompatível com centro."
		if (e.tipo=="caca")!=(obras[e.centro].tipo=="caca"): return "Atividade incompatível com caça."
		if e.get("modo","simulado") not in ["simulado","manual"]: return "Modo de expedição inválido."
		if e.get("modo","simulado")=="manual" and (e.tipo!="caca" or int(e.regiao) not in [14,21]): return "Região sem encontro manual disponível."
		if e.fase=="confronto" and e.tipo!="caca": return "Confronto fora da caça."
		if not numero.call(e.get("duracao_exploracao",60),1,3600) or not numero.call(e.get("intervalo_atividade",12),1,3600):
			return "Duração da expedição inválida."
		if not numero.call(e.get("regiao"),0,29,true) or int(e.regiao)==20: return "Região da expedição inválida."
		if not e.get("equipe") is Array or e.equipe.is_empty() or e.equipe.size()>parametros.integrantes_nivel_1: return "Equipe inválida."
		for chave in ["restante","duracao_fase","viagem","explorado"]:
			if not numero.call(e.get(chave),0,1000000): return "Tempo de expedição inválido."
		if e.restante>e.duracao_fase or e.viagem<=0 or e.explorado>e.get("duracao_exploracao",parametros.exploracao_segundos): return "Progresso inválido."
		for chave in ["ciclos","xp","conhecimento"]:
			if not numero.call(e.get(chave),0,100000,true): return "Experiência da expedição inválida."
		if int(e.ciclos)!=floori((float(e.explorado)+.000001)/intervalo(e)) or (e.tipo!="caca" and int(e.xp)!=int(e.ciclos)):
			return "Ciclos de exploração inconsistentes."
		if e.tipo=="caca":
			var erro_caca:=Caca.validar(e,numero)
			if erro_caca!="": return erro_caca
		if not numero.call(e.get("capturas_alvo",0),0,4,true) or not e.get("equilibrada",false) is bool:
			return "Capturas inválidas."
		var vencimentos: Variant=e.get("vencimentos",{})
		if not vencimentos is Dictionary: return "Validade da carga inválida."
		for r in vencimentos:
			if r not in Alimentacao.TIPOS or not numero.call(vencimentos[r],0,1e12): return "Validade da carga inválida."
		if not e.get("rng") is String or e.rng.length()>20 or not e.rng.is_valid_int() or str(int(e.rng))!=e.rng: return "Estado aleatório inválido."
		if not e.get("cancelada") is bool or not e.get("eventos") is Array or e.eventos.size()>12: return "Registro da expedição inválido."
		for msg in e.eventos:
			if not msg is String: return "Mensagem inválida."
		for chave in ["carga","entregue"]:
			if not e.get(chave) is Dictionary: return "Carga inválida."
			for r in e[chave]:
				if not dados.estoque.has(r) or not numero.call(e[chave][r],0,1000000000,true): return "Recurso de expedição inválido."
		if quantidade(e.carga)>int(parametros.carga_por_pessoa)*e.equipe.size(): return "Carga acima da capacidade."
		if e.fase=="concluida" and not e.carga.is_empty(): return "Carga pendente em expedição concluída."
		var participantes:={}
		for id in e.equipe:
			if not id is String or not pessoas.has(id) or participantes.has(id): return "Integrante inválido."
			participantes[id]=true
			if e.fase in ATIVAS:
				var h: Dictionary=pessoas[id]
				if h.estado=="morto":
					if e.tipo!="caca" or not e.combate.get("aplicado",false) or not e.combate.sobrevivencia.get(id,{}).get("morto",false): return "Morte sem resultado de confronto."
					continue
				if ocupados.has(id) or h.estado!="em_expedicao" or h.get("expedicao")!=e.id or h.obra!="": return "Integrante em duas atividades."
				if h.setor!="" and h.setor!=e.centro: return "Integrante vinculado a outro centro."
				ocupados[id]=true
		if e.fase in ATIVAS:
			centros[e.centro]=int(centros.get(e.centro,0))+1
			if centros[e.centro]>parametros.simultaneas_nivel_1: return "Centro excede expedições simultâneas."
	for h: Dictionary in pessoas.values():
		if h.estado=="em_expedicao" and not ocupados.has(h.id): return "Morador sem expedição."
		if h.estado!="em_expedicao" and h.get("expedicao","")!="": return "Morador com vínculo de expedição inconsistente."
	return ""

static func avancar(estado,segundos: float) -> Array[String]:
	var avisos: Array[String]=[]
	if not is_finite(segundos) or segundos<=0: return avisos
	if not manual_pendente(estado).is_empty(): return avisos
	for e: Dictionary in estado.expedicoes:
		for r in e.get("vencimentos",{}):
			if e.carga.has(r) and e.vencimentos[r]<=estado.tempo_economia+.000001:
				e.carga.erase(r)
				registrar(e,"Alimento da carga estragou.",avisos)
		if e.fase=="aguardando_descarga":
			descarregar(estado,e,avisos)
			continue
		var saldo:=segundos
		while e.fase in ATIVAS and saldo>0:
			if e.fase=="confronto" and e.get("modo","simulado")=="manual": break
			var passo:=minf(saldo,e.restante)
			if e.fase=="exploracao":
				var proxima: float=(e.ciclos+1)*intervalo(e)-e.explorado
				passo=minf(passo,maxf(0,proxima))
				e.explorado+=passo
			e.restante=maxf(0,e.restante-passo)
			if e.restante<.000001: e.restante=0.0
			saldo-=passo
			if e.fase=="exploracao" and e.explorado+0.000001>=(e.ciclos+1)*intervalo(e):
				praticar(estado,e,avisos)
			if e.restante>0: continue
			match e.fase:
				"confronto":
					Caca.Combate.agir_automatico(e.combate)
					if e.combate.resultado!="": terminar_confronto(estado,e,avisos)
					else: iniciar_fase(e,"confronto",2)
				"preparacao":
					iniciar_fase(e,"ida",e.viagem)
					registrar(e,"Equipe a caminho.",avisos)
				"ida":
					iniciar_fase(e,"exploracao",e.get("duracao_exploracao",parametros.exploracao_segundos))
					registrar(e,"A equipe iniciou a exploração.",avisos)
				"exploracao":
					iniciar_fase(e,"retorno",e.viagem)
					registrar(e,"Retornando à aldeia.",avisos)
				"retorno":
					liberar(estado,e)
					iniciar_fase(e,"aguardando_descarga",0)
					descarregar(estado,e,avisos)
					if not e.carga.is_empty(): registrar(e,"Estoque cheio. Excedente preservado para descarga.",avisos)
	return avisos
