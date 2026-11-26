extends RefCounted
## Regras puras, sem cena, relógio da aldeia ou efeitos aplicados a moradores.
static var regras: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/configuracoes/combate.json"))
const RESULTADOS:=["","vitoria","animal_fugiu","retirada","derrota","impasse"]

static func bonus(valor: float) -> int:
	return floori((valor-5)/2)
static func especie(id: String) -> Dictionary:
	for a: Dictionary in regras.animais:
		if a.id==id: return a
	return {}
static func nome_animal(id: String) -> String:
	return {"capivara":"Capivara","queixada":"Queixada","anta":"Anta","jacare_papo_amarelo":"Jacaré-de-papo-amarelo","onca_pintada":"Onça-pintada"}.get(id,id)
static func dado(c: Dictionary,lados:=20) -> int:
	var rng:=RandomNumberGenerator.new()
	rng.state=int(c.rng)
	var valor:=rng.randi_range(1,lados)
	c.rng=str(rng.state)
	return valor
static func registrar(c: Dictionary,msg: String) -> void:
	c.registro.append(msg)
	if c.registro.size()>80: c.registro.pop_front()
static func ator(c: Dictionary,id: String) -> Dictionary:
	for a: Dictionary in c.atores:
		if a.id==id: return a
	return {}
static func pos(a: Dictionary) -> Vector2i:
	return Vector2i(a.x,a.z)
static func distancia(a: Dictionary,b: Dictionary) -> int:
	return absi(int(a.x)-int(b.x))+absi(int(a.z)-int(b.z))
static func humano(h: Dictionary,arma: String,x: int,z: int,resistencia: float=-1) -> Dictionary:
	var treinado: bool=h.get("especialista_caca",h.habilidades.caca>0)
	var vida:=maxi(1,floori(30+2*(h.atributos.resistencia if resistencia<0 else resistencia)))
	var a: Dictionary={"id":h.id,"nome":h.nome,"lado":"equipe","x":x,"z":z,"vida_max":vida,
		"vida":maxi(1,floori(vida*float(h.saude)/100)),"armadura":0,"defesa":10+bonus(h.atributos.agilidade),
		"agilidade":bonus(h.atributos.agilidade),"percepcao":bonus(h.atributos.percepcao),"resistencia":bonus(h.atributos.resistencia),
		"atributo_ataque":bonus(h.atributos.percepcao if arma=="arco" else h.atributos.forca),
		"treinamento":mini(4,floori(maxf(h.habilidades.caca,h.habilidades.combate)/20)),
		"especializacao":2 if treinado else -2,"equipamento":arma,"precisao":int(regras.equipamentos[arma].precisao),
		"dano":regras.equipamentos[arma].dano,"alcance":int(regras.equipamentos[arma].alcance),"movimento":3,
		"pa":0,"atacou":false,"mira":0,"defesa_temp":0,"protegendo":"","xp":0,"morto":false}
	return a
static func novo(equipe: Array,animal: String,semente: int,bloqueios: Array=[],coberturas: Array=[],aguas: Array=[]) -> Dictionary:
	var dados:=especie(animal)
	if dados.is_empty() or equipe.is_empty(): return {}
	var rng:=RandomNumberGenerator.new()
	rng.seed=semente
	var c: Dictionary={"versao":1,"rng":str(rng.state),"animal":animal,"tipo":"defensivo" if animal=="onca_pintada" else "caca",
		"atores":equipe.duplicate(true),"bloqueios":bloqueios.duplicate(true),"coberturas":coberturas.duplicate(true),"aguas":aguas.duplicate(true),
		"ordem":[],"cursor":0,"rodada":1,"dano_total":0,"dano_inicio_rodada":0,"rodadas_sem_dano":0,
		"resultado":"","recursos":{},"registro":[],"aplicado":false,"sobrevivencia":{}}
	var inimigo: Dictionary={"id":"animal","nome":nome_animal(animal),"lado":"animal","x":6,"z":3,
		"vida":int(dados.vida),"vida_max":int(dados.vida),"armadura":int(dados.armadura),"defesa":int(dados.defesa),
		"agilidade":int(dados.defesa)-10,"percepcao":0,"resistencia":0,"atributo_ataque":int(dados.ataque),
		"treinamento":0,"especializacao":0,"precisao":0,"equipamento":"natural","dano":dados.dano,"alcance":1,
		"movimento":int(dados.movimento),"pa":0,"atacou":false,"mira":0,"defesa_temp":0,"protegendo":"","xp":0,"morto":false}
	c.atores.append(inimigo)
	for a: Dictionary in c.atores:
		a.iniciativa=dado(c)+int(a.agilidade)
		c.ordem.append(a.id)
		registrar(c,"%s · iniciativa %d"%[a.nome,a.iniciativa])
	c.ordem.sort_custom(func(i,j):
		var a:=ator(c,i)
		var b:=ator(c,j)
		if a.iniciativa!=b.iniciativa: return a.iniciativa>b.iniciativa
		if a.agilidade!=b.agilidade: return a.agilidade>b.agilidade
		return str(i)<str(j))
	iniciar_turno(c)
	return c
