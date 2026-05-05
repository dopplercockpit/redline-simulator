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

# PATCH 1: Airport CFO statement builder
func load_coa(path: String) -> Dictionary:
	if path.strip_edges() == "":
		push_warning("COA path is empty.")
		return {}
	if not FileAccess.file_exists(path):
		push_warning("COA not found: " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("Invalid COA JSON: " + path)
	return {}

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

func build_statements(ledger: Dictionary, coa: Dictionary) -> Dictionary:
	_ensure_ledger_shape(ledger)
	var tb: Dictionary = ledger.get("trial_balance", {})

	var income_statement: Dictionary = {
		"landing_fees_revenue": 0.0,
		"passenger_facility_charges_revenue": 0.0,
		"concessions_revenue": 0.0,
		"total_operating_revenue": 0.0,
		"payroll_expense": 0.0,
		"utilities_expense": 0.0,
		"route_incentive_expense": 0.0,
		"professional_fees_expense": 0.0,
		"interest_expense": 0.0,
		"total_operating_expense": 0.0,
		"operating_surplus": 0.0
	}
	var balance_sheet: Dictionary = {
		"cash": 0.0,
		"accounts_receivable": 0.0,
		"deferred_revenue": 0.0,
		"accounts_payable": 0.0,
		"accrued_expenses": 0.0,
		"short_term_debt": 0.0,
		"debt_term_loan": 0.0,
		"total_debt": 0.0,
		"retained_earnings": 0.0,
		"total_assets": 0.0,
		"total_liabilities": 0.0,
		"equity": 0.0,
		"liabilities_and_equity": 0.0
	}
	var cash_flow: Dictionary = {}

	var accounts_value = coa.get("accounts", [])
	if typeof(accounts_value) == TYPE_ARRAY:
		for acct_value in accounts_value:
			if typeof(acct_value) != TYPE_DICTIONARY:
				continue
			var acct: Dictionary = acct_value as Dictionary
			var code := str(acct.get("code", ""))
			if code == "":
				continue
			var amount := _present_balance_by_type(str(acct.get("type", "")), float(tb.get(code, 0.0)))
			match code:
				"1000":
					balance_sheet["cash"] = amount
				"1200":
					balance_sheet["accounts_receivable"] = amount
				"1300":
					balance_sheet["deferred_revenue"] = amount
				"2000":
					balance_sheet["accounts_payable"] = amount
				"2100":
					balance_sheet["accrued_expenses"] = amount
				"2300":
					balance_sheet["short_term_debt"] = amount
				"2400":
					balance_sheet["debt_term_loan"] = amount
				"3000":
					balance_sheet["retained_earnings"] = amount
				"4000":
					income_statement["landing_fees_revenue"] = amount
				"4100":
					income_statement["passenger_facility_charges_revenue"] = amount
				"4200":
					income_statement["concessions_revenue"] = amount
				"5000":
					income_statement["payroll_expense"] = amount
				"5100":
					income_statement["utilities_expense"] = amount
				"5200":
					income_statement["route_incentive_expense"] = amount
				"5300":
					income_statement["professional_fees_expense"] = amount
				"5600":
					income_statement["interest_expense"] = amount

	var total_operating_revenue := (
		float(income_statement["landing_fees_revenue"])
		+ float(income_statement["passenger_facility_charges_revenue"])
		+ float(income_statement["concessions_revenue"])
	)
	var total_operating_expense := (
		float(income_statement["payroll_expense"])
		+ float(income_statement["utilities_expense"])
		+ float(income_statement["route_incentive_expense"])
		+ float(income_statement["professional_fees_expense"])
		+ float(income_statement["interest_expense"])
	)
	var operating_surplus := total_operating_revenue - total_operating_expense
	income_statement["total_operating_revenue"] = total_operating_revenue
	income_statement["total_operating_expense"] = total_operating_expense
	income_statement["operating_surplus"] = operating_surplus

	var total_assets := float(balance_sheet["cash"]) + float(balance_sheet["accounts_receivable"])
	var total_liabilities := (
		float(balance_sheet["deferred_revenue"])
		+ float(balance_sheet["accounts_payable"])
		+ float(balance_sheet["accrued_expenses"])
		+ float(balance_sheet["short_term_debt"])
		+ float(balance_sheet["debt_term_loan"])
	)
	var total_debt := float(balance_sheet["short_term_debt"]) + float(balance_sheet["debt_term_loan"])
	var equity := float(balance_sheet["retained_earnings"]) + operating_surplus
	balance_sheet["total_assets"] = total_assets
	balance_sheet["total_liabilities"] = total_liabilities
	balance_sheet["total_debt"] = total_debt
	balance_sheet["equity"] = equity
	balance_sheet["liabilities_and_equity"] = total_liabilities + equity

	var operating_cash_flow := _cash_movement_by_category(ledger, "operating")
	var investing_cash_flow := _cash_movement_by_category(ledger, "investing")
	var financing_cash_flow := _cash_movement_by_category(ledger, "financing")
	var ending_cash := float(balance_sheet["cash"])
	var net_change_in_cash := operating_cash_flow + investing_cash_flow + financing_cash_flow
	cash_flow = {
		"operating_cash_flow": operating_cash_flow,
		"investing_cash_flow": investing_cash_flow,
		"financing_cash_flow": financing_cash_flow,
		"net_change_in_cash": net_change_in_cash,
		"ending_cash": ending_cash
	}

	return {
		"income_statement": income_statement,
		"balance_sheet": balance_sheet,
		"cash_flow": cash_flow,
		"kpis": {
			"cash": ending_cash,
			"operating_margin": operating_surplus / total_operating_revenue if absf(total_operating_revenue) > BALANCE_EPSILON else 0.0
		},
		"tb": tb.duplicate(true)
	}

func _cash_movement_by_category(ledger: Dictionary, category: String) -> float:
	var movement := 0.0
	var transactions: Array = ledger.get("transactions", [])
	for tx_value in transactions:
		if typeof(tx_value) != TYPE_DICTIONARY:
			continue
		var tx: Dictionary = tx_value as Dictionary
		var tx_category := str(tx.get("cash_flow_category", tx.get("category", "operating")))
		if tx_category != category:
			continue
		var journal: Array = tx.get("journal", [])
		for line_value in journal:
			if typeof(line_value) != TYPE_DICTIONARY:
				continue
			var line: Dictionary = line_value as Dictionary
			if str(line.get("gl", "")) != "1000":
				continue
			var amount := float(line.get("amount", 0.0))
			movement += amount if str(line.get("dc", "")) == "D" else -amount
	return movement

# PATCH 1: compatibility wrapper for older Patch 2 call sites.
func rollup_tb_to_statements(ledger: Dictionary, coa: Dictionary) -> Dictionary:
	return build_statements(ledger, coa)
