extends RefCounted
## Motor de dados. Toda duração usa segundos do relógio estratégico.
const Regioes=preload("res://scripts/partida/regioes.gd")
const Alimentacao=preload("res://scripts/partida/alimentacao.gd")
const Caca=preload("res://scripts/partida/caca.gd")
const Pesca=preload("res://scripts/partida/pesca.gd")
const ATIVAS:=["preparacao","ida","exploracao","alerta","confronto","retorno"]
const POLITICAS:=["prudente","equilibrada","agressiva"]
## Etapa 11 (provisório, aprovado): prazo de intervenção em segundos de jogo a 1×.
const PRAZO_ALERTA:=15.0
const NOMES_ATIVIDADE:={"coleta":"Coleta","pesca":"Pesca","reconhecimento":"Reconhecimento","caca":"Caça"}
static var parametros: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/configuracoes/expedicoes.json"))

static func erro_envio(estado,centro: String,tipo: String,regiao: int,equipe: Array,modo: String) -> String:
	if modo not in ["simulado","manual"]: return "Modo indisponível."
	if modo=="manual" and tipo=="caca" and regiao not in Caca.regioes_manuais(): return "Escolha uma região investigada que ofereça caça manual."
	if modo=="manual" and tipo not in ["caca","pesca"]: return "Esta atividade ainda não pode ser jogada."
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

static func politica_padrao(tipo: String) -> String:
	return "equilibrada" if tipo=="caca" else "prudente"

static func enviar(estado,centro: String,tipo: String,regiao: int,equipe: Array,modo: String="simulado",armas: Dictionary={},politica:="") -> Dictionary:
	var erro:=erro_envio(estado,centro,tipo,regiao,equipe,modo)
	if erro!="": return {"ok":false,"erro":erro}
	if politica=="": politica=politica_padrao(tipo)
	if politica not in POLITICAS: return {"ok":false,"erro":"Política da equipe inválida."}
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
		"capturas_alvo":capturas,"equilibrada":true,"vencimentos":{},"politica":politica}
	# Pescaria jogada: campo próprio; "modo" continua sendo o do combate (alertas).
	if tipo=="pesca": e.pesca_jogada=modo=="manual"
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

static func alertas(estado) -> Array:
	return estado.expedicoes.filter(func(e): return e.fase=="alerta")

## Assumir só existe para animais com apresentação manual,
## em qualquer atividade: fora da caça a equipe luta com a ferramenta básica.
static func manual_disponivel(e: Dictionary) -> bool:
	return e.get("fase")=="alerta" and e.get("combate",{}).get("animal","") in Caca.APRESENTACAO_MANUAL

## Clique em "Assumir combate": mesmo estado já sorteado, agora controlado pelo jogador.
static func assumir(estado,id: String) -> String:
	var e:=buscar(estado,id)
	if e.is_empty() or e.fase!="alerta": return "O alerta já foi resolvido."
	if not manual_pendente(estado).is_empty(): return "Conclua o combate em andamento antes de assumir outro."
	if not manual_disponivel(e): return "Combate manual ainda indisponível para este animal."
	e.modo="manual"
	iniciar_fase(e,"confronto",2)
	registrar(e,"Você assumiu o combate.",[])
	return ""

## "Deixar simular" (ou fim do prazo): a equipe resolve sozinha com a sua política.
static func simular(estado,id: String,avisos: Array[String]=[]) -> String:
	var e:=buscar(estado,id)
	if e.is_empty() or e.fase!="alerta": return "O alerta já foi resolvido."
	iniciar_fase(e,"confronto",2)
	registrar(e,"A equipe enfrenta o perigo sozinha (%s)."%e.get("politica","equilibrada"),avisos)
	return ""

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
	if not e.is_empty() and e.fase=="alerta": return "Assuma o combate ou deixe a equipe simular."
	if not e.is_empty() and pesca_ativa(e):
		encerrar_pesca(estado,e,[])
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
	if e.combate.resultado in ["retirada","impasse","derrota"]: e.cancelada=true
	# Fora da caça, vencer ou ver o animal fugir com todos de pé retoma o trabalho.
	var aptos: bool=e.combate.atores.all(func(a): return a.lado!="equipe" or (not a.morto and a.vida>0))
	if e.tipo!="caca" and e.combate.resultado in ["vitoria","animal_fugiu"] and aptos and float(e.get("retomar",0))>0:
		iniciar_fase(e,"exploracao",float(e.retomar))
		e.erase("retomar")
		registrar(e,"A equipe retomou a atividade.",avisos)
		return
	e.erase("retomar")
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
		registrar(e,resumo(estado,e),avisos)

