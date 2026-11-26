extends RefCounted
## Etapa 12 — pesca: espécies, sorteio, mordida, física da briga, registro e economia.
## Regras puras e determinísticas (o gerador aleatório vem de fora). A cena manual, a
## pescaria simulada e os testes usam as mesmas funções; nada aqui toca nós da cena.
##
## Briga: o peixe tem força (puxada), fôlego e um comportamento que alterna modos
## (nadar, corrida, sacudida, salto, fundo, cansado). Segurar = puxar a linha;
## soltar = ceder. Tensão acima do limite desgasta a linha até romper; linha frouxa
## por tempo demais deixa o anzol escapar. Puxar a vara para o lado contrário ao do
## peixe o cansa mais depressa. No salto é preciso ceder, ou ele cospe o anzol.
static var dados: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/configuracoes/pesca.json"))
const MODOS:=["nadar","corrida","sacudida","salto","fundo","cansado"]
## Distância (m) da ponta da vara em que o peixe já pode ser tirado da água.
const MARGEM:=1.7
const SALTO_SUBIDA:=.55
const SALTO_AR:=.7

static func especie(id: String) -> Dictionary:
	return dados.especies.get(id,{})

static func nome(id: String) -> String:
	return especie(id).get("nome",id)

static func habitat(regiao: int) -> String:
	return dados.regioes.get(str(regiao),"rio")

static func fauna(regiao: int) -> Dictionary:
	return dados.habitats[habitat(regiao)]

## 0 (lambari mínimo) a 1 (camurupim máximo): escala de todos os sinais de tamanho.
static func porte(peso: float) -> float:
	return clampf((log(maxf(peso,.01))/log(10.0)+1.7)/3.35,0.0,1.0)

## Experiência de pesca (XP) → 0..1: janela de fisgada maior e linha mais tolerante.
static func habilidade(xp: int) -> float:
	return clampf(xp/250.0,0.0,1.0)

static func lances(integrantes: int) -> int:
	return int(dados.lances_base)+int(dados.lances_por_integrante)*integrantes

static func unidades(kg: float) -> int:
	return 0 if kg<=0 else maxi(1,roundi(kg/float(dados.kg_por_unidade)))

static func formatar_peso(kg: float) -> String:
	return ("%d g"%roundi(kg*1000)) if kg<1.0 else ("%.2f kg"%kg).replace(".",",")

## Sorteio do peixe que vem à isca: espécie pela raridade do habitat, exemplares
## pequenos comuns e grandes raros.
static func sortear(regiao: int,rng: RandomNumberGenerator) -> Dictionary:
	var tabela:=fauna(regiao)
	var total:=0.0
	for k in tabela: total+=float(tabela[k])
	var r:=rng.randf()*total
	var escolhido: String=tabela.keys()[0]
	for k: String in tabela:
		r-=float(tabela[k])
		if r<=0:
			escolhido=k
			break
	var esp:=especie(escolhido)
	var u:=pow(rng.randf(),2.3)
	var peso:=maxf(.01,snappedf(lerpf(esp.peso[0],esp.peso[1],u),.01))
	return {"especie":escolhido,"peso":peso,"comprimento":snappedf(lerpf(esp.comprimento[0],esp.comprimento[1],pow(u,.45)),.01),"tamanho":u}

# ------------------------------------------------------------------ mordida

## Sinais na boia até a mordida de verdade. Cada espécie "fala" de um jeito e a força
## dos sinais cresce com o tamanho: o jogador sente o peixe antes de fisgar.
static func mordida(peixe: Dictionary,hab: float,rng: RandomNumberGenerator) -> Dictionary:
	var esp:=especie(peixe.especie)
	var p:=porte(peixe.peso)
	var eventos: Array=[]
	var t:=rng.randf_range(2.6,7.0)*(1.0-.25*hab)
	var janela:=.45
	var forte:="afundar"
	match esp.comportamento:
		"beliscador":
			for i in rng.randi_range(2,5):
				eventos.append({"t":t,"tipo":"toque","forca":.2+.25*p})
				t+=rng.randf_range(.17,.42)
			janela=.34
		"ladrao":
			for i in rng.randi_range(1,3):
				eventos.append({"t":t,"tipo":"toque","forca":.3+.3*p})
				t+=rng.randf_range(.4,.8)
			forte="puxao"
			janela=.36
		"teimoso":
			for i in rng.randi_range(1,2):
				eventos.append({"t":t,"tipo":"toque","forca":.35+.3*p})
				t+=rng.randf_range(.5,1.0)
			janela=.55
		"emboscada":
			if rng.randf()<.6:
				eventos.append({"t":t,"tipo":"tremor","forca":.2})
				t+=rng.randf_range(1.2,2.6)
			janela=.62
		"fundo":
			for i in rng.randi_range(1,2):
				eventos.append({"t":t,"tipo":"toque","forca":.25+.3*p})
				t+=rng.randf_range(.8,1.4)
			forte="arrasto"
			janela=.95
		"corredor":
			eventos.append({"t":t,"tipo":"toque","forca":.3+.3*p})
			t+=rng.randf_range(.5,1.0)
			forte="corrida"
			janela=.58
		"saltador":
			eventos.append({"t":t,"tipo":"rodada","forca":.6+.4*p})
			t+=rng.randf_range(.9,1.6)
			janela=.5
	eventos.append({"t":t,"tipo":forte,"forca":.55+.45*p})
	janela+=.22*hab
	return {"eventos":eventos,"inicio":t,"janela":janela,"comportamento":esp.comportamento}

