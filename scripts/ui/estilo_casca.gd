extends RefCounted
## Padrão visual único dos menus: casca interna de árvore (a face clara e
## fibrosa que aparece ao descascar o tronco) com borda de casca externa.
## O tema global fica em assets/ui/casca/tema_casca.tres (Projeto → GUI → Tema)
## e é gerado por tools/gerar_tema_casca.gd. Aqui ficam atalhos para scripts.
const TEMA := preload("res://assets/ui/casca/tema_casca.tres")
const FONTE_TITULO := preload("res://assets/ui/fonts/alegreya_sc/AlegreyaSC-Bold.ttf")
const FONTE_TEXTO := preload("res://assets/ui/fonts/alegreya_sans/AlegreyaSans-Medium.ttf")
const TINTA := Color("35271b")
const TINTA_SUAVE := Color("553720")
const TINTA_DESTAQUE := Color("8e3b1f")
const CREME := Color("fff1cf")

## Remove sobreposições antigas e aplica o botão de fibra (ou o primário, tingido de urucum).
static func botao(b: Button, primario := false) -> void:
	for estilo in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		b.remove_theme_stylebox_override(estilo)
	for cor in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		b.remove_theme_color_override(cor)
	b.remove_theme_font_override("font")
	b.theme_type_variation = "BotaoCascaPrimario" if primario else ""

static func estilo(nome: String, tipo := "Button") -> StyleBox:
	return TEMA.get_stylebox(nome, tipo).duplicate()

static func painel(fino := false) -> StyleBox:
	return estilo("panel", "PainelCascaFino" if fino else "PanelContainer")

## Mesmo estilo com margens internas próprias (para botões compactos).
static func margens(b: Control, horizontal: float, vertical: float) -> void:
	for nome in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var s := b.get_theme_stylebox(nome).duplicate() as StyleBox
		s.content_margin_left = horizontal
		s.content_margin_right = horizontal
		s.content_margin_top = vertical
		s.content_margin_bottom = vertical
		b.add_theme_stylebox_override(nome, s)