## Resumo final da viagem: recursos trazidos, perdas, experiência e condição da equipe.
static func resumo(estado,e: Dictionary) -> String:
	var linhas: Array[String]=["Resumo · %s em %s"%[NOMES_ATIVIDADE.get(e.tipo,e.tipo),Regioes.definicoes()[int(e.regiao)].nome]]
	var r: Dictionary=e.get("relatorio",{})
	if not r.is_empty():
		linhas.append("%s · %s · %s"%[Caca.Combate.nome_animal(r.animal),"jogado" if r.modo=="manual" else "simulado",str(r.resultado).replace("_"," ")])
	var trazido: Array[String]=[]
	for k in e.entregue:
		if int(e.entregue[k])>0: trazido.append("%d %s"%[e.entregue[k],str(k).replace("_"," ")])
	linhas.append("Trazido: "+(", ".join(trazido) if not trazido.is_empty() else "nada"))
	if e.has("pesca"):
		var peixes: Array[String]=[]
		for c: Dictionary in e.pesca.capturas: peixes.append("%s %s"%[Pesca.nome(c.especie),Pesca.formatar_peso(float(c.peso))])
		linhas.append("Pescaria jogada · %d de %d lances · %s"%[e.pesca.feitos,e.pesca.lances,", ".join(peixes) if not peixes.is_empty() else "nenhum peixe"])
	var perdas: Array[String]=[]
	for k in r.get("perdas",{}): perdas.append("%d %s"%[r.perdas[k],str(k).replace("_"," ")])
	var xp: Array[String]=[]
	for id in e.equipe:
		var h: Dictionary=estado.pessoa(id)
		if h.is_empty(): continue
		var ganho:=int(r.get("xp",{}).get(h.nome,0))+(0 if e.tipo=="caca" else int(e.xp)+int(e.get("pesca",{}).get("xp",0)))
		xp.append("%s +%d"%[h.nome,ganho])
	linhas.append("XP: "+" · ".join(xp))
	var condicao: Array[String]=[]
	for nome in r.get("feridos",[]): condicao.append(nome+" ferido")
	for nome in r.get("mortos",[]): condicao.append(nome+" morreu")
	linhas.append("Equipe: "+(" · ".join(condicao) if not condicao.is_empty() else "todos bem")+(" · Perdas: "+", ".join(perdas) if not perdas.is_empty() else ""))
	return "\n".join(linhas)

## Sorteio único do encontro de coleta, pesca ou reconhecimento ao iniciar a exploração.
## Guarda o instante e o animal; salvar/carregar não sorteia de novo.
static func planejar_encontro(estado,e: Dictionary) -> void:
	if e.tipo=="caca" or e.has("encontro"): return
	var rng:=RandomNumberGenerator.new()
	rng.state=int(e.rng)
	var regiao:=int(e.regiao)
	var fauna:=Caca.fauna(regiao)
	var perigosos:=fauna.filter(func(a): return a!="capivara")
	var chance:=0.0
	match e.tipo:
		"coleta": chance=.15 if int(Regioes.definicoes()[regiao].perigo)==0 else .30
		"pesca":
			chance=.10 if "jacare_papo_amarelo" in fauna else .05
			perigosos=perigosos.filter(func(a): return a=="jacare_papo_amarelo")
		"reconhecimento": chance=.12 if int(estado.conhecimento[str(regiao)])>=2 else .25
	var encontro:={"em":-1.0,"animal":""}
	if rng.randf()<chance and not fauna.is_empty():
		var animal: String=Caca.sortear_animal(estado,perigosos,rng) if not perigosos.is_empty() else "capivara"
		if animal=="": animal="capivara" if "capivara" in fauna else ""
		if animal!="":
			encontro.animal=animal
			encontro.em=snappedf(rng.randf_range(.15,.85)*float(e.get("duracao_exploracao",parametros.exploracao_segundos)),.01)
	e.encontro=encontro
	e.rng=str(rng.state)

