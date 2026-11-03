extends Control
class_name CatBoardView

signal move_requested(axis: int, line: int, delta: int)
signal move_blocked(axis: int, line: int)
const MoveRules = preload("res://scripts/cat_rules.gd")
@export var arcade_style: bool = false
@export var external_surface: bool = false
var board: Array = []
var cat_clip: Control
var cat_canvas: Node2D
var refill_active: bool = false
var refill_clock: float = 0.0
var refill_duration: float = 0.0
var refill_entries: Dictionary = {}
var cat_locks: Array = []:
	set(value):
		cat_locks = value
		if is_node_ready():
			if dragging and drag_axis >= 0 and not axis_available(drag_axis):
				cancel_drag()
			redraw_board()
var bursts: Array = []
var pop_clock: float = 0.0
var selected := Vector2i(2, 2)
var locked: bool = false:
	set(value):
		locked = value
		if value and dragging:
			cancel_drag()
var highlight: Array = []
var hint_data: Dictionary = {}
var dragging: bool = false
var start_point := Vector2.ZERO
var drag_axis: int = -1
var drag_offset: float = 0.0
# 形变独立于视线；关闭眼睛跟随时拖动仍有弹性。
var motion_axis: int = -1
var motion_line: int = -1
var motion_amount: float = 0.0
var motion_velocity: float = 0.0
var pointer_velocity: float = 0.0
var previous_drag_offset: float = 0.0
var motion_clock: float = 0.0
var blocked_axis: int = -1
var blocked_flash: float = 0.0
const COATS: Array[Color] = [Color("efb25c"), Color("faf4e6"), Color("555967"), Color("eee2c8"), Color("c4b4a0"), Color("f5ebdd")]
const INK := Color("34333b")

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cat_clip = Control.new()
	cat_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cat_clip.clip_contents = true
	add_child(cat_clip)
	cat_canvas = Node2D.new()
	cat_clip.add_child(cat_canvas)
	cat_canvas.draw.connect(draw_cat_layer.bind(cat_canvas))
	resized.connect(sync_cat_layer)
	sync_cat_layer()

func board_rect() -> Rect2:
	var side: float = minf(size.x, size.y) - 12.0
	return Rect2((size - Vector2.ONE * side) / 2.0, Vector2.ONE * side)

func axis_available(axis: int) -> bool:
	return MoveRules.can_shift(axis,selected.y if axis==0 else selected.x,cat_locks)

func cancel_drag(rebound: bool = false) -> void:
	dragging = false
	drag_axis = -1
	drag_offset = 0.0
	previous_drag_offset = 0.0
	pointer_velocity = 0.0
	blocked_axis = -1
	if not rebound:
		motion_axis = -1
		motion_line = -1
		motion_amount = 0.0
		motion_velocity = 0.0
		blocked_flash = 0.0
	redraw_board()

func reject_axis(axis: int) -> void:
	if blocked_axis != axis:
		move_blocked.emit(axis,selected.y if axis==0 else selected.x)
	blocked_axis = axis
	blocked_flash = 0.25
	drag_offset = 0.0
	redraw_board()

func begin_drag(point: Vector2) -> void:
	if locked:
		return
	var rect: Rect2 = board_rect()
	if not rect.has_point(point):
		return
	cancel_drag()
	var cell: Vector2 = (point-rect.position)/(rect.size.x/6.0)
	selected = Vector2i(int(cell.x),int(cell.y))
	if not axis_available(0) and not axis_available(1):
		reject_axis(0)
		return
	start_point = point
	dragging = true
	grab_focus()
	redraw_board()

func drag_to(point: Vector2) -> void:
	if not dragging:
		return
	if locked:
		cancel_drag()
		return
	var diff: Vector2 = point-start_point
	if drag_axis < 0:
		if diff.length() <= 8.0:
			return
		var axis: int = 0 if absf(diff.x)>absf(diff.y) else 1
		if not axis_available(axis):
			reject_axis(axis)
			return
		drag_axis = axis
		motion_axis = axis
		motion_line = selected.y if axis==0 else selected.x
		blocked_axis = -1
	if not axis_available(drag_axis):
		cancel_drag()
		return
	drag_offset = diff.x if drag_axis==0 else diff.y
	redraw_board()

