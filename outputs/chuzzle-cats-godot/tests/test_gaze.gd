extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var view=load("res://scripts/board_view.gd").new()
	var target:=Vector2(310,270)
	for y in 6:
		for x in 6:
			var center:=Vector2(40+x*80,40+y*80)
			var gaze: Vector2=view.gaze_for_target(center,0.75,target)
			var toward: Vector2=target-center
			assert(gaze.x*toward.x>=0 and gaze.y*toward.y>=0,"Every cat must look toward cursor")
			assert(pow(gaze.x/3.2,2)+pow(gaze.y/3.4,2)<=1.001,"Gaze must stay inside eye")
	assert(view.gaze_for_target(Vector2(20,100),1.0,Vector2(100,100)).x>0)
	assert(view.gaze_for_target(Vector2(180,100),1.0,Vector2(100,100)).x<0)
	assert(view.gaze_for_target(target,1.0,target).is_zero_approx())
	view.update_gaze(0.0,Vector2.ZERO,true)
	view.update_gaze(0.05,Vector2(100,50),true)
	assert(view.smoothed_gaze_target.x>0 and view.smoothed_gaze_target.x<100,"Cursor target should ease smoothly")
	view.update_gaze(0.05,Vector2(100,50),false)
	assert(not view.gaze_tracking and not view.gaze_target_ready)
	view.update_gaze(0.05,Vector2(200,100),true)
	assert(view.smoothed_gaze_target==Vector2(200,100),"Re-entry should initialize target")
	view.free()
	print("PASS: 36 cat gaze directions, per-cat target geometry, pupil bounds, smoothing, cursor leave/re-entry")
	quit(0)
