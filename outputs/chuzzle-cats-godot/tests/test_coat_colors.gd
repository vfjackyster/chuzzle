extends SceneTree

func _initialize() -> void:
	var view=load("res://scripts/board_view.gd").new()
	assert(view.CAT_TEXTURES.size()==7)
	var values: Array[float]=[]
	for index in [1,3,4]:
		var art: Image=view.CAT_TEXTURES[index].get_image()
		var total: float=0.0
		var saturation: float=0.0
		var count: int=0
		# Sample the central forehead, away from pink ears and the nose.
		for y in range(int(art.get_height()*0.30),int(art.get_height()*0.48),12):
			for x in range(int(art.get_width()*0.35),int(art.get_width()*0.65),12):
				var c: Color=art.get_pixel(x,y)
				if c.a<0.9: continue
				total+=c.v
				saturation+=c.s
				count+=1
		var brightness: float=total/maxi(count,1)
		var mean_saturation: float=saturation/maxi(count,1)
		values.append(brightness)
		assert(mean_saturation<0.3,"Solid gray/black/white coats should stay neutral, not neon")
		print("NATURAL SOLID COAT ",index+1," brightness=",snappedf(brightness,0.01)," saturation=",snappedf(mean_saturation,0.01))
	assert(values[1]+0.12<values[0] and values[0]+0.12<values[2],"Black, blue-gray, white need clear lightness separation")
	view.free()
	print("PASS: seven natural coats, neutral solid fur, black < gray < white lightness")
	quit(0)
