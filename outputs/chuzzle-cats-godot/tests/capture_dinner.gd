extends SceneTree
func _initialize() -> void:
	root.visible = false
	call_deferred("run")
func capture(viewport: SubViewport, filename: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var picture: Image = viewport.get_texture().get_image()
	assert(picture.save_png(ProjectSettings.globalize_path("res://../"+filename))==OK)
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(540,900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.start_level(2)
	game.score = 28
	game.station.food_amount = 28
	game.view.cat_locks = [Vector2i(1,1),Vector2i(4,4)]
	game._refresh()
	print("SIZES ",game.size," ",game.station.size," ",game.view.size)
	await capture(viewport,"猫咪晚饭棋盘.png")
	game.station.meal_time = 1.1
	game.station.food_amount = 50
	game.station.set_process(false)
	game.station.queue_redraw()
	game.status.text = "食盆装满啦，开饭！"
	await capture(viewport,"猫咪吃饭演出.png")
	game.station.meal_time = 3.1
	game.station.happy = true
	game.station.queue_redraw()
	await capture(viewport,"猫咪吃饱过关.png")
	print("PASS real renderer dinner screenshots")
	viewport.queue_free()
	await process_frame
	quit()
