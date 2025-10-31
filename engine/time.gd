# res://engine/time.gd
extends Resource

var _start_date: Dictionary = {"year": 2026, "month": 1, "day": 3}
var _day_index: int = 0             # days since start
var _month_length_days: int = 28    # 4 weeks per month
var _week_length_days: int = 7

func init(cfg: Dictionary) -> void:
	if cfg.has("start"):
		_start_date = _parse_iso(cfg["start"])
	_month_length_days = int(cfg.get("month_length_days", 28))
	_day_index = 0

func today() -> Dictionary:
	# We keep simple counters; UI can render fancier later
	return {"day_index": _day_index}

func advance_day() -> void:
	_day_index += 1

func is_month_end() -> bool:
	return (_day_index % _month_length_days) == 0

func current_month() -> int:
	return int(_day_index / _month_length_days) + 1

func week_in_month() -> int:
	return int((_day_index % _month_length_days) / _week_length_days) + 1

func _parse_iso(s: String) -> Dictionary:
	# "YYYY-MM-DD" -> {year, month, day}; minimalist
	var parts := s.split("-")
	if parts.size() == 3:
		return {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}
	return _start_date
