extends "res://scripts/board_view.gd"

var demo_cursor_enabled: bool = false
var demo_cursor := Vector2.ZERO

func _ready() -> void:
	selected=Vector2i(-1,-1)
	animate_eyes=false
	show_cat_numbers=false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("f6f1e7"))
	draw_string(ThemeDB.fallback_font,Vector2(60,60),"NATURAL COATS / CURSOR GAZE" if demo_cursor_enabled else "NINE NATURAL CAT COATS",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("26352e"))
	var names: Array[String]=["01 TABBY","02 BLUE GRAY","03 COW","04 BLACK","05 WHITE","06 SIAMESE","07 CALICO","08 BENGAL","09 TORTOISESHELL"]
	for i in CAT_TEXTURES.size():
		var center:=Vector2(210+(i%3)*390,205+floori(i/3.0)*270)
		_cat(center,1.65,i,false,i)
		draw_string(ThemeDB.fallback_font,center+Vector2(-75,112),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("52634f"))
	if demo_cursor_enabled:
		var cursor_shape := PackedVector2Array([demo_cursor, demo_cursor+Vector2(0,32), demo_cursor+Vector2(10,24), demo_cursor+Vector2(19,40), demo_cursor+Vector2(26,35), demo_cursor+Vector2(17,20), demo_cursor+Vector2(31,19), demo_cursor])
		draw_colored_polygon(cursor_shape,Color("ffdc63"))
		draw_polyline(cursor_shape,Color("26352e"),2.5,true)
