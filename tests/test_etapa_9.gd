extends SceneTree
const E=preload("res://scripts/partida/estado_partida.gd")
const C=preload("res://scripts/partida/configuracao_partida.gd")
const B=preload("res://scripts/partida/combate.gd")
const X=preload("res://scripts/partida/expedicoes.gd")
const S=preload("res://scripts/partida/salvamento.gd")
var total:=0
var falhas:=0
var pasta: String
var estatisticas:={}
func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func passo(e,t: float) -> void: e.avancar_simulacao(e.relogio.avancar(t))
func aldeia():
	var e=E.nova(C.new())
	e.construir("oca",Vector2(-5,-4))
	passo(e,18)
	return e
func soldados() -> Array:
	var e=aldeia()
	var equipe: Array=[]
	for i in range(2):
		var h: Dictionary=e.habitantes[i]
		for k in h.atributos: h.atributos[k]=5
		h.nome="Caçador %d"%(i+1)
		h.especialista_caca=true
		equipe.append(B.humano(h,"arco" if i==0 else "lanca",1,3+i))
	return equipe
func arena(semente:=5,animal:="queixada") -> Dictionary:
	return B.novo(soldados(),animal,semente)
func turno(c: Dictionary,id: String) -> void:
	c.cursor=c.ordem.find(id)
	B.iniciar_turno(c)
func espelho(c: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(c))
func validar(c: Dictionary,nome: String) -> void:
	var erro:=B.validar(c,E.numero)
	ok(erro=="",nome+" "+erro)

func regras() -> void:
	var equipe:=soldados()
	var c:=B.novo(equipe,"queixada",99)
	var d:=B.novo(equipe,"queixada",99)
	ok(c==d,"Semente e estado iguais reproduzem iniciativa")
	validar(c,"Confronto inicial válido")
	turno(c,"pessoa_1")
	var a:=B.atual(c)
	var b:=B.ator(c,"animal")
	a.x=1
	a.z=3
	b.x=5
	b.z=3
	var snapshot:=JSON.stringify(c)
	ok(B.agir(c,"pessoa_2","atacar","animal")!="" and JSON.stringify(c)==snapshot,"Não age fora do turno nem consome RNG")
	ok(B.agir(c,a.id,"mover","",Vector2i(2,3))=="","Movimento ortogonal dentro do alcance")
	ok(a.pa==1,"Mover custa um PA")
	ok(B.agir(c,a.id,"mover","",Vector2i(7,7))!="","Movimento longo rejeitado")
	ok(B.agir(c,a.id,"atacar","animal")=="","Ataque válido")
	ok(B.atual(c).id!=a.id,"PA zero passa turno")
	turno(c,"pessoa_1")
	ok(B.agir(c,a.id,"atacar","animal")=="","Primeiro ataque")
	snapshot=JSON.stringify(c)
	ok(B.agir(c,a.id,"atacar","animal")!="" and JSON.stringify(c)==snapshot,"Limite de um ataque preserva estado")
	B.agir(c,a.id,"defender")
	ok(a.defesa_temp==2,"Defesa aplica bônus")
	turno(c,a.id)
	ok(a.defesa_temp==0 and a.pa==2,"Bônus expira no início do próprio turno")
	c.bloqueios=[{"x":3,"z":3}]
	ok(not B.linha_livre(c,a,b),"Obstáculo alto bloqueia tiro")
	ok(B.agir(c,a.id,"atacar","animal")!="","Tiro através de obstáculo rejeitado")
	c.bloqueios=[]
	c.coberturas=[{"x":5,"z":2}]
	ok(B.cobertura(c,b)==2,"Cobertura baixa protege de tiro")
	c.aguas=[{"x":2,"z":3}]
	a.x=1
	ok(not B.livre(c,Vector2i(2,3),a.id),"Caçador não caminha na água")
	c.animal="jacare_papo_amarelo"
	ok(B.livre(c,Vector2i(2,3),"animal"),"Jacaré pode ocupar água")
	c=arena()
	turno(c,"pessoa_1")
	a=B.atual(c)
	a.vida=0
	ok(B.agir(c,a.id,"defender")!="","Incapacitado não age")
	var achou:={1:false,20:false}
	for semente in range(1,150):
		c=arena(semente)
		turno(c,"pessoa_1")
		a=B.atual(c)
		b=B.ator(c,"animal")
		a.x=1
		a.z=3
		b.x=2
		b.z=3
		a.atributo_ataque=100
		b.vida=1000
		b.vida_max=1000
		b.armadura=2
		var proximo:=B.dado(c.duplicate(true))
		if proximo not in [1,20] or achou[proximo]: continue
		B.agir(c,a.id,"atacar","animal")
		if proximo==1: ok(b.vida==1000,"Um natural erra mesmo com bônus enorme")
		else: ok(1000-b.vida>=1 and 1000-b.vida<=11,"Crítico dobra apenas dados; armadura subtrai uma vez")
		achou[proximo]=true
		if achou[1] and achou[20]: break
	ok(achou[1] and achou[20],"Fixtures encontraram ambos extremos do D20")
	c=arena(22)
	turno(c,"animal")
	a=B.atual(c)
	var protegido:=B.ator(c,"pessoa_2")
	var protetor:=B.ator(c,"pessoa_1")
	a.x=2
	a.z=3
	a.atributo_ataque=100
	protegido.x=1
	protegido.z=3
	protetor.x=1
	protetor.z=4
	protetor.protegendo=protegido.id
	protetor.armadura=1
	var antes: int=protegido.vida
	var hp: int=protetor.vida
	B.agir(c,a.id,"atacar",protegido.id)
	ok(protegido.vida==antes and protetor.vida<hp and protetor.protegendo=="","Proteção intercepta um ataque sem encadear")
	c=arena()
	for h: Dictionary in c.atores: h.armadura=1000
	B.resolver(c)
	ok(c.resultado=="impasse","Confronto sem progresso encerra sem vitória arbitrária")
	ok(c.recursos.is_empty(),"Impasse não cria recompensa")
	c=arena()
	for h: Dictionary in c.atores:
		if h.lado=="equipe": h.vida=0
	B.verificar_fim(c)
	ok(c.resultado=="derrota" and c.sobrevivencia.size()==2,"Derrota testa sobrevivência individual")
	snapshot=JSON.stringify(c)
	B.verificar_fim(c)
	ok(JSON.stringify(c)==snapshot,"Sobrevivência não é rerrolada")
	validar(c,"Derrota válida")
	c=arena()
	turno(c,"pessoa_1")
	B.atual(c).agilidade=-100
	var vida_antes: int=B.atual(c).vida
	ok(B.agir(c,"pessoa_1","fugir")=="" and c.resultado=="" and B.ator(c,"pessoa_1").vida==vida_antes,"Retirada falha consome turno sem ataque gratuito")
	c=arena()
	turno(c,"pessoa_1")
	B.atual(c).agilidade=100
	B.agir(c,"pessoa_1","fugir")
	ok(c.resultado=="retirada" and c.recursos.is_empty(),"Retirada bem sucedida não rende caça")

