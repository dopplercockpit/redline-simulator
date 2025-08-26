# backend/ar.py
from fastapi import APIRouter
from datetime import date
from pydantic import BaseModel
from backend.services.finance.ledger_store import get_ledger
from backend.models.journal import JournalEntry, JournalLine

router = APIRouter(prefix="/ar", tags=["Accounts Receivable"])

class CashReceiptRequest(BaseModel):
    receipt_id: str
    customer_id: str
    receipt_date: date
    amount_invoice: float   # full original invoice amount being settled
    amount_received: float  # cash received
    discount_taken: float = 0.0  # early-pay discount taken (optional)
    memo: str = ""

@router.post("/receive")
def receive_cash(req: CashReceiptRequest):
    """
    Standard cash receipt with optional early-pay discount.
    JE:
      DR 1000 Cash ................. amount_received
      DR 4100 Sales Returns/Allow... discount_taken   (contra-revenue)
      CR 1100 Accounts Receivable .. amount_invoice
    """
    L = get_ledger()
    lines = [
        JournalLine("1000", debit=round(req.amount_received, 2)),
        JournalLine("1100", credit=round(req.amount_invoice, 2)),
    ]
    if req.discount_taken and req.discount_taken > 0:
        lines.insert(1, JournalLine("4100", debit=round(req.discount_taken, 2)))  # contra-revenue

    je = JournalEntry(
        je_id=f"AR-{req.receipt_id}",
        je_date=req.receipt_date,
        memo=req.memo or f"Cash receipt from {req.customer_id}",
        lines=lines
    )
    L.post(je)
    return {"posted": True, "journal_id": je.je_id, "lines": [l.__dict__ for l in lines]}
