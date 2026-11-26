extends "res://scripts/ui/menu_expedicao_casca.gd"
signal enviar_solicitado(centro: String,tipo: String,regiao: int,equipe: Array)
signal retorno_solicitado(id: String)
signal fechar_solicitado
signal regiao_apontada(indice: int)
signal hud_alternado(visivel: bool)
signal gerenciar_solicitado(centro: String)
const FASES:={"preparacao":"Preparando","ida":"Viajando","exploracao":"Explorando","alerta":"Alerta de perigo","confronto":"Confronto simulado","retorno":"Retornando","aguardando_descarga":"Aguardando espaço no estoque","concluida":"Concluída"}
const NOMES_POLITICA:={"prudente":"Prudente · recua cedo","equilibrada":"Equilibrada","agressiva":"Agressiva · só recua no limite"}
var aberto:=false
var centro:=""
var tela_atual:="preparar"
var escala_usuario:=1.0
var assinatura:=""
var _tempo:=0.0
var corpo: VBoxContainer
var rolagem: ScrollContainer
var seletor_centro: OptionButton
var seletor_tipo: OptionButton
var confirmar: Button
var linhas: Dictionary={}
var aviso_texto:=""
var origem_contextual:=false
var modo_caca:="simulado"
## Etapa 11: política da equipe para a simulação de encontros ("" = padrão da atividade).
var politica:=""
func _ready() -> void:
	previa=false
	super._ready()
	hide()
func reiniciar(novo) -> void:
	estado=novo
	equipe.clear()
	armas.clear()
	centro=""
	aberto=false
	hide()
func abrir(novo,origem: String="",destino: int=-1) -> void:
	modo_caca="simulado"
	politica=""
	estado=novo
	equipe.clear()
	armas.clear()
	equipando=""
	aviso_texto=""
	origem_contextual=origem!=""
	if origem!="": centro=origem
	if estado.estrutura(centro).is_empty():
		centro=""
		for c: Dictionary in estado.construcoes:
			if c.pronta and c.tipo in ["coleta","pesca","caca"]:
				centro=c.id
				break
	if destino>=0 and int(estado.conhecimento[str(destino)])<2:
		centro=""
		for estrutura: Dictionary in estado.construcoes:
			if estrutura.pronta and estrutura.tipo=="coleta":
				centro=estrutura.id
				break
	var c: Dictionary=estado.estrutura(centro)
	tipo=c.get("tipo","coleta")
	if destino>=0:
		regiao=destino
		if int(estado.conhecimento[str(destino)])<2 and tipo=="coleta": tipo="reconhecimento"
	elif tipo=="pesca": regiao=21
	else: regiao=14
	aberto=true
	show()
	compacto()
func seletor(p: Node) -> OptionButton:
	var b:=OptionButton.new()
	b.add_theme_font_override("font",FONTE_TEXTO)
	b.add_theme_font_size_override("font_size",18)
	b.add_theme_color_override("font_color",Color("35271b"))
	b.custom_minimum_size.y=32
	b.clip_text=true
	Casca.margens(b,12,4)
	p.add_child(b)
	return b
