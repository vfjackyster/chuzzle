extends Control
var rig: Node2D
var player: AnimationPlayer
var phase_label: Label
var progress: HSlider
var syncing: bool = false
var manual_capture: bool = false
var paused: bool = false
var slow: bool = false

func _ready() -> void:
	rig = get_node("CatRig")
	player = get_node("AnimationPlayer")
	player.play("meal")
	var title := Label.new()
	title.position = Vector2(54,36)
	title.text = "软糯虎斑 · 晚饭时间"
	title.add_theme_font_size_override("font_size",28)
	title.add_theme_color_override("font_color",Color("334d40"))
	add_child(title)
	var subtitle := Label.new()
	subtitle.position = Vector2(55,78)
	subtitle.text = "一只猫的动作样片  /  期待 → 小跳靠近 → 吃饭 → 满足"
	subtitle.add_theme_font_size_override("font_size",16)
	subtitle.add_theme_color_override("font_color",Color("7d8470"))
	add_child(subtitle)
	phase_label = Label.new()
	phase_label.position = Vector2(56,120)
	phase_label.add_theme_font_size_override("font_size",19)
	phase_label.add_theme_color_override("font_color",Color("b98250"))
	add_child(phase_label)
	var actions := HBoxContainer.new()
	actions.position = Vector2(55,566)
	actions.add_theme_constant_override("separation",12)
	add_child(actions)
	for item in ["重播","暂停 / 继续","慢放 ×0.65"]:
		var button := Button.new()
		button.text = item
		button.pressed.connect(control_animation.bind(item))
		actions.add_child(button)
	progress = HSlider.new()
	progress.position = Vector2(440,574)
	progress.size = Vector2(420,24)
	progress.min_value = 0
	progress.max_value = 6
	progress.step = 0.001
	progress.value_changed.connect(scrub)
	add_child(progress)

func control_animation(action: String) -> void:
	match action:
		"重播":
			paused = false
			player.play("meal")
			player.seek(0,true)
		"暂停 / 继续":
			paused = not paused
			if paused: player.pause()
			else: player.play("meal")
		"慢放 ×0.65":
			slow = not slow
			player.speed_scale = 0.65 if slow else 1.0

func scrub(value: float) -> void:
	if syncing: return
	player.pause()
	paused = true
	player.seek(value,true)

func set_time(value: float) -> void:
	player.pause()
	rig.pose_time = value
	refresh()

func _process(delta: float) -> void:
	if manual_capture: return
	var target: Vector2 = (get_local_mouse_position()-rig.position-rig.head_root.position).normalized()
	rig.mouse_gaze = rig.mouse_gaze.lerp(target,1-exp(-delta*10))
	refresh()

func refresh() -> void:
	var t: float = rig.pose_time
	phase_label.text = "闻到猫粮，期待地看一眼" if t<1.08 else ("压一压，轻轻跳过去" if t<2.1 else ("低头开饭，耳朵和尾巴慢半拍" if t<4.6 else "抬头回弹，舔舔嘴，吃饱啦"))
	syncing = true
	progress.value = t
	syncing = false
	queue_redraw()

func ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var polygon := PackedVector2Array()
	for i in 48:
		var angle: float = i*TAU/48
		polygon.append(center+Vector2(cos(angle),sin(angle))*radii)
	draw_colored_polygon(polygon,color)

func _draw() -> void:
	if rig == null: return
	# 地毯、阴影与食盆的内沿在角色后方，外壁由前景绘制。
	ellipse(Vector2(480,481),Vector2(365,44),Color("e8dfc9"))
	var at := Vector2(664,455)
	ellipse(at+Vector2(0,24),Vector2(108,15),Color(0.32,0.28,0.18,0.12))
	ellipse(at,Vector2(108,39),Color("c8845b"))
	ellipse(at-Vector2(0,5),Vector2(97,29),Color("805b42"))
	var ratio: float = 1.0-smoothstep(2.75,4.45,rig.pose_time)
	for i in int(54*ratio):
		var p := Vector2(fmod(i*37.0,161)-80,fmod(i*19.0,30)-20)
		if pow(p.x/88,2)+pow(p.y/30,2)>1: continue
		draw_circle(at+p,5.5,Color("d7a962") if i%2==0 else Color("b77d42"))
	# 前景食盆用独立节点，覆盖低头进食时的嘴部与身体。
	if not has_node("BowlFront"):
		var foreground := Node2D.new()
		foreground.name = "BowlFront"
		foreground.z_index = 4
		foreground.draw.connect(draw_bowl_front.bind(foreground))
		add_child(foreground)
	get_node("BowlFront").queue_redraw()

func draw_bowl_front(canvas: Node2D) -> void:
	var at := Vector2(664,455)
	canvas.draw_colored_polygon(PackedVector2Array([at+Vector2(-106,0),at+Vector2(106,0),at+Vector2(84,49),at+Vector2(-84,49)]),Color("cb8059"))
	canvas.draw_line(at+Vector2(-104,0),at+Vector2(104,0),Color("f5cd9d"),5,true)
	canvas.draw_circle(at+Vector2(0,25),9,Color("ffe5bc"))
	for off in [Vector2(-11,12),Vector2(0,8),Vector2(11,12)]:
		canvas.draw_circle(at+off,4,Color("ffe5bc"))
	if rig.pose_time>4.85:
		for i in 3:
			var h := Vector2(540+i*34,187-sin(rig.pose_time*2+i)*8)
			canvas.draw_circle(h,5,Color("d89a86"))
			canvas.draw_circle(h+Vector2(7,0),5,Color("d89a86"))
			canvas.draw_colored_polygon(PackedVector2Array([h+Vector2(-5,2),h+Vector2(12,2),h+Vector2(3.5,12)]),Color("d89a86"))