func finish_drag() -> void:
	if not dragging:
		return
	var axis: int = drag_axis
	var line: int = selected.y if axis==0 else selected.x
	var allowed: bool = axis>=0 and not locked and axis_available(axis)
	var delta: int = roundi(drag_offset/(board_rect().size.x/6.0))
	cancel_drag(allowed)
	if allowed and delta%6!=0:
		move_requested.emit(axis,line,delta)

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		begin_drag(event.position)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		var axis: int = -1
		var delta: int = 0
		match event.keycode:
			KEY_LEFT: axis=0; delta=-1
			KEY_RIGHT: axis=0; delta=1
			KEY_UP: axis=1; delta=-1
			KEY_DOWN: axis=1; delta=1
		if axis>=0:
			if axis_available(axis):
				move_requested.emit(axis,selected.y if axis==0 else selected.x,delta)
			else:
				reject_axis(axis)
			accept_event()

func _input(event: InputEvent) -> void:
	if not dragging:
		return
	if event is InputEventMouseMotion:
		drag_to(get_global_transform_with_canvas().affine_inverse()*event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		finish_drag()

# 有界时间步弹簧：快速拖动更明显，停住和松手后自动恢复。
func update_drag_motion(delta: float) -> void:
	var was_animating: bool = motion_axis>=0 or blocked_flash>0
	var elapsed: float = clampf(delta,0.0,0.1)
	motion_clock += elapsed
	blocked_flash = maxf(0,blocked_flash-elapsed)
	var target: float = 0.0
	if dragging and drag_axis>=0:
		if not axis_available(drag_axis):
			cancel_drag()
			return
		var speed: float = (drag_offset-previous_drag_offset)/maxf(elapsed,0.001)
		pointer_velocity = lerpf(pointer_velocity,speed,1-exp(-elapsed*18))
		previous_drag_offset = drag_offset
		var cell_size: float = maxf(board_rect().size.x/6.0,1)
		target = clampf(pointer_velocity/(cell_size*14),-0.75,0.75)+clampf(drag_offset/cell_size,-1,1)*0.25
	var steps: int = maxi(1,ceili(elapsed*120))
	var dt: float = elapsed/steps
	for i in steps:
		motion_velocity += ((target-motion_amount)*190-motion_velocity*17)*dt
		motion_amount += motion_velocity*dt
	motion_amount = clampf(motion_amount,-1.1,1.1)
	if not dragging and absf(motion_amount)<0.001 and absf(motion_velocity)<0.01:
		motion_amount=0
		motion_velocity=0
		motion_axis=-1
		motion_line=-1
	if was_animating or motion_axis>=0 or blocked_flash>0:
		redraw_board()

func head_drag_pose(cell: Vector2i) -> Vector3:
	if motion_axis<0 or not MoveRules.can_shift(motion_axis,motion_line,cat_locks):
		return Vector3.ZERO
	if (motion_axis==0 and cell.y!=motion_line) or (motion_axis==1 and cell.x!=motion_line):
		return Vector3.ZERO
	var amount: float = motion_amount
	var wave: float = sin(motion_clock*10+float(cell.x+cell.y)*0.65)*absf(amount)*0.010
	var angle: float = amount*0.065+wave
	var stretch: float = absf(amount)*0.055
	return Vector3(angle,stretch,-stretch*0.65) if motion_axis==0 else Vector3(angle*0.7,-stretch*0.65,stretch)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_drag()

func _draw() -> void:
	var rect: Rect2 = board_rect()
	if rect.size.x <= 0:
		return
	if not external_surface:
		draw_style_box(_box(Color("02030b") if arcade_style else Color("203a32"),18), rect.grow(5))
	var cell: float = rect.size.x / 6.0
	for y in 6:
		for x in 6:
			var tile := Rect2(rect.position + Vector2(x, y) * cell, Vector2.ONE * cell)
			if not external_surface:
				draw_style_box(_box(Color("02030b") if arcade_style else (Color("2c493d") if (x+y)%2==0 else Color("29453a")),8), tile.grow(-2))
			if not hint_data.is_empty() and ((hint_data.axis == 0 and hint_data.line == y) or (hint_data.axis == 1 and hint_data.line == x)):
				draw_rect(tile.grow(-2), Color(0.85, 0.94, 0.53, 0.22))
	if blocked_flash>0 and blocked_axis>=0:
		var stripe := Rect2(rect.position+Vector2(0,selected.y*cell),Vector2(rect.size.x,cell)) if blocked_axis==0 else Rect2(rect.position+Vector2(selected.x*cell,0),Vector2(cell,rect.size.y))
		draw_rect(stripe,Color(0.95,0.6,0.35,blocked_flash*0.55))
	if board.is_empty():
		return
	if cat_canvas != null:
		cat_canvas.queue_redraw()
	for burst: Dictionary in bursts:
		var at: Vector2 = rect.position+(Vector2(burst.cell)+Vector2.ONE*0.5)*cell
		var t: float = burst.age/0.65
		draw_set_transform(Vector2.ZERO)
		draw_arc(at,cell*(0.22+t*0.5),0,TAU,32,Color(1,0.85,0.48,1-t),3*(1-t),true)
		for j in 8:
			var angle: float = j*TAU/8.0
			var point: Vector2 = at+Vector2(cos(angle),sin(angle))*cell*t*0.68
			draw_circle(point,3.5*(1-t),Color(1,0.91,0.65,1-t))
	if not dragging:
		draw_rect(Rect2(rect.position + Vector2(selected) * cell + Vector2.ONE*3, Vector2.ONE * (cell-6)), Color("e2efac"), false, 2)
	draw_set_transform(Vector2.ZERO)

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


# Animation-ready image layer: GPT Image fur/ears/nose + independent eye animation.
const CAT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/cats/natural-v1/tabby.png"),
	preload("res://assets/cats/natural-v1/blue.png"),
	preload("res://assets/cats/natural-v1/cow.png"),
	preload("res://assets/cats/natural-v1/black.png"),
	preload("res://assets/cats/natural-v1/white.png"),
	preload("res://assets/cats/natural-v1/siamese.png"),
	preload("res://assets/cats/natural-v1/calico.png"),
	preload("res://assets/cats/natural-v1/bengal.png"),
	preload("res://assets/cats/natural-v1/tortoiseshell.png")
]
@export var animate_eyes: bool = true
@export var show_cat_numbers: bool = true
var animation_clock: float = 0.0
var redraw_budget: float = 0.0
var gaze_tracking: bool = false
var gaze_target_ready: bool = false
var smoothed_gaze_target := Vector2.ZERO
const EYE_OFFSETS: Array[Vector2] = [Vector2(14.4,-0.96),Vector2(14.4,-0.96),Vector2(14.4,-0.96),Vector2(14.4,-0.96),Vector2(14.4,-0.96),Vector2(14.4,-0.96),Vector2(14.4,-0.96),Vector2(14.4,-0.96),Vector2(14.4,-0.96)]
const IRIS_COLORS: Array[Color] = [Color("a5b778"),Color("d8a14e"),Color("84adb3"),Color("d8ba60"),Color("98b779"),Color("75b7d2"),Color("a5b778"),Color("9cbf78"),Color("d6aa4e")]

