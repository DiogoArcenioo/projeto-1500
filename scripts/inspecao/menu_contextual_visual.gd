extends CanvasLayer
## Protótipo visual aprovado no portão A. Botões não executam regras de gameplay.
const Casca = preload("res://scripts/ui/estilo_casca.gd")
var expandido: bool = false
var _recolhido: PanelContainer
var _expandido: PanelContainer
var _superficie: Control

func _ready() -> void:
	construir()
	get_viewport().size_changed.connect(ajustar)
	ajustar()

func caixa(cor: Color, borda: Color, raio: int = 12) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = cor
	estilo.border_color = borda
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(raio)
	estilo.content_margin_left = 22
	estilo.content_margin_right = 22
	estilo.content_margin_top = 16
	estilo.content_margin_bottom = 16
	return estilo

func texto(pai: Node, conteudo: String, tamanho: int = 18, cor: Color = Casca.TINTA) -> Label:
	var label := Label.new()
	label.text = conteudo
	if tamanho >= 20: label.theme_type_variation = "TituloCasca"
	label.add_theme_font_size_override("font_size", tamanho)
	label.add_theme_color_override("font_color", cor)
	pai.add_child(label)
	return label

func botao(pai: Node, conteudo: String, primario: bool = false) -> Button:
	var b := Button.new()
	b.text = conteudo
	b.custom_minimum_size = Vector2(148, 44)
	b.add_theme_font_size_override("font_size", 18)
	Casca.botao(b, primario)
	pai.add_child(b)
	return b

func painel() -> PanelContainer:
	var p := PanelContainer.new()
	_superficie.add_child(p)
	p.anchor_left = .5
	p.anchor_right = .5
	p.anchor_top = 1
	p.anchor_bottom = 1
	return p

func construir() -> void:
	_superficie = Control.new()
	add_child(_superficie)
	_superficie.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_superficie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recolhido = painel()
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 24)
	_recolhido.add_child(linha)
	texto(linha, "Fogueira", 26)
	var informacao := VBoxContainer.new()
	informacao.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(informacao)
	texto(informacao, "Oca · 2 vagas de moradia", 18)
	texto(informacao, "30 madeira · 20 fibras", 15, Casca.TINTA_SUAVE)
	var comunidade := botao(linha, "Comunidade")
	comunidade.pressed.connect(func(): definir_expandido(true))
	var construir_oca := botao(linha, "Construir oca", true)
	construir_oca.tooltip_text = "Prévia visual do botão; a construção ainda não está integrada."
	_expandido = painel()
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 16)
	_expandido.add_child(coluna)
	var cabecalho := HBoxContainer.new()
	coluna.add_child(cabecalho)
	var titulo := texto(cabecalho, "Comunidade", 26)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto(cabecalho, "2 moradores · 2 vagas", 16, Casca.TINTA_SUAVE)
	var fechar := botao(cabecalho, "Recolher")
	fechar.pressed.connect(func(): definir_expandido(false))
	var separador := HSeparator.new()
	coluna.add_child(separador)
	var conteudo := HBoxContainer.new()
	conteudo.add_theme_constant_override("separation", 32)
	coluna.add_child(conteudo)
	var moradores := VBoxContainer.new()
	moradores.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moradores.add_theme_constant_override("separation", 10)
	conteudo.add_child(moradores)
	for nome: String in ["Morador 01", "Moradora 01"]:
		var linha_morador := PanelContainer.new()
		linha_morador.theme_type_variation = "CartaoCasca"
		moradores.add_child(linha_morador)
		var dados := HBoxContainer.new()
		linha_morador.add_child(dados)
		var nome_label := texto(dados, nome, 18)
		nome_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texto(dados, "Livre", 16, Casca.TINTA_SUAVE)
	var setor := VBoxContainer.new()
	setor.custom_minimum_size.x = 330
	setor.add_theme_constant_override("separation", 10)
	conteudo.add_child(setor)
	texto(setor, "Centro de coleta · 0/2", 21)
	texto(setor, "Selecione um morador", 16, Casca.TINTA_SUAVE)
	var atribuir := botao(setor, "Atribuir", true)
	atribuir.tooltip_text = "Prévia visual; moradores e setor ainda não estão vinculados."
	definir_expandido(false)

func definir_expandido(valor: bool) -> void:
	expandido = valor
	_recolhido.visible = not valor
	_expandido.visible = valor
	ajustar()

func ajustar() -> void:
	var largura := minf(1080, get_viewport().get_visible_rect().size.x - 48)
	for p: PanelContainer in [_recolhido, _expandido]:
		p.offset_left = -largura / 2
		p.offset_right = largura / 2
		p.offset_bottom = -20
		p.offset_top = -20 - (272 if p == _expandido else 90)
