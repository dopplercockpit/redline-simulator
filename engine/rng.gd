# res://engine/RNG.gd
extends Resource

var _rng := RandomNumberGenerator.new()

func set_seed(seed: int) -> void:
	_rng.seed = seed

func randf() -> float:
	return _rng.randf()

func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)
