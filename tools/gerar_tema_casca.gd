extends SceneTree
## Gera as texturas e o tema global de casca interna a partir da arte aprovada
## em assets/ui/expedicoes/casca_interna_painel.png.
## Uso (duas fases, com importação entre elas):
##   godot --headless --path . -s tools/gerar_tema_casca.gd -- texturas
##   godot --headless --path . --import
##   godot --headless --path . -s tools/gerar_tema_casca.gd -- tema
const ORIGEM:="res://assets/ui/expedicoes/casca_interna_painel.png"
const PASTA:="res://assets/ui/casca/"
const FONTE_TITULO:="res://assets/ui/fonts/alegreya_sc/AlegreyaSC-Bold.ttf"
const FONTE_TEXTO:="res://assets/ui/fonts/alegreya_sans/AlegreyaSans-Medium.ttf"
## Espessura da borda de casca (relevo escuro) em cada escala gerada.
const MARGEM_PAINEL:=34
const MARGEM_PAINEL_FINO:=18
const MARGEM_BOTAO:=9
const TINTA:=Color("35271b")

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if "tema" in args: gerar_tema()
	else: gerar_texturas()
	quit()

func caminho(nome: String) -> String:
	return ProjectSettings.globalize_path(PASTA+nome)

func gerar_texturas() -> void:
	DirAccess.make_dir_recursive_absolute(caminho(""))
	var img:=Image.load_from_file(ProjectSettings.globalize_path(ORIGEM))
	img.convert(Image.FORMAT_RGBA8)
	for par in [["painel.png",.30],["painel_fino.png",.16]]:
		var p:=img.duplicate() as Image
		p.resize(roundi(img.get_width()*par[1]),roundi(img.get_height()*par[1]),Image.INTERPOLATE_LANCZOS)
		p.save_png(caminho(par[0]))
	# Fibras da casca interna, sem a borda: base das peças pequenas.
	var fibras:=img.get_region(Rect2i(420,330,560,175))
	fibras.resize(320,100,Image.INTERPOLATE_LANCZOS)
	realcar_fibras(fibras)
	var variantes:={
		"botao":func(c: Color): return c,
		"botao_foco":func(c: Color): return c.lerp(Color("f3d39a"),.38),
		"botao_pressionado":func(c: Color): return c*Color(.74,.72,.70,1),
		"botao_inativo":func(c: Color): return Color(c.get_luminance(),c.get_luminance(),c.get_luminance()).lerp(c,.35).lerp(Color("d8c6a6"),.35),
		"botao_primario":func(c: Color): return c*Color(.98,.56,.44,1),
		"botao_primario_foco":func(c: Color): return (c*Color(.98,.56,.44,1)).lerp(Color("e07a4c"),.3),
		"botao_primario_pressionado":func(c: Color): return c*Color(.72,.40,.31,1),
		"cartao":func(c: Color): return c.lerp(Color("f1dcae"),.55),
	}
	for nome: String in variantes:
		var b:=fibras.duplicate() as Image
		var f: Callable=variantes[nome]
		for y in b.get_height():
			for x in b.get_width():
				b.set_pixel(x,y,f.call(b.get_pixel(x,y)))
		var aro:=Color("e8bd68") if nome.ends_with("pressionado") else Color("4f2f18")
		moldurar(b,aro,nome=="botao_inativo")
		b.save_png(caminho(nome+".png"))
	print("Texturas de casca geradas em ",PASTA)

func realcar_fibras(img: Image) -> void:
	var media:=Color(0,0,0)
	for y in img.get_height():
		for x in img.get_width(): media+=img.get_pixel(x,y)
	media/=float(img.get_width()*img.get_height())
	for y in img.get_height():
		for x in img.get_width():
			var c:=img.get_pixel(x,y)
			c=media+(c-media)*1.7
			c.a=1
			img.set_pixel(x,y,c.clamp())

