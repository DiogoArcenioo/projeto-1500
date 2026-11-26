extends SceneTree
## Etapa 12 — pesca manual: espécies, mordida, física da briga, economia, registro,
## perigo durante a pescaria, save/load e a cena jogada por um robô.
##   godot --headless --path . --script res://tests/test_etapa_12.gd
const E=preload("res://scripts/partida/estado_partida.gd")
const C=preload("res://scripts/partida/configuracao_partida.gd")
const X=preload("res://scripts/partida/expedicoes.gd")
const P=preload("res://scripts/partida/pesca.gd")
const Regioes=preload("res://scripts/partida/regioes.gd")
var total:=0
var falhas:=0

func _initialize() -> void: executar.call_deferred()
func ok(v: bool,n: String) -> void:
	total+=1
	if not v:
		falhas+=1
		push_error(n)
func passo(e,t: float) -> Array[String]: return e.avancar_simulacao(e.relogio.avancar(t))
func jogo(e,t: float) -> Array[String]:
	e.relogio.tempo_total+=t
	return e.avancar_simulacao(t)
func valido(e,n: String) -> void:
	var erro:=E.validar(e.serializar())
	ok(erro=="",n+" "+erro)

func aldeia():
	var e=E.nova(C.new())
	e.construir("oca",Vector2(-5,-4))
	passo(e,18)
	e.construir("oca",Vector2(-6,5.5))
	for h: Dictionary in e.habitantes: e.atribuir(h.id,e.construcoes[-1].id)
	passo(e,60)
	for k in e.conhecimento: e.conhecimento[k]=maxi(2,int(e.conhecimento[k]))
	e.construir("pesca",Vector2(8,1.2))
	for h: Dictionary in e.habitantes: e.atribuir(h.id,e.construcoes[-1].id)
	passo(e,60)
	for h: Dictionary in e.habitantes:
		if h.estado!="livre": e.atribuir(h.id,"")
	return e

func centro(e,tipo: String) -> String:
	for c: Dictionary in e.construcoes:
		if c.tipo==tipo and c.pronta: return c.id
	return ""

## Robô cuidadoso: puxa enquanto a tensão é segura, cede no salto, vara do lado oposto.
func cuidadoso(b: Dictionary) -> Array:
	var puxar: bool=(not b.no_ar and b.modo not in ["salto","corrida"] and float(b.tensao)<.78) or b.modo=="cansado"
	return [puxar,-signf((b.dir as Vector2).x)]

func brigar(peixe: Dictionary,estrategia: Callable,semente:=7,limite:=240.0) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	rng.seed=semente
	var b:=P.criar_briga(peixe,.85,0.0,8.0,rng)
	var modos:={}
	var t:=0.0
	while b.resultado=="" and t<limite:
		var entrada: Array=estrategia.call(b)
		P.passo(b,entrada[0],entrada[1],1.0/30.0,rng)
		modos[b.modo]=true
		t+=1.0/30.0
	b.modos=modos.keys()
	b.duracao=t
	return b

