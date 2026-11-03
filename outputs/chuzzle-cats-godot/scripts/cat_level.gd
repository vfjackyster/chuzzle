extends Resource
class_name CatLevel
@export var title: String = "晚饭时间"
@export_range(7,9) var cat_types: int = 7
@export_range(1,100) var moves: int = 10
# 一只消除猫 = 一份猫粮。连锁没有数量倍率。
@export_range(1,300) var target: int = 35
@export var random_seed: int = 42
@export var suppress_refill_matches: bool = true
# 0 关闭落锁；锁所在行列不可拖，可通过匹配清除。
@export_range(0,10) var lock_every: int = 0
@export_range(0,6) var max_locks: int = 0
@export_range(0,3) var reshuffles: int = 2