func determinismo_e_simulacoes() -> void:
	var equipe:=soldados()
	for especie: Dictionary in B.regras.animais:
		var contagens:={}
		for seed_value in range(1,21):
			var c:=B.novo(equipe,especie.id,seed_value)
			var clone:=espelho(c)
			for i in range(7):
				if c.resultado=="": B.agir_automatico(c)
			var salvo:=espelho(c)
			B.resolver(c)
			B.resolver(salvo)
			# Manual reproduz o plano da política automática pelo mesmo contrato de ações.
			for i in range(2000):
				if clone.resultado!="": break
				var plano:=B.decisao(clone)
				var id: String=B.atual(clone).id
				var erro:=B.agir(clone,id,plano.acao,plano.get("alvo",""),Vector2i(plano.get("x",-1),plano.get("z",-1)))
				if erro!="": B.encerrar_turno(clone)
			ok(c.resultado==clone.resultado and c.rng==clone.rng and c.registro==clone.registro,"Manual/automático equivalentes "+especie.id+str(seed_value))
			ok(c.resultado==salvo.resultado and c.rng==salvo.rng,"Retomada no meio do confronto "+especie.id+str(seed_value))
			ok(c.resultado!="" and c.rodada<=41,"Confronto encerra "+especie.id+str(seed_value))
			validar(c,"Confronto encerrado válido")
			contagens[c.resultado]=int(contagens.get(c.resultado,0))+1
		estatisticas[especie.id]=contagens
	print("SIMULACOES_ETAPA_9: ",JSON.stringify(estatisticas))