func regras() -> void:
	var rng:=RandomNumberGenerator.new()
	rng.seed=12
	var vistos:={}
	for i in range(600):
		for regiao in [3,21,27,28]:
			var p:=P.sortear(regiao,rng)
			var esp:=P.especie(p.especie)
			ok(P.fauna(regiao).has(p.especie),"Espécie do habitat %d"%regiao)
			ok(p.peso>=float(esp.peso[0])-.01 and p.peso<=float(esp.peso[1])+.01,"Peso dentro da espécie")
			vistos[p.especie]=true
	ok(vistos.size()==7,"As sete espécies aparecem nos sorteios")
	ok(not P.fauna(3).has("camurupim") and P.fauna(27).has("robalo"),"Cabeceira sem camurupim; baixo rio com robalo")
	var a:=RandomNumberGenerator.new()
	var b:=RandomNumberGenerator.new()
	a.seed=99
	b.seed=99
	ok(P.sortear(21,a)==P.sortear(21,b),"Sorteio determinístico pela semente")
	ok(P.porte(.03)<P.porte(1.0) and P.porte(1.0)<P.porte(30.0),"Porte cresce com o peso")
	ok(P.unidades(0)==0 and P.unidades(.05)==1 and P.unidades(7.0)==10,"Peso vira porções de peixe")
	# Mordida: sinais em ordem, a mordida de verdade por último e a janela de fisgada.
	for especie in ["lambari","acara","piau","traira","jundia","robalo","camurupim"]:
		var esp:=P.especie(especie)
		var m:=P.mordida({"especie":especie,"peso":esp.peso[1]},0.0,rng)
		var ultimo: Dictionary=m.eventos[-1]
		ok(is_equal_approx(float(ultimo.t),float(m.inicio)) and ultimo.tipo in ["afundar","puxao","arrasto","corrida"],"Mordida forte de "+especie)
		ok(P.fisgar(m,float(m.inicio)-.5).resultado=="cedo","Cedo demais em "+especie)
		ok(P.fisgar(m,float(m.inicio)+float(m.janela)+.1).resultado=="tarde","Tarde demais em "+especie)
		var f:=P.fisgar(m,float(m.inicio)+float(m.janela)*.3)
		ok(f.resultado=="fisgou" and f.firmeza>.95,"Fisgada no ponto em "+especie)
	var leve:=P.mordida({"especie":"robalo","peso":.6},0.0,rng)
	var pesado:=P.mordida({"especie":"robalo","peso":5.5},0.0,rng)
	ok(float(pesado.eventos[-1].forca)>float(leve.eventos[-1].forca),"Peixe grande afunda a boia com mais força")
	var novato:=P.mordida({"especie":"lambari","peso":.05},0.0,rng)
	var mestre:=P.mordida({"especie":"lambari","peso":.05},1.0,rng)
	ok(float(mestre.janela)>float(novato.janela),"Experiência alarga a janela de fisgada")

func briga() -> void:
	var pequeno:=brigar({"especie":"lambari","peso":.05},cuidadoso)
	ok(pequeno.resultado=="capturado","Lambari capturado com cuidado ("+pequeno.resultado+")")
	ok(pequeno.duracao<20,"Peixe pequeno cansa rápido (%.1f s)"%pequeno.duracao)
	var medio:=brigar({"especie":"robalo","peso":3.0},cuidadoso)
	ok(medio.resultado=="capturado","Robalo de 3 kg capturado com cuidado ("+medio.resultado+")")
	ok(medio.duracao>pequeno.duracao*2,"Robalo briga muito mais que o lambari (%.1f s)"%medio.duracao)
	ok("corrida" in medio.modos,"Robalo dá corridas")
	var forte:=brigar({"especie":"camurupim","peso":30.0},func(_b): return [true,0.0])
	ok(forte.resultado in ["linha_rompeu","escapou"],"Puxar sem parar um camurupim de 30 kg perde o peixe ("+forte.resultado+")")
	ok(forte.duracao<20,"…e perde depressa")
	var solto:=brigar({"especie":"acara","peso":.3},func(_b): return [false,0.0],3,90.0)
	ok(solto.resultado=="escapou","Sem puxar, a linha afrouxa e o anzol solta ("+solto.resultado+")")
	var fundo:=brigar({"especie":"jundia","peso":2.5},cuidadoso,5)
	ok("fundo" in fundo.modos,"Jundiá vai para o fundo")
	var salto:=brigar({"especie":"camurupim","peso":12.0},cuidadoso,11,400.0)
	ok("salto" in salto.modos,"Camurupim salta")
	# Lado da vara: contra o peixe cansa mais depressa.
	var rng:=RandomNumberGenerator.new()
	var cansa:={}
	for lado in [-1.0,1.0]:
		rng.seed=4
		var b:=P.criar_briga({"especie":"robalo","peso":3.0},.9,0.0,8.0,rng)
		b.dir=Vector2(.8,.6).normalized()
		b.modo="nadar"
		b.tempo_modo=99.0
		for i in range(60):
			b.dir=Vector2(.8,.6).normalized()
			P.passo(b,true,lado,1.0/30.0,rng)
		cansa[lado]=b.folego
	ok(cansa[-1.0]<cansa[1.0],"Vara contra o lado do peixe o cansa mais")
	# Resultado de taxa: robô cuidadoso pega a maioria dos peixes comuns.
	var pegos:=0
	for i in range(20):
		var r:=RandomNumberGenerator.new()
		r.seed=100+i
		var p:=P.sortear(21,r)
		if brigar(p,cuidadoso,200+i,300.0).resultado=="capturado": pegos+=1
	ok(pegos>=12,"Robô cuidadoso pega a maioria (%d de 20)"%pegos)