func _process(delta: float) -> void:
	if refill_active:
		refill_clock = minf(refill_clock+maxf(delta,0),refill_duration)
		redraw_board()
	update_drag_motion(delta)
	pop_clock += delta
	for i in range(bursts.size()-1,-1,-1):
		bursts[i].age += delta
		if bursts[i].age > 0.65:
			bursts.remove_at(i)
	if not bursts.is_empty() or not highlight.is_empty():
		redraw_board()
	if not animate_eyes or not is_visible_in_tree():
		return
	animation_clock += delta
	var cursor_inside: bool = get_viewport().get_visible_rect().has_point(get_viewport().get_mouse_position())
	update_gaze(delta, get_local_mouse_position(), cursor_inside)
	redraw_budget += delta
	if redraw_budget >= 1.0 / 30.0:
		redraw_budget = fmod(redraw_budget, 1.0 / 30.0)
		redraw_board()

# Cursor target is shared, but each cat calculates its own direction from its center.
func update_gaze(delta: float, target: Vector2, active: bool) -> void:
	gaze_tracking = active
	if not active:
		gaze_target_ready = false
		return
	if not gaze_target_ready:
		smoothed_gaze_target = target
		gaze_target_ready = true
	else:
		smoothed_gaze_target = smoothed_gaze_target.lerp(target, 1.0 - exp(-maxf(delta, 0.0) * 16.0))

