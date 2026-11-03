extends Node2D
var down: float = 0.0
var gaze := Vector2.ZERO
var lick: float = 0.0
var chew: float = 0.0
func _draw() -> void:
	# 常睁眼；低头时眼睛随透视下移，绝不切成闭眼帧。
	for side in [-1,1]:
		var at := Vector2(side*31.0,lerpf(-2.0,20.0,down))
		var eye_scale := Vector2(1.0,lerpf(1.0,0.84,down))
		draw_set_transform(at,0,eye_scale)
		var outline := PackedVector2Array()
		for i in 33:
			var a: float = i*TAU/32.0
			outline.append(Vector2(cos(a)*17.5,sin(a)*20.0))
		draw_colored_polygon(outline,Color("fff7df"))
		draw_polyline(outline,Color("5b4637"),1.5,true)
		var pupil: Vector2 = gaze*Vector2(4,4)+Vector2(0,down*4)
		draw_circle(pupil,12.5,Color("819e67"))
		draw_circle(pupil,8.5,Color("393b31"))
		draw_circle(pupil+Vector2(-3.5,-5.0),4.0,Color("fffef1"))
		draw_circle(pupil+Vector2(4,4),1.6,Color("fffef1"))
	draw_set_transform(Vector2.ZERO)
	if lick > 0.01:
		var tongue := PackedVector2Array()
		for i in 17:
			var a: float = i*PI/16.0
			tongue.append(Vector2(cos(a)*7,47+sin(a)*12*lick))
		draw_colored_polygon(tongue,Color("e39d9c"))
		draw_line(Vector2(0,48),Vector2(0,48+8*lick),Color("bf737f"),1.0,true)
	if chew>0.01 and down>0.5:
		draw_circle(Vector2(-23,42),2.5*chew,Color("f1c1a2"))
		draw_circle(Vector2(23,42),2.5*chew,Color("f1c1a2"))
