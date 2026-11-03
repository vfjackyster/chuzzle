extends SceneTree
const Rules = preload("res://scripts/cat_rules.gd")
var requests: Array = []
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func press(view: Control, cell: Vector2i) -> Vector2:
	var rect: Rect2 = view.board_rect()
	var at: Vector2 = rect.position+(Vector2(cell)+Vector2.ONE*0.5)*rect.size.x/6
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=at
	view._gui_input(event)
	return at
func motion(view: Control, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=view.get_global_transform_with_canvas()*at
	view._input(event)
func release(view: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=false
	view._input(event)
func run() -> void:
	var view = preload("res://scripts/board_view.gd").new()
	view.size=Vector2(396,396)
	root.add_child(view)
	view.set_process(false)
	view.animate_eyes=false
	var rng := RandomNumberGenerator.new()
	rng.seed=42
	view.board=Rules.fresh(rng,9)
	var original: Array = view.board.duplicate(true)
	view.move_requested.connect(func(axis: int,line: int,delta: int): requests.append([axis,line,delta]))
	view.cat_locks=[Vector2i(2,2)]
	var at: Vector2=press(view,Vector2i(4,2))
	motion(view,at+Vector2(150,0))
	view.update_drag_motion(0.016)
	check(view.drag_axis==-1 and view.drag_offset==0 and view.motion_amount==0,"Locked row must never enter visual drag")
	release(view)
	check(requests.is_empty(),"Locked row must emit no request")
	at=press(view,Vector2i(2,4))
	motion(view,at+Vector2(0,-150))
	release(view)
	check(requests.is_empty() and view.drag_offset==0,"Locked column must not preview or commit")
	press(view,Vector2i(2,2))
	check(not view.dragging,"Locked cat must not initiate either-axis drag")
	at=press(view,Vector2i(4,2))
	motion(view,at+Vector2(0,70))
	check(view.drag_axis==1 and view.drag_offset==70,"Unlocked column crossing locked row remains usable")
	release(view)
	check(requests==[[1,4,1]],"Valid drag commits exactly once")
	requests.clear()
	# A denied axis may change to a permitted direction before release.
	at=press(view,Vector2i(4,2))
	motion(view,at+Vector2(50,0))
	motion(view,at+Vector2(10,70))
	release(view)
	check(requests==[[1,4,1]],"Switching away from blocked axis should remain possible")
	requests.clear()
	view.selected=Vector2i(2,2)
	for key in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
		var event := InputEventKey.new()
		event.keycode=key
		event.pressed=true
		view._gui_input(event)
	check(requests.is_empty(),"All four keys must respect row/column locks")
	view.cat_locks=[]
	at=press(view,Vector2i(4,2))
	motion(view,at+Vector2(90,0))
	view.update_drag_motion(0.04)
	check(absf(view.motion_amount)>0.01,"Drag produces visible deformation even with gaze disabled")
	check(view.head_drag_pose(Vector2i(4,1))==Vector3.ZERO,"Unselected cats stay undeformed")
	var pose: Vector3=view.head_drag_pose(Vector2i(4,2))
	check(absf(pose.x)<0.09 and absf(pose.y)<0.07 and pose.y>0,"Head tilt and stretch stay subtle")
	release(view)
	for i in 240: view.update_drag_motion(1.0/120)
	check(view.motion_amount==0 and view.motion_axis==-1,"Release rebound settles exactly to rest")
	requests.clear()
	at=press(view,Vector2i(4,2))
	motion(view,at+Vector2(90,0))
	view.cat_locks=[Vector2i(0,2)]
	check(not view.dragging and view.drag_offset==0,"Lock arriving mid-drag cancels preview immediately")
	release(view)
	check(requests.is_empty(),"Cancelled gesture must never commit")
	view.cat_locks=[]
	at=press(view,Vector2i(4,2))
	motion(view,at+Vector2(90,0))
	view.cat_locks.append(Vector2i(0,2))
	release(view)
	check(requests.is_empty(),"Release guard handles in-place lock mutation")
	view.cat_locks=[]
	at=press(view,Vector2i(4,2))
	motion(view,at+Vector2(90,0))
	view.locked=true
	check(not view.dragging and view.motion_amount==0,"Global busy lock cancels active drag")
	check(view.board==original,"Preview and blocked input must never mutate board data")
	print("RESULT drag/lock input regression: ",failures," failures")
	view.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
