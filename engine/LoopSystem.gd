# res://engine/LoopSystem.gd
extends Node

signal loop_updated(snapshot: Dictionary)

var _state: LoopState = preload("res://engine/LoopState.gd").new()

func reset() -> void:
	_state.reset()
	emit_signal("loop_updated", get_snapshot())

func get_state_ref() -> LoopState:
	# Exposed for DecisionResolver only. UI should use get_snapshot().
	return _state

func get_snapshot() -> Dictionary:
	return {
		"hq_strength": _state.hq_strength,
		"recruits": _state.recruits.duplicate(true),
		"unlocks": _state.unlocks.duplicate(true),
		"audit_pressure": _state.audit_pressure,
		"flags": _state.flags.duplicate(true),
		"memory": _state.memory.duplicate(true),
		"points": _state.points,
		"audit_score": _state.audit_score,
		"completed_missions": _state.completed_missions.duplicate(true),
		"mission_log": _state.mission_log.duplicate(true),
		"inbox": _state.inbox.duplicate(true),
		"week_number": _state.week_number,
		"month_number": _state.month_number
	}

func notify_updated() -> void:
	emit_signal("loop_updated", get_snapshot())
