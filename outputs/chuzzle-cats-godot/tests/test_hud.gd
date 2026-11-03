extends SceneTree
var failures: int=0
func check(ok: bool,message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func click(viewport: SubViewport, at: Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=at
	viewport.push_input(motion,true)
	for down in [true,false]:
		var button:=InputEventMouseButton.new()
		button.button_index=MOUSE_BUTTON_LEFT
		button.pressed=down
		button.position=at
		viewport.push_input(button,true)
	await process_frame

func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(540,960)
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	var hud: Control=game.hud
	check(game.view.external_surface,"Board preserves the chosen felt skin")
	check(hud.stage.size==Vector2(540,960),"Reference layout uses portrait stage")
	check(game.view.size.x>=500,"Board keeps near-full screen width")
	await click(viewport,Vector2(60,30))
	check(hud.menu_overlay.visible,"Pointer click opens menu")
	for i in 3:
		var level_button: Button
		for child: Node in hud.menu_overlay.get_children():
			if child is Button and child.text=="关卡 %d" % (i+1): level_button=child
		check(level_button.text=="关卡 %d" % (i+1),"Expected level control")
		level_button.pressed.emit()
		check(game.level_index==i,"Menu level button selects the correct level")
		if i<2: hud.toggle_menu()
	check(not hud.menu_overlay.visible,"Selecting level closes menu")
	game.score=12
	game.moves=6
	game._refresh()
	check(hud.food_label.text=="猫粮 12 / 50" and hud.moves_label.text=="6","Food and move labels reflect game state")
	var original: Array=game.view.board.duplicate(true)
	var remaining: int=game.shuffles_left
	game.shuffle_button.pressed.emit()
	check(game.shuffles_left==remaining-1 and game.view.board!=original,"Bottom tool performs real limited reshuffle")
	# Board and food station transforms must still align after responsive scaling.
	viewport.size=Vector2i(360,640)
	await process_frame
	await process_frame
	check(is_equal_approx(hud.stage.scale.x,2.0/3),"Stage scales at 360x640")
	game.station.add_food([Vector2i(2,3)],game.view)
	var from: Vector2=game.station.flights.back().from
	var rect: Rect2=game.view.board_rect()
	var expected: Vector2=game.view.get_global_transform_with_canvas()*(rect.position+Vector2(2.5,3.5)*rect.size.x/6)
	var actual: Vector2=game.station.get_global_transform_with_canvas()*from
	check(actual.distance_to(expected)<0.01,"Flying food originates at actual cat under scale")
	game.station.meal_time=0.5
	await process_frame
	check(hud.meal_dim.visible and hud.meal_title.visible,"Eating presentation overlays the board")
	game.start_level(0)
	await process_frame
	check(not hud.meal_dim.visible and not game.next_button.visible,"Restart closes old meal result")
	print("RESULT HUD controls and responsive transforms: ",failures," failures")
	viewport.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
