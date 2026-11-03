extends RefCounted
class_name CatRules

const SIZE: int = 6

static func matches(board: Array) -> Array:
	var seen: Dictionary = {}
	var hits: Array = []
	for y in SIZE:
		for x in SIZE:
			var first := Vector2i(x, y)
			if seen.has(first) or board[y][x] < 0:
				continue
			var pending: Array = [first]
			var group: Array = []
			seen[first] = true
			while not pending.is_empty():
				var cell: Vector2i = pending.pop_back()
				group.append(cell)
				for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var next: Vector2i = cell + step
					if next.x < 0 or next.y < 0 or next.x >= SIZE or next.y >= SIZE:
						continue
					if not seen.has(next) and board[next.y][next.x] == board[y][x]:
						seen[next] = true
						pending.append(next)
			if group.size() >= 3:
				hits.append_array(group)
	return hits

static func shifted(board: Array, axis: int, line: int, delta: int) -> Array:
	var result: Array = board.duplicate(true)
	for i in SIZE:
		var dest: int = posmod(i + delta, SIZE)
		if axis == 0:
			result[line][dest] = board[line][i]
		else:
			result[dest][line] = board[i][line]
	return result

static func hint(board: Array, locks: Array = []) -> Dictionary:
	var best: Dictionary = {}
	for axis in 2:
		for line in SIZE:
			if not can_shift(axis, line, locks):
				continue
			for delta in range(1, SIZE):
				var count: int = matches(shifted(board, axis, line, delta)).size()
				if count > int(best.get("count", 0)):
					best = {"axis": axis, "line": line, "delta": delta, "count": count}
	return best

static func fresh(rng: RandomNumberGenerator, colors: int) -> Array:
	for attempt in 500:
		var board: Array = []
		for y in SIZE:
			var row: Array = []
			for x in SIZE:
				row.append(rng.randi_range(0, colors - 1))
			board.append(row)
		for retry in 200:
			var hits: Array = matches(board)
			if hits.is_empty():
				break
			for cell: Vector2i in hits:
				board[cell.y][cell.x] = rng.randi_range(0, colors - 1)
		if matches(board).is_empty() and not hint(board).is_empty():
			return board
	# 随机重试达到上限时，使用确定性后备布局，并验证它有有效动作。
	var fallback: Array = []
	for y in SIZE:
		var row: Array = []
		for x in SIZE:
			row.append((x + y) % colors)
		fallback.append(row)
	return fallback

static func refill(board: Array, rng: RandomNumberGenerator, colors: int, suppress: bool) -> Array:
	var result: Array = board.duplicate(true)
	var new_cells: Dictionary = {}
	for x in SIZE:
		var column: Array = []
		for y in SIZE:
			if result[y][x] >= 0:
				column.append(result[y][x])
		var missing: int = SIZE - column.size()
		for y in missing:
			new_cells[Vector2i(x, y)] = true
			column.push_front(rng.randi_range(0, colors - 1))
		for y in SIZE:
			result[y][x] = column[y]
	if suppress:
		for retry in 16:
			var changed: bool = false
			for cell: Vector2i in matches(result):
				if new_cells.has(cell):
					result[cell.y][cell.x] = rng.randi_range(0, colors - 1)
					changed = true
			if not changed:
				break
	return result

static func can_shift(axis: int, line: int, locks: Array) -> bool:
	for cell: Vector2i in locks:
		if (axis == 0 and cell.y == line) or (axis == 1 and cell.x == line):
			return false
	return true

static func fallen_locks(board: Array, locks: Array) -> Array:
	var result: Array = []
	for cell: Vector2i in locks:
		if board[cell.y][cell.x] < 0:
			continue
		var below: int = 0
		for y in range(cell.y+1,SIZE):
			if board[y][cell.x] < 0:
				below += 1
		result.append(cell+Vector2i(0,below))
	return result
