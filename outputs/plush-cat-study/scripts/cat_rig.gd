extends Node2D
class_name PlushCatRig
# 独立层级，可在 Godot 编辑器中检查头、身、尾与表情。
@export_range(0,6) var pose_time: float = 0.0:
	set(value):
		pose_time = clampf(value,0,6)
		if is_node_ready(): apply_pose()
var body: Sprite2D
var tail: Sprite2D
var head_root: Node2D
var front: Polygon2D
var lowered: Polygon2D
var face: Node2D
var rest_vertices := PackedVector2Array()
var expected_gaze := Vector2(0.7,0.1)
var mouse_gaze := Vector2.ZERO
var mouse_tracking: bool = true

func sprite_layer(texture_path: String, width: float, parent: Node) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path)
	sprite.scale = Vector2.ONE*width/sprite.texture.get_width()
	parent.add_child(sprite)
	return sprite

func mesh_layer(texture_path: String) -> Polygon2D:
	var mesh := Polygon2D.new()
	mesh.texture = load(texture_path)
	var points := PackedVector2Array()
	var uv := PackedVector2Array()
	var faces: Array[PackedInt32Array] = []
	const STEPS: int = 16
	for y in STEPS+1:
		for x in STEPS+1:
			points.append(Vector2(float(x)/STEPS-0.5,float(y)/STEPS-0.5)*220)
			uv.append(Vector2(float(x)/STEPS,float(y)/STEPS)*mesh.texture.get_size())
	for y in STEPS:
		for x in STEPS:
			var i: int = y*(STEPS+1)+x
			faces.append(PackedInt32Array([i,i+1,i+STEPS+2]))
			faces.append(PackedInt32Array([i,i+STEPS+2,i+STEPS+1]))
	mesh.polygon = points
	mesh.uv = uv
	mesh.polygons = faces
	head_root.add_child(mesh)
	if rest_vertices.is_empty(): rest_vertices = points
	return mesh

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tail = sprite_layer("res://assets/tail.png",130,self)
	tail.name = "Tail"
	body = sprite_layer("res://assets/body.png",195,self)
	body.name = "Body"
	head_root = Node2D.new()
	head_root.name = "Head"
	add_child(head_root)
	front = mesh_layer("res://assets/head_front.png")
	front.name = "FrontHead"
	lowered = mesh_layer("res://assets/head_down.png")
	lowered.name = "EatingHead"
	face = preload("res://scripts/face.gd").new()
	face.name = "AlwaysOpenEyes"
	head_root.add_child(face)
	apply_pose()

func ramp(a: float, b: float, value: float) -> float:
	return smoothstep(a,b,value)

func apply_pose() -> void:
	var t: float = pose_time
	var anticipation: float = sin(clampf((t-0.6)/0.5,0,1)*PI)
	var travel: float = ramp(1.08,1.92,t)
	var traveling: bool = t>=1.08 and t<1.92
	var hop_phase: float = clampf((t-1.08)/0.84,0,1)*TAU
	var hop: float = absf(sin(hop_phase))*30.0 if traveling else 0.0
	var landed: float = maxf(t-1.92,0)
	var landing_spring: float = sin(landed*24.0)*exp(-landed*9.0) if t>=1.92 else 0.0
	var breathe: float = sin(t*TAU*0.55)*0.015
	var squash: float = anticipation*0.13-landing_spring*0.07
	if traveling: squash += cos(hop_phase*2)*0.07
	position = Vector2(300+travel*283,475-hop+anticipation*7)
	var body_scale: float = 195.0/body.texture.get_width()
	body.position = Vector2(-8,-77+squash*25)
	body.scale = Vector2(1+squash-breathe,1-squash+breathe)*body_scale
	body.rotation = -0.04*anticipation+(sin(hop_phase)*0.04 if traveling else 0.0)
	tail.position = Vector2(-78,-88)
	tail.rotation = sin(t*3.2-0.6)*0.13+sin(t*6.4)*0.025
	if t>4.7: tail.rotation += sin((t-4.7)*8)*0.17
	var down: float = ramp(2.1,2.65,t)*(1-ramp(4.3,4.85,t))
	var eat_envelope: float = ramp(2.6,2.85,t)*(1-ramp(4.15,4.4,t))
	var chew_wave: float = sin((t-2.6)*TAU*3.2)*eat_envelope
	var recover_t: float = maxf(t-4.7,0)
	var recover: float = sin(recover_t*15)*exp(-recover_t*4)*ramp(4.6,4.75,t)
	head_root.position = Vector2(down*24,-183+down*80+squash*13+chew_wave*2.4-recover*9)
	head_root.rotation = anticipation*0.055+down*0.10+landing_spring*0.04-recover*0.025
	head_root.scale = Vector2(1-squash*0.35,1+squash*0.35)
	front.modulate.a = 1-down
	lowered.modulate.a = down
	var points := rest_vertices.duplicate()
	for i in points.size():
		var v: Vector2 = rest_vertices[i]
		var ear_weight: float = smoothstep(25,83,absf(v.x))*(1-smoothstep(-60,-5,v.y))
		var wave: float = sin(t*4.0+(0.0 if v.x<0 else 1.2))*1.3
		var lag: float = landing_spring*5.0+recover*3.2+wave
		points[i] += Vector2(signf(v.x)*lag*0.45,lag)*ear_weight
	front.polygon = points
	lowered.polygon = points
	face.down = down
	face.lick = sin(clampf((t-4.95)/0.48,0,1)*PI)
	face.chew = absf(chew_wave)
	var gaze: Vector2 = expected_gaze.lerp(Vector2(0,0.9),down)
	if mouse_tracking and down<0.2:
		gaze = gaze.lerp(mouse_gaze,0.5)
	face.gaze = gaze
	face.queue_redraw()
	queue_redraw()

func _draw() -> void:
	# 阴影与角色分离，跳跃时收小，传达离地高度。
	var height: float = 475-position.y
	draw_set_transform(Vector2(0,height))
	draw_ellipse_shadow(1-clampf(height/100.0,0,0.4))
	draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow(factor: float) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var a: float = i*TAU/32.0
		points.append(Vector2(cos(a)*80*factor,sin(a)*13*factor))
	draw_colored_polygon(points,Color(0.30,0.28,0.18,0.13))