## Cantos arredondados, aro escuro de casca e leve volume (claro em cima,
## sombra embaixo), para o botão parecer uma lasca de madeira descascada.
func moldurar(img: Image,aro: Color,inativo:=false) -> void:
	var w:=img.get_width()
	var h:=img.get_height()
	var raio:=8.0
	for y in h:
		for x in w:
			var c:=img.get_pixel(x,y)
			var cx:=clampf(x+.5,raio,w-raio)
			var cy:=clampf(y+.5,raio,h-raio)
			var d:=raio-Vector2(x+.5,y+.5).distance_to(Vector2(cx,cy))
			var borda:=minf(minf(x+.5,w-x-.5),minf(y+.5,h-y-.5))
			if Vector2(x+.5,y+.5).distance_to(Vector2(cx,cy))>0: borda=d
			c=c*(1.08-.22*float(y)/h)
			if borda<2.2: c=c.lerp(aro,.9)
			elif borda<4.5: c=c.lerp(aro,.35)
			elif y<6: c=c.lerp(Color("fff0c8"),.18)
			c.a=clampf(borda+.5,0,1)*(.82 if inativo else 1.0)
			img.set_pixel(x,y,c.clamp())

func caixa_textura(nome: String,margem: int,conteudo: Vector4) -> StyleBoxTexture:
	var s:=StyleBoxTexture.new()
	s.texture=load(PASTA+nome+".png")
	s.set_texture_margin_all(margem)
	s.content_margin_left=conteudo.x
	s.content_margin_top=conteudo.y
	s.content_margin_right=conteudo.z
	s.content_margin_bottom=conteudo.w
	return s

func plano(cor: String,borda: String,raio:=4) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new()
	s.bg_color=Color(cor)
	s.border_color=Color(borda)
	s.set_border_width_all(1)
	s.set_corner_radius_all(raio)
	return s

