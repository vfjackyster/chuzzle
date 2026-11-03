extends SceneTree
func _initialize() -> void:
	root.visible = false
	call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(540,900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.start_level(1)
	# 演示从接近完成的食盆开始；真正的通关门控由 test_dinner 验证。
	game.score = game.data.target-3
	game.station.food_amount = game.score
	game._refresh()
	var path: String = ProjectSettings.globalize_path("res://../../work/dinner-frames")
	DirAccess.make_dir_recursive_absolute(path)
	for frame in 96:
		if frame == 12:
			var h: Dictionary = game.Rules.hint(game.view.board)
			game.request_move(h.axis,h.line,h.delta)
		await create_timer(1.0/12).timeout
		RenderingServer.force_draw(false)
		var img: Image = viewport.get_texture().get_image()
		assert(img.save_png(path+"/frame_%03d.png" % frame)==OK)
	print("PASS dinner animation 96 frames")
	viewport.queue_free()
	await process_frame
	quit()