func expedicao() -> void:
	var e=aldeia()
	var ids: Array=e.habitantes.map(func(h): return h.id)
	ok(X.erro_envio(e,centro(e,"pesca"),"pesca",21,[ids[0]],"manual")=="","Pesca à mão pode ser enviada")
	ok(X.erro_envio(e,centro(e,"pesca"),"coleta",21,[ids[0]],"manual")!="","Só caça e pesca são jogáveis")
	var r:=X.enviar(e,centro(e,"pesca"),"pesca",21,[ids[0],ids[1]],"manual")
	ok(r.ok,"Pescaria enviada "+str(r.get("erro","")))
	var v:=X.buscar(e,r.id)
	v.encontro={"em":-1.0,"animal":""}
	for i in range(200):
		if not X.pesca_pendente(e).is_empty(): break
		jogo(e,1)
	ok(not X.pesca_pendente(e).is_empty() and v.fase=="exploracao","Pescaria aguarda o jogador na chegada")
	ok(v.pesca.lances==P.lances(2) and v.pesca.feitos==0,"Lances pela equipe")
	var antes: float=v.restante
	jogo(e,30)
	ok(v.restante==antes and v.ciclos==0,"Aldeia congelada durante a pescaria")
	valido(e,"Save válido no meio da pescaria")
	var xp0:=int(e.pessoa(ids[0]).habilidades.pesca)
	ok(X.iniciar_lance(e,v)=="","Lance liberado")
	var info:=X.registrar_lance(e,v,0,{"especie":"traira","peso":1.4},true)
	ok(info.get("recorde",false),"Primeira traíra é recorde")
	ok(X.registrar_lance(e,v,0,{"especie":"traira","peso":9.0},true).is_empty(),"Mesmo lance não registra duas vezes")
	ok(v.pesca.capturas.size()==1 and is_equal_approx(v.pesca.kg,1.4),"Uma captura registrada")
	ok(int(e.pessoa(ids[0]).habilidades.pesca)==xp0+2 and int(e.pessoa(ids[1]).habilidades.pesca)==xp0+2,"XP da captura para a equipe")
	ok(not X.registrar_lance(e,v,1,{"especie":"traira","peso":.8},true).recorde,"Traíra menor não é recorde")
	ok(e.registro_pesca.traira.quantidade==2 and is_equal_approx(e.registro_pesca.traira.maior,1.4),"Registro: quantidade e maior exemplar")
	X.registrar_lance(e,v,2,{"especie":"lambari","peso":.04},false)
	# Save/load no meio: a sessão continua do lance certo.
	var dados: Dictionary=e.serializar()
	ok(E.validar(dados)=="","Save com registro e pescaria válido")
	var c=E.desserializar(JSON.parse_string(JSON.stringify(dados)))
	var v2:=X.buscar(c,v.id)
	ok(v2.pesca.feitos==3 and c.registro_pesca.traira.quantidade==2 and X.pesca_ativa(v2),"Carregar retoma a pescaria")
	var ruim: Dictionary=JSON.parse_string(JSON.stringify(dados))
	ruim.expedicoes[0].pesca.capturas.append({"especie":"tubarao","peso":3})
	ok(E.validar(ruim)!="","Peixe inexistente rejeitado no save")
	var ruim2: Dictionary=JSON.parse_string(JSON.stringify(dados))
	ruim2.registro_pesca={"traira":{"quantidade":0,"maior":1,"pescador":""}}
	ok(E.validar(ruim2)!="","Registro inválido rejeitado")
	for i in range(int(v.pesca.lances)-3): X.registrar_lance(e,v,int(v.pesca.feitos),{"especie":"acara","peso":.3},true)
	ok(v.fase=="retorno" and v.pesca.fim,"Últimas iscas encerram a pescaria e a equipe volta")
	ok(int(v.carga.get("peixe",0))==P.unidades(v.pesca.kg),"Peso pescado vira carga uma única vez")
	var estoque:=int(e.estoque.peixe)
	for i in range(400):
		if v.fase=="concluida": break
		jogo(e,1)
	ok(v.fase=="concluida" and int(e.estoque.peixe)==estoque+P.unidades(v.pesca.kg),"Peixe chega ao estoque no retorno")
	ok(X.resumo(e,v).contains("Pescaria jogada"),"Resumo cita a pescaria jogada")
	valido(e,"Save válido após a pescaria")