static func atual(c: Dictionary) -> Dictionary:
	return ator(c,c.ordem[int(c.cursor)]) if not c.is_empty() and c.resultado=="" else {}
static func vivos(c: Dictionary,lado: String) -> Array:
	return c.atores.filter(func(a): return a.lado==lado and a.vida>0 and not a.morto)
static func finalizar(c: Dictionary,resultado: String) -> void:
	if c.resultado!="": return
	c.resultado=resultado
	if resultado=="vitoria": c.recursos=especie(c.animal).recursos.duplicate()
	if resultado=="derrota":
		var dificuldade:=16 if c.animal=="onca_pintada" else 10
		for a: Dictionary in c.atores:
			if a.lado!="equipe": continue
			var roll:=dado(c)
			a.morto=roll+int(a.resistencia)<dificuldade
			c.sobrevivencia[a.id]={"d20":roll,"bonus":a.resistencia,"dificuldade":dificuldade,"morto":a.morto}
			registrar(c,"%s · sobrevivência D20 %d %+d contra %d: %s"%[a.nome,roll,a.resistencia,dificuldade,"morte" if a.morto else "sobrevive ferido"])
	registrar(c,"Resultado · "+resultado.replace("_"," "))
static func verificar_fim(c: Dictionary) -> bool:
	if c.resultado!="": return true
	if vivos(c,"animal").is_empty(): finalizar(c,"vitoria")
	elif vivos(c,"equipe").is_empty(): finalizar(c,"derrota")
	return c.resultado!=""
static func iniciar_turno(c: Dictionary) -> void:
	if verificar_fim(c): return
	for tentativa in range(c.ordem.size()):
		var a:=ator(c,c.ordem[int(c.cursor)])
		if a.vida>0 and not a.morto:
			a.pa=int(regras.turno.pontos_acao)
			a.atacou=false
			a.mira=0
			a.defesa_temp=0
			a.protegendo=""
			return
		c.cursor=(int(c.cursor)+1)%c.ordem.size()
static func encerrar_turno(c: Dictionary) -> void:
	if verificar_fim(c): return
	var a:=atual(c)
	a.pa=0
	a.mira=0
	for tentativa in range(c.ordem.size()):
		c.cursor=(int(c.cursor)+1)%c.ordem.size()
		if c.cursor==0:
			c.rodada+=1
			c.rodadas_sem_dano=int(c.rodadas_sem_dano)+1 if c.dano_inicio_rodada==c.dano_total else 0
			c.dano_inicio_rodada=c.dano_total
			if c.rodada>int(regras.termino_seguranca.rodadas_maximas) or c.rodadas_sem_dano>=int(regras.termino_seguranca.rodadas_sem_dano_maximas):
				finalizar(c,"impasse")
				return
		if ator(c,c.ordem[int(c.cursor)]).vida>0: break
	iniciar_turno(c)
static func dentro(p: Vector2i) -> bool:
	return p.x>=0 and p.y>=0 and p.x<int(regras.tabuleiro.largura) and p.y<int(regras.tabuleiro.altura)
static func contem(lista: Array,p: Vector2i) -> bool:
	return lista.any(func(v): return int(v.x)==p.x and int(v.z)==p.y)
static func livre(c: Dictionary,p: Vector2i,excecao: String="") -> bool:
	if not dentro(p) or contem(c.bloqueios,p): return false
	if contem(c.aguas,p) and not (excecao=="animal" and c.animal=="jacare_papo_amarelo"): return false
	return not c.atores.any(func(a): return a.id!=excecao and a.vida>0 and pos(a)==p)
static func caminho(c: Dictionary,a: Dictionary,destino: Vector2i) -> Array:
	if not livre(c,destino,a.id): return []
	var inicio:=pos(a)
	var fila: Array=[inicio]
	var anterior:={inicio:inicio}
	while not fila.is_empty():
		var p: Vector2i=fila.pop_front()
		if p==destino: break
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var q: Vector2i=p+d
			if not anterior.has(q) and livre(c,q,a.id):
				anterior[q]=p
				fila.append(q)
	if not anterior.has(destino): return []
	var rota: Array=[]
	var p:=destino
	while p!=inicio:
		rota.push_front(p)
		p=anterior[p]
	return rota