static func disparar_encontro(estado,e: Dictionary,avisos: Array[String]) -> void:
	var animal: String=e.encontro.animal
	e.encontro.em=-1.0
	if animal=="capivara":
		registrar(e,"Uma capivara cruzou o caminho e seguiu para a água.",avisos)
		return
	e.retomar=e.restante
	Caca.criar(estado,e,animal)
	abrir_alerta(e,avisos)

static func abrir_alerta(e: Dictionary,avisos: Array[String]) -> void:
	iniciar_fase(e,"alerta",PRAZO_ALERTA)
	registrar(e,"PERIGO · %s ameaça a equipe."%Caca.Combate.nome_animal(e.combate.animal),avisos)

## Enquanto houver alerta aberto o relógio fica em 1×; depois volta à velocidade escolhida.
static func ajustar_velocidade(estado) -> void:
	var aberto:=not alertas(estado).is_empty()
	if aberto and int(estado.velocidade_antes_alerta)==0:
		estado.velocidade_antes_alerta=estado.relogio.velocidade
		estado.relogio.definir_velocidade(1)
	elif not aberto and int(estado.velocidade_antes_alerta)>0 and manual_pendente(estado).is_empty() and pesca_pendente(estado).is_empty():
		if estado.relogio.velocidade==1: estado.relogio.definir_velocidade(int(estado.velocidade_antes_alerta))
		estado.velocidade_antes_alerta=0

static func praticar(estado,e: Dictionary,avisos: Array[String]) -> void:
	if e.tipo=="caca":
		e.ciclos+=1
		if e.combate.is_empty():
			Caca.criar(estado,e)
			registrar(e,("Ataque defensivo · " if e.combate.tipo=="defensivo" else "Encontro de caça · ")+Caca.Combate.nome_animal(e.combate.animal),avisos)
			# Caça manual escolhida no envio entra direto; a simulada abre o alerta de intervenção.
			if e.get("modo","simulado")=="manual": iniciar_fase(e,"confronto",2)
			else: abrir_alerta(e,avisos)
		return
	var rng:=RandomNumberGenerator.new()
	rng.state=int(e.rng)
	var encontro: Dictionary
	if e.tipo=="pesca":
		var q:=mini(e.equipe.size(),maxi(0,int(e.get("capturas_alvo",1))-quantidade(e.carga)))
		encontro={"texto":"Peixe fisgado." if q>0 else "Um peixe escapou.","recursos":{"peixe":q}}
		if q>0: encontro.especies=pescado_simulado(estado,e,q)
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
			if encontro.has("especies"): mensagem="%s na carga."%encontro.especies
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
		if e.get("modo","simulado")=="manual" and e.get("combate",{}).is_empty() and (e.tipo!="caca" or int(e.regiao) not in Caca.regioes_manuais()): return "Região sem encontro manual disponível."
		if not e.get("pesca_jogada",false) is bool or (e.get("pesca_jogada",false) and e.tipo!="pesca"): return "Pescaria jogada inválida."
		if e.has("pesca"):
			var erro_pesca:=validar_pesca(e,numero)
			if erro_pesca!="": return erro_pesca
		if e.get("politica","equilibrada") not in POLITICAS: return "Política da equipe inválida."
		var plano: Variant=e.get("encontro",{"em":-1.0,"animal":""})
		if not plano is Dictionary or not numero.call(plano.get("em"),-1,3600) or not plano.get("animal") is String: return "Encontro planejado inválido."
		if plano.animal!="" and plano.animal not in Caca.fauna(int(e.regiao)): return "Animal fora da fauna da região."
		if e.has("retomar") and not numero.call(e.retomar,0,3600): return "Retomada da atividade inválida."
		if e.has("relatorio") and not e.relatorio is Dictionary: return "Relatório do encontro inválido."
		if not numero.call(e.get("xp_encontro",0),0,1000,true): return "XP do encontro inválido."
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
		if e.tipo=="caca" or e.has("combate"):
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
					if not e.get("combate",{}).get("aplicado",false) or not e.combate.sobrevivencia.get(id,{}).get("morto",false): return "Morte sem resultado de confronto."
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
	if not manual_pendente(estado).is_empty() or not pesca_pendente(estado).is_empty(): return avisos
	for e: Dictionary in estado.expedicoes:
		if e.fase=="exploracao": planejar_encontro(estado,e)
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
			if pesca_ativa(e):
				preparar_pesca(estado,e)
				break
			var passo:=minf(saldo,e.restante)
			if e.fase=="exploracao":
				var proxima: float=(e.ciclos+1)*intervalo(e)-e.explorado
				passo=minf(passo,maxf(0,proxima))
				if float(e.get("encontro",{}).get("em",-1))>=0: passo=minf(passo,maxf(0,e.encontro.em-e.explorado))
				e.explorado+=passo
			e.restante=maxf(0,e.restante-passo)
			if e.restante<.000001: e.restante=0.0
			saldo-=passo
			if e.fase=="exploracao" and float(e.get("encontro",{}).get("em",-1))>=0 and e.explorado+0.000001>=e.encontro.em:
				disparar_encontro(estado,e,avisos)
				continue
			if e.fase=="exploracao" and e.explorado+0.000001>=(e.ciclos+1)*intervalo(e):
				praticar(estado,e,avisos)
			if e.restante>0: continue
			match e.fase:
				"alerta":
					registrar(e,"Prazo encerrado: a equipe resolve sozinha.",avisos)
					iniciar_fase(e,"confronto",2)
				"confronto":
					Caca.Combate.agir_automatico(e.combate)
					if e.combate.resultado!="": terminar_confronto(estado,e,avisos)
					else: iniciar_fase(e,"confronto",2)
				"preparacao":
					iniciar_fase(e,"ida",e.viagem)
					registrar(e,"Equipe a caminho.",avisos)
				"ida":
					iniciar_fase(e,"exploracao",e.get("duracao_exploracao",parametros.exploracao_segundos))
					planejar_encontro(estado,e)
					if pesca_ativa(e): preparar_pesca(estado,e)
					registrar(e,"A equipe iniciou a exploração.",avisos)
				"exploracao":
					iniciar_fase(e,"retorno",e.viagem)
					registrar(e,"Retornando à aldeia.",avisos)
				"retorno":
					liberar(estado,e)
					iniciar_fase(e,"aguardando_descarga",0)
					descarregar(estado,e,avisos)
					if not e.carga.is_empty(): registrar(e,"Estoque cheio. Excedente preservado para descarga.",avisos)
	ajustar_velocidade(estado)
	return avisos