func perigo() -> void:
	var e=aldeia()
	var ids: Array=e.habitantes.map(func(h): return h.id)
	var r:=X.enviar(e,centro(e,"pesca"),"pesca",27,[ids[0],ids[1]],"manual")
	var v:=X.buscar(e,r.id)
	v.encontro={"em":40.0,"animal":"jacare_papo_amarelo"}
	for i in range(200):
		if not X.pesca_pendente(e).is_empty(): break
		jogo(e,1)
	ok(v.pesca.perigo>=1,"Perigo marcado para um lance da sessão")
	var avisos: Array[String]=[]
	for i in range(int(v.pesca.perigo)):
		ok(X.iniciar_lance(e,v,avisos)=="","Lance antes do perigo")
		X.registrar_lance(e,v,i,{"especie":"lambari","peso":.05},true)
	ok(X.iniciar_lance(e,v,avisos)=="perigo" and v.fase=="alerta","Jacaré interrompe a pescaria com o alerta comum")
	ok(X.pesca_pendente(e).is_empty(),"Pescaria pausada enquanto há perigo")
	valido(e,"Save válido com alerta na pescaria")
	X.simular(e,v.id)
	for i in range(600):
		if v.fase not in ["confronto","alerta"]: break
		jogo(e,1)
	if v.fase=="exploracao":
		ok(X.pesca_ativa(v),"Depois do perigo a pescaria continua")
		ok(X.iniciar_lance(e,v)=="","Lances seguintes liberados")
	else:
		ok(v.fase in ["retorno","aguardando_descarga","concluida"],"Equipe recua depois do perigo ("+v.fase+")")
	ok(int(v.carga.get("carne",0))>=0,"Sem recompensa duplicada")

func simulada() -> void:
	var e=aldeia()
	var ids: Array=e.habitantes.map(func(h): return h.id)
	var r:=X.enviar(e,centro(e,"pesca"),"pesca",21,[ids[0]],"simulado")
	var v:=X.buscar(e,r.id)
	v.encontro={"em":-1.0,"animal":""}
	var avisos: Array[String]=[]
	for i in range(900):
		avisos.append_array(jogo(e,1))
		if v.fase=="concluida": break
	ok(v.fase=="concluida","Pescaria simulada conclui sozinha")
	ok(not e.registro_pesca.is_empty(),"Pescaria simulada também alimenta o registro")
	var nomeou:=false
	for a in avisos:
		for esp in ["Lambari","Acará","Piau","Traíra","Jundiá","Robalo","Camurupim"]:
			if a.contains(esp): nomeou=true
	ok(nomeou,"Mensagens da simulação nomeiam a espécie")

func cena() -> void:
	var e=aldeia()
	var ids: Array=e.habitantes.map(func(h): return h.id)
	var r:=X.enviar(e,centro(e,"pesca"),"pesca",21,[ids[0]],"manual")
	var v:=X.buscar(e,r.id)
	v.encontro={"em":-1.0,"animal":""}
	for i in range(200):
		if not X.pesca_pendente(e).is_empty(): break
		jogo(e,1)
	var c=load("res://scenes/encontros/pesca_manual.tscn").instantiate()
	c.estado=e
	c.expedicao_id=v.id
	c.automatico=true
	var fim:=[false]
	c.concluido.connect(func(): fim[0]=true)
	root.add_child(c)
	await process_frame
	var fases:={}
	for i in range(30*600):
		c._process(1.0/30.0)
		fases[c.fase]=true
		if fim[0]: break
	ok(fim[0],"Robô joga a sessão inteira até voltar à aldeia")
	ok(fases.has("briga") and fases.has("espera") and fases.has("voando"),"Cena passou por lançar, esperar e brigar")
	ok(v.pesca.fim and int(v.pesca.feitos)==int(v.pesca.lances),"Todos os lances registrados uma vez")
	ok(v.fase=="retorno","Equipe volta depois da sessão")
	print("SESSAO capturas ",v.pesca.capturas," kg ",v.pesca.kg)
	c.queue_free()
	await process_frame

func executar() -> void:
	regras()
	briga()
	expedicao()
	perigo()
	simulada()
	await cena()
	print("ETAPA_12: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