static func linha_livre(c: Dictionary,a: Dictionary,b: Dictionary) -> bool:
	var p:=Vector2(pos(a))+Vector2.ONE*.5
	var fim:=Vector2(pos(b))+Vector2.ONE*.5
	# Amostragem densa de grade; cantos altos também bloqueiam tiros diagonais.
	var passos:=maxi(1,ceili(p.distance_to(fim)*12))
	for i in range(1,passos):
		var q:=Vector2i((p.lerp(fim,float(i)/passos)).floor())
		if contem(c.bloqueios,q): return false
	return true
static func cobertura(c: Dictionary,alvo: Dictionary) -> int:
	for v in c.coberturas:
		if pos(alvo).distance_to(Vector2i(v.x,v.z))<=1: return int(regras.tabuleiro.cobertura_baixa_bonus_defesa_distancia)
	return 0
static func pode_atacar(c: Dictionary,a: Dictionary,b: Dictionary) -> bool:
	return b.vida>0 and a.lado!=b.lado and distancia(a,b)<=int(a.alcance) and linha_livre(c,a,b)
static func agir(c: Dictionary,id: String,acao: String,alvo: String="",destino: Vector2i=Vector2i(-1,-1)) -> String:
	if c.is_empty() or c.resultado!="": return "O confronto já terminou."
	var a:=atual(c)
	if a.id!=id or a.vida<=0 or a.morto: return "Fora do turno ou personagem incapacitado."
	if acao=="passar":
		encerrar_turno(c)
		return ""
	var custo:=2 if acao=="fugir" else 1
	if acao not in ["mover","atacar","mirar","defender","proteger","fugir"]: return "Ação desconhecida."
	if int(a.pa)<custo: return "Pontos de ação insuficientes."
	var b:=ator(c,alvo)
	var rota: Array=[]
	match acao:
		"mover":
			rota=caminho(c,a,destino)
			if rota.is_empty() or rota.size()>int(a.movimento): return "Destino fora do alcance, ocupado ou bloqueado."
		"atacar":
			if a.atacou: return "Só um ataque por turno."
			if b.is_empty() or not pode_atacar(c,a,b): return "Alvo fora do alcance ou sem linha de tiro."
		"proteger":
			if b.is_empty() or b.lado!=a.lado or b.id==a.id or b.vida<=0 or distancia(a,b)!=1: return "Escolha aliado vivo adjacente."
	a.pa-=custo
	match acao:
		"mover":
			a.x=destino.x
			a.z=destino.y
			registrar(c,"%s moveu para %d,%d."%[a.nome,a.x,a.z])
		"mirar": a.mira=int(regras.turno.mirar.bonus_proximo_ataque)
		"defender": a.defesa_temp=int(regras.turno.defender.bonus_defesa)
		"proteger": a.protegendo=b.id
		"fugir":
			if a.lado=="animal":
				if int(a.x) not in [0,7] and int(a.z) not in [0,7]:
					a.pa+=custo
					return "O animal precisa alcançar uma borda."
				var percepcao:=0
				for h: Dictionary in vivos(c,"equipe"): percepcao=maxi(percepcao,h.percepcao)
				var roll:=dado(c)
				var dificuldade:=12+percepcao
				registrar(c,"%s · fuga D20 %d %+d contra %d"%[a.nome,roll,a.agilidade,dificuldade])
				if roll+a.agilidade>=dificuldade: finalizar(c,"animal_fugiu")
			else:
				var perigo: String=especie(c.animal).perigo
				var dificuldade:=12+int(regras.turno.retirada_equipe.acrescimo_por_perigo[perigo])
				var roll:=dado(c)
				var modificador: int=a.agilidade+a.treinamento
				registrar(c,"%s · retirada D20 %d %+d contra %d"%[a.nome,roll,modificador,dificuldade])
				if roll+modificador>=dificuldade: finalizar(c,"retirada")
		"atacar":
			a.atacou=true
			var roll:=dado(c)
			var modificador: int=a.atributo_ataque+a.treinamento+a.especializacao+a.precisao+a.mira
			var defesa: int=b.defesa+b.defesa_temp+(cobertura(c,b) if a.alcance>1 else 0)
			var acertou: bool=roll==20 or (roll!=1 and roll+modificador>=defesa)
			registrar(c,"%s → %s · D20 %d + atributo %d + treino %d + especialização %d + precisão %d + mira %d = %d contra defesa %d: %s"%[a.nome,b.nome,roll,a.atributo_ataque,a.treinamento,a.especializacao,a.precisao,a.mira,roll+modificador,defesa,"CRÍTICO" if roll==20 else ("acerto" if acertou else "erro")])
			a.mira=0
			if acertou:
				var protetores:=vivos(c,b.lado).filter(func(h): return h.protegendo==b.id and distancia(h,b)==1 and h.id!=b.id)
				if not protetores.is_empty():
					b=protetores[0]
					b.protegendo=""
					b.xp=mini(8,int(b.xp)+1)
					registrar(c,b.nome+" interceptou o ataque.")
				var partes: PackedStringArray=str(a.dano).split("d")
				var restantes:=partes[1].split("+")
				var bruto:=int(restantes[1]) if restantes.size()>1 else 0
				for i in range(int(partes[0])*(2 if roll==20 else 1)): bruto+=dado(c,int(restantes[0]))
				var dano:=maxi(0,bruto-int(b.armadura))
				b.vida=maxi(0,int(b.vida)-dano)
				c.dano_total+=dano
				registrar(c,"Dano %d − armadura %d = %d · %s: %d/%d HP"%[bruto,b.armadura,dano,b.nome,b.vida,b.vida_max])
			a.xp=mini(8,int(a.xp)+1)
	if verificar_fim(c): return ""
	if a.pa<=0: encerrar_turno(c)
	return ""
