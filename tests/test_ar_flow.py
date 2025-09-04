from datetime import date
from backend.services.finance.ledger_store import reset_ledger, get_ledger
from backend.services.finance.postings import post_invoice, post_cash_receipt, post_return

def test_ar_cash_return_flow():
    reset_ledger()
    L = get_ledger()

    # Scenario: order 1001
    # Invoice 10,000 on 2025-01-16
    post_invoice("1001", amount=10_000.0, je_date=date(2025,1,16))
    # Cash 8,500 + discount 500 on 2025-01-20
    post_cash_receipt("1001", cash_amount=8_500.0, discount=500.0, je_date=date(2025,1,20))
    # Return 2,000 on 2025-01-22
    post_return("1001", return_amount=2_000.0, je_date=date(2025,1,22))

    # Compute deltas for the whole month
    delta = L.delta_tb(date(2025,1,1), date(2025,1,31))
    end   = L.trial_balance(date(2025,1,31))

    # Cash should increase by +8,500
    assert round(float(delta.get("1000", 0.0)), 2) == 8500.00

    # Revenue +10,000; Returns +2,500 (500 discount + 2,000 return)
    assert round(float(delta.get("4000", 0.0)), 2) == -10000.00  # credit-negative convention
    assert round(float(delta.get("4100", 0.0)), 2) == 2500.00    # debit-positive

    # AR movement: +10,000 (invoice) - (8,500 + 500) (cash+disc) - 2,000 (return) = 0
    assert round(float(delta.get("1100", 0.0)), 2) == 0.00

    # Ending AR should be zero in this closed scenario
    assert round(float(end.get("1100", 0.0)), 2) == 0.00
