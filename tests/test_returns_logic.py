from datetime import date
from backend.services.finance.ledger_store import reset_ledger, get_ledger
from backend.services.finance.seed import post_invoice, post_cash_receipt, post_return

def _round(x): 
    return round(float(x), 2)

def test_returns_and_discounts_do_not_overrelease_ar():
    reset_ledger()
    L = get_ledger()

    # Invoice 10,000
    post_invoice(L, "O-1", 10_000.0, date(2025,1,10))
    # Return 3,000
    post_return(L, "O-1", 3_000.0, date(2025,1,12))
    # Cash 6,500 with 500 discount  => total release = 7,000
    post_cash_receipt(L, "O-1", 6_500.0, 500.0, date(2025,1,15))

    # Movement in Jan:
    delta = L.delta_tb(date(2025,1,1), date(2025,1,31))
    end   = L.trial_balance(date(2025,1,31))

    # Revenue: -10,000; Returns: +3,500 (3,000 return + 500 discount)
    assert _round(delta["4000"]) == -10000.00
    assert _round(delta["4100"]) == 3500.00

    # AR: +10,000 (invoice) - 3,000 (return) - 7,000 (cash+disc) = 0
    assert _round(delta["1100"]) == 0.00
    assert _round(end.get("1100", 0.0)) == 0.00

def test_disallow_negative_inputs_and_zero_amounts():
    reset_ledger()
    L = get_ledger()

    import pytest
    with pytest.raises(ValueError): post_invoice(L, "O-2", -1.0, date(2025,1,5))
    with pytest.raises(ValueError): post_return(L, "O-2", -0.01, date(2025,1,6))
    with pytest.raises(ValueError): post_cash_receipt(L, "O-2", -1.0, 0.0, date(2025,1,7))

def test_multi_order_scenario_balances_hold():
    reset_ledger()
    L = get_ledger()

    # Order A
    post_invoice(L, "A", 12_000.0, date(2025,1,05))
    post_cash_receipt(L, "A", 10_000.0, 0.0, date(2025,1,09))
    # open AR for A: 2,000

    # Order B
    post_invoice(L, "B", 8_000.0, date(2025,1,10))
    post_return(L, "B", 1_000.0, date(2025,1,12))
    post_cash_receipt(L, "B", 5_500.0, 500.0, date(2025,1,14))
    # open AR for B: 1,000 (8k -1k -6k)

    # Order C (no cash yet)
    post_invoice(L, "C", 5_000.0, date(2025,1,20))

    delta = L.delta_tb(date(2025,1,1), date(2025,1,31))
    end   = L.trial_balance(date(2025,1,31))

    # Cash = 10,000 + 5,500 = 15,500
    assert _round(delta.get("1000", 0.0)) == 15500.00
    # Revenue = -(12k + 8k + 5k) = -25,000
    assert _round(delta.get("4000", 0.0)) == -25000.00
    # Returns/Discounts = + (1,000 + 500) = +1,500
    assert _round(delta.get("4100", 0.0)) == 1500.00
    # Ending AR = 2,000 (A) + 1,000 (B) + 5,000 (C) = 8,000
    assert _round(end.get("1100", 0.0)) == 8000.00