func gerar_tema() -> void:
	var t:=Theme.new()
	var titulo: Font=load(FONTE_TITULO)
	var corpo: Font=load(FONTE_TEXTO)
	t.default_font=corpo
	t.default_font_size=17
	var painel:=caixa_textura("painel",MARGEM_PAINEL,Vector4(34,28,34,28))
	var fino:=caixa_textura("painel_fino",MARGEM_PAINEL_FINO,Vector4(16,11,16,11))
	for tipo in ["PanelContainer","Panel"]: t.set_stylebox("panel",tipo,painel)
	t.set_type_variation("PainelCascaFino","PanelContainer")
	t.set_stylebox("panel","PainelCascaFino",fino)
	t.set_type_variation("CartaoCasca","PanelContainer")
	t.set_stylebox("panel","CartaoCasca",caixa_textura("cartao",MARGEM_BOTAO,Vector4(12,8,12,8)))
	# Textos
	for tipo in ["Label","RichTextLabel"]:
		t.set_color("font_color" if tipo=="Label" else "default_color",tipo,TINTA)
	t.set_type_variation("TituloCasca","Label")
	t.set_font("font","TituloCasca",titulo)
	t.set_font_size("font_size","TituloCasca",22)
	# Botões de fibra
	var margem_botao:=Vector4(13,6,13,6)
	for tipo in ["Button","OptionButton","MenuButton","CheckButton","CheckBox"]:
		t.set_font("font",tipo,titulo)
		t.set_font_size("font_size",tipo,17)
		t.set_color("font_color",tipo,TINTA)
		t.set_color("font_hover_color",tipo,Color("21170f"))
		t.set_color("font_pressed_color",tipo,Color("fff0cf"))
		t.set_color("font_hover_pressed_color",tipo,Color("fff3d8"))
		t.set_color("font_focus_color",tipo,TINTA)
		t.set_color("font_disabled_color",tipo,Color("6a5843"))
		t.set_color("icon_normal_color",tipo,TINTA)
		if tipo in ["CheckButton","CheckBox"]: continue
		t.set_stylebox("normal",tipo,caixa_textura("botao",MARGEM_BOTAO,margem_botao))
		t.set_stylebox("hover",tipo,caixa_textura("botao_foco",MARGEM_BOTAO,margem_botao))
		t.set_stylebox("pressed",tipo,caixa_textura("botao_pressionado",MARGEM_BOTAO,margem_botao))
		t.set_stylebox("hover_pressed",tipo,caixa_textura("botao_pressionado",MARGEM_BOTAO,margem_botao))
		t.set_stylebox("disabled",tipo,caixa_textura("botao_inativo",MARGEM_BOTAO,margem_botao))
		t.set_stylebox("focus",tipo,StyleBoxEmpty.new())
	t.set_type_variation("BotaoCascaPrimario","Button")
	t.set_stylebox("normal","BotaoCascaPrimario",caixa_textura("botao_primario",MARGEM_BOTAO,margem_botao))
	t.set_stylebox("hover","BotaoCascaPrimario",caixa_textura("botao_primario_foco",MARGEM_BOTAO,margem_botao))
	t.set_stylebox("pressed","BotaoCascaPrimario",caixa_textura("botao_primario_pressionado",MARGEM_BOTAO,margem_botao))
	t.set_color("font_color","BotaoCascaPrimario",Color("fff1cf"))
	t.set_color("font_hover_color","BotaoCascaPrimario",Color("fff6df"))
	t.set_color("font_focus_color","BotaoCascaPrimario",Color("fff1cf"))
	# Popups, dicas e rolagem
	t.set_stylebox("panel","PopupMenu",fino)
	t.set_stylebox("hover","PopupMenu",caixa_textura("botao_foco",MARGEM_BOTAO,Vector4(8,2,8,2)))
	for cor in ["font_color","font_accelerator_color"]: t.set_color(cor,"PopupMenu",TINTA)
	t.set_color("font_hover_color","PopupMenu",Color("21170f"))
	t.set_color("font_disabled_color","PopupMenu",Color("7a6650"))
	t.set_font("font","PopupMenu",corpo)
	t.set_stylebox("panel","TooltipPanel",fino)
	t.set_color("font_color","TooltipLabel",TINTA)
	t.set_font("font","TooltipLabel",corpo)
	t.set_font_size("font_size","TooltipLabel",16)
	for tipo in ["VScrollBar","HScrollBar"]:
		var trilho:=plano("6b4a2b55","00000000",5)
		t.set_stylebox("scroll",tipo,trilho)
		t.set_stylebox("scroll_focus",tipo,trilho)
		t.set_stylebox("grabber",tipo,plano("8a5a31","5a3a1f",5))
		t.set_stylebox("grabber_highlight",tipo,plano("a8703d","5a3a1f",5))
		t.set_stylebox("grabber_pressed",tipo,plano("6e4522","5a3a1f",5))
	var fundo_barra:=plano("d9b77f","8a6740",5)
	fundo_barra.set_content_margin_all(0)
	t.set_stylebox("background","ProgressBar",fundo_barra)
	t.set_stylebox("fill","ProgressBar",plano("9c4a2a","6d331d",5))
	t.set_color("font_color","ProgressBar",TINTA)
	for tipo in ["HSeparator","VSeparator"]:
		var linha:=StyleBoxLine.new()
		linha.color=Color("7a4c2a")
		linha.thickness=2
		linha.vertical=tipo=="VSeparator"
		t.set_stylebox("separator",tipo,linha)
	var campo:=caixa_textura("cartao",MARGEM_BOTAO,Vector4(10,6,10,6))
	t.set_stylebox("normal","LineEdit",campo)
	t.set_stylebox("focus","LineEdit",StyleBoxEmpty.new())
	t.set_color("font_color","LineEdit",TINTA)
	var erro:=ResourceSaver.save(t,PASTA+"tema_casca.tres")
	print("Tema salvo: ",PASTA+"tema_casca.tres"," · ",error_string(erro))
