extends SceneTree
const Rules = preload("res://scripts/cat_rules.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var view = preload("res://scripts/board_view.gd").new()
	view.size=Vector2(396,396)
	root.add_child(view)
	view.set_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed=42
	var before: Array=Rules.fresh(rng,9)
	var holes: Array=before.duplicate(true)
	for y in [0,2,4]: holes[y][0]=-1
	holes[4][1]=-1
	for y in 6: holes[y][2]=-1
	view.board=holes
	view.cat_locks=[Vector2i(1,1),Vector2i(0,4)]
	var filled: Array=Rules.refill(holes,rng,9,true)
	var rng_snapshot: int=rng.state
	var duration: float=view.start_refill(filled)
	check(duration>0.4 and duration<0.9,"Refill duration must reflect travel and landing")
	check(rng.state==rng_snapshot,"Animation must not consume gameplay random numbers")
	check(view.cat_locks==[Vector2i(1,2)],"Locks follow surviving cats, cleared locks disappear")
	check(view.falling_row(Vector2i(0,3))==1,"Survivor starts at original row")
	check(view.falling_row(Vector2i(1,2))==1,"Locked survivor starts at original row")
	for y in 3:
		check(view.falling_row(Vector2i(0,y))<0,"New cats must start above the board")
	for y in 6:
		check(view.falling_row(Vector2i(2,y))<0,"Full column refill must enter from above")
	for y in 6:
		check(view.falling_row(Vector2i(5,y))==y,"Unaffected columns remain still")
	view.refill_clock=duration*0.4
	check(view.falling_row(Vector2i(0,3))>1 and view.falling_row(Vector2i(0,3))<3,"Survivor must visibly pass through intermediate positions")
	view.refill_clock=duration
	for y in 6:
		for x in 6:
			check(is_equal_approx(view.falling_row(Vector2i(x,y)),y),"Every cat must land on its final cell")
	view.finish_refill()
	check(not view.refill_active and view.refill_entries.is_empty() and view.board==filled,"Finish clears visual tracks without changing refill results")
	view.board=holes
	view.start_refill(filled)
	view.cancel_refill()
	check(not view.refill_active and view.refill_entries.is_empty(),"Restart cancellation clears all old motion")
	view.queue_free()
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var h: Dictionary=Rules.hint(game.view.board)
	game.request_move(h.axis,h.line,h.delta)
	var deadline: int=Time.get_ticks_msec()+3000
	while not game.view.refill_active and Time.get_ticks_msec()<deadline:
		await process_frame
	check(game.view.refill_active and game.busy and game.view.locked,"Input stays locked while cats are falling")
	check(game.view.highlight.is_empty(),"Next cascade must not pop before landing")
	game.start_level(2)
	var restarted: Array=game.view.board.duplicate(true)
	await create_timer(1.1).timeout
	check(game.view.board==restarted and game.score==0 and not game.busy and not game.view.refill_active,"Restart mid-refill must cancel old board, score and animation")
	print("RESULT refill animation: ",failures," failures")
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
