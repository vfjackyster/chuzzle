extends "res://scripts/board_view.gd"
# 复用同一套猫头像和独立眼睛；此控件仅负责食盆与演出。
const KIBBLE = preload("res://assets/ui/kitchen/kibble.png")
var compact_mode: bool = false
var food_amount: float = 0.0
var food_target: int = 35
var meal_time: float = -1.0
var happy: bool = false
var flights: Array = []
var recipient: int = 0

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 10

func reset_meal(target: int, kind: int) -> void:
	food_target = target
	food_amount = 0
	meal_time = -1
	happy = false
	recipient = kind
	flights.clear()
	queue_redraw()

func bowl_point() -> Vector2:
	return Vector2(size.x*0.5,-249) if compact_mode and meal_time<0 and not happy else Vector2(size.x*0.72,100)

func add_food(cells: Array, board_control: Control) -> void:
	var rect: Rect2 = board_control.board_rect()
	for cell: Vector2i in cells:
		var point: Vector2 = rect.position+(Vector2(cell)+Vector2.ONE*0.5)*rect.size.x/6.0
		var origin: Vector2 = get_global_transform_with_canvas().affine_inverse()*(board_control.get_global_transform_with_canvas()*point)
		flights.append({"from":origin,"age":-minf(flights.size()*0.008,0.15)})

func _process(delta: float) -> void:
	super._process(delta)
	if meal_time >= 0:
		meal_time += delta
	for i in range(flights.size()-1,-1,-1):
		flights[i].age += delta
		if flights[i].age >= 0.7:
			flights.remove_at(i)
	queue_redraw()

func _draw() -> void:
	if size.x < 1:
		return
	if compact_mode and meal_time<0 and not happy:
		draw_food_flights()
		return
	draw_style_box(_box(Color("eee3ce"),18),Rect2(Vector2.ZERO,size))
	var bowl: Vector2 = bowl_point()
	var eating: bool = meal_time >= 0 and meal_time < 2.8
	var approach: float = smoothstep(0.0,0.55,meal_time) if eating else (1.0 if happy else 0.0)
	var cat_at: Vector2 = Vector2(83,68).lerp(bowl+Vector2(-40,-55),approach)
	# 身体与前爪，头部前倾并有咀嚼起伏。
	draw_circle(cat_at+Vector2(-6,41),34,Color("d9b386"))
	draw_circle(cat_at+Vector2(-24,54),13,Color("f0d8b5"))
	draw_circle(cat_at+Vector2(20,54),13,Color("f0d8b5"))
	if eating:
		cat_at.y += sin(meal_time*19.0)*3.0+8
	_cat(cat_at,0.92,recipient,false,0)
	if eating:
		draw_circle(cat_at+Vector2(0,19),3.0+absf(sin(meal_time*19))*2.0,Color("704f40"))
	draw_set_transform(Vector2.ZERO)
	var ratio: float = clampf(food_amount/food_target,0,1)
	if meal_time >= 0:
		ratio *= 1.0-smoothstep(0.5,2.8,meal_time)
	# 碗的内沿、可见猫粮、外壁；粮量随进度上升。
	draw_style_box(_box(Color("8a6652"),22),Rect2(bowl-Vector2(77,27),Vector2(154,53)))
	draw_style_box(_box(Color("3c4b43"),18),Rect2(bowl-Vector2(69,22),Vector2(138,39)))
	for i in int(45*ratio):
		var px: float = fmod(i*37.0,120.0)-60.0
		var py: float = fmod(i*17.0,24.0)-17.0
		draw_circle(bowl+Vector2(px,py),4.5,Color("bb884b") if i%2==0 else Color("d6a665"))
	draw_colored_polygon(PackedVector2Array([bowl+Vector2(-74,0),bowl+Vector2(74,0),bowl+Vector2(57,43),bowl+Vector2(-57,43)]),Color("ce7d57"))
	draw_line(bowl+Vector2(-73,0),bowl+Vector2(73,0),Color("f4c7a0"),4,true)
	draw_circle(bowl+Vector2(0,20),7,Color("ffe3bc"))
	for offset in [Vector2(-8,10),Vector2(0,7),Vector2(8,10)]:
		draw_circle(bowl+offset,3,Color("ffe3bc"))
	var caption: String = "再来一点，就能开饭啦"
	if eating: caption = "啊呜…啊呜…"
	elif happy: caption = "吃饱啦！谢谢你"
	draw_string(ThemeDB.fallback_font,Vector2(14,size.y-12),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("5b6350"))
	draw_food_flights()
	if happy:
		for i in 3:
			var at: Vector2 = cat_at+Vector2(-40+i*38,-53-sin(animation_clock*2+i)*6)
			draw_circle(at,5,Color("d99985"))
			draw_circle(at+Vector2(7,0),5,Color("d99985"))
			draw_colored_polygon(PackedVector2Array([at+Vector2(-5,2),at+Vector2(12,2),at+Vector2(3.5,12)]),Color("d99985"))

func draw_food_flights() -> void:
	var bowl: Vector2 = bowl_point()
	for flight: Dictionary in flights:
		if flight.age < 0: continue
		var t: float = clampf(flight.age/0.7,0,1)
		var at: Vector2 = flight.from.lerp(bowl-Vector2(0,15),t)+Vector2(0,-sin(t*PI)*65)
		draw_texture_rect(KIBBLE,Rect2(at-Vector2(7,7),Vector2(14,14)),false)