func compacto() -> void:
	for n in mini.get_children():
		mini.remove_child(n)
		n.queue_free()
	var col:=VBoxContainer.new()
	col.add_theme_constant_override("separation",6)
	mini.add_child(col)
	var topo:=HBoxContainer.new()
	col.add_child(topo)
	titulo_mini=texto(topo,estado.NOMES_CONSTRUCOES.get(tipo,"Expedições") if origem_contextual else "Expedições",21)
	titulo_mini.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var fechar:=botao(topo,"×",func(): fechar_solicitado.emit())
	fechar.custom_minimum_size=Vector2(26,28)
	seletor_centro=seletor(col)
	seletor_centro.visible=not origem_contextual
	for c: Dictionary in estado.construcoes:
		if c.pronta and c.tipo in ["caca","pesca","coleta"]:
			seletor_centro.add_item(estado.NOMES_CONSTRUCOES[c.tipo]+" "+str(c.id).get_slice("_",1))
			seletor_centro.set_item_metadata(seletor_centro.item_count-1,c.id)
			if c.id==centro: seletor_centro.select(seletor_centro.item_count-1)
	seletor_centro.item_selected.connect(func(i: int):
		abrir(estado,seletor_centro.get_item_metadata(i)))
	botao_abrir=botao(col,{"caca":"Caçar","pesca":"Pescar","coleta":"Enviar expedição","reconhecimento":"Enviar expedição"}[tipo],func(): mostrar_passo(1),true)
	botao_abrir.disabled=centro==""
	if centro=="": texto(col,"Construa um centro primeiro.",16)
	botao(col,"Acompanhar",func(): mostrar_passo(4))
	if centro!="": botao(col,"Gerenciar",func(): gerenciar_solicitado.emit(centro))
	mostrar_passo(0)
func habilidade() -> String:
	return {"caca":"Caça","pesca":"Pesca","coleta":"Coleta","reconhecimento":"Total"}[tipo]
func disponivel(h: Dictionary) -> bool:
	return not h.is_empty() and h.estado in ["livre","trabalhando"] and h.saude>0 and (h.setor=="" or h.setor==centro) and Exp.Caca.Saude.impedimento_expedicao(h)==""
func mostrar_passo(passo: int) -> void:
	if not is_instance_valid(conteudo): return
	equipe=equipe.filter(func(id): return disponivel(estado.pessoa(id)))
	if passo in [2,3] and equipe.is_empty(): passo=1
	etapa=passo
	tela_atual="acompanhar" if passo==4 else "preparar"
	cards.clear()
	linhas.clear()
	mini.visible=passo==0
	quadro.visible=passo>0
	for c in conteudo.get_children():
		conteudo.remove_child(c)
		c.queue_free()
	if passo>0:
		cabecalho()
		mensagem=texto(conteudo,aviso_texto,16,"7b3523")
		mensagem.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		mensagem.visible=aviso_texto!=""
		rolagem=ScrollContainer.new()
		rolagem.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		rolagem.size_flags_vertical=Control.SIZE_EXPAND_FILL
		rolagem.custom_minimum_size.y=285
		conteudo.add_child(rolagem)
		corpo=VBoxContainer.new()
		corpo.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		corpo.add_theme_constant_override("separation",5)
		rolagem.add_child(corpo)
		var externo:=conteudo
		conteudo=corpo
		match passo:
			1: escolher_equipe()
			2: escolher_armas()
			3: confirmacao()
			4: acompanhamento()
		conteudo=externo
		rodape()
	assinatura=chave()
	ajustar()
func escolher_equipe() -> void:
	if tipo in ["coleta","reconhecimento"]:
		seletor_tipo=seletor(conteudo)
		seletor_tipo.add_item("Coleta")
		seletor_tipo.add_item("Reconhecimento")
		seletor_tipo.select(1 if tipo=="reconhecimento" else 0)
		seletor_tipo.item_selected.connect(func(i: int):
			tipo="coleta" if i==0 else "reconhecimento"
			politica=""
			mostrar_passo(1))
	super.escolher_equipe()
	if estado.moradores_vivos().is_empty(): texto(conteudo,"Construa uma oca para receber moradores.",18)