## Puxar a vara no instante t (s desde que a isca assentou).
static func fisgar(m: Dictionary,t: float) -> Dictionary:
	if t<float(m.inicio)-.06: return {"resultado":"cedo"}
	if t>float(m.inicio)+float(m.janela): return {"resultado":"tarde"}
	var ideal: float=m.inicio+m.janela*.3
	var firmeza:=1.0-clampf(absf(t-ideal)/(float(m.janela)*.8),0.0,1.0)*.45
	return {"resultado":"fisgou","firmeza":firmeza}

## Puxar cedo demais assusta o peixe (os beliscadores insistem mais).
static func assustou(m: Dictionary,rng: RandomNumberGenerator) -> bool:
	return rng.randf()<(.3 if m.comportamento=="beliscador" else .55)

## Beliscador e teimoso voltam uma vez à isca depois de uma fisgada perdida.
static func insiste(m: Dictionary,tentativa: int) -> bool:
	return tentativa<1 and m.comportamento in ["beliscador","teimoso"]

# ------------------------------------------------------------------ briga

static func criar_briga(peixe: Dictionary,firmeza: float,hab: float,distancia: float,rng: RandomNumberGenerator) -> Dictionary:
	var esp:=especie(peixe.especie)
	var peso: float=peixe.peso
	var b:={"especie":peixe.especie,"peso":peso,"porte":porte(peso),"comportamento":esp.comportamento,
		"forca":float(esp.forca)*sqrt(peso),"agil":float(esp.agilidade),
		"capacidade":float(esp.resistencia)*6.0*(.5+pow(peso,.6)),"folego":1.0,"firmeza":firmeza,"habilidade":hab,
		"pos":Vector2(rng.randf_range(-.6,.6),maxf(distancia,MARGEM+.5)),"vel":Vector2.ZERO,
		"dir":Vector2(rng.randf_range(-.7,.7),1.0).normalized(),"linha":maxf(distancia,MARGEM+.5)+.05,
		"tensao":0.0,"dano":0.0,"folga":0.0,"risco":0.0,"pousar":0.0,"profundidade":.4,
		"modo":"nadar","tempo_modo":0.0,"fase_modo":0.0,"tempo":0.0,"no_ar":false,
		"resultado":"","motivo":"","evento":"fisgado"}
	# Os grandes saem na primeira corrida; os pequenos se debatem.
	definir_modo(b,"corrida" if b.porte>.45 else "sacudida",rng)
	return b

static func resistencia_linha(b: Dictionary) -> float:
	return float(dados.linha.resistencia)+float(dados.linha.resistencia_maxima_bonus)*float(b.habilidade)

static func definir_modo(b: Dictionary,modo: String,rng: RandomNumberGenerator) -> void:
	b.modo=modo
	b.fase_modo=0.0
	b.evento=modo
	match modo:
		"nadar": b.tempo_modo=rng.randf_range(1.0,2.4)
		"corrida":
			b.tempo_modo=rng.randf_range(1.0,2.4)*(.7+1.2*b.porte)
			b.dir=Vector2(rng.randf_range(-.9,.9),1.0).normalized()
		"sacudida": b.tempo_modo=rng.randf_range(.7,1.5)
		"salto": b.tempo_modo=SALTO_SUBIDA+SALTO_AR+.25
		"fundo":
			b.tempo_modo=rng.randf_range(1.8,3.5)
			b.dir=Vector2(rng.randf_range(-.3,.3),1.0).normalized()
		"cansado": b.tempo_modo=rng.randf_range(1.5,3.0)

