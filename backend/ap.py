# backend/ap.py
from fastapi import APIRouter
from datetime import date
from pydantic import BaseModel
from backend.services.finance.ledger_store import get_ledger
from backend.models.journal import JournalEntry, JournalLine

router = APIRouter(prefix="/ap", tags=["Accounts Payable"])

class SupplierBillRequest(BaseModel):
    bill_id: str
    supplier_id: str
    bill_date: date
    amount: float
    description: str = ""
    capitalize_to_inventory: bool = True  # True=DR 1200 Inventory; False=DR 6000 SG&A

class SupplierPaymentRequest(BaseModel):
    payment_id: str
    supplier_id: str
    payment_date: date
    amount_invoice: float
    amount_paid: float
    discount_taken: float = 0.0
    memo: str = ""

@router.post("/bill")
def enter_supplier_bill(req: SupplierBillRequest):
    """
    Record supplier invoice.
      If capitalize_to_inventory:
         DR 1200 Inventory ........ amount
      else:
         DR 6000 SG&A Expense ..... amount
      CR 2000 Accounts Payable .... amount
    """
    L = get_ledger()
    debit_acct = "1200" if req.capitalize_to_inventory else "6000"
    lines = [
        JournalLine(debit_acct, debit=round(req.amount, 2)),
        JournalLine("2000",       credit=round(req.amount, 2)),
    ]
    je = JournalEntry(
        je_id=f"APB-{req.bill_id}",
        je_date=req.bill_date,
        memo=req.description or f"Supplier bill {req.bill_id} - {req.supplier_id}",
        lines=lines
    )
    L.post(je)
    return {"posted": True, "journal_id": je.je_id, "lines": [l.__dict__ for l in lines]}

@router.post("/pay")
def pay_supplier(req: SupplierPaymentRequest):
    """
    Pay supplier with optional early-pay discount.
    JE:
      DR 2000 Accounts Payable .... amount_invoice
      CR 1000 Cash ................ amount_paid
      CR 7000 Other Income ........ discount_taken  (purchase discount)
    """
    L = get_ledger()
    lines = [
        JournalLine("2000", debit=round(req.amount_invoice, 2)),
        JournalLine("1000", credit=round(req.amount_paid, 2)),
    ]
    if req.discount_taken and req.discount_taken > 0:
        lines.append(JournalLine("7000", credit=round(req.discount_taken, 2)))  # purchase discount → other income

    je = JournalEntry(
        je_id=f"APP-{req.payment_id}",
        je_date=req.payment_date,
        memo=req.memo or f"Pay supplier {req.supplier_id}",
        lines=lines
    )
    L.post(je)
    return {"posted": True, "journal_id": je.je_id, "lines": [l.__dict__ for l in lines]}