func integracao() -> void:
	var e=aldeia()
	ok(e.construir("caca",Vector2(6,-1),PI/2)=="","Centro de caça aprovado pode ser construído e girado")
	ok(e.estoque.madeira==65 and e.estoque.fibras_vegetais==48,"Custo do centro")
	passo(e,60)
	for h: Dictionary in e.habitantes: e.atribuir(h.id,"obra_2")
	var equipe: Array=e.habitantes.map(func(h): return h.id)
	var envio:=X.enviar(e,"obra_2","caca",14,equipe,"simulado",{equipe[0]:"arco",equipe[1]:"lanca"})
	ok(envio.ok,"Envio de caça real")
	ok(not X.enviar(e,"obra_2","pesca",21,equipe).ok,"Centro não aceita pesca")
	ok(not X.enviar(e,"obra_2","caca",14,[equipe[0]]).ok,"Limite de uma equipe")
	var exp: Dictionary=e.expedicoes[-1]
	passo(e,3+exp.viagem+exp.duracao_exploracao)
	# Etapa 11: a caça simulada abre um alerta de intervenção antes do confronto.
	ok(exp.fase=="alerta" and not exp.combate.is_empty(),"Busca cria confronto único com alerta")
	ok(X.simular(e,exp.id)=="" and exp.fase=="confronto","Deixar simular inicia o confronto")
	ok(exp.combate.animal!="onca_pintada","Primeira caça não encontra onça")
	ok(exp.carga.is_empty(),"Sem carne antes de vencer")
	var erro:=E.validar(e.serializar())
	ok(erro=="","Confronto integrado válido "+erro)
	var salvar:=S.new(pasta)
	var r: Dictionary=salvar.salvar(e,"manual")
	ok(r.ok,"Salvar confronto em arquivo "+str(r))
	var l: Dictionary=salvar.carregar("manual")
	ok(l.ok,"Carregar confronto")
	if not l.ok: return
	var clone=l.estado
	passo(e,1000)
	for i in range(200): passo(clone,5)
	ok(exp.fase=="concluida","Retorno conclui caça")
	ok(e.estoque==clone.estoque and exp.combate.rng==clone.expedicoes[-1].combate.rng,"Economia e combate independem do passo de tempo")
	erro=E.validar(e.serializar())
	ok(erro=="","Retorno íntegro "+erro)
	var xp: int=e.habitantes[0].xp
	var estoque: Dictionary=e.estoque.duplicate()
	X.Caca.aplicar(e,exp)
	X.descarregar(e,exp,[])
	ok(e.habitantes[0].xp==xp and e.estoque==estoque,"Resultado e descarga não duplicam XP ou recursos")
	# Vitória controlada: carne e couro viajam na carga e só entram no retorno.
	e=aldeia()
	e.construir("caca",Vector2(6,-1))
	passo(e,60)
	X.enviar(e,"obra_2","caca",14,equipe)
	exp=e.expedicoes[-1]
	passo(e,3+exp.viagem+exp.duracao_exploracao)
	X.simular(e,exp.id)
	B.ator(exp.combate,"animal").vida=0
	B.verificar_fim(exp.combate)
	X.terminar_confronto(e,exp,[])
	ok(e.estoque.carne==0 and exp.carga.carne==4 and exp.carga.couro==1,"Recompensa de capivara preservada na carga antes do retorno")
	passo(e,exp.viagem)
	ok(exp.fase=="concluida" and e.estoque.carne==4 and e.estoque.couro==1,"Retorno entrega carne e couro uma vez")
	# Derrota controlada verifica ciclo de morte e evita ressurreição por alimentação.
	e=aldeia()
	e.construir("caca",Vector2(6,-1))
	passo(e,60)
	X.enviar(e,"obra_2","caca",14,[e.habitantes[0].id])
	exp=e.expedicoes[-1]
	passo(e,3+exp.viagem+exp.duracao_exploracao)
	X.simular(e,exp.id)
	var a: Dictionary=exp.combate.atores[0]
	a.vida=0
	a.resistencia=-100
	B.verificar_fim(exp.combate)
	X.terminar_confronto(e,exp,[])
	ok(e.habitantes[0].estado=="morto" and e.populacao()==1,"Morte reduz população viva sem reutilizar ID")
	passo(e,1500)
	ok(e.habitantes[0].saude==0 and e.habitantes[0].estado=="morto","Alimentação não ressuscita falecidos")
	erro=E.validar(e.serializar())
	ok(erro=="","Falecimento persiste sem corromper histórico "+erro)

func executar() -> void:
	pasta="user://testes_etapa_9/"+Crypto.new().generate_random_bytes(8).hex_encode()
	regras()
	determinismo_e_simulacoes()
	integracao()
	print("ETAPA_9: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
