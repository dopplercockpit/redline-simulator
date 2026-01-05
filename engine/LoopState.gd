# res://engine/LoopState.gd
extends Resource
class_name LoopState

const VERSION := "1.0.0"

# Canonical loop state. Mutate only via DecisionResolver.
var hq_strength: float = 0.0
var recruits := {}        # relationship_id -> data
var unlocks := {}         # system_id -> data
var audit_pressure: float = 0.0
var flags := {}           # persistent story flags
var memory := {}          # long-term memory payloads

# Turn tracking (1 turn = 1 week; 4 turns = month end)
var week_number: int = 0
var month_number: int = 1

func reset() -> void:
	hq_strength = 0.0
	recruits = {}
	unlocks = {}
	audit_pressure = 0.0
	flags = {}
	memory = {}
	week_number = 0
	month_number = 1
