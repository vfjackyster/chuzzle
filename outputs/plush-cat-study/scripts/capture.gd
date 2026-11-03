extends SceneTree
func _initialize() -> void:
	root.visible = false
	call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960,640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var study = load("res://scenes/study.tscn").instantiate()
	viewport.add_child(study)
	await process_frame
	await process_frame
	study.manual_capture = true
	study.player.pause()
	study.rig.mouse_tracking = false
	for time_value in [0.5,1.5,3.3,5.3]:
		study.set_time(time_value)
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var img: Image = viewport.get_texture().get_image()
		assert(img.save_png(ProjectSettings.globalize_path("res://../../work/plush_pose_%02d.png" % int(time_value*10)))==OK)
	print("PASS sample rendered key poses")
	viewport.queue_free()
	await process_frame
	quit()
