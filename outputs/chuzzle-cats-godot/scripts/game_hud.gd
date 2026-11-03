extends Control
signal restart_requested
signal level_requested(index: int)
const KITCHEN = preload("res://assets/ui/kitchen/kitchen-skin.png")
const KIBBLE = preload("res://assets/ui/kitchen/kibble.png")
const BASE := Vector2(540,960)
var stage: Control
var view: Control
var station: Control
var heading: Label
var stats: Label
var status: Label
var progress: ProgressBar
var hint_button: Button
var shuffle_button: Button
var next_button: Button
var food_label: Label
var moves_label: Label
var level_label: Label
var shuffle_label: Label
var menu_overlay: Control
var meal_dim: ColorRect
var meal_title: Label
var remaining_ratio: float = 1.0
var food_ratio: float = 0.0
var displayed_ratio: float = 0.0

func box(color: Color, radius: int, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.border_color=border
	style.set_border_width_all(width)
	return style

func label_at(text: String, rect: Rect2, font_size: int, color: Color, outline: Color = Color.TRANSPARENT, outline_size: int = 0) -> Label:
	var label := Label.new()
	label.text=text
	label.position=rect.position
	label.size=rect.size
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",outline)
	label.add_theme_constant_override("outline_size",outline_size)
	stage.add_child(label)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func text_button(text: String, rect: Rect2, tint: Color) -> Button:
	var button := Button.new()
	button.text=text
	button.position=rect.position
	button.size=rect.size
	button.add_theme_font_size_override("font_size",25)
	button.add_theme_color_override("font_color",tint)
	button.add_theme_color_override("font_outline_color",Color("fff5d9"))
	button.add_theme_constant_override("outline_size",0)
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover",box(Color(1,1,1,0.1),14))
	button.add_theme_stylebox_override("pressed",box(Color(0.1,0,0.2,0.22),14))
	button.add_theme_stylebox_override("focus",box(Color.TRANSPARENT,14,Color(1,1,1,0.5),2))
	stage.add_child(button)
	return button

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	stage=Control.new()
	stage.size=BASE
	stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(stage)
	var menu_button: Button=text_button("",Rect2(16,14,114,51),Color("614322"))
	menu_button.pressed.connect(toggle_menu)
	hint_button=text_button("",Rect2(413,14,114,51),Color("614322"))
	label_at("菜单",Rect2(61,18,65,39),25,Color("614322"))
	label_at("提示",Rect2(455,18,68,39),25,Color("614322"))
	level_label=label_at("01",Rect2(0,0,1,1),1,Color.TRANSPARENT)
	level_label.visible=false
	food_label=label_at("猫粮 0 / 35",Rect2(193,204,166,36),21,Color("64431e"))
	moves_label=label_at("10",Rect2(421,191,78,46),40,Color("ad5a19"))
	label_at("步数",Rect2(416,171,86,27),20,Color("68451e"))
	view=preload("res://scripts/board_view.gd").new()
	view.external_surface=true
	view.position=Vector2(17,300)
	view.size=Vector2(506,500)
	stage.add_child(view)
	shuffle_button=text_button("",Rect2(204,815,134,118),Color("64431e"))
	shuffle_button.add_theme_font_size_override("font_size",54)
	shuffle_button.tooltip_text="重排棋盘并解锁"
	shuffle_label=label_at("重排 2",Rect2(215,881,111,33),24,Color("64431e"))
	status=label_at("拖动整行或整列，收集猫粮",Rect2(18,933,504,27),12,Color("644e31"),Color("fff3d9"),2)
	status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	progress=ProgressBar.new()
	progress.visible=false
	stage.add_child(progress)
	meal_dim=ColorRect.new()
	meal_dim.color=Color(0.18,0.13,0.07,0.70)
	meal_dim.position=Vector2(24,306)
	meal_dim.size=Vector2(492,486)
	meal_dim.z_index=9
	meal_dim.visible=false
	stage.add_child(meal_dim)
	meal_title=label_at("开饭啦！",Rect2(80,356,380,55),33,Color("fff2c8"),Color("6d461d"),4)
	meal_title.z_index=11
	meal_title.visible=false
	station=preload("res://scripts/food_station.gd").new()
	station.compact_mode=true
	station.position=Vector2(45,430)
	station.size=Vector2(450,170)
	stage.add_child(station)
	next_button=Button.new()
	next_button.text="下一关  →"
	next_button.position=Vector2(162,635)
	next_button.size=Vector2(216,61)
	next_button.z_index=11
	style_menu_button(next_button)
	stage.add_child(next_button)
	build_menu()
	resized.connect(layout_stage)
	layout_stage()

func style_menu_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size",20)
	button.add_theme_color_override("font_color",Color("634825"))
	button.add_theme_stylebox_override("normal",box(Color("f5e8c8"),13,Color("d0ab73"),2))
	button.add_theme_stylebox_override("hover",box(Color("fff4dc"),13,Color("d39a53"),2))
	button.add_theme_stylebox_override("pressed",box(Color("e7d3ae"),13,Color("bc8945"),2))

func menu_action(text: String, y: float, action: Callable) -> Button:
	var button := Button.new()
	button.text=text
	button.position=Vector2(101,y)
	button.size=Vector2(338,48)
	style_menu_button(button)
	button.pressed.connect(action)
	menu_overlay.add_child(button)
	return button

func build_menu() -> void:
	menu_overlay=Control.new()
	menu_overlay.size=BASE
	menu_overlay.z_index=30
	menu_overlay.visible=false
	stage.add_child(menu_overlay)
	var dim:=ColorRect.new()
	dim.color=Color(0.16,0.10,0.03,0.76)
	dim.size=BASE
	menu_overlay.add_child(dim)
	var panel:=Panel.new()
	panel.position=Vector2(71,155)
	panel.size=Vector2(398,620)
	panel.add_theme_stylebox_override("panel",box(Color("fff3d9"),25,Color("d49a55"),4))
	menu_overlay.add_child(panel)
	heading=Label.new()
	heading.position=Vector2(91,171)
	heading.size=Vector2(358,46)
	heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size",20)
	heading.add_theme_color_override("font_color",Color("644923"))
	menu_overlay.add_child(heading)
	stats=Label.new()
	stats.position=Vector2(91,217)
	stats.size=Vector2(358,35)
	stats.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size",16)
	stats.add_theme_color_override("font_color",Color("806746"))
	menu_overlay.add_child(stats)
	menu_action("继续游戏",265,toggle_menu)
	menu_action("重新开始",325,func(): toggle_menu(); restart_requested.emit())
	for i in 3:
		menu_action("关卡 %d" % (i+1),385+i*56,func(): toggle_menu(); level_requested.emit(i))
	menu_action("视线：跟随 / 静止",558,func(): view.animate_eyes=not view.animate_eyes; view.redraw_board())
	var help:=Label.new()
	help.position=Vector2(98,625)
	help.size=Vector2(344,129)
	help.text="整行／整列循环拖动，同类相连 ≥3。\n锁所在行列不能拖动，匹配即可解锁。\n①虎斑 ②蓝猫 ③奶牛 ④黑猫 ⑤白猫\n⑥暹罗 ⑦三花 ⑧孟加拉 ⑨玳瑁"
	help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size",15)
	help.add_theme_color_override("font_color",Color("806746"))
	menu_overlay.add_child(help)

func toggle_menu() -> void:
	view.cancel_drag()
	menu_overlay.visible=not menu_overlay.visible

func layout_stage() -> void:
	if stage==null: return
	var factor: float=minf(size.x/BASE.x,size.y/BASE.y)
	stage.scale=Vector2.ONE*factor
	stage.position=(size-BASE*factor)*0.5
	queue_redraw()

func sync_game(food: int,target: int,moves: int,budget: int,index: int,shuffles: int,_busy: bool,finished: bool) -> void:
	food_ratio=clampf(float(food)/target,0,1)
	remaining_ratio=clampf(float(moves)/budget,0,1)
	food_label.text="猫粮 %d / %d" % [food,target]
	moves_label.text=str(moves)
	level_label.text="%02d" % (index+1)
	shuffle_label.text="重排 %d" % shuffles
	if finished and food<target:
		status.text="本次未完成 · 打开菜单重新开始"
	queue_redraw()

func _process(delta: float) -> void:
	displayed_ratio=lerpf(displayed_ratio,food_ratio,1-exp(-delta*7))
	var meal: bool=station!=null and (station.meal_time>=0 or station.happy)
	if meal_dim!=null:
		meal_dim.visible=meal
		meal_title.visible=meal
		meal_title.text="吃饱啦，谢谢你！" if station.happy else "装满啦，开饭！"
	queue_redraw()

func _draw() -> void:
	if stage==null: return
	draw_set_transform(stage.position,0,stage.scale)
	draw_texture_rect(KITCHEN,Rect2(Vector2.ZERO,BASE),false)
	# 食盆内的猫粮由真实进度控制，未烘焙在背景中。
	var ratio: float=displayed_ratio
	if station!=null and station.meal_time>=0:
		ratio *= 1-smoothstep(0.5,2.8,station.meal_time)
	for i in int(65*ratio):
		var row: int=i/13
		var column: int=i%13
		var point:=Vector2(174+column*15.2+(row%2)*5.0+sin(i*2.4)*2.5,185-row*6.6+sin(i*3.7)*1.8)
		if pow((point.x-270)/108,2)+pow((point.y-178)/19,2)>1: continue
		draw_set_transform(stage.position+point*stage.scale,sin(i*2.7)*0.8,stage.scale)
		draw_texture_rect(KIBBLE,Rect2(-11,-11,22,22),false,Color.WHITE if i%2==0 else Color(0.91,0.83,0.69))
	draw_set_transform(Vector2.ZERO)