func confirmacao() -> void:
	# O resumo visual usa o destino real filtrado, inclusive fronteiras.
	var resumo:=conteudo
	if tipo=="caca":
		var escolha:=seletor(conteudo)
		escolha.add_item("Simular a caça")
		escolha.add_item("Jogar combate manual")
		escolha.select(1 if modo_caca=="manual" else 0)
		escolha.item_selected.connect(func(i: int):
			modo_caca="manual" if i==1 else "simulado"
			if modo_caca=="manual" and regiao not in Exp.Caca.regioes_manuais(): regiao=14
			mostrar_passo(3))
	if tipo=="pesca":
		var escolha_pesca:=seletor(conteudo)
		escolha_pesca.add_item("Simular a pescaria")
		escolha_pesca.add_item("Pescar à mão · você joga cada lance")
		escolha_pesca.select(1 if modo_caca=="manual" else 0)
		escolha_pesca.tooltip_text="À mão: sinta a mordida na boia, fisgue no momento certo e canse o peixe sem arrebentar a linha."
		escolha_pesca.item_selected.connect(func(i: int):
			modo_caca="manual" if i==1 else "simulado"
			mostrar_passo(3))
	if politica=="": politica=Exp.politica_padrao(tipo)
	var escolha_politica:=seletor(conteudo)
	for p: String in Exp.POLITICAS:
		escolha_politica.add_item("Se houver perigo · "+NOMES_POLITICA[p])
	escolha_politica.select(Exp.POLITICAS.find(politica))
	escolha_politica.tooltip_text="Usada quando a equipe resolve um encontro sozinha. Não garante segurança; no combate manual você decide."
	escolha_politica.item_selected.connect(func(i: int): politica=Exp.POLITICAS[i])
	var dest:=seletor(conteudo)
	seletor_destino=dest
	for r: Dictionary in Regioes.definicoes():
		if tipo=="caca" and modo_caca=="manual" and r.id not in Exp.Caca.regioes_manuais(): continue
		if r.id==20: continue
		var nivel:=int(estado.conhecimento[str(r.id)])
		if tipo=="reconhecimento":
			if nivel==0 and not Regioes.fronteira(r.id,estado.conhecimento): continue
		elif nivel<2: continue
		if tipo=="pesca" and not r.recursos.has("peixe"): continue
		if tipo=="caca" and Exp.Caca.fauna(r.id).is_empty(): continue
		if Regioes.viagem(r.id,estado.conhecimento)<0: continue
		dest.add_item(r.nome if nivel>0 else "Desconhecido · fronteira "+str(r.id+1),r.id)
		if r.id==regiao: dest.select(dest.item_count-1)
	regiao=dest.get_selected_id() if dest.item_count>0 else -1
	dest.item_selected.connect(func(_i: int):
		regiao=dest.get_selected_id()
		mostrar_passo(3))
	texto(resumo,"Sua equipe",21)
	for id in equipe:
		var h: Dictionary=estado.pessoa(id)
		var card:=PanelContainer.new()
		card.add_theme_stylebox_override("panel",plano("e6cb9a","9d794a"))
		resumo.add_child(card)
		var linha:=HBoxContainer.new()
		card.add_child(linha)
		retrato(linha,h,Vector2(60,65))
		var col:=VBoxContainer.new()
		linha.add_child(col)
		texto(col,h.nome,21)
		texto(col,("Arco" if armas.get(id,"arco")=="arco" else "Lança") if tipo=="caca" else "Equipamento do centro",17)
		texto(col,"Saúde %d%% · %s %d XP"%[h.saude,habilidade(),xp_atividade(h)],16)
	if regiao>=0:
		var viagem:=Regioes.viagem(regiao,estado.conhecimento)
		texto(resumo,"Ida %d s · Atividade %d s · Retorno %d s"%[ceili(viagem),ceili(Exp.duracao_planejada(tipo,viagem)),ceili(viagem)],18)
		regiao_apontada.emit(regiao)
	var nota:=texto(resumo,"Há risco de ferimentos e mortes. O confronto acrescenta tempo à viagem." if tipo=="caca" else "Os recursos chegam no retorno. Excedentes aguardam espaço no estoque. Animais podem surpreender a equipe: um alerta permite intervir.",17,"7b3523")
	nota.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func rodape() -> void:
	var linha:=HBoxContainer.new()
	conteudo.add_child(linha)
	voltar=botao(linha,"Voltar",func(): mostrar_passo(0 if etapa==4 else maxi(0,etapa-1)))
	var espaco:=Control.new()
	espaco.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	linha.add_child(espaco)
	if etapa==4:
		botao(linha,"Nova expedição",compacto,true)
		return
	frente=botao(linha,{"caca":"Enviar caça","pesca":"Enviar pescaria","coleta":"Enviar expedição","reconhecimento":"Enviar expedição"}[tipo] if etapa==3 else "Seguinte",func():
		if etapa==3: enviar_solicitado.emit(centro,tipo,regiao,equipe.duplicate())
		else: mostrar_passo(etapa+1),true)
	confirmar=frente if etapa==3 else null
	atualizar_resumo()