static func alvo_mais_proximo(c: Dictionary,a: Dictionary) -> Dictionary:
	var adversarios:=vivos(c,"animal" if a.lado=="equipe" else "equipe")
	adversarios.sort_custom(func(i,j):
		if distancia(a,i)!=distancia(a,j): return distancia(a,i)<distancia(a,j)
		return i.vida<j.vida)
	return adversarios[0] if not adversarios.is_empty() else {}
static func decisao(c: Dictionary) -> Dictionary:
	var a:=atual(c)
	if a.is_empty(): return {}
	var b:=alvo_mais_proximo(c,a)
	if b.is_empty(): return {"acao":"passar"}
	if a.lado=="equipe":
		var vida:=0.0
		var maxima:=0.0
		for h: Dictionary in c.atores:
			if h.lado=="equipe":
				vida+=h.vida
				maxima+=h.vida_max
		if maxima>0 and vida/maxima<.30 and a.pa>=2: return {"acao":"fugir"}
	else:
		var fugir: bool=c.animal=="capivara" or (c.animal=="anta" and a.vida>a.vida_max*.25)
		if fugir:
			if (int(a.x) in [0,7] or int(a.z) in [0,7]) and a.pa>=2: return {"acao":"fugir"}
			var melhor: Array=[]
			for i in range(8):
				for p in [Vector2i(0,i),Vector2i(7,i),Vector2i(i,0),Vector2i(i,7)]:
					var rota:=caminho(c,a,p)
					if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()): melhor=rota
			if not melhor.is_empty() and not a.atacou:
				var p: Vector2i=melhor[mini(int(a.movimento),melhor.size())-1]
				return {"acao":"mover","x":p.x,"z":p.y}
	if not a.atacou and pode_atacar(c,a,b):
		if a.pa>=2 and a.lado=="equipe" and a.mira==0: return {"acao":"mirar"}
		return {"acao":"atacar","alvo":b.id}
	if a.pa>0 and not a.atacou:
		var melhor: Array=[]
		for x in range(8):
			for z in range(8):
				var candidato:=a.duplicate()
				candidato.x=x
				candidato.z=z
				if not pode_atacar(c,candidato,b): continue
				var rota:=caminho(c,a,Vector2i(x,z))
				if not rota.is_empty() and (melhor.is_empty() or rota.size()<melhor.size()): melhor=rota
		if not melhor.is_empty():
			var p: Vector2i=melhor[mini(int(a.movimento),melhor.size())-1]
			return {"acao":"mover","x":p.x,"z":p.y}
	if a.lado=="equipe":
		for h: Dictionary in vivos(c,"equipe"):
			if h.id!=a.id and h.vida<h.vida_max*.5 and distancia(a,h)==1: return {"acao":"proteger","alvo":h.id}
	if a.defesa_temp==0: return {"acao":"defender"}
	return {"acao":"passar"}
static func agir_automatico(c: Dictionary) -> String:
	var d:=decisao(c)
	if d.is_empty(): return ""
	var id: String=atual(c).id
	var erro:=agir(c,id,d.acao,d.get("alvo",""),Vector2i(d.get("x",-1),d.get("z",-1)))
	if erro!="": encerrar_turno(c)
	return erro
