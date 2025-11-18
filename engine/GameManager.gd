# res://engine/GameManager.gd
extends Node

signal turn_advanced(new_week, new_month)
signal mission_triggered(mission_id)

var state: GameState = GameState.new()
var current_week: int = 1
var current_month: int = 1
var is_month_end: bool = false

# 1 Turn = 1 Week
func advance_week():
	current_week += 1

	# Check for Month End (Every 4th week)
	if current_week % 4 == 0:
		trigger_month_end_close()
	else:
		# Process standard weekly operational costs (burn rate)
		process_weekly_burn()
		emit_signal("turn_advanced", current_week, current_month)

func trigger_month_end_close():
	state.is_month_end = true
	current_month += 1
	emit_signal("mission_triggered", "month_end_close_" + str(current_month))
	print("Month End Close! Time to report.")

func process_weekly_burn():
	# Simple simulation logic (later move this to Python backend)
	var weekly_opex = 5000.0
	state.cash -= weekly_opex
	state.expense_ytd += weekly_opex

	# Additional airline-specific weekly operations
	# This would include fuel costs, crew salaries, etc.
	# For MVP, keeping it simple
