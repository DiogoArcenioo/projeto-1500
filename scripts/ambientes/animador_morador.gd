extends RefCounted
## Anima um morador da aldeia (assets/models/habitantes/aldeia/<visual>.glb).
## O relógio da partida comanda a animação (avancar): pausa e 2x/3x valem também aqui.
## Cada ofício mostra a sua ferramenta (nós Prop_* presos aos ossos); as demais ficam ocultas.
## Clipes e ferramentas são gerados por tools/animar_moradores.py.

const LACOS := ["parado","olhar","conversar","coletar","capinar","plantar","pescar","artesanato","construir","andar"]
const FERRAMENTA := {"capinar":"Prop_Pau","pescar":"Prop_Lanca","construir":"Prop_Macete",
	"artesanato":"Prop_Flecha","coletar":"Prop_Cesto"}
const ARQUIVO_VELOCIDADES := "res://assets/models/habitantes/aldeia/animacao.json"
static var velocidades: Dictionary = {}

var jogador: AnimationPlayer
var props: Dictionary = {}
var atual := ""
## Metros por segundo em que os pés do clipe "andar" não escorregam.
var velocidade_andar := 1.0

static func caminho(visual: String) -> String:
	return "res://assets/models/habitantes/aldeia/%s.glb"%visual

func _init(modelo: Node3D, visual: String) -> void:
	if velocidades.is_empty() and FileAccess.file_exists(ARQUIVO_VELOCIDADES):
		var lido: Variant=JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO_VELOCIDADES))
		if lido is Dictionary: velocidades=lido
	velocidade_andar=float(velocidades.get(visual,{}).get("andar",1.0))
	var lista: Array[Node]=modelo.find_children("*","AnimationPlayer",true,false)
	if lista.is_empty(): return
	jogador=lista[0]
	jogador.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for nome: String in jogador.get_animation_list():
		if nome in LACOS: jogador.get_animation(nome).loop_mode=Animation.LOOP_LINEAR
	# O Blender numera nomes repetidos entre personagens (Prop_Pau_001): vale o prefixo.
	for no: Node in modelo.find_children("Prop_*","Node3D",true,false):
		for ferramenta: String in FERRAMENTA.values():
			if String(no.name).begins_with(ferramenta): props[ferramenta]=no
		(no as Node3D).visible=false

func tem(clipe: String) -> bool:
	return jogador!=null and jogador.has_animation(clipe)

## Troca de clipe com mistura (segundos); 'desencontro' começa o laço num ponto
## qualquer para que vizinhos não se movam em sincronia.
func tocar(clipe: String,mistura:=.35,desencontro:=-1.0) -> void:
	if clipe==atual or not tem(clipe): return
	atual=clipe
	jogador.play(clipe,mistura)
	if desencontro>=0: jogador.seek(fmod(desencontro,jogador.current_animation_length),true)
	for nome: String in props: props[nome].visible=FERRAMENTA.get(clipe,"")==nome

func avancar(segundos: float) -> void:
	if jogador: jogador.advance(segundos)
