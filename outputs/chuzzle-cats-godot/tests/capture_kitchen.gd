extends SceneTree
func _initialize() -> void:
	root.visible=false
	call_deferred("run")
func shot(viewport: SubViewport, filename: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../"+filename))==OK)
func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(540,960)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var game=load("res://scenes/main.tscn").instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.start_level(2)
	game.score=28
	game.moves=7
	game.station.food_amount=28
	game.view.cat_locks=[Vector2i(1,1)]
	game._refresh()
	game.hud.displayed_ratio=28.0/50
	game.status.text="拖动整行或整列，收集猫粮"
	await shot(viewport,"奶油厨房实际UI.png")
	game.hud.toggle_menu()
	await shot(viewport,"奶油厨房菜单.png")
	game.hud.toggle_menu()
	game.score=50
	game._refresh()
	game.hud.displayed_ratio=1.0
	game.station.food_amount=50
	game.station.meal_time=1.1
	game.station.set_process(false)
	game.station.queue_redraw()
	await shot(viewport,"奶油厨房吃饭弹层.png")
	print("PASS UI GPU captures at 540x960")
	viewport.queue_free()
	await process_frame
	quit()
