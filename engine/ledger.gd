extends RefCounted

# PATCH 1: LEDGER
# Lightweight ledger utility for transaction validation + trial balance storage.

const BALANCE_EPSILON := 0.0001

func new_ledger_state() -> Dictionary:
	return {
		"transactions": [],
		"trial_balance": {}
	}

func _ensure_ledger_shape(ledger: Dictionary) -> void:
	if typeof(ledger.get("transactions", null)) != TYPE_ARRAY:
		ledger["transactions"] = []
	if typeof(ledger.get("trial_balance", null)) != TYPE_DICTIONARY:
		ledger["trial_balance"] = {}

func validate_transaction(tx: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var debits := 0.0
	var credits := 0.0

	var journal_value = tx.get("journal", [])
	if typeof(journal_value) != TYPE_ARRAY:
		errors.append("journal must be an Array")
		return {
			"ok": false,
			"errors": errors,
			"debits": debits,
			"credits": credits
		}

	var journal: Array = journal_value
	if journal.is_empty():
		errors.append("journal must be non-empty")

	for line_value in journal:
		if typeof(line_value) != TYPE_DICTIONARY:
			errors.append("journal line must be a Dictionary")
			continue

		var line: Dictionary = line_value as Dictionary
		var gl := str(line.get("gl", ""))
		var dc := str(line.get("dc", ""))
		var amount := float(line.get("amount", 0.0))

		if gl.strip_edges() == "":
			errors.append("journal line missing gl")
		if dc != "D" and dc != "C":
			errors.append("journal line dc must be 'D' or 'C'")
		if amount <= 0.0:
			errors.append("journal line amount must be > 0")

		if amount > 0.0:
			if dc == "D":
				debits += amount
			elif dc == "C":
				credits += amount

	if errors.is_empty() and absf(debits - credits) > BALANCE_EPSILON:
		errors.append("transaction is not balanced")

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"debits": debits,
		"credits": credits
	}

func post_transaction(ledger: Dictionary, tx: Dictionary) -> Dictionary:
	_ensure_ledger_shape(ledger)

	var validation: Dictionary = validate_transaction(tx)
	if not bool(validation.get("ok", false)):
		return {
			"ok": false,
			"errors": validation.get("errors", []),
			"posted": false
		}

	var transactions: Array = ledger.get("transactions", [])
	transactions.append(tx)
	ledger["transactions"] = transactions

	var tb: Dictionary = ledger.get("trial_balance", {})
	var journal: Array = tx.get("journal", [])
	for line_value in journal:
		if typeof(line_value) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = line_value as Dictionary
		var gl := str(line.get("gl", ""))
		if gl.strip_edges() == "":
			continue
		var amount := float(line.get("amount", 0.0))
		var signed_amount := amount if str(line.get("dc", "")) == "D" else -amount
		tb[gl] = float(tb.get(gl, 0.0)) + signed_amount
	ledger["trial_balance"] = tb

	return {
		"ok": true,
		"posted": true
	}

func seed_opening_balances(ledger: Dictionary, opening_balances: Dictionary) -> void:
	_ensure_ledger_shape(ledger)
	var tb: Dictionary = {}
	for gl_code in opening_balances.keys():
		tb[str(gl_code)] = float(opening_balances.get(gl_code, 0.0))
	ledger["trial_balance"] = tb

func get_gl_balance(ledger: Dictionary, gl: String) -> float:
	_ensure_ledger_shape(ledger)
	var tb: Dictionary = ledger.get("trial_balance", {})
	return float(tb.get(gl, 0.0))
