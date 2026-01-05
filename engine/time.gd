# res://engine/time.gd
extends Resource

var _week_index: int = 0           # weeks since start
var _weeks_per_month: int = 4

func init(cfg: Dictionary) -> void:
	_weeks_per_month = int(cfg.get("weeks_per_month", 4))
	_week_index = 0

func advance_week() -> void:
	_week_index += 1

func is_month_end() -> bool:
	return _week_index > 0 and (_week_index % _weeks_per_month) == 0

func current_week() -> int:
	return _week_index

func current_month() -> int:
	return int(_week_index / _weeks_per_month) + 1

func week_in_month() -> int:
	return int((_week_index % _weeks_per_month)) + 1
