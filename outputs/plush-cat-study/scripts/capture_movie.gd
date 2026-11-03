extends SceneTree
func _initialize() -> void:
	root.visible = false
	call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720,480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var study = load("res://scenes/study.tscn").instantiate()
	study.scale = Vector2(0.75,0.75)
	viewport.add_child(study)
	await process_frame
	await process_frame
	study.manual_capture = true
	study.player.pause()
	study.rig.mouse_tracking = false
	for frame in 144:
		study.set_time(float(frame)/24)
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var img: Image = viewport.get_texture().get_image()
		assert(img.save_png(ProjectSettings.globalize_path("res://../../work/plush-study-frames/frame_%03d.png" % frame))==OK)
	print("PASS 144 frames, 720x480, 24 fps")
	# 时间轴控制和视觉层不影响游戏随机数；验证复播与慢放控制。
	study.control_animation("重播")
	study.player.advance(0.6)
	assert(study.rig.pose_time>0.5 and study.rig.pose_time<0.7)
	study.control_animation("暂停 / 继续")
	assert(not study.player.is_playing())
	study.control_animation("慢放 ×0.65")
	assert(is_equal_approx(study.player.speed_scale,0.65))
	study.scrub(3.2)
	assert(is_equal_approx(study.rig.pose_time,3.2))
	for texture_path in ["body","head_front","head_down","tail"]:
		var art: Image = load("res://assets/"+texture_path+".png").get_image()
		assert(art.get_pixel(0,0).a<0.01)
	print("PASS replay, pause, slow motion, scrubbing, transparent layers")
	viewport.queue_free()
	await process_frame
	quit()
