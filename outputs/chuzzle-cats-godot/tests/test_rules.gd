extends SceneTree
const Rules = preload("res://scripts/cat_rules.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sparse: Array = []
	for y in 6:
		sparse.append([-1,-1,-1,-1,-1,-1])
	sparse[0][0]=0; sparse[1][0]=0; sparse[1][1]=0
	check(Rules.matches(sparse).size()==3,"L shape must match")
	sparse[1][0]=-1; sparse[2][2]=0
	check(Rules.matches(sparse).is_empty(),"Diagonal must not match")
	sparse[1][1]=-1; sparse[2][2]=-1; sparse[0][5]=0; sparse[1][5]=0
	check(Rules.matches(sparse).is_empty(),"Opposite edges must not connect")
	var rng := RandomNumberGenerator.new()
	for colors in [7,8,9]:
		for seed_value in range(1,101):
			rng.seed=seed_value
			var a: Array=Rules.fresh(rng,colors)
			check(Rules.matches(a).is_empty(),"Initial board must be stable")
			check(not Rules.hint(a).is_empty(),"Initial board must have a move")
			rng.seed=seed_value
			check(a==Rules.fresh(rng,colors),"Seed must reproduce initial board")
			for axis in 2:
				check(Rules.shifted(Rules.shifted(a,axis,2,3),axis,2,-3)==a,"Shift inverse must restore board")
	print("PASS: matching, cyclic moves, 300 seeded stable/playable/reproducible boards")
	Engine.time_scale = 30
	var scene: PackedScene=load("res://scenes/main.tscn")
	var game=scene.instantiate()
	root.add_child(game)
	await process_frame
	for level_index in 3:
		game.start_level(level_index)
		var steps: int=0
		while not game.finished and steps<25:
			var h: Dictionary=Rules.hint(game.view.board,game.view.cat_locks)
			check(not h.is_empty(),"Active board requires a move")
			if h.is_empty(): break
			await game.request_move(h.axis,h.line,h.delta)
			check(not game.busy,"Move should finish")
			check(Rules.matches(game.view.board).is_empty(),"Resolution should leave a stable board")
			steps+=1
		check(game.finished and game.score>=game.data.target,"Demo level must be completable by immediate-match hint strategy")
		print("PASS level %d: %d steps, %d points" % [level_index+1,steps,game.score])
	game.start_level(0)
	var before: Array=game.view.board.duplicate(true)
	var invalid: Dictionary={}
	for line in 6:
		for delta in range(1,6):
			if Rules.matches(Rules.shifted(before,0,line,delta)).is_empty():
				invalid={"line":line,"delta":delta}
	if not invalid.is_empty():
		var budget: int=game.moves
		await game.request_move(0,invalid.line,invalid.delta)
		check(game.moves==budget and game.score==0 and game.view.board==before,"Invalid move must roll back without cost")
	var h: Dictionary=Rules.hint(game.view.board,game.view.cat_locks)
	game.request_move(h.axis,h.line,h.delta)
	game.start_level(1)
	await create_timer(0.2).timeout
	check(game.score==0 and game.moves==game.data.moves and not game.busy,"Restart must cancel old asynchronous move")
	# 补球不能修改存活猫的相对顺序。
	var holes: Array=before.duplicate(true)
	holes[0][0]=-1; holes[3][0]=-1
	var survivors: Array=[]
	for y in 6:
		if holes[y][0]>=0: survivors.append(holes[y][0])
	for suppress in [false,true]:
		rng.seed=42
		var filled: Array=Rules.refill(holes,rng,5,suppress)
		for i in survivors.size():
			check(filled[i+2][0]==survivors[i],"Refill must preserve survivors in order")

	print("PASS: invalid rollback, restart cancellation, refill ordering")
	print("RESULT: %d failures" % failures)
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)