func gaze_for_target(center: Vector2, factor: float, target: Vector2) -> Vector2:
	var toward: Vector2 = (target - center) / maxf(factor, 0.001)
	var strength: float = minf(toward.length() / 60.0, 1.0)
	var direction: Vector2 = toward.normalized() * strength
	return Vector2(direction.x * 3.2, direction.y * 3.4)

func _eye(center: Vector2, gaze: Vector2, iris: Color, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var outline := PackedVector2Array()
	for i in 33:
		var angle: float = TAU * float(i) / 32.0
		outline.append(center + Vector2(cos(angle)*9.8,sin(angle)*11.7))
	canvas.draw_colored_polygon(outline, Color("fffdf4"))
	canvas.draw_polyline(outline,INK,1.15,true)
	# Eyes stay open; only the gaze moves.
	var iris_center: Vector2 = center + Vector2(gaze.x,gaze.y)
	var iris_shape := PackedVector2Array()
	var pupil_shape := PackedVector2Array()
	for i in 32:
		var angle: float = TAU * float(i) / 32.0
		iris_shape.append(iris_center+Vector2(cos(angle)*5.9,sin(angle)*7.2))
		pupil_shape.append(iris_center+Vector2(cos(angle)*3.2,sin(angle)*5.8))
	canvas.draw_colored_polygon(iris_shape,iris)
	canvas.draw_colored_polygon(pupil_shape,INK)
	canvas.draw_circle(iris_center+Vector2(-1.6,-2.6),1.7,Color.WHITE)
	canvas.draw_circle(iris_center+Vector2(1.7,2.0),0.75,Color(1,1,1,0.75))

func _cat(center: Vector2, scale_value: float, kind: int, popping: bool, identity: int = 0, drag_pose: Vector3 = Vector3.ZERO, canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	var factor: float = scale_value * (1.0 + sin(minf(pop_clock/0.28,1.0)*PI)*0.22 if popping else 1.0)
	var stretch := Vector2(1+drag_pose.y,1+drag_pose.z)
	canvas.draw_set_transform(center,drag_pose.x,stretch*factor)
	canvas.draw_texture_rect(CAT_TEXTURES[kind],Rect2(-48,-48,96,96),false)
	var gaze := Vector2.ZERO

	if animate_eyes:
		gaze = Vector2(sin(animation_clock*0.63+identity*1.7)*1.4,sin(animation_clock*0.4+identity)*0.7)
		if gaze_tracking:
			var target: Vector2 = smoothed_gaze_target-(board_rect().position if canvas!=self else Vector2.ZERO)
			var local_target: Vector2 = center+(target-center).rotated(-drag_pose.x)/stretch
			gaze = gaze_for_target(center,factor,local_target)

	for side in [-1,1]:
		_eye(Vector2(side*EYE_OFFSETS[kind].x,EYE_OFFSETS[kind].y),gaze,IRIS_COLORS[kind],canvas)
	if show_cat_numbers:
		canvas.draw_circle(Vector2(0,42),8.5,Color("fff9e8"))
		canvas.draw_arc(Vector2(0,42),8.5,0,TAU,32,Color("6a6350"),1.0,true)
		canvas.draw_string(ThemeDB.fallback_font,Vector2(-3.7,46.3),str(kind+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,INK)
	canvas.draw_set_transform(Vector2.ZERO)






func celebrate(cells: Array) -> void:
	pop_clock = 0.0
	for cell: Vector2i in cells:
		bursts.append({"cell":cell,"age":0.0})
	redraw_board()

func redraw_board() -> void:
	queue_redraw()
	if is_instance_valid(cat_canvas): cat_canvas.queue_redraw()

func sync_cat_layer() -> void:
	if not is_instance_valid(cat_clip): return
	var rect: Rect2 = board_rect()
	cat_clip.position = rect.position
	cat_clip.size = rect.size
	redraw_board()

func cancel_refill() -> void:
	refill_active = false
	refill_clock = 0
	refill_duration = 0
	refill_entries.clear()
	redraw_board()

# 此处只建立位置轨迹，不重抽猫、不消耗游戏随机数。
func start_refill(filled: Array) -> float:
	cancel_refill()
	var fallen: Array = MoveRules.fallen_locks(board,cat_locks)
	for x in 6:
		var survivors: Array = []
		for y in 6:
			if board[y][x]>=0: survivors.append(y)
		var missing: int = 6-survivors.size()
		for y in 6:
			var source_y: float = y-missing if y<missing else survivors[y-missing]
			var distance: float = y-source_y
			if distance <= 0: continue
			var delay: float = x*0.014+(missing-1-y)*0.018 if y<missing else x*0.014
			var duration: float = 0.22+sqrt(distance)*0.075
			refill_entries[Vector2i(x,y)] = {"from":source_y,"delay":delay,"duration":duration,"new":y<missing}
			refill_duration = maxf(refill_duration,delay+duration+0.13)
	board = filled
	cat_locks = fallen
	refill_active = not refill_entries.is_empty()
	redraw_board()
	return refill_duration

func finish_refill() -> void:
	refill_active = false
	refill_entries.clear()
	refill_clock = refill_duration
	redraw_board()

func falling_row(cell: Vector2i) -> float:
	if not refill_active or not refill_entries.has(cell): return cell.y
	var entry: Dictionary = refill_entries[cell]
	var elapsed: float = refill_clock-float(entry.delay)
	if elapsed<=0: return entry.from
	var t: float = elapsed/float(entry.duration)
	if t<1: return lerpf(entry.from,cell.y,t*t)
	var landing: float = clampf((elapsed-float(entry.duration))/0.13,0,1)
	return cell.y+sin(landing*PI)*0.045

func falling_pose(cell: Vector2i) -> Vector3:
	if not refill_active or not refill_entries.has(cell): return Vector3.ZERO
	var entry: Dictionary = refill_entries[cell]
	var elapsed: float = refill_clock-float(entry.delay)
	if elapsed<0: return Vector3.ZERO
	if elapsed<float(entry.duration):
		var t: float = elapsed/float(entry.duration)
		return Vector3(0,-0.018*t,0.035*t)
	var landing: float = clampf((elapsed-float(entry.duration))/0.13,0,1)
	var squash: float = sin(landing*PI)
	return Vector3(0,squash*0.065,-squash*0.045)

func draw_cat_layer(canvas: CanvasItem) -> void:
	if board.is_empty(): return
	var side: float = board_rect().size.x
	var cell: float = side/6
	for y in 6:
		for x in 6:
			var kind: int = board[y][x]
			if kind<0: continue
			var where := Vector2i(x,y)
			var center := Vector2((x+0.5)*cell,(falling_row(where)+0.5)*cell)
			var active: bool = dragging and drag_axis>=0 and axis_available(drag_axis) and ((drag_axis==0 and selected.y==y) or (drag_axis==1 and selected.x==x))
			if active:
				if drag_axis==0: center.x=fposmod(center.x+drag_offset,side)
				else: center.y=fposmod(center.y+drag_offset,side)
			var pose: Vector3 = falling_pose(where) if refill_active else head_drag_pose(where)
			_cat(center,cell/108,kind,where in highlight,y*6+x,pose,canvas)
			# 循环拖动的边界补绘同一只猫，由父控件裁剪，消除半个头突然跳边的现象。
			if active:
				var offset: Vector2 = Vector2(side,0) if drag_axis==0 else Vector2(0,side)
				_cat(center-offset,cell/108,kind,false,y*6+x,pose,canvas)
				_cat(center+offset,cell/108,kind,false,y*6+x,pose,canvas)
	for where: Vector2i in cat_locks:
		if board[where.y][where.x]<0: continue
		var at := Vector2((where.x+0.78)*cell,(falling_row(where)+0.76)*cell)
		canvas.draw_set_transform(Vector2.ZERO)
		canvas.draw_arc(at+Vector2(0,-7),6,PI,TAU,16,Color("ffe2a1"),3,true)
		canvas.draw_style_box(_box(Color("d89645"),3),Rect2(at-Vector2(9,4),Vector2(18,15)))
		canvas.draw_circle(at+Vector2(0,2),2,Color("654624"))
	canvas.draw_set_transform(Vector2.ZERO)
