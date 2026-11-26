extends RefCounted
## Medidas compartilhadas com a água renderizada por montar_cenario.gd.
const TAMANHOS:={"oca":Vector2(5.4,6.2),"coleta":Vector2(3.5,3.5),"agricultura":Vector2(6.2,7),"pesca":Vector2(4.9,4.4),"caca":Vector2(4.4,3.7)}
const ROCHAS:=[Vector2(-13,-8),Vector2(-17,-4),Vector2(-9,-12),Vector2(11,-9),Vector2(-12,10),Vector2(-12,-11),Vector2(-17,2)]

static func centro_rio(z: float) -> float:
	return 17+3.2*sin(-z*.075)+1.3*sin(-z*.17)
static func meia_largura_rio(z: float) -> float:
	return 4.4+.45*sin(-z*.12)
static func margem_rio(z: float) -> float:
	return centro_rio(z)-meia_largura_rio(z)
static func na_agua(p: Vector2) -> bool:
	return absf(p.x-centro_rio(p.y))<=meia_largura_rio(p.y) and absf(p.y)<=100
static func local(p: Vector2,centro: Vector2,angulo: float) -> Vector2:
	return (p-centro).rotated(angulo)
static func distancia_caixa(p: Vector2,centro: Vector2,metade: Vector2,angulo: float) -> float:
	var q:=local(p,centro,angulo)
	return q.distance_to(q.clamp(-metade,metade))
static func cantos(p: Vector2,metade: Vector2,a: float) -> Array[Vector2]:
	var lista: Array[Vector2]=[]
	for x in [-1,1]:
		for z in [-1,1]: lista.append(p+Vector2(x*metade.x,z*metade.y).rotated(-a))
	return lista
static func sobrepoe(p: Vector2,m: Vector2,a: float,q: Vector2,n: Vector2,b: float,folga: float=.15) -> bool:
	for eixo in [Vector2.RIGHT.rotated(-a),Vector2.DOWN.rotated(-a),Vector2.RIGHT.rotated(-b),Vector2.DOWN.rotated(-b)]:
		var r: float=absf(eixo.dot(Vector2.RIGHT.rotated(-a)))*m.x+absf(eixo.dot(Vector2.DOWN.rotated(-a)))*m.y
		r+=absf(eixo.dot(Vector2.RIGHT.rotated(-b)))*n.x+absf(eixo.dot(Vector2.DOWN.rotated(-b)))*n.y
		if absf((q-p).dot(eixo))>=r+folga: return false
	return true
static func distancia_agua(p: Vector2,m: Vector2,a: float) -> float:
	var distancia:=INF
	# A amostragem usa os mesmos segmentos de meio metro da malha do rio.
	var inicio:=floori((p.y-m.length()-3)*2)
	var fim:=ceili((p.y+m.length()+3)*2)
	for i in range(inicio,fim+1):
		var z:=float(i)*.5
		distancia=minf(distancia,distancia_caixa(Vector2(margem_rio(z),z),p,m,a))
	return distancia
static func terreno(p: Vector2,m: Vector2,a: float) -> bool:
	for c in cantos(p,m,a):
		if c.length()>17.8: return false
	# Verifica o interior e as bordas, inclusive junto às curvas do rio.
	for i in range(ceili(m.x*4)+1):
		for j in range(ceili(m.y*4)+1):
			var u:=Vector2(lerpf(-m.x,m.x,float(i)/ceili(m.x*4)),lerpf(-m.y,m.y,float(j)/ceili(m.y*4)))
			var c:=p+u.rotated(-a)
			if c.x>margem_rio(c.y)-.20: return false
	if distancia_caixa(Vector2.ZERO,p,m,a)<1.9: return false
	for rocha in ROCHAS:
		if distancia_caixa(rocha,p,m,a)<1.5: return false
	return true