static func resolver(c: Dictionary) -> void:
	for i in range(2000):
		if c.resultado!="": return
		agir_automatico(c)
	if c.resultado=="": finalizar(c,"impasse")

static func validar(c: Variant,numero: Callable) -> String:
	if not c is Dictionary or c.get("versao")!=1 or not c.get("animal") is String: return "Confronto inválido."
	if especie(c.animal).is_empty(): return "Animal desconhecido."
	if not c.get("rng") is String or not c.rng.is_valid_int() or str(int(c.rng))!=c.rng: return "Semente inválida."
	if c.get("resultado") not in RESULTADOS or not c.get("aplicado") is bool: return "Resultado inválido."
	if not c.get("atores") is Array or c.atores.size() not in [2,3] or not c.get("ordem") is Array or c.ordem.size()!=c.atores.size(): return "Participantes inválidos."
	for k in ["bloqueios","coberturas","aguas","registro"]:
		if not c.get(k) is Array: return "Tabuleiro inválido."
	for k in ["bloqueios","coberturas","aguas"]:
		for p in c[k]:
			if not p is Dictionary or not numero.call(p.get("x"),0,7,true) or not numero.call(p.get("z"),0,7,true): return "Obstáculo inválido."
	if c.registro.size()>80 or c.registro.any(func(m): return not m is String): return "Registro inválido."
	for k in ["rodada","cursor","dano_total","dano_inicio_rodada","rodadas_sem_dano"]:
		if not numero.call(c.get(k),0,1000000,true): return "Andamento inválido."
	if c.cursor>=c.ordem.size() or c.rodada<1: return "Turno inválido."
	var ids:={}
	for a in c.atores:
		if not a is Dictionary or not a.get("id") is String or ids.has(a.id) or not a.get("nome") is String or a.get("lado") not in ["equipe","animal"]: return "Ator inválido."
		ids[a.id]=true
		for k in ["x","z"]:
			if not numero.call(a.get(k),0,7,true): return "Posição inválida."
		for k in ["vida","vida_max","armadura","defesa","treinamento","precisao","movimento","pa","mira","defesa_temp","xp"]:
			if not numero.call(a.get(k),0,10000,true): return "Atributo de combate inválido."
		if a.vida>a.vida_max or a.vida_max<1 or a.pa>2 or a.xp>8 or not a.get("atacou") is bool or not a.get("morto") is bool or not a.get("protegendo") is String: return "Condição de combate inválida."
		for k in ["agilidade","percepcao","resistencia","atributo_ataque","especializacao"]:
			if not numero.call(a.get(k),-100,100,true): return "Modificador inválido."
		if a.get("equipamento") not in ["arco","lanca","natural"] or not a.get("dano") is String or not numero.call(a.get("alcance"),1,8,true) or not numero.call(a.get("iniciativa"),-100,200,true): return "Arma inválida."
		var re:=RegEx.new()
		re.compile("^[1-2]d[468](\\+[0-3])?$")
		if re.search(a.dano)==null: return "Dano inválido."
	for id in c.ordem:
		if not ids.has(id) or c.ordem.count(id)!=1: return "Fila de iniciativa inválida."
	if not ids.has("animal") or c.atores.filter(func(a): return a.lado=="animal").size()!=1: return "Animal inválido."
	for a: Dictionary in c.atores:
		if a.protegendo!="" and not ids.has(a.protegendo): return "Proteção inválida."
	if not c.get("recursos") is Dictionary or not c.get("sobrevivencia") is Dictionary: return "Recompensas inválidas."
	for r in c.recursos:
		if r not in ["carne","couro"] or not numero.call(c.recursos[r],0,100,true): return "Recurso de caça inválido."
	var esperados: Dictionary=especie(c.animal).recursos if c.resultado=="vitoria" else {}
	if esperados.size()!=c.recursos.size(): return "Recompensa incompatível com resultado."
	for r in esperados:
		if int(c.recursos.get(r,-1))!=int(esperados[r]): return "Quantidade de recompensa incompatível."
	if c.resultado=="" and (c.aplicado or atual(c).vida<=0 or atual(c).pa<=0): return "Turno ativo inválido."
	if c.resultado!="derrota" and not c.sobrevivencia.is_empty(): return "Sobrevivência fora de derrota."
	for id in c.sobrevivencia:
		var s: Variant=c.sobrevivencia[id]
		if not ids.has(id) or not s is Dictionary or not numero.call(s.get("d20"),1,20,true) or not numero.call(s.get("bonus"),-100,100,true) or not numero.call(s.get("dificuldade"),1,30,true) or not s.get("morto") is bool: return "Sobrevivência inválida."
	return ""
