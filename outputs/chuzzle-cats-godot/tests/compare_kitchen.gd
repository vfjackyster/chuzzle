extends SceneTree
func _initialize() -> void:
	root.visible=false
	call_deferred("run")
func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1080,960)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas:=Node2D.new()
	viewport.add_child(canvas)
	var source:=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://../UI风格探索/01-奶油猫咪厨房.png")))
	var actual:=ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://../奶油厨房实际UI.png")))
	canvas.draw.connect(func():
		canvas.draw_texture_rect(source,Rect2(0,0,540,960),false)
		canvas.draw_texture_rect(actual,Rect2(540,0,540,960),false)
	)
	canvas.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	assert(viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../work/kitchen-design-comparison.png"))==OK)
	viewport.queue_free()
	await process_frame
	quit()
