
# backend/services/finance/seed.py
from datetime import date
from ...models.journal import Ledger, JournalEntry, JournalLine


def post_invoice(order_id: str, amount: float, je_date: date, memo: str = ""):
    """
    Invoice/Ship:
      DR 1100 Accounts Receivable
        CR 4000 Revenue
    """
    L = get_ledger()
    je = JournalEntry(
        je_id=f"INV-{order_id}-{je_date.isoformat()}",
        je_date=je_date,
        memo=memo or f"Invoice for order {order_id}",
        lines=[
            JournalLine("1100", debit=amount, credit=0.0),  # AR
            JournalLine("4000", debit=0.0, credit=amount),  # Revenue
        ],
    )
    L.post(je)

# --- Validation helpers (prevent dumb shit) ---
def _ensure_positive(name: str, value: float):
    if value is None:
        raise ValueError(f"{name} is required")
    if value < 0:
        raise ValueError(f"{name} must be >= 0, got {value}")

def _ensure_date(name: str, d):
    if d is None:
        raise ValueError(f"{name} is required")

def post_invoice(L: Ledger, order_id: str, amount: float, je_date: date, memo: str = ""):
    _ensure_positive("amount", amount); _ensure_date("je_date", je_date)
    je = JournalEntry(
        je_id=f"INV-{order_id}-{je_date.isoformat()}",
        je_date=je_date,
        memo=memo or f"Invoice for order {order_id}",
        lines=[
            JournalLine("1100", debit=amount, credit=0.0),  # AR +
            JournalLine("4000", debit=0.0, credit=amount),  # REV -
        ],
    )
    L.post(je)

def post_cash_receipt(L: Ledger, order_id: str, cash_amount: float, discount: float, je_date: date, memo: str = ""):
    _ensure_positive("cash_amount", cash_amount); _ensure_date("je_date", je_date)
    discount = discount or 0.0
    _ensure_positive("discount", discount)

    total_release = cash_amount + discount
    # Guard: you can't release more AR than exists (within this order’s window)
    # We'll compute period AR balance below in the test; here we just post cleanly.
    lines = [JournalLine("1000", debit=cash_amount, credit=0.0)]
    if discount > 0:
        lines.append(JournalLine("4100", debit=discount, credit=0.0))  # Contra-REV +
    lines.append(JournalLine("1100", debit=0.0, credit=total_release)) # AR -
    je = JournalEntry(
        je_id=f"CASH-{order_id}-{je_date.isoformat()}",
        je_date=je_date,
        memo=memo or f"Cash receipt for order {order_id}",
        lines=lines,
    )
    L.post(je)

def post_return(L: Ledger, order_id: str, return_amount: float, je_date: date, memo: str = ""):
    _ensure_positive("return_amount", return_amount); _ensure_date("je_date", je_date)
    je = JournalEntry(
        je_id=f"RET-{order_id}-{je_date.isoformat()}",
        je_date=je_date,
        memo=memo or f"Sales return for order {order_id}",
        lines=[
            JournalLine("4100", debit=return_amount, credit=0.0),  # Contra-REV +
            JournalLine("1100", debit=0.0, credit=return_amount),  # AR -
        ],
    )
    L.post(je)


def seed_ledger() -> Ledger:
    """Posts a handful of entries to prove full statements work."""
    L = Ledger()

    # T1: Sell common stock for cash (equity financing)
    L.post(JournalEntry(
        je_id="T1", je_date=date(2025, 1, 2), memo="Sell stock for cash",
        lines=[
            JournalLine("1000", debit=500_000.00),   # Cash +
            JournalLine("3000", credit=100_000.00),  # Common Stock
            JournalLine("3100", credit=400_000.00),  # APIC
        ]
    ))

    # Buy equipment (CapEx)
    L.post(JournalEntry(
        je_id="T4", je_date=date(2025, 1, 15), memo="Purchase PPE for cash",
        lines=[
            JournalLine("1500", debit=300_000.00),  # PPE
            JournalLine("1000", credit=300_000.00), # Cash
        ]
    ))

    # Purchase inventory on AP
    L.post(JournalEntry(
        je_id="INV1", je_date=date(2025, 2, 1), memo="Buy inventory on credit",
        lines=[
            JournalLine("1200", debit=120_000.00),   # Inventory
            JournalLine("2000", credit=120_000.00),  # AP
        ]
    ))

    # Sell goods on credit: Revenue & AR
    L.post(JournalEntry(
        je_id="SALE1", je_date=date(2025, 2, 15), memo="Ship product to customer on credit",
        lines=[
            JournalLine("1100", debit=180_000.00),  # AR
            JournalLine("4000", credit=180_000.00), # Revenue
        ]
    ))

    # Recognize COGS and relieve inventory
    L.post(JournalEntry(
        je_id="COGS1", je_date=date(2025, 2, 15), memo="COGS recognition",
        lines=[
            JournalLine("5000", debit=90_000.00),   # COGS
            JournalLine("1200", credit=90_000.00),  # Inventory
        ]
    ))

    # Collect some AR
    L.post(JournalEntry(
        je_id="ARCOLL1", je_date=date(2025, 3, 5), memo="AR collection",
        lines=[
            JournalLine("1000", debit=160_000.00),  # Cash
            JournalLine("1100", credit=160_000.00), # AR
        ]
    ))

    # Pay some AP
    L.post(JournalEntry(
        je_id="APPMT1", je_date=date(2025, 3, 10), memo="Pay suppliers",
        lines=[
            JournalLine("2000", debit=80_000.00),   # AP
            JournalLine("1000", credit=80_000.00),  # Cash
        ]
    ))

    # Record OpEx (SG&A)
    L.post(JournalEntry(
        je_id="OPEX1", je_date=date(2025, 3, 20), memo="Monthly SG&A",
        lines=[
            JournalLine("6000", debit=40_000.00),   # SG&A
            JournalLine("2000", credit=20_000.00),  # AP
            JournalLine("1000", credit=20_000.00),  # Cash
        ]
    ))

    # Monthly depreciation
    L.post(JournalEntry(
        je_id="DEPR1", je_date=date(2025, 3, 31), memo="Monthly depreciation",
        lines=[
            JournalLine("6300", debit=5_000.00),    # Depreciation Expense
            JournalLine("1590", credit=5_000.00),   # Accumulated Depreciation
        ]
    ))

    # Income tax accrual (simple)
    L.post(JournalEntry(
        je_id="TAX1", je_date=date(2025, 3, 31), memo="Tax expense accrual",
        lines=[
            JournalLine("7300", debit=6_000.00),    # Income Tax Expense
            JournalLine("2700", credit=6_000.00),   # Taxes Payable
        ]
    ))


    ## --- Demo postings for sanity check ---
    #post_invoice(L, order_id="1001", amount=10000.0, je_date=date(2025, 1, 16))
    #post_cash_receipt(L, order_id="1001", cash_amount=8500.0, discount=500.0, je_date=date(2025, 1, 20))
    #post_return(L, order_id="1001", return_amount=2000.0, je_date=date(2025, 1, 22))

    # Multi-order demo (optional, but helpful)
    #post_invoice(L, "A", 12000.0, date(2025,1,5))
    #post_cash_receipt(L, "A", 10000.0, 0.0, date(2025,1,9))

    #post_invoice(L, "B", 8000.0, date(2025,1,10))
    #post_return(L, "B", 1000.0, date(2025,1,12))
    #post_cash_receipt(L, "B", 5500.0, 500.0, date(2025,1,14))

    #post_invoice(L, "C", 5000.0, date(2025,1,20))
    # leave C open (no cash yet)


    return L