# ------------------------------------------------------------------ etapa 12: pesca jogada

## A pescaria jogada substitui a exploração simulada: um número fixo de lances (iscas);
## cada lance termina uma única vez, com ou sem peixe, e só então entra na carga e no XP.
static func pesca_ativa(e: Dictionary) -> bool:
	return e.get("tipo")=="pesca" and e.get("pesca_jogada",false)==true and e.get("fase")=="exploracao" and not e.get("pesca",{}).get("fim",false)

static func pesca_pendente(estado) -> Dictionary:
	for e: Dictionary in estado.expedicoes:
		if pesca_ativa(e): return e
	return {}

static func preparar_pesca(estado,e: Dictionary) -> void:
	if e.has("pesca"): return
	planejar_encontro(estado,e)
	var n:=Pesca.lances(e.equipe.size())
	var perigo:=-1
	if float(e.encontro.em)>=0 and e.encontro.animal!="":
		perigo=clampi(int(float(e.encontro.em)/float(e.duracao_exploracao)*n),1,n-1)
	e.pesca={"lances":n,"feitos":0,"capturas":[],"kg":0.0,"xp":0,"perigo":perigo,"fim":false}

## Antes de cada lance. "perigo": o encontro sorteado aconteceu e abriu o alerta comum.
static func iniciar_lance(estado,e: Dictionary,avisos: Array[String]=[]) -> String:
	if not pesca_ativa(e): return "Pescaria encerrada."
	preparar_pesca(estado,e)
	if int(e.pesca.feitos)>=int(e.pesca.lances): return "Sem iscas."
	if int(e.pesca.perigo)>=0 and int(e.pesca.feitos)>=int(e.pesca.perigo):
		e.pesca.perigo=-1
		disparar_encontro(estado,e,avisos)
		if e.fase=="alerta": return "perigo"
	return ""