func atualizar_resumo() -> void:
	if not is_instance_valid(frente) or etapa==4: return
	var erro:=Exp.erro_envio(estado,centro,tipo,regiao,equipe,modo_caca if tipo in ["caca","pesca"] else "simulado") if etapa==3 else ("Escolha a equipe." if equipe.is_empty() else "")
	frente.disabled=erro!=""
	frente.tooltip_text=erro
func notificar(valor: String) -> void:
	aviso_texto=valor
	if is_instance_valid(mensagem):
		mensagem.text=valor
		mensagem.visible=valor!=""
func apresentar(tela: String) -> void:
	mostrar_passo(4 if tela=="acompanhar" else (3 if not equipe.is_empty() else 1))
func carga_texto(carga: Dictionary) -> String:
	var partes: Array[String]=[]
	for r in carga:
		if int(carga[r])>0: partes.append("%d %s"%[carga[r],str(r).replace("_"," ")])
	return ", ".join(partes) if not partes.is_empty() else "vazia"

func acompanhamento() -> void:
	if estado.expedicoes.is_empty():
		texto(corpo,"As expedições enviadas aparecerão aqui.",18)
		return
	var ordenadas: Array=estado.expedicoes.duplicate()
	ordenadas.reverse()
	for e: Dictionary in ordenadas:
		var separador:=HSeparator.new()
		corpo.add_child(separador)
		var linha:=HBoxContainer.new()
		linha.add_theme_constant_override("separation",24)
		corpo.add_child(linha)
		var dados:=VBoxContainer.new()
		dados.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		linha.add_child(dados)
		var nome: String=Regioes.definicoes()[int(e.regiao)].nome if int(estado.conhecimento[str(int(e.regiao))])>0 else "Região desconhecida"
		texto(dados,"%s · %s · %s"%[e.id,e.tipo.capitalize(),nome],19)
		var nomes: Array[String]=[]
		for id in e.equipe: nomes.append(estado.pessoa(id).nome)
		var equipe_label:=texto(dados,"Equipe · "+", ".join(nomes),16)
		equipe_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var carga:=texto(dados,"",16)
		carga.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var xp:=texto(dados,"",15)
		var condicao:=texto(dados,"",15)
		condicao.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var andamento:=VBoxContainer.new()
		andamento.custom_minimum_size.x=300
		linha.add_child(andamento)
		var fase:=texto(andamento,"",17)
		fase.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var progresso:=ProgressBar.new()
		progresso.custom_minimum_size.y=22
		progresso.show_percentage=false
		progresso.add_theme_stylebox_override("background",plano("e2c18c","987348"))
		progresso.add_theme_stylebox_override("fill",plano("355447","355447"))
		andamento.add_child(progresso)
		var retorno:=botao(andamento,"Solicitar retorno",retorno_solicitado.emit.bind(e.id))
		var evento:=texto(dados,"",15,"51402a")
		evento.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		linhas[e.id]={"carga":carga,"xp":xp,"condicao":condicao,"fase":fase,"progresso":progresso,"retorno":retorno,"evento":evento}
	atualizar_acompanhamento()

