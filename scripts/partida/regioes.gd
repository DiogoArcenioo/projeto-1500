extends RefCounted
## Definições do território fictício. Conhecimento pertence à partida.
const TAMANHO:=Vector2(2400,1600)
const SEMENTE:=1506
const Caca=preload("res://scripts/partida/caca.gd")
const NOMES:=["Serra distante","Alto da mata","Cabeceiras","Cachoeiras","Mata do nascente","Costa distante",
	"Encosta oeste","Bosque alto","Riacho","Curva do norte","Mata úmida","Restinga distante",
	"Colinas","Mata aberta","Arredores","Margem alta","Palmeiral","Baixada",
	"Mata fechada","Bosque sul","Aldeia","Margem do rio","Campo de pedras","Mata costeira",
	"Ravinas","Vale sombreado","Clareiras","Curva do sul","Lagoas","Bosque leste"]
static var _definicoes: Array[Dictionary]=[]

static func iniciais() -> Dictionary:
	var dados:={}
	for i in range(30): dados[str(i)]=2 if i in [14,20,21] else 0
	return dados

static func definicoes() -> Array[Dictionary]:
	if not _definicoes.is_empty(): return _definicoes
	var rng:=RandomNumberGenerator.new()
	rng.seed=SEMENTE
	for j in range(5):
		for i in range(6):
			var id:=j*6+i
			var pos:=Vector2((i+.5+rng.randf_range(-.16,.16))/6,(j+.5+rng.randf_range(-.16,.16))/5)
			if id==20: pos=Vector2(.38,.62)
			if id==14: pos=Vector2(.40,.47)
			if id==21: pos=Vector2(.58,.61)
			var recursos: Array=["madeira","fibras_vegetais","vegetais"]
			if id in [3,8,9,15,21,27,28]: recursos=["fibras_vegetais","plantas_medicinais","peixe"]
			if id in [0,6,12,22,24]: recursos=["madeira","pedra","fibras_vegetais"]
			_definicoes.append({"id":id,"nome":NOMES[id],"pos":pos*TAMANHO,"conhecida":id in [14,20,21],
				"recursos":recursos,"abundancia":75,"perigo":0 if id in [14,20,21] else 1,
				"animais":Caca.fauna(id),"vizinhas":[]})
	for r: Dictionary in _definicoes:
		var poly:=PackedVector2Array([Vector2.ZERO,Vector2(TAMANHO.x,0),TAMANHO,Vector2(0,TAMANHO.y)])
		for outra: Dictionary in _definicoes:
			if outra.id==r.id: continue
			poly=recortar(poly,(outra.pos+r.pos)*.5,(outra.pos-r.pos).normalized())
		r.poligono=poly
	for r: Dictionary in _definicoes:
		for outra: Dictionary in _definicoes:
			if r.id==outra.id: continue
			var comuns:=0
			for p: Vector2 in r.poligono:
				for q: Vector2 in outra.poligono:
					if p.distance_squared_to(q)<.01: comuns+=1
			if comuns>=2: r.vizinhas.append(outra.id)
	return _definicoes

static func recortar(poly: PackedVector2Array,meio: Vector2,normal: Vector2) -> PackedVector2Array:
	var saida:=PackedVector2Array()
	for i in range(poly.size()):
		var a:=poly[i]
		var b:=poly[(i+1)%poly.size()]
		var da: float=(a-meio).dot(normal)
		var db: float=(b-meio).dot(normal)
		if da<=0: saida.append(a)
		if (da<0 and db>0) or (da>0 and db<0): saida.append(a.lerp(b,da/(da-db)))
	return saida

static func fronteira(indice: int,conhecimento: Dictionary) -> bool:
	for vizinha in definicoes()[indice].vizinhas:
		if int(conhecimento[str(vizinha)])>0: return true
	return false

static func viagem(indice: int,conhecimento: Dictionary) -> float:
	var dist:={20:0.0}
	var visitadas:={}
	var defs:=definicoes()
	while visitadas.size()<defs.size():
		var atual:=-1
		var menor:=INF
		for id in dist:
			if not visitadas.has(id) and dist[id]<menor:
				menor=dist[id]
				atual=id
		if atual<0: return -1
		if atual==indice: return maxf(20,menor)
		visitadas[atual]=true
		for vizinho in defs[atual].vizinhas:
			if vizinho!=indice and int(conhecimento[str(vizinho)])==0: continue
			var custo: float=defs[atual].pos.distance_to(defs[vizinho].pos)*.10
			dist[vizinho]=minf(float(dist.get(vizinho,INF)),menor+custo)
	return -1

static func revelar(conhecimento: Dictionary,indice: int,pontos: int) -> void:
	conhecimento[str(indice)]=clampi(int(conhecimento[str(indice)])+pontos,0,3)

static func informacoes(indice: int,conhecimento: Dictionary) -> String:
	var nivel:=int(conhecimento[str(indice)])
	if nivel==0: return "Desconhecido\nOs detalhes dependem de reconhecimento."
	var r: Dictionary=definicoes()[indice]
	var linhas: Array[String]=[r.nome,"Conhecimento · %d/3"%nivel]
	if indice==20: return "\n".join(linhas+["Ponto de partida da comunidade."])
	var tempo:=viagem(indice,conhecimento)
	linhas.append("Viagem de ida · %d s a 1×"%ceili(tempo))
	if nivel>=2:
		var nomes:={"madeira":"madeira","pedra":"pedra","fibras_vegetais":"fibras","vegetais":"vegetais","plantas_medicinais":"plantas medicinais","peixe":"peixes"}
		var tipos: Array[String]=[]
		for recurso in r.recursos: tipos.append(nomes[recurso])
		linhas.append("Recursos · "+", ".join(tipos))
		linhas.append("Abundância · %d%%"%r.abundancia)
		linhas.append("Perigo · "+("Baixo" if r.perigo==0 else "Pouco conhecido"))
	else:
		linhas.append("Recursos, abundância e perigo por investigar.")
	linhas.append("Animais · "+", ".join(r.animais.map(Caca.Combate.nome_animal)) if nivel>=3 else "Animais · Não investigados")
	return "\n".join(linhas)

static func sortear(indice: int,atividade: String,rng: RandomNumberGenerator) -> Dictionary:
	var r: Dictionary=definicoes()[indice]
	var peso_rastros:=10+int(r.perigo)*5
	var dado:=rng.randi_range(1,100)
	if dado<=peso_rastros:
		return {"tipo":"rastros","texto":"Rastros não identificados.","recursos":{}}
	if atividade=="reconhecimento":
		return {"tipo":"observacao","texto":"Terreno reconhecido.","recursos":{}}
	var elegiveis: Array=[]
	for recurso in r.recursos:
		if recurso in ["madeira","fibras_vegetais","vegetais","plantas_medicinais"]: elegiveis.append(recurso)
	if dado>90 or elegiveis.is_empty():
		return {"tipo":"caminho","texto":"A equipe prosseguiu pela região.","recursos":{}}
	var recurso: String=elegiveis[rng.randi_range(0,elegiveis.size()-1)]
	var quantidade:=rng.randi_range(1,3)
	return {"tipo":"coleta","texto":"%d %s encontrados."%[quantidade,recurso.replace("_"," ")],"recursos":{recurso:quantidade}}
