extends SceneTree
func _initialize() -> void:
	root.visible=false
	call_deferred("run")
func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(540,900)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.start_level(2)
	game.view.set_process(false)
	game.view.animate_eyes=false
	game.view.move_requested.disconnect(Callable(game,"request_move"))
	game.view.cat_locks=[Vector2i(1,1)]
	var rect: Rect2=game.view.board_rect()
	var cell: float=rect.size.x/6
	var free_at: Vector2=rect.position+Vector2(2.5,4.5)*cell
	var locked_at: Vector2=rect.position+Vector2(3.5,1.5)*cell
	var column_at: Vector2=rect.position+Vector2(1.5,3.5)*cell
	var folder: String=ProjectSettings.globalize_path("res://../../work/drag-v6-frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var original: Array=game.view.board.duplicate(true)
	for frame in 120:
		if frame==0:
			game.view.begin_drag(free_at)
		if frame<48:
			var offset: float=sin(frame/48.0*TAU)*cell*1.4
			game.view.drag_to(free_at+Vector2(offset,0))
			game.status.text="轻轻拖动：猫头随速度摆动、拉伸"
		elif frame==48:
			game.view.finish_drag()
		elif frame<72:
			game.status.text="松开后，猫头柔和回弹"
		elif frame<96:
			if frame==72: game.view.begin_drag(locked_at)
			game.view.drag_to(locked_at+Vector2(cell*1.6,0))
			game.status.text="锁行测试：拖动被阻止，猫头保持原位"
		else:
			if frame==96:
				game.view.finish_drag()
				game.view.begin_drag(column_at)
			game.view.drag_to(column_at+Vector2(0,cell*1.6))
			game.status.text="锁列测试：拖动被阻止，猫头保持原位"
		game.view.update_drag_motion(1.0/24)
		game.view.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var img: Image=viewport.get_texture().get_image()
		assert(img.save_png(folder+"/frame_%03d.png" % frame)==OK)
		if frame==16: img.save_png(ProjectSettings.globalize_path("res://../猫头拖动形变.png"))
	assert(game.view.board==original,"Visual dragging must not mutate game data")
	print("PASS drag GPU capture: 120 frames; locked row and column retain original board")
	viewport.queue_free()
	await process_frame
	quit()
