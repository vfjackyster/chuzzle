extends Control

const Rules = preload("res://scripts/cat_rules.gd")
const LevelData = preload("res://scripts/cat_level.gd")
const BoardView = preload("res://scripts/board_view.gd")
const LEVELS = [preload("res://levels/level_01.tres"),preload("res://levels/level_02.tres"),preload("res://levels/level_03.tres")]
var hud: Control
var station: Control
var shuffle_button: Button
var shuffles_left: int = 2
var turns: int = 0
var view: Control
var heading: Label
var stats: Label
var status: Label
var progress: ProgressBar
var hint_button: Button
var next_button: Button
var level_index: int = 0
var score: int = 0
var moves: int = 0
var busy: bool = false
var finished: bool = false
var generation: int = 0
var data: Resource
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	_build_ui()
	start_level(0)

func _build_ui() -> void:
	hud = preload("res://scripts/game_hud.gd").new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(hud)
	view = hud.view
	station = hud.station
	heading = hud.heading
	stats = hud.stats
	status = hud.status
	progress = hud.progress
	hint_button = hud.hint_button
	shuffle_button = hud.shuffle_button
	next_button = hud.next_button
	view.move_requested.connect(request_move)
	view.move_blocked.connect(func(_axis: int,_line: int):
		status.text = "这条行列有锁，不能拖动。移动其他行列来匹配解锁。"
	)
	hint_button.pressed.connect(show_hint)
	shuffle_button.pressed.connect(reshuffle)
	next_button.pressed.connect(func(): start_level(level_index+1))
	hud.restart_requested.connect(func(): start_level(level_index))
	hud.level_requested.connect(start_level)

func start_level(index: int) -> void:
	generation += 1
	level_index = clampi(index,0,LEVELS.size()-1)
	data = LEVELS[level_index]
	rng.seed = data.random_seed
	score = 0
	turns = 0
	shuffles_left = data.reshuffles
	view.cat_locks = []
	view.bursts = []
	station.reset_meal(data.target,level_index)
	moves = data.moves
	busy = false
	finished = false
	view.cancel_drag()
	view.cancel_refill()
	view.highlight = []
	view.hint_data = {}
	view.board = Rules.fresh(rng,data.cat_types)
	heading.text = "%02d / %s" % [level_index+1,data.title]
	status.text = "装满食盆就能开饭！共 %d 种猫，每只消除猫贡献一份猫粮。" % data.cat_types
	_refresh()

func _refresh() -> void:
	stats.text = "猫粮  %d / %d 份      剩余步数  %d" % [score,data.target,moves]
	progress.value = minf(100.0,float(score)/data.target*100.0)
	shuffle_button.text = ""
	shuffle_button.disabled = busy or finished or shuffles_left <= 0
	view.locked = busy or finished
	hint_button.disabled = busy or finished
	next_button.visible = finished and score >= data.target and level_index < LEVELS.size()-1
	hud.sync_game(score,data.target,moves,data.moves,level_index,shuffles_left,busy,finished)
	view.queue_redraw()

func show_hint() -> void:
	if busy or finished:
		return
	var h: Dictionary = Rules.hint(view.board,view.cat_locks)
	if h.is_empty():
		return
	view.hint_data = h
	var delta: int = int(h.delta) if int(h.delta) <= 3 else int(h.delta)-6
	var direction: String = ("右" if delta>0 else "左") if h.axis==0 else ("下" if delta>0 else "上")
	status.text = "第 %d %s向%s移动 %d 格。" % [int(h.line)+1,"行" if h.axis==0 else "列",direction,absi(delta)]
	view.queue_redraw()

func request_move(axis: int, line: int, delta: int) -> void:
	if busy or finished or delta % 6 == 0:
		return
	if not Rules.can_shift(axis,line,view.cat_locks):
		status.text = "这条行列被锁住了。移动其他行列，让同类猫连过来解锁。"
		return
	var token: int = generation
	busy = true
	view.hint_data = {}
	var before: Array = view.board
	view.board = Rules.shifted(before,axis,line,delta)
	_refresh()
	await get_tree().create_timer(0.12).timeout
	if token != generation:
		return
	var hits: Array = Rules.matches(view.board)
	if hits.is_empty():
		view.board = before
		busy = false
		status.text = "没有形成匹配，已弹回，不扣步。"
		_refresh()
		return
	moves -= 1
	turns += 1
	var combo: int = 0
	while not hits.is_empty():
		combo += 1
		var gain: int = hits.size()
		view.celebrate(hits)
		station.add_food(hits,view)
		view.highlight = hits
		status.text = "消除 %d 只 · 第 %d 连锁 · +%d 份猫粮" % [hits.size(),combo,gain]
		_refresh()
		await get_tree().create_timer(0.32).timeout
		if token != generation:
			return
		for cell: Vector2i in hits:
			view.board[cell.y][cell.x] = -1
		view.cat_locks = view.cat_locks.filter(func(cell: Vector2i): return view.board[cell.y][cell.x]>=0)
		view.highlight = []
		view.queue_redraw()
		var filled: Array = Rules.refill(view.board,rng,data.cat_types,data.suppress_refill_matches)
		var fall_time: float = view.start_refill(filled)
		# 猫粮飞行与补落同时进行；落稳前保持输入锁定，不检查下一轮连锁。
		await get_tree().create_timer(maxf(fall_time,0.55)).timeout
		if token != generation:
			return
		view.finish_refill()
		score += gain
		station.food_amount = score
		_refresh()
		hits = Rules.matches(view.board)
	if score >= data.target:
		status.text = "食盆装满啦，开饭！"
		station.meal_time = 0.0
		_refresh()
		await get_tree().create_timer(3.1).timeout
		if token != generation:
			return
		station.happy = true
		finished = true
		status.text = "小猫吃饱啦，过关！" if level_index < LEVELS.size()-1 else "三碗晚饭完成！小猫们都吃饱啦。"
	elif moves <= 0:
		finished = true
		status.text = "猫粮还不够，步数用完了。重新安排消除路线吧。"
	else:
		add_lock()
		if Rules.hint(view.board,view.cat_locks).is_empty():
			if shuffles_left > 0:
				status.text = "暂无可动匹配，使用一次重排解开局面。"
			else:
				finished = true
				status.text = "没有可动匹配，重排也用完了。本次未完成。"
	busy = false
	_refresh()

func add_lock() -> void:
	if data.lock_every <= 0 or turns % data.lock_every != 0 or view.cat_locks.size() >= data.max_locks:
		return
	var candidates: Array = []
	for y in 6:
		for x in 6:
			if Vector2i(x,y) not in view.cat_locks:
				candidates.append(Vector2i(x,y))
	while not candidates.is_empty():
		var cell: Vector2i = candidates.pop_at(rng.randi_range(0,candidates.size()-1))
		view.cat_locks.append(cell)
		if not Rules.hint(view.board,view.cat_locks).is_empty():
			status.text += "  新增一把锁：被锁猫所在行列暂停拖动。"
			return
		view.cat_locks.erase(cell)

func reshuffle() -> void:
	if busy or finished or shuffles_left <= 0:
		return
	shuffles_left -= 1
	view.cat_locks = []
	view.cancel_drag()
	view.cancel_refill()
	view.hint_data = {}
	view.board = Rules.fresh(rng,data.cat_types)
	status.text = "重排完成，锁已解除。剩余 %d 次重排。" % shuffles_left
	_refresh()
