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

# PATCH 2: LEDGER TB -> statements rollup
func normalize_sign_by_account_type(acct_type: String, tb_balance: float) -> float:
	return _present_balance_by_type(acct_type, tb_balance)

func _present_balance_by_type(acct_type: String, tb_balance: float) -> float:
	var t := acct_type.to_lower()
	if t == "revenue":
		return absf(tb_balance)
	if t == "expense":
		return maxf(tb_balance, 0.0)
	if t == "liability" or t == "equity":
		return absf(tb_balance)
	return tb_balance

func rollup_tb_to_statements(ledger: Dictionary, coa: Dictionary) -> Dictionary:
	_ensure_ledger_shape(ledger)
	var tb: Dictionary = ledger.get("trial_balance", {})
	var empty_result := {
		"income_statement": {},
		"balance_sheet": {},
		"cash_flow": {},
		"tb": tb.duplicate(true)
	}

	if typeof(coa) != TYPE_DICTIONARY:
		return empty_result
	var accounts_value = coa.get("accounts", [])
	if typeof(accounts_value) != TYPE_ARRAY:
		return empty_result

	var account_meta_by_code: Dictionary = {}
	for acct_value in accounts_value:
		if typeof(acct_value) != TYPE_DICTIONARY:
			continue
		var acct: Dictionary = acct_value as Dictionary
		var code := str(acct.get("code", ""))
		if code == "":
			continue
		account_meta_by_code[code] = acct

	var income_statement: Dictionary = {}
	var balance_sheet: Dictionary = {}
	var cash_flow: Dictionary = {}
	var total_revenue := 0.0
	var total_expense := 0.0
	var total_assets := 0.0
	var total_liabilities := 0.0
	var total_equity := 0.0

	for gl_code in tb.keys():
		var code := str(gl_code)
		var tb_balance := float(tb.get(gl_code, 0.0))
		var meta: Dictionary = account_meta_by_code.get(code, {}) as Dictionary
		if meta.is_empty():
			continue

		var acct_type := str(meta.get("type", "")).to_lower()
		var statement := str(meta.get("statement", "")).to_upper()
		var rollup_key := str(meta.get("rollup", code))
		if rollup_key == "":
			rollup_key = code

		var presented := _present_balance_by_type(acct_type, tb_balance)

		if statement == "IS" or acct_type == "revenue" or acct_type == "expense":
			income_statement[rollup_key] = float(income_statement.get(rollup_key, 0.0)) + presented
			if acct_type == "revenue":
				total_revenue += presented
			elif acct_type == "expense":
				total_expense += presented
		elif statement == "BS" or acct_type == "asset" or acct_type == "liability" or acct_type == "equity":
			balance_sheet[rollup_key] = float(balance_sheet.get(rollup_key, 0.0)) + presented
			if acct_type == "asset":
				total_assets += presented
			elif acct_type == "liability":
				total_liabilities += presented
			elif acct_type == "equity":
				total_equity += presented

	var net_income := total_revenue - total_expense
	income_statement["total_revenue"] = total_revenue
	income_statement["total_expense"] = total_expense
	income_statement["net_income"] = net_income

	balance_sheet["total_assets"] = total_assets
	balance_sheet["total_liabilities"] = total_liabilities
	balance_sheet["total_equity"] = total_equity
	balance_sheet["is_balanced"] = absf(total_assets - (total_liabilities + total_equity)) <= BALANCE_EPSILON

	var ending_cash := 0.0
	if balance_sheet.has("cash"):
		ending_cash = float(balance_sheet.get("cash", 0.0))
	elif tb.has("1000"):
		ending_cash = _present_balance_by_type("asset", float(tb.get("1000", 0.0)))

	cash_flow = {
		"net_income": net_income,
		"change_in_working_capital": 0.0,
		"capex": 0.0,
		"debt_activity": 0.0,
		"equity_activity": 0.0,
		"net_change_in_cash": 0.0,
		"ending_cash": ending_cash
	}

	return {
		"income_statement": income_statement,
		"balance_sheet": balance_sheet,
		"cash_flow": cash_flow,
		"tb": tb.duplicate(true)
	}
