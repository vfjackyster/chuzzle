extends SceneTree

func _initialize() -> void:
	root.visible=false
	call_deferred("run")

func run() -> void:
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(1200,900)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var preview=load("res://tests/cat_showcase.gd").new()
	preview.size=Vector2(1200,900)
	viewport.add_child(preview)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var picture: Image=viewport.get_texture().get_image()
	if picture==null or picture.is_empty():
		push_error("Render capture unavailable")
		quit(1)
		return
	var result: int=picture.save_png(ProjectSettings.globalize_path("res://../小猫素材预览.png"))
	print("SHOWCASE_CAPTURE ",result," ",picture.get_size())
	viewport.queue_free()
	await process_frame
	quit(result)