static func trocar_modo(b: Dictionary,rng: RandomNumberGenerator) -> void:
	var c: String=b.comportamento
	var f: float=b.folego
	if f<.18:
		definir_modo(b,"cansado",rng)
		return
	var pesos:={"nadar":3.0,"corrida":(3.2 if c=="corredor" else 1.2)*f,
		"sacudida":3.0 if c in ["teimoso","emboscada","beliscador"] else 1.0,
		"salto":(2.6*f if c=="saltador" else (.35*f if c=="corredor" else 0.0)),
		"fundo":3.2 if c=="fundo" else .3}
	var total:=0.0
	for k in pesos: total+=pesos[k]
	var r:=rng.randf()*total
	for k: String in pesos:
		r-=pesos[k]
		if r<=0:
			definir_modo(b,k,rng)
			return
	definir_modo(b,"nadar",rng)

## Um passo da física. puxar: botão segurado. lado: -1..1, para onde a vara aponta.
static func passo(b: Dictionary,puxar: bool,lado: float,dt: float,rng: RandomNumberGenerator) -> void:
	if b.resultado!="" or dt<=0: return
	b.tempo+=dt
	b.evento=""
	var jog: Dictionary=dados.pescador
	var maximo: float=dados.linha.comprimento_maximo
	b.tempo_modo-=dt
	b.fase_modo+=dt
	var distancia: float=b.pos.length()
	# Perto da margem com fôlego, o peixe dispara para longe.
	if distancia<MARGEM+.6 and b.folego>.3 and b.modo!="corrida": definir_modo(b,"corrida",rng)
	elif b.tempo_modo<=0: trocar_modo(b,rng)
	var mult: float=1.0
	match b.modo:
		"nadar": mult=.55
		"corrida": mult=1.9
		"sacudida": mult=.6+.7*absf(sin(b.fase_modo*(13.0+9.0*b.agil)))
		"salto": mult=.8 if b.fase_modo<SALTO_SUBIDA else .45
		"fundo": mult=1.1
		"cansado": mult=.22
	var vigor: float=.3+.7*float(b.folego)
	b.no_ar=b.modo=="salto" and b.fase_modo>=SALTO_SUBIDA and b.fase_modo<SALTO_SUBIDA+SALTO_AR
	# Direção: vagueia com a agilidade e tende a fugir da margem enquanto tem força.
	b.dir=(b.dir as Vector2).rotated(rng.randf_range(-1.0,1.0)*b.agil*2.4*dt)
	if b.modo!="cansado" and b.dir.y<.15: b.dir=(b.dir+Vector2(0,3.0*dt)).normalized()
	if b.modo=="cansado": b.dir=(b.dir+(-b.pos.normalized())*1.5*dt).normalized()
	var empuxo: Vector2=b.dir*b.forca*mult*vigor
	var u: Vector2=b.pos/maxf(distancia,.01)
	var a_favor: float=maxf(0.0,empuxo.dot(u))
	# Velocidade: agilidade e modo, quase independente do peso.
	var veloc: float=(.45+.85*mult)*(.6+.8*b.agil)*vigor
	b.vel=(b.vel as Vector2).lerp(b.dir*veloc,1.0-exp(-dt*(2.0+3.0*b.agil)))
	b.pos+=b.vel*dt
	b.pos.y=maxf(b.pos.y,.6)
	# Outra margem: o peixe vira e corre ao longo do rio.
	var limite: float=b.get("limite",1e9)
	if b.pos.y>limite:
		b.pos.y=limite
		b.vel.y=minf(b.vel.y,0.0)
		if b.dir.y>0: b.dir=Vector2(signf(b.dir.x) if absf(b.dir.x)>.05 else 1.0,-.2).normalized()
	distancia=b.pos.length()
	var esticada: bool=distancia>=b.linha-.05
	var forca_jog: float=float(jog.forca)*(1.0+.25*b.habilidade)
	var tensao: float=0.0
	if puxar:
		if esticada:
			tensao=sqrt(a_favor*a_favor+forca_jog*forca_jog)+.05
			var saldo: float=forca_jog-a_favor
			if saldo>0: b.linha-=saldo*float(jog.recolher)*(.35 if b.modo=="fundo" else 1.0)*dt
			else: b.linha+=-saldo*float(jog.dar_linha)*.45*dt
		else:
			b.linha-=float(jog.folga_recolher)*dt
	else:
		# Ceder: a linha corre pelos dedos com atrito; o peixe leva o que quiser.
		# A linha arrasta na água mesmo quando o peixe corre de lado.
		if esticada: tensao=minf(maxf(a_favor*.42+.03,.05+.06*(b.vel as Vector2).length()),.8)
		b.linha=maxf(b.linha,distancia)
	if b.linha>=maximo:
		b.linha=maximo
		if esticada: tensao=maxf(tensao,a_favor*1.15+.1)
	b.linha=maxf(b.linha,.4)
	if distancia>b.linha:
		b.pos=u*b.linha
		var radial: float=(b.vel as Vector2).dot(u)
		if radial>0: b.vel-=u*radial
	# A linha de fibra estica: a tensão sobe em ~0,15 s e dá tempo de reagir.
	b.tensao=lerpf(float(b.tensao),tensao/resistencia_linha(b),1.0-exp(-dt*7.0))
	# Fôlego: trabalhar contra a tensão cansa; vara do lado oposto cansa mais.
	var lado_fator: float=1.0
	if absf(b.dir.x)>.2: lado_fator=1.0+.6*clampf(-lado*signf(b.dir.x),-1.0,1.0)
	var esforco: float=clampf(b.tensao,0.0,1.3)
	b.folego=clampf(b.folego-dt*(.12+1.05*esforco*lado_fator)/b.capacidade+(dt*.05/b.capacidade if b.tensao<.08 else 0.0),0.0,1.0)
	# Desgaste da linha.
	if b.tensao>1.0: b.dano+=((b.tensao-1.0)*3.0+.6)*dt
	else: b.dano=maxf(0.0,b.dano-.3*dt)
	if b.comportamento=="emboscada" and b.modo=="sacudida" and b.tensao>.5: b.dano+=.12*dt
	if b.dano>=1.0:
		b.resultado="linha_rompeu"
		b.motivo="A linha arrebentou."
		return
	# Salto: com a linha tensa no ar o peixe cospe o anzol.
	if b.no_ar and b.tensao>.45:
		b.risco+=(b.tensao-.45)*5.0*dt
		if b.risco>b.firmeza*.55:
			b.resultado="escapou"
			b.motivo="Cuspiu o anzol no salto."
			return
	elif not b.no_ar: b.risco=maxf(0.0,b.risco-.4*dt)
	# Linha frouxa.
	if b.tensao<.07: b.folga+=dt*(1.6 if b.modo in ["sacudida","salto"] else 1.0)
	else: b.folga=maxf(0.0,b.folga-2.0*dt)
	if b.folga>1.7*b.firmeza+.4*b.habilidade:
		b.resultado="escapou"
		b.motivo="A linha afrouxou e o anzol soltou."
		return
	# Profundidade para a apresentação (negativa = fora da água).
	var alvo_prof: float={"nadar":.26,"corrida":.3,"sacudida":.06,"salto":.05,"fundo":1.2,"cansado":.02}[b.modo]
	b.profundidade=lerpf(b.profundidade,alvo_prof,1.0-exp(-dt*2.5))
	# Tirar da água.
	if distancia<MARGEM and b.folego<.3:
		b.evento="margem"
		if puxar and b.tensao<.95: b.pousar+=dt
		else: b.pousar=maxf(0.0,b.pousar-dt*.5)
		if b.pousar>=.9:
			b.resultado="capturado"
			b.motivo="Peixe fora da água!"

# ------------------------------------------------------------------ registro

## Registro de espécies da partida: quantidade e maior exemplar de cada uma.
## Devolve true quando o exemplar é recorde da espécie.
static func registrar(estado,peixe: Dictionary,pescador: String) -> bool:
	var r: Dictionary=estado.registro_pesca.get(peixe.especie,{"quantidade":0,"maior":0.0,"pescador":""})
	r.quantidade=int(r.quantidade)+1
	var recorde: bool=float(peixe.peso)>float(r.maior)
	if recorde:
		r.maior=float(peixe.peso)
		r.pescador=pescador
	estado.registro_pesca[peixe.especie]=r
	return recorde

static func validar_registro(registro: Variant,numero: Callable) -> String:
	if not registro is Dictionary: return "Registro de pesca inválido."
	for k in registro:
		var r: Variant=registro[k]
		if not k is String or especie(k).is_empty() or not r is Dictionary: return "Espécie de peixe inválida."
		if not numero.call(r.get("quantidade"),1,1000000,true) or not numero.call(r.get("maior"),0,1000) or not r.get("pescador") is String:
			return "Registro de pesca inválido."
	return ""