## Resultado de um lance; ignorado se o índice não for o lance atual (sem recompensa dupla).
static func registrar_lance(estado,e: Dictionary,indice: int,peixe: Dictionary,capturado: bool) -> Dictionary:
	if not pesca_ativa(e) or not e.has("pesca") or indice!=int(e.pesca.feitos): return {}
	e.pesca.feitos=int(e.pesca.feitos)+1
	var xp:=int(Pesca.dados.xp_por_lance)+(int(Pesca.dados.xp_por_captura) if capturado else 0)
	e.pesca.xp=int(e.pesca.xp)+xp
	for id in e.equipe:
		var h: Dictionary=estado.pessoa(id)
		if not h.is_empty() and h.estado!="morto": estado.experiencia(h,"pesca",xp)
	var info:={"recorde":false,"registrado":true}
	if capturado:
		e.pesca.capturas.append({"especie":peixe.especie,"peso":float(peixe.peso)})
		e.pesca.kg=float(e.pesca.kg)+float(peixe.peso)
		info.recorde=Pesca.registrar(estado,peixe,estado.pessoa(e.equipe[0]).get("nome",""))
		registrar(e,"%s de %s fisgado."%[Pesca.nome(peixe.especie),Pesca.formatar_peso(float(peixe.peso))],[])
	if int(e.pesca.feitos)>=int(e.pesca.lances): encerrar_pesca(estado,e,[])
	return info

## Fim da pescaria (iscas esgotadas ou "Encerrar"): o peso pescado vira carga e a equipe volta.
static func encerrar_pesca(estado,e: Dictionary,avisos: Array[String]) -> void:
	if not pesca_ativa(e): return
	preparar_pesca(estado,e)
	e.pesca.fim=true
	var capacidade: int=int(parametros.carga_por_pessoa)*e.equipe.size()
	var q: int=mini(Pesca.unidades(float(e.pesca.kg)),capacidade-quantidade(e.carga))
	if q>0:
		e.carga.peixe=int(e.carga.get("peixe",0))+q
		if not e.vencimentos.has("peixe"):
			e.vencimentos.peixe=estado.tempo_economia+Alimentacao.parametros.validade_dias.peixe*estado.relogio.duracao_dia_segundos
	registrar(e,"Pescaria encerrada: %d peixe(s), %s · %d na carga."%[e.pesca.capturas.size(),Pesca.formatar_peso(float(e.pesca.kg)),maxi(q,0)],avisos)
	iniciar_fase(e,"retorno",e.viagem)

## Pescaria simulada: a mesma quantidade de antes, agora com espécie e peso no registro.
static func pescado_simulado(estado,e: Dictionary,q: int) -> String:
	var rng:=RandomNumberGenerator.new()
	rng.seed=hash(str(e.id)+":"+str(e.ciclos))
	var nomes: Array[String]=[]
	for i in range(q):
		var peixe:=Pesca.sortear(int(e.regiao),rng)
		var h: Dictionary=estado.pessoa(e.equipe[i%e.equipe.size()])
		Pesca.registrar(estado,peixe,h.get("nome",""))
		nomes.append("%s (%s)"%[Pesca.nome(peixe.especie),Pesca.formatar_peso(float(peixe.peso))])
	return ", ".join(nomes)

static func validar_pesca(e: Dictionary,numero: Callable) -> String:
	var p: Variant=e.pesca
	if e.tipo!="pesca" or not p is Dictionary: return "Pescaria inválida."
	if not numero.call(p.get("lances"),1,20,true) or not numero.call(p.get("feitos"),0,p.get("lances",0),true): return "Lances de pesca inválidos."
	if not numero.call(p.get("kg"),0,10000) or not numero.call(p.get("xp"),0,1000,true) or not numero.call(p.get("perigo"),-1,20,true): return "Pescaria inválida."
	if not p.get("fim") is bool or not p.get("capturas") is Array or p.capturas.size()>int(p.feitos): return "Capturas de pesca inválidas."
	for c in p.capturas:
		if not c is Dictionary or Pesca.especie(str(c.get("especie",""))).is_empty() or not numero.call(c.get("peso"),.01,1000): return "Peixe inválido."
	return ""
