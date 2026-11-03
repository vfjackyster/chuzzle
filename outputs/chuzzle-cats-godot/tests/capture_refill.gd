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
	var folder: String=ProjectSettings.globalize_path("res://../../work/refill-v7-frames")
	DirAccess.make_dir_recursive_absolute(folder)
	var captured_fall: bool=false
	for frame in 120:
		if frame in [8,55,95] and not game.busy and not game.finished:
			var h: Dictionary=game.Rules.hint(game.view.board,game.view.cat_locks)
			game.request_move(h.axis,h.line,h.delta)
		await create_timer(1.0/24).timeout
		RenderingServer.force_draw(false)
		var img: Image=viewport.get_texture().get_image()
		assert(img.save_png(folder+"/frame_%03d.png" % frame)==OK)
		if not captured_fall and game.view.refill_active and game.view.refill_clock>0.18:
			captured_fall=true
			img.save_png(ProjectSettings.globalize_path("res://../小猫补落过程.png"))
	assert(captured_fall,"Capture must include actual running refill animation")
	print("PASS real-render refill capture 120 frames")
	viewport.queue_free()
	await process_frame
	quit()