func atualizar_acompanhamento() -> void:
	for e: Dictionary in estado.expedicoes:
		if not linhas.has(e.id): continue
		var l: Dictionary=linhas[e.id]
		l.carga.text=("Entregue · " if e.fase=="concluida" else "Carga · ")+carga_texto(e.entregue if e.fase=="concluida" else e.carga)
		l.xp.text=("XP da equipe · %d   Conhecimento obtido · %d" if e.tipo=="caca" else "XP por integrante · %d   Conhecimento obtido · %d")%[e.xp,e.conhecimento]
		l.fase.text=FASES[e.fase]+(" · %d s"%ceili(e.restante) if e.fase in Exp.ATIVAS else "")
		l.progresso.value=100*(1-float(e.restante)/maxf(.001,e.duracao_fase)) if e.fase in Exp.ATIVAS else 100
		l.retorno.disabled=e.fase not in ["preparacao","ida","exploracao","confronto"]
		if e.fase=="alerta":
			l.fase.text="Alerta · %s · %d s"%[Exp.Caca.Combate.nome_animal(e.combate.animal),ceili(e.restante)]
		l.retorno.text="Cancelar preparação" if e.fase=="preparacao" else ("Tentar retirada" if e.fase=="confronto" else "Solicitar retorno")
		if e.fase=="confronto" and not e.combate.is_empty():
			var atual:=Exp.Caca.Combate.atual(e.combate)
			l.retorno.disabled=atual.is_empty() or atual.lado!="equipe" or atual.pa<2
			l.fase.text="%s · rodada %d"%[Exp.Caca.Combate.nome_animal(e.combate.animal),e.combate.rodada]
		l.evento.text=e.eventos[-1] if not e.eventos.is_empty() else "Equipe em preparação."
		if e.fase in ["alerta","confronto"] and not e.get("combate",{}).is_empty(): l.evento.text=e.combate.registro[-1] if not e.combate.registro.is_empty() else "Confronto preparado."
		l.condicao.text=""
		if not e.get("combate",{}).is_empty():
			var condicoes: Array[String]=[]
			for a: Dictionary in e.combate.atores:
				if a.lado=="equipe": condicoes.append("%s: %s"%[a.nome,"morto" if a.morto else ("incapacitado" if a.vida==0 else "%d/%d HP"%[a.vida,a.vida_max])])
			l.condicao.text="No encontro · "+" · ".join(condicoes)+" · Política "+str(e.get("politica","equilibrada"))
		l.condicao.visible=l.condicao.text!=""


func chave() -> String:
	if estado==null: return ""
	var itens: Array=[estado.conhecimento]
	for c: Dictionary in estado.construcoes: itens.append([c.id,c.pronta])
	for h: Dictionary in estado.habitantes: itens.append([h.id,h.estado,h.setor,h.saude,h.habilidades])
	for e: Dictionary in estado.expedicoes: itens.append([e.id,e.fase])
	return str(itens)
func _process(delta: float) -> void:
	if not aberto or estado==null: return
	_tempo+=delta
	if _tempo<.25: return
	_tempo=0
	if chave()!=assinatura:
		var scroll:=rolagem.scroll_vertical if is_instance_valid(rolagem) else 0
		mostrar_passo(etapa)
		if is_instance_valid(rolagem): rolagem.set_deferred("scroll_vertical",scroll)
	elif etapa==4: atualizar_acompanhamento()
	else: atualizar_resumo()
func _unhandled_key_input(e: InputEvent) -> void:
	if not aberto or not e is InputEventKey or not e.pressed or e.echo: return
	if e.physical_keycode==KEY_ESCAPE:
		if etapa>0: compacto()
		else: fechar_solicitado.emit()
	elif e.physical_keycode==KEY_H:
		visible=not visible
		hud_alternado.emit(visible)
	else: return
	get_viewport().set_input_as_handled()
