extends SceneTree
const Estado=preload("res://scripts/partida/estado_partida.gd")
const Config=preload("res://scripts/partida/configuracao_partida.gd")
const Salvar=preload("res://scripts/partida/salvamento.gd")
const Regioes=preload("res://scripts/partida/regioes.gd")
const Exp=preload("res://scripts/partida/expedicoes.gd")
var total:=0
var falhas:=0
var pasta: String

func _initialize() -> void:
	call_deferred("executar")

func conferir(valor: bool,nome: String) -> void:
	total+=1
	if not valor:
		falhas+=1
		push_error(nome)

func aldeia():
	var e=Estado.nova(Config.new())
	e.construir("oca",Vector2(-5,-4))
	e.avancar_aldeia(18)
	e.construir("oca",Vector2(4,-8))
	e.avancar_aldeia(18)
	e.construir("coleta",Vector2(6,-1))
	e.avancar_aldeia(10)
	e.construir("coleta",Vector2(-13,3))
	e.avancar_aldeia(10)
	return e

func carregar(e):
	var s:=Salvar.new(pasta)
	conferir(s.salvar(e,"manual").ok,"Gravar snapshot "+str(e.expedicoes.size()))
	var l:=s.carregar("manual")
	conferir(l.ok,"Ler snapshot")
	return l.estado if l.ok else e

func teste_mapa() -> void:
	conferir(Regioes.definicoes().size()==30,"Trinta regiões estáveis")
	var inicial:=Regioes.iniciais()
	var todas:=inicial.duplicate()
	for i in range(30): todas[str(i)]=3
	for r: Dictionary in Regioes.definicoes():
		conferir(not r.vizinhas.is_empty(),"Região conectada "+r.nome)
		conferir(Regioes.viagem(r.id,todas)>0,"Rota até "+r.nome)
	conferir(not Regioes.informacoes(0,inicial).contains("Serra"),"Dados desconhecidos ocultos")
	Regioes.revelar(inicial,0,1)
	conferir(Regioes.informacoes(0,inicial).contains("Serra") and not Regioes.informacoes(0,inicial).contains("Abundância"),"Conhecimento parcial")
	Regioes.revelar(inicial,0,2)
	conferir(Regioes.informacoes(0,inicial).contains("Abundância"),"Conhecimento acumulado")
	var e=Estado.nova(Config.new())
	e.conhecimento=inicial
	e=carregar(e)
	conferir(int(e.conhecimento["0"])==3,"Conhecimento persistente")
	var antigo: Dictionary=e.serializar()
	antigo.erase("conhecimento")
	antigo.erase("expedicoes")
	antigo.erase("sequencia_expedicao")
	conferir(Estado.desserializar(antigo)!=null,"Saves antigos migrados")
	var rng1:=RandomNumberGenerator.new()
	var rng2:=RandomNumberGenerator.new()
	rng1.seed=1500
	rng2.seed=1500
	for i in range(30):
		conferir(Exp.Regioes.sortear(14,"coleta",rng1)==Exp.Regioes.sortear(14,"coleta",rng2),"Sorteio reproduzível")

func teste_expedicoes() -> void:
	var e=aldeia()
	var a: Dictionary=e.habitantes[0]
	var b: Dictionary=e.habitantes[1]
	e.atribuir(a.id,"obra_3")
	e.atribuir(b.id,"obra_4")
	var envio:=Exp.enviar(e,"obra_3","coleta",14,[a.id])
	conferir(envio.ok,"Enviar coleta")
	conferir(not Exp.enviar(e,"obra_3","coleta",14,[e.habitantes[2].id]).ok,"Limite independente de simultâneas")
	conferir(not Exp.enviar(e,"obra_4","coleta",14,[a.id]).ok,"Equipe não participa de duas atividades")
	conferir(e.atribuir(a.id,"")!="","Integrante indisponível para transferência")
	conferir(Exp.enviar(e,"obra_4","reconhecimento",13,[b.id]).ok,"Duas expedições de centros distintos")
	conferir(not Exp.enviar(e,"obra_4","coleta",14,[b.id,b.id]).ok,"Duplo envio bloqueado")
	conferir(Estado.validar(e.serializar())=="","Estado ativo válido")
	e=carregar(e)
	a=e.habitantes[0]
	b=e.habitantes[1]
	var saldo_madeira: int=e.estoque.madeira
	var saldo_vegetais: int=e.estoque.vegetais
	var saldo_fibras: int=e.estoque.fibras_vegetais
	Exp.avancar(e,3)
	conferir(e.expedicoes[0].fase=="ida","Preparação para ida")
	Exp.avancar(e,float(e.expedicoes[0].viagem)+60)
	conferir(e.expedicoes[0].ciclos>=1 and a.habilidades.coleta>0,"Atividade concede XP")
	conferir(e.estoque.madeira==saldo_madeira and e.estoque.vegetais==saldo_vegetais and e.estoque.fibras_vegetais==saldo_fibras,"Carga fora do estoque durante exploração")
	var estado_rng: String=e.expedicoes[0].rng
	e=carregar(e)
	conferir(e.expedicoes[0].rng==estado_rng,"Sorteio preservado no save")
	var clone=Estado.desserializar(e.serializar())
	for i in range(720): Exp.avancar(clone,.5)
	Exp.avancar(e,360)
	conferir(JSON.stringify(e.serializar())==JSON.stringify(clone.serializar()),"Simulação independente do tamanho do passo")
	conferir(e.habitantes[0].estado=="trabalhando" and e.habitantes[1].estado=="trabalhando","Vínculo profissional restaurado")
	conferir(int(e.conhecimento["13"])>0,"Reconhecimento descobre região")
	conferir(e.habitantes[1].habilidades.coleta==0,"Reconhecimento não concede XP de coleta")
	var antes: Dictionary=e.estoque.duplicate()
	Exp.avancar(e,999)
	conferir(e.estoque==antes,"Retorno idempotente")
	e=carregar(e)
	conferir(e.expedicoes[0].fase=="concluida","Conclusão persistida")
	antes=e.estoque.duplicate()
	Exp.avancar(e,999)
	conferir(e.estoque==antes,"Carregar não duplica recompensa")
	var corrompido: Dictionary=e.serializar()
	corrompido.expedicoes[0].rng="invalido"
	conferir(Estado.validar(corrompido)!="","RNG inválido rejeitado")

