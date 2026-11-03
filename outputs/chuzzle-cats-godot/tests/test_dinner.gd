extends SceneTree
const Rules = preload("res://scripts/cat_rules.gd")
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var random_policy := RandomNumberGenerator.new()
	var results: Array = []
	for level in 3:
		for greedy in [false,true]:
			var wins: int = 0
			var total_food: int = 0
			for seed_value in range(1,41):
				game.start_level(level)
				game.rng.seed = seed_value
				game.view.board = Rules.fresh(game.rng,game.data.cat_types)
				random_policy.seed = seed_value+9000
				for step in 10:
					var choices: Array = []
					for axis in 2:
						for line in 6:
							if not Rules.can_shift(axis,line,game.view.cat_locks): continue
							for delta in range(1,6):
								if not Rules.matches(Rules.shifted(game.view.board,axis,line,delta)).is_empty():
									choices.append({"axis":axis,"line":line,"delta":delta})
					if choices.is_empty():
						if game.shuffles_left<=0: break
						game.reshuffle()
						choices.append(Rules.hint(game.view.board))
					var action: Dictionary = Rules.hint(game.view.board,game.view.cat_locks) if greedy else choices[random_policy.randi_range(0,choices.size()-1)]
					game.view.board = Rules.shifted(game.view.board,action.axis,action.line,action.delta)
					var hit: Array = Rules.matches(game.view.board)
					var chain: int = 0
					while not hit.is_empty():
						game.score += hit.size()
						for cell: Vector2i in hit: game.view.board[cell.y][cell.x] = -1
						game.view.cat_locks = Rules.fallen_locks(game.view.board,game.view.cat_locks)
						game.view.board = Rules.refill(game.view.board,game.rng,game.data.cat_types,true)
						hit = Rules.matches(game.view.board)
						chain += 1
						check(chain<100,"Resolution must terminate")
						if chain>=100: break
					game.turns += 1
					if game.score >= game.data.target: break
					game.add_lock()
				if game.score >= game.data.target: wins += 1
				total_food += game.score
			results.append({"level":level+1,"policy":"greedy" if greedy else "random_valid","wins":wins,"samples":40,"mean_food":float(total_food)/40})
	print(JSON.stringify(results))
	var file := FileAccess.open("res://../猫咪晚饭难度抽样.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	# Core invariants: locked axes rejected, lock falls with surviving cat and disappears when cleared.
	check(not Rules.can_shift(0,2,[Vector2i(1,2)]),"Locked row rejects moves")
	check(not Rules.can_shift(1,1,[Vector2i(1,2)]),"Locked column rejects moves")
	check(Rules.can_shift(0,3,[Vector2i(1,2)]),"Other rows remain movable")
	game.start_level(2)
	var holes: Array = game.view.board.duplicate(true)
	holes[4][1] = -1
	check(Rules.fallen_locks(holes,[Vector2i(1,2),Vector2i(1,4)])==[Vector2i(1,3)],"Locks follow survivors and cleared locks vanish")
	var original: Array = game.view.board.duplicate(true)
	game.view.cat_locks = [Vector2i(1,2)]
	await game.request_move(0,2,1)
	check(game.view.board==original and game.moves==10,"Blocked request must cost nothing")
	Engine.time_scale = 30
	# Exercise real async pipeline, including eating gate; also restart mid-flight and mid-meal.
	for i in 3:
		game.start_level(i)
		var attempts: int = 0
		while not game.finished and attempts < 10:
			var h: Dictionary = Rules.hint(game.view.board,game.view.cat_locks)
			if h.is_empty():
				game.reshuffle()
				h = Rules.hint(game.view.board,game.view.cat_locks)
			if h.is_empty(): break
			await game.request_move(h.axis,h.line,h.delta)
			check(not game.busy,"Async move unlocks controls")
			check(Rules.matches(game.view.board).is_empty(),"Board stable after resolution")
			attempts += 1
		print("FIXED_LEVEL ",i+1," food=",game.score," moves=",game.moves," won=",game.station.happy)
	game.start_level(0)
	var h: Dictionary = Rules.hint(game.view.board)
	game.request_move(h.axis,h.line,h.delta)
	game.start_level(2)
	await create_timer(2).timeout
	check(game.score==0 and game.moves==10 and not game.busy and game.station.meal_time<0,"Restart cancels pending flights and async move")
	game.start_level(0)
	game.score = game.data.target-1
	h = Rules.hint(game.view.board)
	game.request_move(h.axis,h.line,h.delta)
	while game.station.meal_time<0:
		await process_frame
	check(game.busy and not game.finished and not game.next_button.visible,"Meal must finish before next level is offered")
	game.start_level(1)
	await create_timer(4).timeout
	check(not game.finished and not game.station.happy and game.score==0,"Restart during meal cancels old victory")
	print("RESULT ",failures," failures")
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
