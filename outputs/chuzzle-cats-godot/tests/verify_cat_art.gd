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
	game.view.animate_eyes=false
	game.view.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../天然毛色棋盘预览.png"))
	assert(game.view.CAT_TEXTURES.size()==9)
	for texture: Texture2D in game.view.CAT_TEXTURES:
		var art: Image=texture.get_image()
		assert(art.get_width()>0 and art.get_height()>0)
		assert(art.get_pixel(0,0).a<0.01,"Artwork needs real alpha")
	# Fix the gaze target and compare rendered eyes at different clocks.
	game.view.animate_eyes=true
	game.view.set_process(false)
	game.station.set_process(false)
	game.view.update_gaze(1.0,Vector2(400,200),true)
	var snapshot: int=game.rng.state
	var eye_reference: PackedByteArray
	for time_value in [0.0,0.07,0.2,3.4,4.5,6.0]:
		game.view.animation_clock=time_value
		game.view.queue_redraw()
		await process_frame
		await process_frame
		RenderingServer.force_draw(false)
		var rendered: PackedByteArray=viewport.get_texture().get_image().get_data()
		if eye_reference.is_empty():
			eye_reference=rendered
		else:
			assert(rendered==eye_reference,"Eyes must stay open: no blink frames at any clock")
	assert(game.rng.state==snapshot,"Visuals must not consume gameplay RNG")
	print("PASS: 9 natural transparent textures; rendered no-blink invariance; gameplay RNG isolation")
	viewport.queue_free()
	await process_frame
	var frames_path: String=ProjectSettings.globalize_path("res://../../work/cat-natural-frames")
	DirAccess.make_dir_recursive_absolute(frames_path)
	var animation_viewport:=SubViewport.new()
	animation_viewport.size=Vector2i(600,450)
	animation_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(animation_viewport)
	var showcase=load("res://tests/cat_showcase.gd").new()
	showcase.size=Vector2(1200,900)
	showcase.scale=Vector2(0.5,0.5)
	animation_viewport.add_child(showcase)
	showcase.animate_eyes=true
	showcase.demo_cursor_enabled=true
	showcase.set_process(false)
	for frame in 72:
		showcase.animation_clock=float(frame)/12.0
		var angle: float=float(frame)/72.0*TAU
		showcase.demo_cursor=Vector2(600+480*cos(angle),450+230*sin(angle))
		showcase.update_gaze(1.0,showcase.demo_cursor,true)
		showcase.queue_redraw()
		await process_frame
		RenderingServer.force_draw(false)
		animation_viewport.get_texture().get_image().save_png(frames_path+"/frame_%03d.png"%frame)
	print("PASS: natural-coat board and 72 mouse-follow preview frames")
	animation_viewport.queue_free()
	await process_frame
	quit(0)
