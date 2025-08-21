
# backend/services/finance/seed.py
from datetime import date
from ...models.journal import Ledger, JournalEntry, JournalLine

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

    return L