func teste_cancelamento_excedente() -> void:
	var e=aldeia()
	var id: String=e.habitantes[0].id
	conferir(not Exp.enviar(e,"obra_3","coleta",0,[id]).ok,"Coleta em região oculta bloqueada")
	conferir(not Exp.enviar(e,"obra_3","coleta",14,[id],"manual").ok,"Modo não disponível rejeitado")
	conferir(not Exp.enviar(e,"obra_3","coleta",14,[id,id]).ok,"Equipe duplicada rejeitada")
	conferir(not Exp.enviar(e,"obra_3","coleta",14,[id,e.habitantes[1].id,e.habitantes[2].id]).ok,"Tamanho de equipe bloqueado")
	var resposta:=Exp.enviar(e,"obra_3","coleta",14,[id])
	conferir(Exp.retornar(e,resposta.id)=="","Cancelar durante preparação")
	conferir(e.habitantes[0].estado=="livre" and e.habitantes[0].xp>0,"Preparação libera morador")
	resposta=Exp.enviar(e,"obra_3","coleta",14,[id])
	Exp.avancar(e,8)
	conferir(Exp.retornar(e,resposta.id)=="" and is_equal_approx(e.expedicoes[-1].restante,5),"Retorno usa trecho percorrido")
	e=carregar(e)
	Exp.avancar(e,5)
	conferir(e.expedicoes[-1].fase=="concluida","Cancelar ida volta sem travar")
	resposta=Exp.enviar(e,"obra_3","coleta",14,[id])
	# Fixture de depósito material cheio; comida tem lotes e capacidade própria na etapa 8.
	e.estoque.madeira=e.LIMITE_ESTOQUE
	Exp.avancar(e,600)
	var exp: Dictionary=e.expedicoes[-1]
	exp.carga={"madeira":3}
	exp.fase="aguardando_descarga"
	Exp.descarregar(e,exp,[])
	conferir(exp.fase=="aguardando_descarga" and not exp.carga.is_empty(),"Excedente fica preservado")
	conferir(e.habitantes[0].estado=="livre","Morador livre com carga aguardando descarga")
	e=carregar(e)
	exp=e.expedicoes[-1]
	var carga: Dictionary=exp.carga.duplicate()
	var r: String=carga.keys()[0]
	e.estoque[r]-=1
	Exp.avancar(e,1)
	conferir(Exp.quantidade(exp.carga)==Exp.quantidade(carga)-1,"Descarga parcial segura")
	for recurso in exp.carga: e.estoque[recurso]=0
	Exp.avancar(e,1)
	conferir(exp.fase=="concluida" and exp.carga.is_empty(),"Descarga termina quando há espaço")

func teste_integracao() -> void:
	var cena=load("res://scenes/main.tscn").instantiate()
	cena.salvamento=Salvar.new(pasta)
	root.add_child(cena)
	cena.set_process(false)
	cena.abrir_mapa()
	conferir(cena.mapa_regional.visible and not cena._controle.is_processing(),"Mapa aberto com câmera da aldeia bloqueada")
	cena.mapa_regional.alternar_inspecao()
	conferir(not cena.mapa_regional.mapa.mostrar_tudo,"Revelação de inspeção indisponível na partida")
	cena.fechar_mapa()
	conferir(not cena.mapa_regional.visible and cena._controle.is_processing(),"Retorna à aldeia")
	cena.estado=aldeia()
	cena.aldeia.reiniciar(cena.estado)
	cena.painel.reiniciar(cena.estado)
	var envio:=Exp.enviar(cena.estado,"obra_3","coleta",14,[cena.estado.habitantes[0].id])
	conferir(envio.ok,"Expedição no estado real")
	cena.alternar_pausa()
	var restante: float=cena.estado.expedicoes[-1].restante
	cena._process(10)
	conferir(cena.estado.expedicoes[-1].restante==restante,"Pausa congela expedições")
	cena.alternar_pausa()
	cena.definir_velocidade(3)
	cena._process(1)
	conferir(cena.estado.expedicoes[-1].fase=="ida","Velocidade afeta motor de expedições")
	conferir(not cena.aldeia.atores[cena.estado.habitantes[0].id].modelo.visible,"Integrante ausente da aldeia")
	cena.queue_free()
	await process_frame

func executar() -> void:
	pasta="user://testes_etapas_6_7/"+Crypto.new().generate_random_bytes(8).hex_encode()
	teste_mapa()
	teste_expedicoes()
	teste_cancelamento_excedente()
	await teste_integracao()
	var d:=DirAccess.open(pasta)
	if d:
		for f in d.get_files(): DirAccess.remove_absolute(pasta.path_join(f))
		DirAccess.remove_absolute(pasta)
	print("ETAPAS_6_7: %d verificações; %d falhas"%[total,falhas])
	quit(1 if falhas else 0)
