from datetime import date
from .ledger_store import get_ledger

def seed_january_2025():
    """
    Creates simple Jan-2025 activity:
    - Opening equity + cash
    - Sales (cash + AR), returns, COGS, opex, interest, tax
    """
    L = get_ledger()

    # Opening capital (Jan 1)
    L.post("2025-01-01", "Opening Equity", [
        ("1000", 200000.00, 0.0),  # Cash
        ("3000", 0.0, 200000.00),  # Equity
    ])

    # Sale on credit Jan 5 (10k revenue, 6k cogs)
    L.post("2025-01-05", "Sale on credit", [
        ("1100", 10000.00, 0.0),   # AR
        ("4000", 0.0, 10000.00),   # Revenue
        ("5000", 6000.00, 0.0),    # COGS
        ("1200", 0.0, 6000.00),    # Inventory
    ])

    # Cash sale Jan 9 (7k revenue, 4k cogs)
    L.post("2025-01-09", "Cash sale", [
        ("1000", 7000.00, 0.0),
        ("4000", 0.0, 7000.00),
        ("5000", 4000.00, 0.0),
        ("1200", 0.0, 4000.00),
    ])

    # Return Jan 12 (2k revenue reversal)
    L.post("2025-01-12", "Customer return", [
        ("4100", 2000.00, 0.0),    # Returns (debit)
        ("1100", 0.0, 2000.00),    # Reduce AR
    ])

    # AR collection Jan 15 (8.5k net after discount)
    L.post("2025-01-15", "Collect AR", [
        ("1000", 8500.00, 0.0),
        ("1100", 0.0, 8500.00),
    ])

    # Opex Jan 20 (3k)
    L.post("2025-01-20", "Operating expenses", [
        ("6000", 3000.00, 0.0),
        ("1000", 0.0, 3000.00),
    ])

    # Interest Jan 25 (300)
    L.post("2025-01-25", "Interest expense", [
        ("7200", 300.00, 0.0),
        ("1000", 0.0, 300.00),
    ])

    # Tax Jan 31 (500)
    L.post("2025-01-31", "Income tax", [
        ("7300", 500.00, 0.0),
        ("1000", 0.0, 500.00),
    ])
